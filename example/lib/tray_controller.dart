import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:tray_manager_winui/tray_manager_winui.dart';

class TrayController extends ChangeNotifier implements TrayListener {
  TrayController() {
    trayManager.addListener(this);
    _listenToWinUIEvents();
    _buildMenu();
    _applyMenuAndStyle();

    if (Platform.isWindows) {
      trayManager.setIcon('images/tray_icon.ico');
      trayManager.setToolTip('tray_manager_winui example');
    }
  }

  // ---------------------------------------------------------------------------
  // Menu
  // ---------------------------------------------------------------------------

  late Menu _menu;
  Menu get menu => _menu;

  late WinUIMenuItem _radioSmall;
  late WinUIMenuItem _radioMedium;
  late WinUIMenuItem _radioLarge;

  void _buildMenu() {
    _radioSmall = WinUIMenuItem.radio(
      label: 'Small',
      radioGroup: 'viewSize',
      onClick: _onRadioClick,
    );
    _radioMedium = WinUIMenuItem.radio(
      label: 'Medium',
      radioGroup: 'viewSize',
      checked: true,
      onClick: _onRadioClick,
    );
    _radioLarge = WinUIMenuItem.radio(
      label: 'Large',
      radioGroup: 'viewSize',
      onClick: _onRadioClick,
    );

    _menu = Menu(
      items: [
        WinUIMenuItem(
          label: 'Cut',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.cut),
          acceleratorText: 'Ctrl+X',
          toolTip: 'Cut selection to clipboard',
          onClick: (_) => _showSnack('Cut'),
        ),
        WinUIMenuItem(
          label: 'Copy',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.copy),
          acceleratorText: 'Ctrl+C',
          toolTip: 'Copy selection to clipboard',
          onClick: (_) => _showSnack('Copy'),
        ),
        WinUIMenuItem(
          label: 'Paste',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.paste),
          acceleratorText: 'Ctrl+V',
          disabled: true,
          toolTip: 'Paste from clipboard (disabled demo)',
        ),
        MenuItem.separator(),
        WinUIMenuItem.checkbox(
          label: 'Dark Mode',
          checked: false,
          winuiIcon: const WinUIIcon.glyph(0xE793),
          onClick: (item) {
            item.checked = !(item.checked == true);
            _applyMenuAndStyle();
          },
        ),
        WinUIMenuItem.checkbox(
          label: 'Notifications',
          checked: true,
          winuiIcon: const WinUIIcon.glyph(0xEA8F),
          onClick: (item) {
            item.checked = !(item.checked == true);
            _applyMenuAndStyle();
          },
        ),
        MenuItem.separator(),
        WinUIMenuItem.submenu(
          label: 'View',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.zoom),
          submenu: Menu(items: [_radioSmall, _radioMedium, _radioLarge]),
        ),
        WinUIMenuItem.submenu(
          label: 'More',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.more),
          submenu: Menu(
            items: [
              WinUIMenuItem(
                label: 'Settings',
                winuiIcon: WinUIIcon.symbol(WinUISymbol.setting),
                acceleratorText: 'Ctrl+,',
                onClick: (_) => _showSnack('Settings'),
              ),
              WinUIMenuItem(
                label: 'Refresh',
                winuiIcon: WinUIIcon.symbol(WinUISymbol.refresh),
                acceleratorText: 'F5',
                onClick: (_) => _showSnack('Refresh'),
              ),
              MenuItem.separator(),
              WinUIMenuItem(
                label: 'Help',
                winuiIcon: WinUIIcon.symbol(WinUISymbol.help),
                toolTip: 'Open help documentation',
                onClick: (_) => _showSnack('Help'),
              ),
            ],
          ),
        ),
        MenuItem.separator(),
        WinUIMenuItem(
          label: 'Open Log',
          onClick: (_) => _showSnack('Open Log (no icon)'),
        ),
        WinUIMenuItem(
          label: 'About',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.contact),
          onClick: (_) =>
              _showSnack('tray_manager_winui – WinUI 3 Context Menu'),
        ),
        WinUIMenuItem(
          label: 'Exit',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.cancel),
          acceleratorText: 'Alt+F4',
          onClick: (_) => exit(0),
        ),
      ],
    );
  }

  void _onRadioClick(MenuItem clicked) {
    for (final item in [_radioSmall, _radioMedium, _radioLarge]) {
      item.checked = (item == clicked);
    }
    _applyMenuAndStyle();
    if (kDebugMode) print('Radio selected: ${clicked.label}');
  }

  // ---------------------------------------------------------------------------
  // Style
  // ---------------------------------------------------------------------------

  WinUIContextMenuStyle? _style = const WinUIContextMenuStyle(
    backgroundColor: Color(0xFF2D2D2D),
    textColor: Color(0xFFFFFFFF),
    fontSize: 14,
    cornerRadius: 8,
    themeMode: WinUIThemeMode.dark,
  );

  WinUIContextMenuStyle? get style => _style;

  set style(WinUIContextMenuStyle? value) {
    _style = value;
    _applyMenuAndStyle();
    notifyListeners();
  }

  void _applyMenuAndStyle() {
    TrayManagerWinUI.instance.setContextMenu(_menu, style: _style);
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  final List<String> _eventLog = [];
  List<String> get eventLog => List.unmodifiable(_eventLog);

  final List<StreamSubscription<dynamic>> _subs = [];

  void _listenToWinUIEvents() {
    final winui = TrayManagerWinUI.instance;
    _subs.add(winui.onMenuItemClick.listen(_onMenuItemClick));
    _subs.add(winui.onMenuOpening.listen((_) => _addEvent('Opening')));
    _subs.add(winui.onMenuClosing.listen((_) => _addEvent('Closing')));
    _subs.add(winui.onMenuClosed.listen((_) => _addEvent('Closed')));
  }

  void _onMenuItemClick(MenuItem item) {
    if (kDebugMode) print('WinUI Menu clicked: ${item.label}');
    _addEvent('Click: ${item.label}');
  }

  void _addEvent(String name) {
    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    _eventLog.insert(0, '$ts  $name');
    if (_eventLog.length > 50) _eventLog.removeLast();
    notifyListeners();
  }

  void clearEventLog() {
    _eventLog.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // SnackBar bridge – set by the app shell so we can show messages from here.
  // ---------------------------------------------------------------------------

  GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  void _showSnack(String text) {
    scaffoldMessengerKey?.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Show menu (can be called from UI button too)
  // ---------------------------------------------------------------------------

  Future<void> showMenu() async {
    await TrayManagerWinUI.instance.showContextMenu();
  }

  // ---------------------------------------------------------------------------
  // TrayListener
  // ---------------------------------------------------------------------------

  @override
  void onTrayIconRightMouseDown() {
    if (kDebugMode) print('onTrayIconRightMouseDown');
    TrayManagerWinUI.instance.showContextMenu();
  }

  @override
  void onTrayIconRightMouseUp() {}
  @override
  void onTrayIconMouseDown() {}
  @override
  void onTrayIconMouseUp() {}
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {}

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    trayManager.removeListener(this);
    super.dispose();
  }
}
