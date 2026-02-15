#include "include/tray_manager_winui/tray_manager_winui_plugin.h"
#include "winui_context_menu.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <optional>
#include <string>

namespace tray_manager_winui {

namespace {

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel;

}  // namespace

class TrayManagerWinuiPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(
      flutter::PluginRegistrarWindows* registrar);

  TrayManagerWinuiPlugin(flutter::PluginRegistrarWindows* registrar);

  virtual ~TrayManagerWinuiPlugin();

  TrayManagerWinuiPlugin(const TrayManagerWinuiPlugin&) = delete;
  TrayManagerWinuiPlugin& operator=(const TrayManagerWinuiPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::PluginRegistrarWindows* registrar_;
  flutter::EncodableMap cached_menu_;
  flutter::EncodableMap cached_style_;
};

void TrayManagerWinuiPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  g_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "tray_manager_winui",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<TrayManagerWinuiPlugin>(registrar);

  g_channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

TrayManagerWinuiPlugin::TrayManagerWinuiPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {}

TrayManagerWinuiPlugin::~TrayManagerWinuiPlugin() {}

void TrayManagerWinuiPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() == "setContextMenu") {
    const auto& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    cached_menu_ =
        std::get<flutter::EncodableMap>(args.at(flutter::EncodableValue("menu")));
    auto style_it = args.find(flutter::EncodableValue("style"));
    if (style_it != args.end()) {
      const auto* style_map = std::get_if<flutter::EncodableMap>(&style_it->second);
      cached_style_ = style_map ? *style_map : flutter::EncodableMap();
    } else {
      cached_style_.clear();
    }
    TriggerWinUIPreInitialization();
    result->Success(flutter::EncodableValue(true));
  } else if (method_call.method_name() == "showContextMenu") {
    if (cached_menu_.empty()) {
      result->Success(flutter::EncodableValue(false));
      return;
    }
    std::optional<double> pos_x;
    std::optional<double> pos_y;
    std::optional<std::string> placement;

    const auto* encodable_args = method_call.arguments();
    const auto* args =
        encodable_args ? std::get_if<flutter::EncodableMap>(encodable_args)
                       : nullptr;
    if (args) {
      auto get_double = [&](const char* key) -> std::optional<double> {
        auto it = args->find(flutter::EncodableValue(key));
        if (it == args->end()) return std::nullopt;
        const auto* d = std::get_if<double>(&it->second);
        if (d) return *d;
        const auto* i = std::get_if<int32_t>(&it->second);
        if (i) return static_cast<double>(*i);
        return std::nullopt;
      };
      auto get_string = [&](const char* key) -> std::optional<std::string> {
        auto it = args->find(flutter::EncodableValue(key));
        if (it == args->end()) return std::nullopt;
        const auto* s = std::get_if<std::string>(&it->second);
        return s ? std::optional<std::string>(*s) : std::nullopt;
      };
      pos_x = get_double("x");
      pos_y = get_double("y");
      placement = get_string("placement");
    }

    bool shown = ShowWinUIContextMenu(cached_menu_, cached_style_,
                                      g_channel.get(), pos_x, pos_y, placement);
    result->Success(flutter::EncodableValue(shown));
  } else {
    result->NotImplemented();
  }
}

}  // namespace tray_manager_winui

void TrayManagerWinuiPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  tray_manager_winui::TrayManagerWinuiPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
