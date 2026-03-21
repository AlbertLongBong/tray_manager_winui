import 'dart:async';
import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:tray_manager_winui/tray_manager_winui.dart';
import 'package:tray_manager_winui_example/pages/home.dart';
import 'package:tray_manager_winui_example/pages/style_playground.dart';

class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> with TrayListener {
  Menu? _menu;
  WinUIContextMenuStyle? _currentStyle;
  final List<String> _eventLog = [];
  final List<StreamSubscription> _subs = [];

  late final WinUIMenuItem _radioSmall;
  late final WinUIMenuItem _radioMedium;
  late final WinUIMenuItem _radioLarge;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    _setupWinUIMenu();
    if (Platform.isWindows) {
      trayManager.setIcon('images/tray_icon.ico');
      trayManager.setToolTip('tray_manager_winui example');
    }
  }

  void _onRadioClick(MenuItem clicked) {
    for (final item in [_radioSmall, _radioMedium, _radioLarge]) {
      item.checked = (item == clicked);
    }
    _applyMenuStyle();
    if (kDebugMode) {
      print('Radio selected: ${clicked.label}');
    }
  }

  void _setupWinUIMenu() {
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
          onClick: (_) => BotToast.showText(text: 'Cut'),
        ),
        WinUIMenuItem(
          label: 'Copy',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.copy),
          acceleratorText: 'Ctrl+C',
          toolTip: 'Copy selection to clipboard',
          onClick: (_) => BotToast.showText(text: 'Copy'),
        ),
        WinUIMenuItem(
          label: 'Paste',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.paste),
          acceleratorText: 'Ctrl+V',
          disabled: true,
          toolTip: 'Paste from clipboard',
        ),
        MenuItem.separator(),
        WinUIMenuItem.checkbox(
          label: 'Dark Mode',
          checked: false,
          winuiIcon: const WinUIIcon.glyph(0xE793),
          onClick: (item) {
            item.checked = !(item.checked == true);
            if (kDebugMode) print('Dark Mode: ${item.checked}');
          },
        ),
        WinUIMenuItem.checkbox(
          label: 'Notifications',
          checked: true,
          winuiIcon: const WinUIIcon.glyph(0xEA8F),
          onClick: (item) {
            item.checked = !(item.checked == true);
          },
        ),
        MenuItem.separator(),
        WinUIMenuItem.submenu(
          label: 'View',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.zoom),
          submenu: Menu(
            items: [
              _radioSmall,
              _radioMedium,
              _radioLarge,
            ],
          ),
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
                onClick: (_) => BotToast.showText(text: 'Settings'),
              ),
              WinUIMenuItem(
                label: 'Refresh',
                winuiIcon: WinUIIcon.symbol(WinUISymbol.refresh),
                acceleratorText: 'F5',
                onClick: (_) => BotToast.showText(text: 'Refresh'),
              ),
              MenuItem.separator(),
              WinUIMenuItem(
                label: 'Help',
                winuiIcon: WinUIIcon.symbol(WinUISymbol.help),
                toolTip: 'Open help documentation',
                onClick: (_) => BotToast.showText(text: 'Help'),
              ),
            ],
          ),
        ),
        MenuItem.separator(),
        WinUIMenuItem(
          label: 'About',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.contact),
          onClick: (_) {
            BotToast.showText(
                text: 'tray_manager_winui – WinUI 3 Context Menu');
          },
        ),
        WinUIMenuItem(
          label: 'Exit',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.cancel),
          acceleratorText: 'Alt+F4',
          onClick: (_) => exit(0),
        ),
      ],
    );

    _currentStyle = const WinUIContextMenuStyle(
      backgroundColor: Color(0xFF2D2D2D),
      textColor: Color(0xFFFFFFFF),
      fontSize: 14,
      cornerRadius: 8,
      themeMode: WinUIThemeMode.dark,
    );
    _applyMenuStyle();

    final winui = TrayManagerWinUI.instance;
    _subs.add(winui.onMenuItemClick.listen(_handleMenuItemClick));
    _subs.add(winui.onMenuOpening.listen((_) => _addEvent('Opening')));
    _subs.add(winui.onMenuClosing.listen((_) => _addEvent('Closing')));
    _subs.add(winui.onMenuClosed.listen((_) => _addEvent('Closed')));
  }

  void _addEvent(String name) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _eventLog.insert(0, '$ts  $name');
      if (_eventLog.length > 20) _eventLog.removeLast();
    });
  }

  void clearEventLog() {
    setState(() => _eventLog.clear());
  }

  void _applyMenuStyle() {
    if (_menu != null) {
      TrayManagerWinUI.instance.setContextMenu(
        _menu!,
        style: _currentStyle,
      );
    }
  }

  void updateStyle(WinUIContextMenuStyle? style) {
    setState(() {
      _currentStyle = style;
      _applyMenuStyle();
    });
  }

  void _handleMenuItemClick(MenuItem menuItem) {
    if (kDebugMode) {
      print('WinUI Menu clicked: ${menuItem.label}');
    }
    BotToast.showText(text: 'Clicked: ${menuItem.label}');
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    trayManager.removeListener(this);
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    if (_menu == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('tray_manager_winui Example'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Info', icon: Icon(Icons.info_outline)),
              Tab(text: 'Styling', icon: Icon(Icons.palette_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            HomePage(menu: _menu!),
            StylePlaygroundPage(
              menu: _menu!,
              initialStyle: _currentStyle,
              onStyleChanged: updateStyle,
              eventLog: _eventLog,
              onClearLog: clearEventLog,
            ),
          ],
        ),
      ),
    );
  }
}
