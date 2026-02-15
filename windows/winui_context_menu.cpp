#include "winui_context_menu.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <chrono>
#include <condition_variable>
#include <future>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>

#if defined(TRAY_MANAGER_WINUI_USE_WINUI) && TRAY_MANAGER_WINUI_USE_WINUI

#include <Windows.h>
#undef GetCurrentTime  // Avoid conflict with WinRT animation interface
#include <winrt/Microsoft.UI.Dispatching.h>
#include <winrt/Microsoft.UI.Interop.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Controls.Primitives.h>
#include <winrt/Microsoft.UI.Xaml.Hosting.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.Numerics.h>
#include <winrt/Windows.UI.h>
#include <winrt/Windows.UI.Text.h>
#include <winrt/Microsoft.UI.Xaml.Markup.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

#include <MddBootstrap.h>
#include <sstream>
#include <WindowsAppSDK-VersionInfo.h>

using namespace winrt;
using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;
using namespace winrt::Microsoft::UI::Xaml::Controls::Primitives;
using namespace winrt::Microsoft::UI::Xaml::Hosting;
using namespace winrt::Microsoft::UI::Xaml::Media;
using namespace winrt::Microsoft::UI::Dispatching;
using namespace winrt::Windows::UI;

namespace tray_manager_winui {

namespace {

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  int size = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (size <= 0) return std::wstring();
  std::wstring result(size - 1, 0);
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, result.data(), size);
  return result;
}

struct WinUIState {
  bool initialized = false;
  bool init_in_progress = false;
  std::condition_variable cv;
  DispatcherQueueController controller{nullptr};
  DispatcherQueue queue{nullptr};
  winrt::Microsoft::UI::Xaml::Hosting::WindowsXamlManager xamlManager{nullptr};
  std::mutex mutex;
};

WinUIState& GetWinUIState() {
  static WinUIState state;
  return state;
}

// Holder for WinUI objects; must outlive the flyout until Closed.
struct MenuHolder {
  DesktopWindowXamlSource xamlSource;
  Canvas canvas;
  MenuFlyout flyout;
};

// Data for the host window subclass to handle click-outside close.
struct MenuHostData {
  WNDPROC oldProc;
  MenuHolder* holder;
};

LRESULT CALLBACK MenuHostWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
  auto* data = reinterpret_cast<MenuHostData*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));

  if (msg == WM_ACTIVATE && LOWORD(wParam) == WA_INACTIVE && data && data->holder) {
    try {
      data->holder->flyout.Hide();
    } catch (...) {
      // Ignore; Closed handler will still run if flyout was open
    }
    data->holder = nullptr;  // Prevent double execution
  }

  if (msg == WM_DESTROY && data) {
    WNDPROC oldProc = data->oldProc;
    SetWindowLongPtr(hwnd, GWLP_USERDATA, 0);
    delete data;
    return CallWindowProc(oldProc, hwnd, msg, wParam, lParam);
  }

  return data ? CallWindowProc(data->oldProc, hwnd, msg, wParam, lParam)
              : DefWindowProc(hwnd, msg, wParam, lParam);
}

bool EnsureWinUIInitialized() {
  auto& state = GetWinUIState();
  std::lock_guard lock(state.mutex);
  if (state.initialized) return true;

  // Windows App SDK 1.5 - required for MenuFlyout.ShowAt fix (microsoft-ui-xaml#7989)
  constexpr UINT32 c_majorMinor = 0x00010005;
  constexpr PCWSTR c_versionTag = L"";
  PACKAGE_VERSION minVersion{};
  minVersion.Version = WINDOWSAPPSDK_RUNTIME_VERSION_UINT64;
  HRESULT hr = MddBootstrapInitialize2(
      c_majorMinor, c_versionTag, minVersion,
      MddBootstrapInitializeOptions_OnNoMatch_ShowUI);
  if (FAILED(hr)) {
    state.init_in_progress = false;
    state.cv.notify_all();
    return false;
  }

  // Do NOT call init_apartment: Flutter's platform thread is already STA.
  // CreateOnDedicatedThread manages its own apartment on the XAML thread.
  state.controller = DispatcherQueueController::CreateOnDedicatedThread();
  state.queue = state.controller.DispatcherQueue();

  // Initialize WinUI XAML infrastructure on the dedicated thread.
  // Must be done before creating any XAML objects.
  using XamlManager = winrt::Microsoft::UI::Xaml::Hosting::WindowsXamlManager;
  std::promise<XamlManager> xamlInitPromise;
  auto xamlInitFuture = xamlInitPromise.get_future();
  state.queue.TryEnqueue(DispatcherQueuePriority::High,
                         [&xamlInitPromise]() {
                           try {
                             auto manager = XamlManager::InitializeForCurrentThread();
                             xamlInitPromise.set_value(std::move(manager));
                           } catch (...) {
                             xamlInitPromise.set_value(XamlManager{nullptr});
                           }
                         });

  try {
    state.xamlManager = xamlInitFuture.get();
  } catch (...) {
    state.init_in_progress = false;
    state.cv.notify_all();
    return false;
  }
  if (!state.xamlManager) {
    state.init_in_progress = false;
    state.cv.notify_all();
    return false;
  }

  state.initialized = true;
  state.init_in_progress = false;
  state.cv.notify_all();
  return true;
}

// Gets optional int64 from EncodableMap (Dart int may be int32 or int64).
int64_t GetStyleInt(const flutter::EncodableMap& style, const char* key) {
  auto it = style.find(flutter::EncodableValue(key));
  if (it == style.end()) return 0;
  const auto* i32 = std::get_if<int32_t>(&it->second);
  const auto* i64 = std::get_if<int64_t>(&it->second);
  if (i32) return *i32;
  if (i64) return *i64;
  return 0;
}

// Gets optional double from EncodableMap.
double GetStyleDouble(const flutter::EncodableMap& style, const char* key) {
  auto it = style.find(flutter::EncodableValue(key));
  if (it == style.end()) return 0;
  const auto* d = std::get_if<double>(&it->second);
  return d ? *d : 0;
}

// Gets optional string from EncodableMap.
std::string GetStyleString(const flutter::EncodableMap& style, const char* key) {
  auto it = style.find(flutter::EncodableValue(key));
  if (it == style.end()) return "";
  const auto* s = std::get_if<std::string>(&it->second);
  return s ? *s : "";
}

// Gets optional bool from EncodableMap. Returns default_val when key is missing.
bool GetStyleBool(const flutter::EncodableMap& style, const char* key,
                  bool default_val = true) {
  auto it = style.find(flutter::EncodableValue(key));
  if (it == style.end()) return default_val;
  const auto* b = std::get_if<bool>(&it->second);
  return b ? *b : default_val;
}

// Maps Dart placement string to FlyoutPlacementMode. Returns true if mapped.
bool TryParsePlacement(const std::string& s,
                       FlyoutPlacementMode& out_mode) {
  if (s == "top") {
    out_mode = FlyoutPlacementMode::Top;
    return true;
  }
  if (s == "bottom") {
    out_mode = FlyoutPlacementMode::Bottom;
    return true;
  }
  if (s == "left") {
    out_mode = FlyoutPlacementMode::Left;
    return true;
  }
  if (s == "right") {
    out_mode = FlyoutPlacementMode::Right;
    return true;
  }
  if (s == "full") {
    out_mode = FlyoutPlacementMode::Full;
    return true;
  }
  if (s == "auto") {
    out_mode = FlyoutPlacementMode::Auto;
    return true;
  }
  if (s == "topEdgeAlignedLeft") {
    out_mode = FlyoutPlacementMode::TopEdgeAlignedLeft;
    return true;
  }
  if (s == "topEdgeAlignedRight") {
    out_mode = FlyoutPlacementMode::TopEdgeAlignedRight;
    return true;
  }
  if (s == "bottomEdgeAlignedLeft") {
    out_mode = FlyoutPlacementMode::BottomEdgeAlignedLeft;
    return true;
  }
  if (s == "bottomEdgeAlignedRight") {
    out_mode = FlyoutPlacementMode::BottomEdgeAlignedRight;
    return true;
  }
  if (s == "leftEdgeAlignedTop") {
    out_mode = FlyoutPlacementMode::LeftEdgeAlignedTop;
    return true;
  }
  if (s == "leftEdgeAlignedBottom") {
    out_mode = FlyoutPlacementMode::LeftEdgeAlignedBottom;
    return true;
  }
  if (s == "rightEdgeAlignedTop") {
    out_mode = FlyoutPlacementMode::RightEdgeAlignedTop;
    return true;
  }
  if (s == "rightEdgeAlignedBottom") {
    out_mode = FlyoutPlacementMode::RightEdgeAlignedBottom;
    return true;
  }
  return false;
}

// Formats 0xAARRGGBB as "#AARRGGBB" for XAML.
std::wstring ColorToXamlString(int64_t value) {
  wchar_t buf[16];
  swprintf_s(buf, L"#%02X%02X%02X%02X",
             static_cast<unsigned>((value >> 24) & 0xFF),
             static_cast<unsigned>((value >> 16) & 0xFF),
             static_cast<unsigned>((value >> 8) & 0xFF),
             static_cast<unsigned>(value & 0xFF));
  return buf;
}

// Creates SolidColorBrush from ARGB int64 (0xAARRGGBB) via XAML.
// Returns null brush if value is 0. Uses XamlReader to avoid linker issues.
Brush CreateBrushFromStyleInt(const flutter::EncodableMap& style,
                              const char* key) {
  int64_t value = GetStyleInt(style, key);
  if (value == 0) return nullptr;
  std::wstring xaml =
      std::wstring(L"<SolidColorBrush xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Color='")
      + ColorToXamlString(value) + L"'/>";
  try {
    return winrt::Microsoft::UI::Xaml::Markup::XamlReader::Load(xaml).as<Brush>();
  } catch (...) {
    return nullptr;
  }
}

void ApplyStyleToFlyout(MenuFlyout& flyout, const flutter::EncodableMap& style) {
  if (style.empty()) return;

  std::wstringstream xaml;
  xaml << L"<Style TargetType='MenuFlyoutPresenter' "
       << L"xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'>";

  int64_t hoverBg = GetStyleInt(style, "hoverBackgroundColor");
  int64_t sepColor = GetStyleInt(style, "separatorColor");
  int64_t disabledFg = GetStyleInt(style, "disabledTextColor");
  int64_t subMenuOpenedBg = GetStyleInt(style, "subMenuOpenedBackgroundColor");
  int64_t subMenuOpenedFg = GetStyleInt(style, "subMenuOpenedTextColor");
  bool needSubMenuOpenedFix = (subMenuOpenedBg == 0 && subMenuOpenedFg == 0);
  if (hoverBg != 0 || sepColor != 0 || disabledFg != 0 ||
      subMenuOpenedBg != 0 || subMenuOpenedFg != 0 || needSubMenuOpenedFix) {
    std::wstringstream themeContent;
    if (hoverBg != 0) {
      std::wstring hoverStr = ColorToXamlString(hoverBg);
      themeContent << L"<SolidColorBrush x:Key='MenuFlyoutItemBackgroundPointerOver' Color='"
                   << hoverStr << L"'/>"
                   << L"<SolidColorBrush x:Key='ToggleMenuFlyoutItemBackgroundPointerOver' Color='"
                   << hoverStr << L"'/>"
                   << L"<SolidColorBrush x:Key='MenuFlyoutSubItemBackgroundPointerOver' Color='"
                   << hoverStr << L"'/>"
                   << L"<SolidColorBrush x:Key='MenuFlyoutItemRevealBackgroundPointerOver' Color='"
                   << hoverStr << L"'/>"
                   << L"<SolidColorBrush x:Key='ToggleMenuFlyoutItemRevealBackgroundPointerOver' Color='"
                   << hoverStr << L"'/>"
                   << L"<SolidColorBrush x:Key='MenuFlyoutSubItemRevealBackgroundPointerOver' Color='"
                   << hoverStr << L"'/>";
    }
    if (sepColor != 0) {
      themeContent << L"<SolidColorBrush x:Key='MenuFlyoutSeparatorBackground' Color='"
                   << ColorToXamlString(sepColor) << L"'/>";
    }
    if (disabledFg != 0) {
      std::wstring disabledStr = ColorToXamlString(disabledFg);
      themeContent << L"<SolidColorBrush x:Key='MenuFlyoutItemForegroundDisabled' Color='"
                   << disabledStr << L"'/>"
                   << L"<SolidColorBrush x:Key='MenuFlyoutSubItemForegroundDisabled' Color='"
                   << disabledStr << L"'/>"
                   << L"<SolidColorBrush x:Key='MenuFlyoutSubItemChevronDisabled' Color='"
                   << disabledStr << L"'/>"
                   << L"<SolidColorBrush x:Key='ToggleMenuFlyoutItemForegroundDisabled' Color='"
                   << disabledStr << L"'/>"
                   << L"<SolidColorBrush x:Key='ToggleMenuFlyoutItemCheckGlyphForegroundDisabled' Color='"
                   << disabledStr << L"'/>";
    }
    if (subMenuOpenedBg != 0) {
      std::wstring subMenuBgStr = ColorToXamlString(subMenuOpenedBg);
      themeContent << L"<SolidColorBrush x:Key='MenuFlyoutSubItemBackgroundSubMenuOpened' Color='"
                   << subMenuBgStr << L"'/>"
                   << L"<SolidColorBrush x:Key='MenuFlyoutSubItemRevealBackgroundSubMenuOpened' Color='"
                   << subMenuBgStr << L"'/>";
    }
    if (subMenuOpenedFg != 0) {
      std::wstring subMenuFgStr = ColorToXamlString(subMenuOpenedFg);
      themeContent << L"<SolidColorBrush x:Key='MenuFlyoutSubItemForegroundSubMenuOpened' Color='"
                   << subMenuFgStr << L"'/>"
                   << L"<SolidColorBrush x:Key='MenuFlyoutSubItemChevronSubMenuOpened' Color='"
                   << subMenuFgStr << L"'/>";
    }
    if (needSubMenuOpenedFix) {
      std::wstring subMenuBgVal =
          (hoverBg != 0) ? ColorToXamlString(hoverBg) : std::wstring(L"#FF404040");
      int64_t textColor = GetStyleInt(style, "textColor");
      std::wstring subMenuFgVal =
          (textColor != 0) ? ColorToXamlString(textColor) : std::wstring(L"#FFFFFFFF");
      themeContent << L"<SolidColorBrush x:Key='MenuFlyoutSubItemBackgroundSubMenuOpened' Color='"
                   << subMenuBgVal << L"'/>"
                   << L"<SolidColorBrush x:Key='MenuFlyoutSubItemRevealBackgroundSubMenuOpened' Color='"
                   << subMenuBgVal << L"'/>"
                   << L"<SolidColorBrush x:Key='MenuFlyoutSubItemForegroundSubMenuOpened' Color='"
                   << subMenuFgVal << L"'/>"
                   << L"<SolidColorBrush x:Key='MenuFlyoutSubItemChevronSubMenuOpened' Color='"
                   << subMenuFgVal << L"'/>";
    }
    std::wstring content = themeContent.str();
    std::wstringstream resDict;
    resDict << L"<ResourceDictionary "
            << L"xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' "
            << L"xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'>"
            << L"<ResourceDictionary.ThemeDictionaries>"
            << L"<ResourceDictionary x:Key='Default'>" << content << L"</ResourceDictionary>"
            << L"<ResourceDictionary x:Key='Light'>" << content << L"</ResourceDictionary>"
            << L"<ResourceDictionary x:Key='Dark'>" << content << L"</ResourceDictionary>"
            << L"</ResourceDictionary.ThemeDictionaries>"
            << L"</ResourceDictionary>";
    xaml << L"<Setter Property='Resources'><Setter.Value>" << resDict.str()
         << L"</Setter.Value></Setter>";
  }

  int64_t bg = GetStyleInt(style, "backgroundColor");
  if (bg != 0) {
    xaml << L"<Setter Property='Background' "
         << L"Value='" << ColorToXamlString(bg) << L"'/>";
  }

  int64_t fg = GetStyleInt(style, "textColor");
  if (fg != 0) {
    xaml << L"<Setter Property='Foreground' "
         << L"Value='" << ColorToXamlString(fg) << L"'/>";
  }

  double fontSize = GetStyleDouble(style, "fontSize");
  if (fontSize > 0) {
    xaml << L"<Setter Property='FontSize' Value='" << fontSize << L"'/>";
  }

  std::string fontFamily = GetStyleString(style, "fontFamily");
  if (!fontFamily.empty()) {
    std::wstring wfont = Utf8ToWide(fontFamily);
    xaml << L"<Setter Property='FontFamily' Value='" << wfont << L"'/>";
  }

  double cornerRadius = GetStyleDouble(style, "cornerRadius");
  if (cornerRadius >= 0) {
    xaml << L"<Setter Property='CornerRadius' Value='" << cornerRadius << L"'/>";
  }

  auto pad_it = style.find(flutter::EncodableValue("padding"));
  if (pad_it != style.end()) {
    const auto* pad_map = std::get_if<flutter::EncodableMap>(&pad_it->second);
    if (pad_map) {
      auto get_d = [&](const char* k) {
        auto vit = pad_map->find(flutter::EncodableValue(k));
        if (vit == pad_map->end()) return 0.0;
        const auto* vd = std::get_if<double>(&vit->second);
        if (vd) return *vd;
        const auto* vi = std::get_if<int32_t>(&vit->second);
        if (vi) return static_cast<double>(*vi);
        return 0.0;
      };
      double left = get_d("left"), top = get_d("top"),
             right = get_d("right"), bottom = get_d("bottom");
      xaml << L"<Setter Property='Padding' Value='"
           << left << L"," << top << L"," << right << L"," << bottom << L"'/>";
    }
  }

  double minWidth = GetStyleDouble(style, "minWidth");
  if (minWidth > 0) {
    xaml << L"<Setter Property='MinWidth' Value='" << minWidth << L"'/>";
  }

  std::string themeMode = GetStyleString(style, "themeMode");
  if (themeMode == "light") {
    xaml << L"<Setter Property='RequestedTheme' Value='Light'/>";
  } else if (themeMode == "dark") {
    xaml << L"<Setter Property='RequestedTheme' Value='Dark'/>";
  }

  int64_t borderColor = GetStyleInt(style, "borderColor");
  if (borderColor != 0) {
    xaml << L"<Setter Property='BorderBrush' Value='"
         << ColorToXamlString(borderColor) << L"'/>";
  }

  double borderThickness = GetStyleDouble(style, "borderThickness");
  if (borderThickness > 0) {
    xaml << L"<Setter Property='BorderThickness' Value='"
         << borderThickness << L"'/>";
  }

  std::string fontStyle = GetStyleString(style, "fontStyle");
  if (fontStyle == "italic") {
    xaml << L"<Setter Property='FontStyle' Value='Italic'/>";
  } else if (fontStyle == "normal") {
    xaml << L"<Setter Property='FontStyle' Value='Normal'/>";
  }

  auto shadowIt = style.find(flutter::EncodableValue("shadowElevation"));
  if (shadowIt != style.end()) {
    double shadowElevation = GetStyleDouble(style, "shadowElevation");
    if (shadowElevation <= 0) {
      xaml << L"<Setter Property='IsDefaultShadowEnabled' Value='False'/>";
    }
    // shadowElevation > 0: WinUI default shadow (~32px) is used;
    // Translation cannot be set via Style (not a DependencyProperty)
  }

  xaml << L"</Style>";

  try {
    auto styleObj = winrt::Microsoft::UI::Xaml::Markup::XamlReader::Load(
        xaml.str()).as<Style>();
    flyout.MenuFlyoutPresenterStyle(styleObj);
  } catch (...) {
#ifndef NDEBUG
    OutputDebugStringW(L"TrayWinUI: Failed to apply MenuFlyoutPresenterStyle\n");
#endif
  }
}

// Creates compact item styles (no icon column). Returns null style on failure.
struct CompactItemStyles {
  Style menuFlyoutItemStyle{nullptr};
  Style toggleMenuFlyoutItemStyle{nullptr};
  Style menuFlyoutSubItemStyle{nullptr};
};

CompactItemStyles CreateCompactItemStyles(const flutter::EncodableMap* style_map) {
  CompactItemStyles result;
  try {
    // MenuFlyoutItem: Match WinUI template structure. Root: Grid LayoutRoot with
    // TemplateBinding Background. Inline-Hex for hoverBackgroundColor when set.
    std::wstring mfiHoverValue =
        L"{ThemeResource MenuFlyoutItemBackgroundPointerOver}";
    if (style_map) {
      int64_t h = GetStyleInt(*style_map, "hoverBackgroundColor");
      if (h != 0) mfiHoverValue = ColorToXamlString(h);
    }
    std::wstring mfiXaml = L"<Style TargetType='MenuFlyoutItem' "
        L"xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' "
        L"xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'>"
        L"<Setter Property='Background' Value='Transparent'/>"
        L"<Setter Property='Template'><Setter.Value>"
        L"<ControlTemplate TargetType='MenuFlyoutItem'>"
        L"<Grid x:Name='LayoutRoot' Background='{TemplateBinding Background}'>"
        L"<TextBlock x:Name='Text' Text='{TemplateBinding Text}' "
        L"VerticalAlignment='Center' Margin='10,0,10,0' "
        L"Foreground='{TemplateBinding Foreground}'/>"
        L"<VisualStateManager.VisualStateGroups>"
        L"<VisualStateGroup x:Name='CommonStates'>"
        L"<VisualState x:Name='Normal'/>"
        L"<VisualState x:Name='PointerOver'>"
        L"<VisualState.Setters>"
        L"<Setter Target='LayoutRoot.Background' Value='";
    mfiXaml += mfiHoverValue;
    mfiXaml += L"'/>"
        L"</VisualState.Setters></VisualState>"
        L"<VisualState x:Name='Pressed'>"
        L"<VisualState.Setters>"
        L"<Setter Target='LayoutRoot.Background' Value='";
    mfiXaml += mfiHoverValue;
    mfiXaml += L"'/>"
        L"</VisualState.Setters></VisualState>"
        L"<VisualState x:Name='Disabled'>"
        L"<VisualState.Setters>"
        L"<Setter Target='Text.Foreground' Value='{ThemeResource MenuFlyoutItemForegroundDisabled}'/>"
        L"</VisualState.Setters></VisualState>"
        L"</VisualStateGroup></VisualStateManager.VisualStateGroups>"
        L"</Grid></ControlTemplate></Setter.Value></Setter></Style>";
    result.menuFlyoutItemStyle =
        winrt::Microsoft::UI::Xaml::Markup::XamlReader::Load(mfiXaml).as<Style>();

    // ToggleMenuFlyoutItem: Two variants. If checkedIndicatorColor set: thin
    // colored stripe left (4px). Else: checkmark on far right like SubItem Chevron.
    int64_t stripeColor =
        style_map ? GetStyleInt(*style_map, "checkedIndicatorColor") : 0;
    bool useStripe = (stripeColor != 0);
    std::wstring tmiHoverValue =
        L"{ThemeResource ToggleMenuFlyoutItemBackgroundPointerOver}";
    if (style_map) {
      int64_t h = GetStyleInt(*style_map, "hoverBackgroundColor");
      if (h != 0) tmiHoverValue = ColorToXamlString(h);
    }
    std::wstring tmiXaml;
    if (useStripe) {
      std::wstring stripeColorStr = ColorToXamlString(stripeColor);
      tmiXaml = L"<Style TargetType='ToggleMenuFlyoutItem' "
          L"xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' "
          L"xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'>"
          L"<Setter Property='Background' Value='Transparent'/>"
          L"<Setter Property='Padding' Value='0,0,0,0'/>"
          L"<Setter Property='Template'><Setter.Value>"
          L"<ControlTemplate TargetType='ToggleMenuFlyoutItem'>"
          L"<Grid x:Name='LayoutRoot' Background='{TemplateBinding Background}'>"
          L"<TextBlock x:Name='TextBlock' Text='{TemplateBinding Text}' "
          L"VerticalAlignment='Center' Margin='10,0,10,0' "
          L"Foreground='{TemplateBinding Foreground}'/>"
          L"<Border x:Name='CheckStripe' Width='4' HorizontalAlignment='Left' "
          L"VerticalAlignment='Stretch' Opacity='0' Background='";
      tmiXaml += stripeColorStr;
      tmiXaml += L"'/>"
          L"<VisualStateManager.VisualStateGroups>"
          L"<VisualStateGroup x:Name='CommonStates'>"
          L"<VisualState x:Name='Normal'/>"
          L"<VisualState x:Name='PointerOver'>"
          L"<VisualState.Setters>"
          L"<Setter Target='LayoutRoot.Background' Value='";
      tmiXaml += tmiHoverValue;
      tmiXaml += L"'/>"
          L"</VisualState.Setters></VisualState>"
          L"<VisualState x:Name='Pressed'>"
          L"<VisualState.Setters>"
          L"<Setter Target='LayoutRoot.Background' Value='";
      tmiXaml += tmiHoverValue;
      tmiXaml += L"'/>"
          L"</VisualState.Setters></VisualState>"
          L"<VisualState x:Name='Disabled'>"
          L"<VisualState.Setters>"
          L"<Setter Target='TextBlock.Foreground' Value='{ThemeResource ToggleMenuFlyoutItemForegroundDisabled}'/>"
          L"</VisualState.Setters></VisualState>"
          L"</VisualStateGroup>"
          L"<VisualStateGroup x:Name='CheckStates'>"
          L"<VisualState x:Name='Unchecked'/>"
          L"<VisualState x:Name='Checked'>"
          L"<VisualState.Setters>"
          L"<Setter Target='CheckStripe.Opacity' Value='1'/>"
          L"</VisualState.Setters></VisualState>"
          L"</VisualStateGroup></VisualStateManager.VisualStateGroups>"
          L"</Grid></ControlTemplate></Setter.Value></Setter></Style>";
    } else {
      tmiXaml = L"<Style TargetType='ToggleMenuFlyoutItem' "
          L"xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' "
          L"xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'>"
          L"<Setter Property='Background' Value='Transparent'/>"
          L"<Setter Property='Template'><Setter.Value>"
          L"<ControlTemplate TargetType='ToggleMenuFlyoutItem'>"
          L"<Grid x:Name='LayoutRoot' Background='{TemplateBinding Background}'>"
          L"<Grid.ColumnDefinitions>"
          L"<ColumnDefinition Width='*'/><ColumnDefinition Width='Auto'/>"
          L"</Grid.ColumnDefinitions>"
          L"<TextBlock x:Name='TextBlock' Grid.Column='0' Text='{TemplateBinding Text}' "
          L"VerticalAlignment='Center' Margin='10,0,4,0' "
          L"Foreground='{TemplateBinding Foreground}'/>"
          L"<FontIcon x:Name='CheckGlyph' Grid.Column='1' Glyph='&#xE73E;' Opacity='0' "
          L"FontSize='10' VerticalAlignment='Center' Margin='0,0,4,0' "
          L"Foreground='{TemplateBinding Foreground}'/>"
          L"<VisualStateManager.VisualStateGroups>"
          L"<VisualStateGroup x:Name='CommonStates'>"
          L"<VisualState x:Name='Normal'/>"
          L"<VisualState x:Name='PointerOver'>"
          L"<VisualState.Setters>"
          L"<Setter Target='LayoutRoot.Background' Value='";
      tmiXaml += tmiHoverValue;
      tmiXaml += L"'/>"
          L"</VisualState.Setters></VisualState>"
          L"<VisualState x:Name='Pressed'>"
          L"<VisualState.Setters>"
          L"<Setter Target='LayoutRoot.Background' Value='";
      tmiXaml += tmiHoverValue;
      tmiXaml += L"'/>"
          L"</VisualState.Setters></VisualState>"
          L"<VisualState x:Name='Disabled'>"
          L"<VisualState.Setters>"
          L"<Setter Target='TextBlock.Foreground' Value='{ThemeResource ToggleMenuFlyoutItemForegroundDisabled}'/>"
          L"<Setter Target='CheckGlyph.Foreground' Value='{ThemeResource ToggleMenuFlyoutItemCheckGlyphForegroundDisabled}'/>"
          L"</VisualState.Setters></VisualState>"
          L"</VisualStateGroup>"
          L"<VisualStateGroup x:Name='CheckStates'>"
          L"<VisualState x:Name='Unchecked'/>"
          L"<VisualState x:Name='Checked'>"
          L"<VisualState.Setters>"
          L"<Setter Target='CheckGlyph.Opacity' Value='1'/>"
          L"</VisualState.Setters></VisualState>"
          L"</VisualStateGroup></VisualStateManager.VisualStateGroups>"
          L"</Grid></ControlTemplate></Setter.Value></Setter></Style>";
    }
    result.toggleMenuFlyoutItemStyle =
        winrt::Microsoft::UI::Xaml::Markup::XamlReader::Load(tmiXaml).as<Style>();

    // MenuFlyoutSubItem: Match WinUI default template structure for VisualState
    // compatibility. Root: Grid LayoutRoot with TemplateBinding Background.
    // SubMenuOpened must be in CommonStates (not SubMenuOpenedStates).
    // Element names: TextBlock, SubItemChevron. Chevron glyph E974.
    std::wstring hoverValue = L"{ThemeResource MenuFlyoutSubItemBackgroundPointerOver}";
    std::wstring subMenuBgValue =
        L"{ThemeResource MenuFlyoutSubItemBackgroundSubMenuOpened}";
    std::wstring subMenuFgValue;
    bool useSubMenuFg = false;
    if (style_map) {
      int64_t h = GetStyleInt(*style_map, "hoverBackgroundColor");
      if (h != 0) hoverValue = ColorToXamlString(h);
      int64_t sb = GetStyleInt(*style_map, "subMenuOpenedBackgroundColor");
      if (sb != 0) subMenuBgValue = ColorToXamlString(sb);
      int64_t sf = GetStyleInt(*style_map, "subMenuOpenedTextColor");
      if (sf != 0) {
        subMenuFgValue = ColorToXamlString(sf);
        useSubMenuFg = true;
      }
    }
    std::wstring msiXaml = L"<Style TargetType='MenuFlyoutSubItem' "
        L"xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' "
        L"xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'>"
        L"<Setter Property='Background' Value='Transparent'/>"
        L"<Setter Property='Template'><Setter.Value>"
        L"<ControlTemplate TargetType='MenuFlyoutSubItem'>"
        L"<Grid x:Name='LayoutRoot' Padding='0,0,0,0' "
        L"Background='{TemplateBinding Background}'>"
        L"<Grid.ColumnDefinitions>"
        L"<ColumnDefinition Width='*'/><ColumnDefinition Width='Auto'/>"
        L"</Grid.ColumnDefinitions>"
        L"<TextBlock x:Name='TextBlock' Grid.Column='0' Text='{TemplateBinding Text}' "
        L"VerticalAlignment='Center' Margin='10,0,4,0' "
        L"Foreground='{TemplateBinding Foreground}'/>"
        L"<FontIcon x:Name='SubItemChevron' Grid.Column='1' Glyph='&#xE974;' FontSize='12' "
        L"VerticalAlignment='Center' Margin='0,0,4,0' "
        L"Foreground='{TemplateBinding Foreground}'/>"
        L"<VisualStateManager.VisualStateGroups>"
        L"<VisualStateGroup x:Name='CommonStates'>"
        L"<VisualState x:Name='Normal'/>"
        L"<VisualState x:Name='PointerOver'>"
        L"<VisualState.Setters>"
        L"<Setter Target='LayoutRoot.Background' Value='";
    msiXaml += hoverValue;
    msiXaml += L"'/>"
        L"</VisualState.Setters></VisualState>"
        L"<VisualState x:Name='Pressed'>"
        L"<VisualState.Setters>"
        L"<Setter Target='LayoutRoot.Background' Value='";
    msiXaml += hoverValue;
    msiXaml += L"'/>"
        L"</VisualState.Setters></VisualState>"
        L"<VisualState x:Name='SubMenuOpened'>"
        L"<VisualState.Setters>"
        L"<Setter Target='LayoutRoot.Background' Value='";
    msiXaml += subMenuBgValue;
    msiXaml += L"'/>";
    if (useSubMenuFg) {
      msiXaml += L"<Setter Target='TextBlock.Foreground' Value='";
      msiXaml += subMenuFgValue;
      msiXaml += L"'/>"
          L"<Setter Target='SubItemChevron.Foreground' Value='";
      msiXaml += subMenuFgValue;
      msiXaml += L"'/>";
    }
    msiXaml += L"</VisualState.Setters></VisualState>"
        L"<VisualState x:Name='Disabled'>"
        L"<VisualState.Setters>"
        L"<Setter Target='TextBlock.Foreground' Value='{ThemeResource MenuFlyoutSubItemForegroundDisabled}'/>"
        L"<Setter Target='SubItemChevron.Foreground' Value='{ThemeResource MenuFlyoutSubItemChevronDisabled}'/>"
        L"</VisualState.Setters></VisualState>"
        L"</VisualStateGroup></VisualStateManager.VisualStateGroups>"
        L"</Grid></ControlTemplate></Setter.Value></Setter></Style>";
    result.menuFlyoutSubItemStyle =
        winrt::Microsoft::UI::Xaml::Markup::XamlReader::Load(msiXaml).as<Style>();
  } catch (...) {
#ifndef NDEBUG
    OutputDebugStringW(L"TrayWinUI: Failed to create compact item styles\n");
#endif
  }
  return result;
}

void AddMenuItemsToCollection(
    const winrt::Windows::Foundation::Collections::IVector<
        winrt::Microsoft::UI::Xaml::Controls::MenuFlyoutItemBase>& collection,
    const flutter::EncodableList& items,
    flutter::MethodChannel<flutter::EncodableValue>* channel,
    const flutter::EncodableMap* style_map,
    const CompactItemStyles* compact_styles,
    std::shared_ptr<bool> cancelCloseForToggleClick = nullptr) {
  for (const auto& item_val : items) {
    const auto* item_map = std::get_if<flutter::EncodableMap>(&item_val);
    if (!item_map) continue;

    auto get_str = [&](const char* key) -> std::string {
      auto it = item_map->find(flutter::EncodableValue(key));
      if (it == item_map->end()) return "";
      const auto* s = std::get_if<std::string>(&it->second);
      return s ? *s : "";
    };
    auto get_int = [&](const char* key) -> int {
      auto it = item_map->find(flutter::EncodableValue(key));
      if (it == item_map->end()) return 0;
      const auto* i = std::get_if<int>(&it->second);
      return i ? *i : 0;
    };
    auto get_bool = [&](const char* key) -> bool {
      auto it = item_map->find(flutter::EncodableValue(key));
      if (it == item_map->end()) return false;
      const auto* b = std::get_if<bool>(&it->second);
      return b ? *b : false;
    };

    std::string type = get_str("type");
    int id = get_int("id");
    std::string label = get_str("label");
    bool disabled = get_bool("disabled");

    if (type == "separator") {
      MenuFlyoutSeparator sep;
      if (style_map) {
        Brush sepBrush = CreateBrushFromStyleInt(*style_map, "separatorColor");
        if (sepBrush) sep.Background(sepBrush);
      }
      collection.Append(sep);
    } else if (type == "submenu") {
      MenuFlyoutSubItem sub;
      sub.Text(winrt::hstring(Utf8ToWide(label)));
      sub.IsEnabled(!disabled);
      auto sub_it = item_map->find(flutter::EncodableValue("submenu"));
      if (sub_it != item_map->end()) {
        const auto* sub_map = std::get_if<flutter::EncodableMap>(&sub_it->second);
        if (sub_map) {
          auto sub_items_it = sub_map->find(flutter::EncodableValue("items"));
          if (sub_items_it != sub_map->end()) {
            const auto* sub_items = std::get_if<flutter::EncodableList>(&sub_items_it->second);
            if (sub_items) {
              AddMenuItemsToCollection(sub.Items(), *sub_items, channel, style_map,
                                      compact_styles, cancelCloseForToggleClick);
            }
          }
        }
      }
      if (compact_styles && compact_styles->menuFlyoutSubItemStyle) {
        sub.Style(compact_styles->menuFlyoutSubItemStyle);
      }
      if (style_map) {
        double fs = GetStyleDouble(*style_map, "fontSize");
        if (fs > 0) sub.FontSize(fs);
        double itemH = GetStyleDouble(*style_map, "itemHeight");
        if (itemH > 0) sub.MinHeight(itemH);
        Brush fg = disabled && GetStyleInt(*style_map, "disabledTextColor") != 0
                       ? CreateBrushFromStyleInt(*style_map, "disabledTextColor")
                       : CreateBrushFromStyleInt(*style_map, "textColor");
        if (fg) sub.Foreground(fg);
      }
      collection.Append(sub);
    } else if (type == "checkbox") {
      ToggleMenuFlyoutItem toggle;
      toggle.Text(winrt::hstring(Utf8ToWide(label)));
      toggle.IsEnabled(!disabled);
      auto checked_it = item_map->find(flutter::EncodableValue("checked"));
      if (checked_it != item_map->end()) {
        const auto* b = std::get_if<bool>(&checked_it->second);
        toggle.IsChecked(b && *b);
      }
      toggle.Click([channel, id, cancelCloseForToggleClick](auto&&, auto&&) {
        if (cancelCloseForToggleClick) *cancelCloseForToggleClick = true;
        flutter::EncodableMap args;
        args[flutter::EncodableValue("id")] = flutter::EncodableValue(id);
        channel->InvokeMethod("onMenuItemClick",
                             std::make_unique<flutter::EncodableValue>(args));
      });
      if (compact_styles && compact_styles->toggleMenuFlyoutItemStyle) {
        toggle.Style(compact_styles->toggleMenuFlyoutItemStyle);
      }
      if (style_map) {
        double fs = GetStyleDouble(*style_map, "fontSize");
        if (fs > 0) toggle.FontSize(fs);
        double itemH = GetStyleDouble(*style_map, "itemHeight");
        if (itemH > 0) toggle.MinHeight(itemH);
        Brush fg = disabled && GetStyleInt(*style_map, "disabledTextColor") != 0
                       ? CreateBrushFromStyleInt(*style_map, "disabledTextColor")
                       : CreateBrushFromStyleInt(*style_map, "textColor");
        if (fg) toggle.Foreground(fg);
      }
      collection.Append(toggle);
    } else {
      MenuFlyoutItem item;
      item.Text(winrt::hstring(Utf8ToWide(label)));
      item.IsEnabled(!disabled);
      item.Click([channel, id](auto&&, auto&&) {
        flutter::EncodableMap args;
        args[flutter::EncodableValue("id")] = flutter::EncodableValue(id);
        channel->InvokeMethod("onMenuItemClick",
                             std::make_unique<flutter::EncodableValue>(args));
      });
      if (compact_styles && compact_styles->menuFlyoutItemStyle) {
        item.Style(compact_styles->menuFlyoutItemStyle);
      }
      if (style_map) {
        double fs = GetStyleDouble(*style_map, "fontSize");
        if (fs > 0) item.FontSize(fs);
        double itemH = GetStyleDouble(*style_map, "itemHeight");
        if (itemH > 0) item.MinHeight(itemH);
        Brush fg = disabled && GetStyleInt(*style_map, "disabledTextColor") != 0
                       ? CreateBrushFromStyleInt(*style_map, "disabledTextColor")
                       : CreateBrushFromStyleInt(*style_map, "textColor");
        if (fg) item.Foreground(fg);
      }
      collection.Append(item);
    }
  }
}

void ShowMenuOnWinUIThread(
    const flutter::EncodableMap& menu_json,
    const flutter::EncodableMap& style_json,
    flutter::MethodChannel<flutter::EncodableValue>* channel,
    std::optional<double> pos_x,
    std::optional<double> pos_y,
    std::optional<std::string> placement) {
  auto& state = GetWinUIState();
  if (!state.queue) return;

  flutter::EncodableMap menu_copy = menu_json;
  flutter::EncodableMap style_copy = style_json;
  state.queue.TryEnqueue(DispatcherQueuePriority::Normal,
                         [menu_copy, style_copy, channel, pos_x, pos_y,
                          placement]() {
    POINT pt;
    if (pos_x.has_value() && pos_y.has_value()) {
      pt.x = static_cast<LONG>(*pos_x);
      pt.y = static_cast<LONG>(*pos_y);
    } else {
      GetCursorPos(&pt);
    }

    HWND hwnd = CreateWindowExW(
        WS_EX_TOOLWINDOW | WS_EX_TOPMOST, L"Static", L"",
        WS_POPUP, pt.x, pt.y, 1, 1,
        nullptr, nullptr, GetModuleHandle(nullptr), nullptr);
    if (!hwnd) return;

    ShowWindow(hwnd, SW_SHOWNOACTIVATE);

#ifndef NDEBUG
    OutputDebugStringW(L"TrayWinUI: host window created\n");
#endif

    try {
      // Use shared_ptr to keep XAML objects alive until flyout is closed.
      // ShowAt() returns immediately; destroying canvas/flyout while menu is open causes abort().
      auto holder = std::make_shared<MenuHolder>();

      // Use Initialize(WindowId) instead of deprecated IDesktopWindowXamlSourceNative::AttachToWindow
      // (E_NOINTERFACE in unpackaged Win32 apps - WindowsAppSDK #3978)
      auto parentId = winrt::Microsoft::UI::GetWindowIdFromWindow(hwnd);
      holder->xamlSource.Initialize(parentId);

#ifndef NDEBUG
      OutputDebugStringW(L"TrayWinUI: XAML island initialized\n");
#endif

      holder->canvas.Width(1);
      holder->canvas.Height(1);
      holder->xamlSource.Content(holder->canvas);

      // Allow MenuFlyout to overlay taskbar; default true constrains to work area
      holder->xamlSource.ShouldConstrainPopupsToWorkArea(false);

      bool use_compact = GetStyleBool(style_copy, "compactItemLayout", true);
      const flutter::EncodableMap* style_ptr =
          style_copy.empty() ? nullptr : &style_copy;
      CompactItemStyles compact_styles;
      if (use_compact) {
        compact_styles = CreateCompactItemStyles(style_ptr);
      }
      auto cancelCloseForToggle = std::make_shared<bool>(false);
      auto items_it = menu_copy.find(flutter::EncodableValue("items"));
      if (items_it != menu_copy.end()) {
        const auto* items = std::get_if<flutter::EncodableList>(&items_it->second);
        if (items) {
          AddMenuItemsToCollection(
              holder->flyout.Items(), *items, channel, style_ptr,
              use_compact ? &compact_styles : nullptr, cancelCloseForToggle);
        }
      }

      if (!style_copy.empty()) {
        ApplyStyleToFlyout(holder->flyout, style_copy);
      }

      if (placement.has_value()) {
        FlyoutPlacementMode mode;
        if (TryParsePlacement(*placement, mode)) {
          holder->flyout.Placement(mode);
        }
      }

      double shadowElevation = GetStyleDouble(style_copy, "shadowElevation");
      if (shadowElevation > 0) {
        holder->flyout.Opened([holder, shadowElevation](auto&&, auto&&) {
          try {
            auto xamlRoot = holder->canvas.XamlRoot();
            if (!xamlRoot) return;
            winrt::Windows::Foundation::Collections::IVectorView<Popup> popups =
                VisualTreeHelper::GetOpenPopupsForXamlRoot(xamlRoot);
            if (popups.Size() == 0) return;
            Popup popup = popups.GetAt(0);
            UIElement child = popup.Child();
            if (!child) return;
            child.Translation(winrt::Windows::Foundation::Numerics::float3{
                0.f, 0.f, static_cast<float>(shadowElevation)});
          } catch (...) {
            // ignore; shadow is non-critical
          }
        });
      }

      holder->flyout.Closing([cancelCloseForToggle](auto&&, auto&& args) {
        if (*cancelCloseForToggle) {
          args.Cancel(true);
          *cancelCloseForToggle = false;
        }
      });
      holder->flyout.Closed([holder, hwnd](auto&&, auto&&) {
        try {
          PostMessage(hwnd, WM_CLOSE, 0, 0);
        } catch (...) {
          PostMessage(hwnd, WM_CLOSE, 0, 0);
        }
        // holder released when handler returns, tearing down XAML objects
      });

      // Subclass host window to close flyout on click outside (WM_ACTIVATE WA_INACTIVE).
      WNDPROC oldProc =
          reinterpret_cast<WNDPROC>(GetWindowLongPtr(hwnd, GWLP_WNDPROC));
      auto* hostData = new MenuHostData{oldProc, holder.get()};
      SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(hostData));
      SetWindowLongPtr(hwnd, GWLP_WNDPROC,
                      reinterpret_cast<LONG_PTR>(&MenuHostWndProc));

      // ShowAt in Loaded: ensures XAML visual tree is ready (microsoft-ui-xaml#7989).
      // SetForegroundWindow + PostMessage(WM_NULL) before ShowAt: workaround for tray menus (MS KB135788).
      holder->canvas.Loaded([holder, hwnd](auto&&, auto&&) {
        try {
          SetForegroundWindow(hwnd);
          PostMessage(hwnd, WM_NULL, 0, 0);

          auto opts =
              winrt::Microsoft::UI::Xaml::Controls::Primitives::FlyoutShowOptions();
          opts.ShowMode(FlyoutShowMode::Transient);
          winrt::Windows::Foundation::Point pos(0.0f, 0.0f);
          opts.Position(pos);

#ifndef NDEBUG
          OutputDebugStringW(L"TrayWinUI: calling ShowAt\n");
#endif

          holder->flyout.ShowAt(holder->canvas, opts);
        } catch (...) {
          DestroyWindow(hwnd);
        }
      });

    } catch (...) {
#ifndef NDEBUG
      OutputDebugStringW(L"TrayWinUI: XAML setup or ShowAt failed\n");
#endif
      DestroyWindow(hwnd);
    }
  });
}

}  // namespace

void TriggerWinUIPreInitialization() {
  auto& state = GetWinUIState();
  std::lock_guard lock(state.mutex);
  if (state.initialized || state.init_in_progress) return;
  state.init_in_progress = true;
  std::thread([]() {
    EnsureWinUIInitialized();
  }).detach();
}

bool ShowWinUIContextMenu(
    const flutter::EncodableMap& menu_json,
    const flutter::EncodableMap& style_json,
    flutter::MethodChannel<flutter::EncodableValue>* channel,
    std::optional<double> pos_x,
    std::optional<double> pos_y,
    std::optional<std::string> placement) {
  if (!channel) return false;
  try {
    auto& state = GetWinUIState();
    if (!state.initialized) {
      std::unique_lock lock(state.mutex);
      state.cv.wait_for(lock, std::chrono::seconds(8), [&state] {
        return state.initialized || !state.init_in_progress;
      });
    }
    if (!EnsureWinUIInitialized()) return false;
    ShowMenuOnWinUIThread(menu_json, style_json, channel, pos_x, pos_y,
                          placement);
    return true;
  } catch (...) {
    return false;
  }
}

}  // namespace tray_manager_winui

#else  // !TRAY_MANAGER_WINUI_USE_WINUI

namespace tray_manager_winui {

void TriggerWinUIPreInitialization() {}

bool ShowWinUIContextMenu(
    const flutter::EncodableMap&,
    const flutter::EncodableMap&,
    flutter::MethodChannel<flutter::EncodableValue>*,
    std::optional<double>,
    std::optional<double>,
    std::optional<std::string>) {
  return false;
}

}  // namespace tray_manager_winui

#endif
