import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:menu_base/menu_base.dart';

import 'winui_context_menu_style.dart';
import 'winui_flyout_placement.dart';

const _methodChannelName = 'tray_manager_winui';
const _methodOnMenuItemClick = 'onMenuItemClick';

/// Singleton for WinUI 3 context menu display.
///
/// Use alongside [tray_manager]: set the tray icon and listeners with
/// [tray_manager], but call [showContextMenu] (instead of
/// [trayManager.popUpContextMenu]) in [TrayListener.onTrayIconRightMouseDown].
///
/// On non-Windows platforms, [showContextMenu] is a no-op.
class TrayManagerWinUI {
  TrayManagerWinUI._() {
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  static final TrayManagerWinUI instance = TrayManagerWinUI._();

  final MethodChannel _channel = const MethodChannel(_methodChannelName);

  Menu? _menu;
  WinUIContextMenuStyle? _style;
  final StreamController<MenuItem> _menuItemClickController =
      StreamController<MenuItem>.broadcast();

  /// Stream of menu item clicks when using the WinUI context menu.
  Stream<MenuItem> get onMenuItemClick => _menuItemClickController.stream;

  /// Sets the context menu definition (same format as tray_manager).
  ///
  /// Call this instead of [trayManager.setContextMenu] when using WinUI menu.
  ///
  /// Optionally pass [style] to customize the appearance of the WinUI context
  /// menu (background, text color, font, corner radius, etc.).
  Future<void> setContextMenu(Menu menu, {WinUIContextMenuStyle? style}) async {
    _menu = menu;
    _style = style;
    if (!Platform.isWindows) {
      return;
    }
    final Map<String, dynamic> arguments = {
      'menu': menu.toJson(),
      if (style != null) 'style': style.toJson(),
    };
    await _channel.invokeMethod('setContextMenu', arguments);
  }

  /// Shows the WinUI context menu.
  ///
  /// Without [x] and [y], the menu appears at the current cursor position.
  /// With both [x] and [y], the menu appears at the specified screen coordinates
  /// (physical pixels).
  ///
  /// Use [placement] to control where the menu appears relative to the anchor
  /// (e.g. [WinUIFlyoutPlacement.right] for left-handed users). Default is auto.
  ///
  /// Call this from [TrayListener.onTrayIconRightMouseDown] instead of
  /// [trayManager.popUpContextMenu].
  ///
  /// On non-Windows platforms, this does nothing.
  /// Returns `true` if the menu was shown, `false` if WinUI is not available (stub).
  Future<bool> showContextMenu({
    double? x,
    double? y,
    WinUIFlyoutPlacement? placement,
  }) async {
    if (!Platform.isWindows) {
      return false;
    }
    final Map<String, dynamic> arguments = {};
    if (x != null) arguments['x'] = x;
    if (y != null) arguments['y'] = y;
    if (placement != null) arguments['placement'] = placement.name;
    final Object? result = await _channel.invokeMethod(
      'showContextMenu',
      arguments.isEmpty ? null : arguments,
    );
    final bool shown = result == true;
    if (kDebugMode && !shown) {
      debugPrint(
        'tray_manager_winui: WinUI context menu not displayed. '
        'Check: NuGet in PATH? Windows App SDK installed? '
        'See README (MddBootstrap, winget install Microsoft.WindowsAppRuntime.1.5)',
      );
    }
    return shown;
  }

  Future<dynamic> _methodCallHandler(MethodCall call) async {
    if (call.method == _methodOnMenuItemClick) {
      final int id = call.arguments['id'] as int;
      final MenuItem? menuItem = _menu?.getMenuItemById(id);
      if (menuItem != null) {
        final bool? oldChecked = menuItem.checked;
        menuItem.onClick?.call(menuItem);
        _menuItemClickController.add(menuItem);

        final bool? newChecked = menuItem.checked;
        if (oldChecked != newChecked) {
          await setContextMenu(_menu!, style: _style);
        }
      }
    }
  }
}
