# tray_manager_winui – Integration into Your App

Short guide for integrating the WinUI 3 context menu into a Flutter app.

## 1. Dependencies

```yaml
# pubspec.yaml
dependencies:
  tray_manager: ^0.5.2
  tray_manager_winui: ^0.1.0
  menu_base: ^0.1.0   # optional, often brought in by tray_manager
```

## 2. Setup in initState

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:menu_base/menu_base.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:tray_manager_winui/tray_manager_winui.dart';

class _MyAppState extends State<MyApp> with TrayListener {
  Menu? _menu;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);

    if (Platform.isWindows) {
      trayManager.setIcon('images/tray_icon.ico');
      trayManager.setToolTip('My App');
    }

    _setupContextMenu();
  }

  void _setupContextMenu() {
    _menu = Menu(
      items: [
        MenuItem(label: 'Open', onClick: (_) => /* ... */),
        MenuItem.separator(),
        MenuItem.checkbox(
          label: 'Option A',
          checked: false,
          onClick: (item) => setState(() => /* update state */),
        ),
        MenuItem.submenu(
          label: 'More',
          submenu: Menu(items: [
            MenuItem(label: 'Submenu Item', onClick: (_) => /* ... */),
          ]),
        ),
        MenuItem.separator(),
        MenuItem(label: 'Exit', onClick: (_) => exit(0)),
      ],
    );

    // Set WinUI menu (not trayManager.setContextMenu!)
    TrayManagerWinUI.instance.setContextMenu(_menu!);
    TrayManagerWinUI.instance.onMenuItemClick.listen(_handleMenuItemClick);
  }

  void _handleMenuItemClick(MenuItem item) {
    // e.g. for checkbox state updates
  }
}
```

## 3. Right-Click Opens WinUI Menu

```dart
@override
void onTrayIconRightMouseDown() {
  TrayManagerWinUI.instance.showContextMenu();
}
```

## 4. Optional: Styling

`WinUIContextMenuStyle` supports all of the following properties. All are optional – null uses the WinUI default.

```dart
TrayManagerWinUI.instance.setContextMenu(_menu!, style: const WinUIContextMenuStyle(
  // Background and border
  backgroundColor: Color(0xFF2D2D2D),
  borderColor: Color(0xFF404040),
  borderThickness: 1.0,
  cornerRadius: 8.0,

  // Layout
  padding: EdgeInsets.all(8),
  minWidth: 200,
  itemHeight: 36,
  compactItemLayout: true,  // true = compact without icon space

  // Text
  textColor: Color(0xFFFFFFFF),
  fontSize: 14,
  fontFamily: 'Segoe UI',
  fontWeight: FontWeight.w400,
  fontStyle: FontStyle.normal,

  // Theme and colors
  themeMode: WinUIThemeMode.dark,
  separatorColor: Color(0xFF505050),
  disabledTextColor: Color(0xFF808080),
  hoverBackgroundColor: Color(0xFF404040),
  subMenuOpenedBackgroundColor: Color(0xFF404040),
  subMenuOpenedTextColor: Color(0xFFFFFFFF),

  // Checkbox indicator
  checkedIndicatorColor: Color(0xFF4FC3F7),  // null = checkmark on right

  // Effects
  shadowElevation: 32,  // 0 = off, null = WinUI default
));
```

## Checklist

| Step | Done |
|------|------|
| `tray_manager` + `tray_manager_winui` in pubspec | ☐ |
| Tray icon with `trayManager.setIcon()` | ☐ |
| Menu with `TrayManagerWinUI.instance.setContextMenu()` (not trayManager) | ☐ |
| `onTrayIconRightMouseDown()` → `TrayManagerWinUI.instance.showContextMenu()` | ☐ |
| Windows App SDK installed (`winget install Microsoft.WindowsAppRuntime.1.5`) | ☐ |
