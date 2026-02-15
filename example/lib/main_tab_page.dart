import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:menu_base/menu_base.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:tray_manager_winui/tray_manager_winui.dart';
import 'package:tray_manager_winui_example/pages/home.dart';
import 'package:tray_manager_winui_example/pages/style_playground.dart';

/// Main tab container with tray listener and shared menu.
/// Holds the Menu and passes it to StylePlaygroundPage for styling.
class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> with TrayListener {
  Menu? _menu;
  WinUIContextMenuStyle? _currentStyle;

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

  void _setupWinUIMenu() {
    _menu = Menu(
      items: [
        MenuItem(label: 'Look Up "LeanFlutter"'),
        MenuItem(label: 'Search with Google'),
        MenuItem.separator(),
        MenuItem(label: 'Cut'),
        MenuItem(label: 'Copy'),
        MenuItem(label: 'Paste', disabled: true),
        MenuItem.separator(),
        MenuItem.checkbox(
          label: 'Option A',
          checked: false,
          onClick: (item) {
            item.checked = !(item.checked == true);
            if (kDebugMode) {
              print('Checkbox toggled: ${item.checked}');
            }
          },
        ),
        MenuItem.submenu(
          label: 'More',
          submenu: Menu(
            items: [
              MenuItem(label: 'Submenu 1'),
              MenuItem(label: 'Submenu 2', disabled: true),
            ],
          ),
        ),
        MenuItem.separator(),
        MenuItem(
          label: 'About',
          onClick: (_) {
            BotToast.showText(text: 'tray_manager_winui – WinUI 3 Context Menu');
          },
        ),
        MenuItem(label: 'Exit', onClick: (_) => exit(0)),
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
    TrayManagerWinUI.instance.onMenuItemClick.listen(_handleMenuItemClick);
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
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  void onTrayIconRightMouseDown() {
    if (kDebugMode) {
      print('onTrayIconRightMouseDown');
    }
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
            ),
          ],
        ),
      ),
    );
  }
}
