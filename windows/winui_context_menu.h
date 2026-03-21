#ifndef TRAY_MANAGER_WINUI_WINUI_CONTEXT_MENU_H_
#define TRAY_MANAGER_WINUI_WINUI_CONTEXT_MENU_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>
#include <optional>
#include <string>

namespace tray_manager_winui {

/// Shows a WinUI 3 MenuFlyout.
///
/// Without pos_x/pos_y, uses current cursor position. With both, uses the
/// specified screen coordinates (physical pixels).
///
/// \param menu_json Menu structure (same format as tray_manager: {"items": [...]})
/// \param style_json Optional style map (backgroundColor, textColor, fontSize, etc.)
/// \param channel Method channel to invoke "onMenuItemClick" with {"id": itemId}
/// \param pos_x Optional screen X coordinate
/// \param pos_y Optional screen Y coordinate
/// \param placement Optional placement mode (top, bottom, left, right, etc.)
/// \return true on success, false if WinUI unavailable
bool ShowWinUIContextMenu(
    const flutter::EncodableMap& menu_json,
    const flutter::EncodableMap& style_json,
    flutter::MethodChannel<flutter::EncodableValue>* channel,
    std::optional<double> pos_x = std::nullopt,
    std::optional<double> pos_y = std::nullopt,
    std::optional<std::string> placement = std::nullopt);

/// Creates a message-only window on the platform thread for safe
/// InvokeMethod callbacks from the WinUI DispatcherQueue thread.
/// Must be called during plugin registration (platform thread).
void InitPlatformCallback();

/// Destroys the callback window. Call from plugin destructor.
void DestroyPlatformCallback();

/// Starts WinUI initialization in a background thread. Call from setContextMenu
/// to avoid blocking on first showContextMenu.
void TriggerWinUIPreInitialization();

/// Shuts down WinUI infrastructure. Call from plugin destructor for clean
/// release of DispatcherQueueController and WindowsXamlManager.
void ShutdownWinUI();

}  // namespace tray_manager_winui

#endif  // TRAY_MANAGER_WINUI_WINUI_CONTEXT_MENU_H_
