#include "winui_context_menu.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <atomic>
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

std::wstring XamlEscapeAttribute(const std::wstring& input) {
  std::wstring result;
  result.reserve(input.size() + input.size() / 4);
  for (wchar_t c : input) {
    switch (c) {
      case L'&': result += L"&amp;"; break;
      case L'<': result += L"&lt;"; break;
      case L'>': result += L"&gt;"; break;
      case L'"': result += L"&quot;"; break;
      case L'\'': result += L"&apos;"; break;
      default: result += c; break;
    }
  }
  return result;
}

void DebugLog(const wchar_t* msg) {
  OutputDebugStringW(msg);
}

void DebugLog(const wchar_t* context, HRESULT hr) {
  wchar_t buf[256];
  swprintf_s(buf, L"TrayWinUI: %s (HRESULT 0x%08X)\n",
             context, static_cast<unsigned>(hr));
  OutputDebugStringW(buf);
}

// Platform-thread callback window for thread-safe InvokeMethod calls.
// Flutter requires method channel messages on the platform thread.
// WinUI event handlers run on the DispatcherQueue thread, so we
// PostMessage back to this message-only window on the platform thread.
HWND g_platformCallbackHwnd = nullptr;
constexpr UINT WM_FLUTTER_INVOKE = WM_APP + 100;

struct PendingInvoke {
  std::string method;
  flutter::EncodableValue args;
  flutter::MethodChannel<flutter::EncodableValue>* channel;
};

LRESULT CALLBACK PlatformCallbackProc(HWND hwnd, UINT msg,
                                       WPARAM wParam, LPARAM lParam) {
  if (msg == WM_FLUTTER_INVOKE) {
    auto* pending = reinterpret_cast<PendingInvoke*>(lParam);
    if (pending && pending->channel) {
      pending->channel->InvokeMethod(
          pending->method,
          std::make_unique<flutter::EncodableValue>(std::move(pending->args)));
    }
    delete pending;
    return 0;
  }
  return DefWindowProcW(hwnd, msg, wParam, lParam);
}

void InvokeOnPlatformThread(
    flutter::MethodChannel<flutter::EncodableValue>* channel,
    const std::string& method,
    flutter::EncodableValue args = flutter::EncodableValue()) {
  if (!g_platformCallbackHwnd || !channel) return;
  auto* pending = new PendingInvoke{method, std::move(args), channel};
  if (!PostMessageW(g_platformCallbackHwnd, WM_FLUTTER_INVOKE, 0,
                    reinterpret_cast<LPARAM>(pending))) {
    delete pending;
  }
}

struct WinUIState {
  bool initialized = false;
  bool init_in_progress = false;
  bool init_failed = false;
  std::condition_variable cv;
  DispatcherQueueController controller{nullptr};
  DispatcherQueue queue{nullptr};
  winrt::Microsoft::UI::Xaml::Hosting::WindowsXamlManager xamlManager{nullptr};
  std::mutex mutex;
  std::atomic<bool> menu_showing{false};
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
  std::shared_ptr<MenuHolder> holder;
};

// Thread-local hook that forces the arrow cursor on every window owned by the
// WinUI DispatcherQueue thread.  WinUI creates its own top-level popup windows
// for MenuFlyout (and submenus) which have no hCursor set in their WNDCLASS.
// Without this hook those popups show the "app starting" (spinning) cursor
// whenever the mouse rests on the flyout border or between items.
HHOOK g_cursorHook = nullptr;

LRESULT CALLBACK CursorHookProc(int nCode, WPARAM wParam, LPARAM lParam) {
  if (nCode >= 0) {
    auto* cwp = reinterpret_cast<CWPSTRUCT*>(lParam);
    if (cwp && cwp->message == WM_SETCURSOR &&
        LOWORD(cwp->lParam) == HTCLIENT) {
      SetCursor(LoadCursor(nullptr, IDC_ARROW));
    }
  }
  return CallNextHookEx(g_cursorHook, nCode, wParam, lParam);
}

void InstallCursorHook() {
  if (!g_cursorHook) {
    g_cursorHook = SetWindowsHookExW(
        WH_CALLWNDPROC, CursorHookProc, nullptr, GetCurrentThreadId());
  }
}

void RemoveCursorHook() {
  if (g_cursorHook) {
    UnhookWindowsHookEx(g_cursorHook);
    g_cursorHook = nullptr;
  }
}

LRESULT CALLBACK MenuHostWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
  auto* data = reinterpret_cast<MenuHostData*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));

  // Use WM_ACTIVATEAPP instead of WM_ACTIVATE to avoid killing the flyout
  // when WinUI opens a submenu popup (which steals focus from host window
  // but stays within the same process). WM_ACTIVATEAPP only fires when
  // focus moves to a different application.
  if (msg == WM_ACTIVATEAPP && wParam == FALSE && data && data->holder) {
    try {
      data->holder->flyout.Hide();
    } catch (const winrt::hresult_error& e) {
      DebugLog(L"MenuHostWndProc: flyout.Hide() failed", e.code());
    }
  }

  if (msg == WM_DESTROY && data) {
    WNDPROC oldProc = data->oldProc;
    SetWindowLongPtr(hwnd, GWLP_USERDATA, 0);
    data->holder.reset();
    delete data;
    GetWinUIState().menu_showing.store(false);
    return CallWindowProc(oldProc, hwnd, msg, wParam, lParam);
  }

  return data ? CallWindowProc(data->oldProc, hwnd, msg, wParam, lParam)
              : DefWindowProc(hwnd, msg, wParam, lParam);
}

bool EnsureWinUIInitialized() {
  auto& state = GetWinUIState();

  {
    std::unique_lock lock(state.mutex);
    if (state.initialized) return true;
    if (state.init_failed) return false;
    if (state.init_in_progress) {
      state.cv.wait_for(lock, std::chrono::seconds(30), [&state] {
        return state.initialized || state.init_failed;
      });
      return state.initialized;
    }
    state.init_in_progress = true;
  }

  auto fail = [&state]() {
    std::lock_guard lock(state.mutex);
    state.init_in_progress = false;
    state.init_failed = true;
    state.cv.notify_all();
  };

  // Windows App SDK 1.5 - required for MenuFlyout.ShowAt fix (microsoft-ui-xaml#7989)
  constexpr UINT32 c_majorMinor = 0x00010005;
  constexpr PCWSTR c_versionTag = L"";
  PACKAGE_VERSION minVersion{};
  minVersion.Version = WINDOWSAPPSDK_RUNTIME_VERSION_UINT64;
  HRESULT hr = MddBootstrapInitialize2(
      c_majorMinor, c_versionTag, minVersion,
      MddBootstrapInitializeOptions_OnNoMatch_ShowUI);
  if (FAILED(hr)) {
    DebugLog(L"MddBootstrapInitialize2 failed", hr);
    fail();
    return false;
  }

  // Do NOT call init_apartment: Flutter's platform thread is already STA.
  // CreateOnDedicatedThread manages its own apartment on the XAML thread.
  try {
    state.controller = DispatcherQueueController::CreateOnDedicatedThread();
    state.queue = state.controller.DispatcherQueue();
  } catch (const winrt::hresult_error& e) {
    DebugLog(L"DispatcherQueue creation failed", e.code());
    fail();
    return false;
  }

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
                           } catch (const winrt::hresult_error&) {
                             xamlInitPromise.set_value(XamlManager{nullptr});
                           }
                         });

  try {
    state.xamlManager = xamlInitFuture.get();
  } catch (const std::exception&) {
    DebugLog(L"XamlManager init failed (future exception)\n");
    fail();
    return false;
  }
  if (!state.xamlManager) {
    DebugLog(L"XamlManager init returned null\n");
    fail();
    return false;
  }

  {
    std::lock_guard lock(state.mutex);
    state.initialized = true;
    state.init_in_progress = false;
    state.cv.notify_all();
  }
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

// Parses hex icon string ("0xHHHH") and creates a FontIcon.
// Returns null IconElement on invalid input.
IconElement CreateIconFromString(const std::string& iconStr,
                                const std::string& fontFamily) {
  if (iconStr.size() < 3 || iconStr[0] != '0' ||
      (iconStr[1] != 'x' && iconStr[1] != 'X')) {
    return nullptr;
  }
  unsigned long codepoint = 0;
  try {
    codepoint = std::stoul(iconStr.substr(2), nullptr, 16);
  } catch (...) {
    return nullptr;
  }
  if (codepoint == 0 || codepoint > 0xFFFF) return nullptr;

  FontIcon fontIcon;
  wchar_t glyph[2] = {static_cast<wchar_t>(codepoint), L'\0'};
  fontIcon.Glyph(winrt::hstring(glyph));
  fontIcon.FontSize(16);

  if (!fontFamily.empty()) {
    fontIcon.FontFamily(
        Media::FontFamily(winrt::hstring(Utf8ToWide(fontFamily))));
  }
  return fontIcon;
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
    std::wstring wfont = XamlEscapeAttribute(Utf8ToWide(fontFamily));
    xaml << L"<Setter Property='FontFamily' Value='" << wfont << L"'/>";
  }

  int64_t fontWeight = GetStyleInt(style, "fontWeight");
  if (fontWeight > 0) {
    xaml << L"<Setter Property='FontWeight' Value='" << fontWeight << L"'/>";
  }

  auto cr_it = style.find(flutter::EncodableValue("cornerRadius"));
  if (cr_it != style.end()) {
    double cornerRadius = GetStyleDouble(style, "cornerRadius");
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
  }

  double maxHeight = GetStyleDouble(style, "maxHeight");
  if (maxHeight > 0) {
    xaml << L"<Setter Property='MaxHeight' Value='" << maxHeight << L"'/>";
  }

  xaml << L"</Style>";

  try {
    auto styleObj = winrt::Microsoft::UI::Xaml::Markup::XamlReader::Load(
        xaml.str()).as<Style>();
    flyout.MenuFlyoutPresenterStyle(styleObj);
  } catch (const winrt::hresult_error& e) {
    DebugLog(L"Failed to apply MenuFlyoutPresenterStyle", e.code());
  } catch (const std::exception&) {
    DebugLog(L"Failed to apply MenuFlyoutPresenterStyle (std::exception)\n");
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

    // NOTE: RadioMenuFlyoutItem compact style removed. Radio items are now
    // rendered as ToggleMenuFlyoutItem (reusing toggleMenuFlyoutItemStyle)
    // because RadioMenuFlyoutItem crashes in DesktopWindowXamlSource contexts.

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
  } catch (const winrt::hresult_error& e) {
    DebugLog(L"Failed to create compact item styles", e.code());
  } catch (const std::exception&) {
    DebugLog(L"Failed to create compact item styles (std::exception)\n");
  }
  return result;
}

// Applies common per-item styling (fontSize, itemHeight, foreground).
void ApplyItemStyling(MenuFlyoutItemBase const& itemBase,
                      const flutter::EncodableMap& style_map,
                      bool disabled) {
  double fs = GetStyleDouble(style_map, "fontSize");
  double itemH = GetStyleDouble(style_map, "itemHeight");
  Brush fg = disabled && GetStyleInt(style_map, "disabledTextColor") != 0
                 ? CreateBrushFromStyleInt(style_map, "disabledTextColor")
                 : CreateBrushFromStyleInt(style_map, "textColor");

  if (auto mfi = itemBase.try_as<MenuFlyoutItem>()) {
    if (fs > 0) mfi.FontSize(fs);
    if (itemH > 0) mfi.MinHeight(itemH);
    if (fg) mfi.Foreground(fg);
  } else if (auto sub = itemBase.try_as<MenuFlyoutSubItem>()) {
    if (fs > 0) sub.FontSize(fs);
    if (itemH > 0) sub.MinHeight(itemH);
    if (fg) sub.Foreground(fg);
  }
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
    std::string iconStr = get_str("icon");
    std::string iconFontFamily = get_str("iconFontFamily");
    std::string acceleratorText = get_str("acceleratorText");
    std::string toolTipStr = get_str("toolTip");

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
      } else if (!iconStr.empty()) {
        auto iconElem = CreateIconFromString(iconStr, iconFontFamily);
        if (iconElem) sub.Icon(iconElem);
      }
      if (!toolTipStr.empty()) {
        ToolTipService::SetToolTip(sub,
            winrt::box_value(winrt::hstring(Utf8ToWide(toolTipStr))));
      }
      if (style_map) ApplyItemStyling(sub, *style_map, disabled);
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
        InvokeOnPlatformThread(channel, "onMenuItemClick",
                               flutter::EncodableValue(std::move(args)));
      });
      if (compact_styles && compact_styles->toggleMenuFlyoutItemStyle) {
        toggle.Style(compact_styles->toggleMenuFlyoutItemStyle);
      } else if (!iconStr.empty()) {
        auto iconElem = CreateIconFromString(iconStr, iconFontFamily);
        if (iconElem) toggle.Icon(iconElem);
      }
      if (!toolTipStr.empty()) {
        ToolTipService::SetToolTip(toggle,
            winrt::box_value(winrt::hstring(Utf8ToWide(toolTipStr))));
      }
      if (style_map) ApplyItemStyling(toggle, *style_map, disabled);
      collection.Append(toggle);

    } else if (type == "radio") {
      // Render radio items as ToggleMenuFlyoutItem instead of
      // RadioMenuFlyoutItem. RadioMenuFlyoutItem crashes in
      // DesktopWindowXamlSource contexts due to internal visual-tree
      // traversal in its radio-group management code. The mutual-
      // exclusion logic is handled on the Dart side already (the
      // onClick callback updates checked state and calls setContextMenu).
      ToggleMenuFlyoutItem radio;
      radio.Text(winrt::hstring(Utf8ToWide(label)));
      radio.IsEnabled(!disabled);
      auto checked_it = item_map->find(flutter::EncodableValue("checked"));
      if (checked_it != item_map->end()) {
        const auto* b = std::get_if<bool>(&checked_it->second);
        radio.IsChecked(b && *b);
      }
      radio.Click([channel, id, cancelCloseForToggleClick](auto&&, auto&&) {
        if (cancelCloseForToggleClick) *cancelCloseForToggleClick = true;
        flutter::EncodableMap args;
        args[flutter::EncodableValue("id")] = flutter::EncodableValue(id);
        InvokeOnPlatformThread(channel, "onMenuItemClick",
                               flutter::EncodableValue(std::move(args)));
      });
      if (compact_styles && compact_styles->toggleMenuFlyoutItemStyle) {
        radio.Style(compact_styles->toggleMenuFlyoutItemStyle);
      } else if (!iconStr.empty()) {
        auto iconElem = CreateIconFromString(iconStr, iconFontFamily);
        if (iconElem) radio.Icon(iconElem);
      }
      if (!acceleratorText.empty()) {
        radio.KeyboardAcceleratorTextOverride(
            winrt::hstring(Utf8ToWide(acceleratorText)));
      }
      if (!toolTipStr.empty()) {
        ToolTipService::SetToolTip(radio,
            winrt::box_value(winrt::hstring(Utf8ToWide(toolTipStr))));
      }
      if (style_map) ApplyItemStyling(radio, *style_map, disabled);
      collection.Append(radio);

    } else {
      MenuFlyoutItem item;
      item.Text(winrt::hstring(Utf8ToWide(label)));
      item.IsEnabled(!disabled);
      item.Click([channel, id](auto&&, auto&&) {
        flutter::EncodableMap args;
        args[flutter::EncodableValue("id")] = flutter::EncodableValue(id);
        InvokeOnPlatformThread(channel, "onMenuItemClick",
                               flutter::EncodableValue(std::move(args)));
      });
      if (compact_styles && compact_styles->menuFlyoutItemStyle) {
        item.Style(compact_styles->menuFlyoutItemStyle);
      } else if (!iconStr.empty()) {
        auto iconElem = CreateIconFromString(iconStr, iconFontFamily);
        if (iconElem) item.Icon(iconElem);
      }
      if (!acceleratorText.empty()) {
        item.KeyboardAcceleratorTextOverride(
            winrt::hstring(Utf8ToWide(acceleratorText)));
      }
      if (!toolTipStr.empty()) {
        ToolTipService::SetToolTip(item,
            winrt::box_value(winrt::hstring(Utf8ToWide(toolTipStr))));
      }
      if (style_map) ApplyItemStyling(item, *style_map, disabled);
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

  bool expected = false;
  if (!state.menu_showing.compare_exchange_strong(expected, true)) {
    return;
  }

  flutter::EncodableMap menu_copy = menu_json;
  flutter::EncodableMap style_copy = style_json;
  state.queue.TryEnqueue(DispatcherQueuePriority::Normal,
                         [menu_copy, style_copy, channel, pos_x, pos_y,
                          placement]() {
    auto prevDpiContext = SetThreadDpiAwarenessContext(
        DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

    POINT pt;
    if (pos_x.has_value() && pos_y.has_value()) {
      pt.x = static_cast<LONG>(*pos_x);
      pt.y = static_cast<LONG>(*pos_y);
    } else {
      GetCursorPos(&pt);
    }

    static const wchar_t* kMenuHostClass = L"TrayWinUIMenuHost";
    static bool class_registered = false;
    if (!class_registered) {
      WNDCLASSW wc = {};
      wc.lpfnWndProc = DefWindowProcW;
      wc.hInstance = GetModuleHandle(nullptr);
      wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
      wc.lpszClassName = kMenuHostClass;
      RegisterClassW(&wc);
      class_registered = true;
    }

    HWND hwnd = CreateWindowExW(
        WS_EX_TOOLWINDOW | WS_EX_TOPMOST, kMenuHostClass, L"",
        WS_POPUP, pt.x, pt.y, 1, 1,
        nullptr, nullptr, GetModuleHandle(nullptr), nullptr);

    if (prevDpiContext) {
      SetThreadDpiAwarenessContext(prevDpiContext);
    }

    if (!hwnd) {
      GetWinUIState().menu_showing.store(false);
      return;
    }

    InstallCursorHook();

    ShowWindow(hwnd, SW_SHOWNOACTIVATE);

    DebugLog(L"TrayWinUI: host window created\n");

    try {
      // Use shared_ptr to keep XAML objects alive until flyout is closed.
      // ShowAt() returns immediately; destroying canvas/flyout while menu is open causes abort().
      auto holder = std::make_shared<MenuHolder>();

      // Use Initialize(WindowId) instead of deprecated IDesktopWindowXamlSourceNative::AttachToWindow
      // (E_NOINTERFACE in unpackaged Win32 apps - WindowsAppSDK #3978)
      auto parentId = winrt::Microsoft::UI::GetWindowIdFromWindow(hwnd);
      holder->xamlSource.Initialize(parentId);

      DebugLog(L"TrayWinUI: XAML island initialized\n");

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

        auto animIt = style_copy.find(flutter::EncodableValue("enableOpenCloseAnimations"));
        if (animIt != style_copy.end()) {
          const auto* b = std::get_if<bool>(&animIt->second);
          if (b && !*b) {
            holder->flyout.AreOpenCloseAnimationsEnabled(false);
          }
        }
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

      holder->flyout.Opening([channel](auto&&, auto&&) {
        InvokeOnPlatformThread(channel, "onMenuOpening");
      });
      holder->flyout.Closing([cancelCloseForToggle, channel](auto&&, auto&& args) {
        if (*cancelCloseForToggle) {
          args.Cancel(true);
          *cancelCloseForToggle = false;
          return;
        }
        InvokeOnPlatformThread(channel, "onMenuClosing");
      });
      holder->flyout.Closed([holder, hwnd, channel](auto&&, auto&&) {
        RemoveCursorHook();
        InvokeOnPlatformThread(channel, "onMenuClosed");
        PostMessage(hwnd, WM_CLOSE, 0, 0);
      });

      // Subclass host window to close flyout when another app gets focus (WM_ACTIVATEAPP).
      WNDPROC oldProc =
          reinterpret_cast<WNDPROC>(GetWindowLongPtr(hwnd, GWLP_WNDPROC));
      auto* hostData = new MenuHostData{oldProc, holder};
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

          DebugLog(L"TrayWinUI: calling ShowAt\n");

          holder->flyout.ShowAt(holder->canvas, opts);
        } catch (const winrt::hresult_error& e) {
          DebugLog(L"ShowAt failed", e.code());
          RemoveCursorHook();
          DestroyWindow(hwnd);
        } catch (...) {
          DebugLog(L"TrayWinUI: ShowAt failed (unknown exception)\n");
          RemoveCursorHook();
          DestroyWindow(hwnd);
        }
      });

    } catch (const winrt::hresult_error& e) {
      DebugLog(L"XAML setup failed", e.code());
      RemoveCursorHook();
      GetWinUIState().menu_showing.store(false);
      DestroyWindow(hwnd);
    } catch (...) {
      DebugLog(L"TrayWinUI: XAML setup failed (unknown exception)\n");
      RemoveCursorHook();
      GetWinUIState().menu_showing.store(false);
      DestroyWindow(hwnd);
    }
  });
}

}  // namespace

void InitPlatformCallback() {
  static bool registered = false;
  if (!registered) {
    WNDCLASSW wc = {};
    wc.lpfnWndProc = PlatformCallbackProc;
    wc.hInstance = GetModuleHandle(nullptr);
    wc.lpszClassName = L"TrayWinUICallbackWnd";
    RegisterClassW(&wc);
    registered = true;
  }
  g_platformCallbackHwnd = CreateWindowExW(
      0, L"TrayWinUICallbackWnd", L"", 0,
      0, 0, 0, 0, HWND_MESSAGE, nullptr, GetModuleHandle(nullptr), nullptr);
}

void DestroyPlatformCallback() {
  if (g_platformCallbackHwnd) {
    DestroyWindow(g_platformCallbackHwnd);
    g_platformCallbackHwnd = nullptr;
  }
}

void TriggerWinUIPreInitialization() {
  auto& state = GetWinUIState();
  std::lock_guard lock(state.mutex);
  if (state.initialized || state.init_in_progress || state.init_failed) return;
  std::thread([]() {
    EnsureWinUIInitialized();
  }).detach();
}

void ShutdownWinUI() {
  auto& state = GetWinUIState();
  std::lock_guard lock(state.mutex);
  if (!state.initialized) return;
  try {
    if (state.xamlManager) {
      state.xamlManager.Close();
      state.xamlManager = nullptr;
    }
    if (state.controller) {
      state.controller.ShutdownQueueAsync();
      state.controller = nullptr;
    }
    state.queue = nullptr;
  } catch (const winrt::hresult_error& e) {
    DebugLog(L"ShutdownWinUI error", e.code());
  }
  state.initialized = false;
  try {
    MddBootstrapShutdown();
  } catch (...) {}
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
    if (!EnsureWinUIInitialized()) return false;
    ShowMenuOnWinUIThread(menu_json, style_json, channel, pos_x, pos_y,
                          placement);
    return true;
  } catch (const winrt::hresult_error& e) {
    DebugLog(L"ShowWinUIContextMenu error", e.code());
    return false;
  } catch (...) {
    DebugLog(L"ShowWinUIContextMenu: unknown exception\n");
    return false;
  }
}

}  // namespace tray_manager_winui

#else  // !TRAY_MANAGER_WINUI_USE_WINUI

namespace tray_manager_winui {

void InitPlatformCallback() {}
void DestroyPlatformCallback() {}
void TriggerWinUIPreInitialization() {}

void ShutdownWinUI() {}

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
