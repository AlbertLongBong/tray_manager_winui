# tray_manager_winui – Implementierung in deine App

Kurze Anleitung zur Integration des WinUI 3 Kontextmenüs in eine Flutter-App.

## 1. Dependencies

```yaml
# pubspec.yaml
dependencies:
  tray_manager: ^0.5.2
  tray_manager_winui: ^0.1.0
  menu_base: ^0.1.0   # optional, wird oft von tray_manager mitgebracht
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
      trayManager.setToolTip('Meine App');
    }

    _setupContextMenu();
  }

  void _setupContextMenu() {
    _menu = Menu(
      items: [
        MenuItem(label: 'Öffnen', onClick: (_) => /* ... */),
        MenuItem.separator(),
        MenuItem.checkbox(
          label: 'Option A',
          checked: false,
          onClick: (item) => setState(() => /* update state */),
        ),
        MenuItem.submenu(
          label: 'Mehr',
          submenu: Menu(items: [
            MenuItem(label: 'Unterpunkt', onClick: (_) => /* ... */),
          ]),
        ),
        MenuItem.separator(),
        MenuItem(label: 'Beenden', onClick: (_) => exit(0)),
      ],
    );

    // WinUI-Menü setzen (nicht trayManager.setContextMenu!)
    TrayManagerWinUI.instance.setContextMenu(_menu!);
    TrayManagerWinUI.instance.onMenuItemClick.listen(_handleMenuItemClick);
  }

  void _handleMenuItemClick(MenuItem item) {
    // Z.B. für Checkbox-State-Updates
  }
}
```

## 3. Rechtsklick öffnet WinUI-Menü

```dart
@override
void onTrayIconRightMouseDown() {
  TrayManagerWinUI.instance.showContextMenu();
}
```

## 4. Optional: Styling

`WinUIContextMenuStyle` unterstützt alle folgenden Properties. Alle sind optional – null nutzt den WinUI-Standard.

```dart
TrayManagerWinUI.instance.setContextMenu(_menu!, style: const WinUIContextMenuStyle(
  // Hintergrund und Rahmen
  backgroundColor: Color(0xFF2D2D2D),
  borderColor: Color(0xFF404040),
  borderThickness: 1.0,
  cornerRadius: 8.0,

  // Layout
  padding: EdgeInsets.all(8),
  minWidth: 200,
  itemHeight: 36,
  compactItemLayout: true,  // true = kompakt ohne Icon-Platz

  // Text
  textColor: Color(0xFFFFFFFF),
  fontSize: 14,
  fontFamily: 'Segoe UI',
  fontWeight: FontWeight.w400,
  fontStyle: FontStyle.normal,

  // Theme und Farben
  themeMode: WinUIThemeMode.dark,
  separatorColor: Color(0xFF505050),
  disabledTextColor: Color(0xFF808080),
  hoverBackgroundColor: Color(0xFF404040),
  subMenuOpenedBackgroundColor: Color(0xFF404040),
  subMenuOpenedTextColor: Color(0xFFFFFFFF),

  // Checkbox-Indikator
  checkedIndicatorColor: Color(0xFF4FC3F7),  // null = Häkchen rechts

  // Effekte
  shadowElevation: 32,  // 0 = aus, null = WinUI-Standard
));
```

## Checkliste

| Schritt | Erledigt |
|---------|----------|
| `tray_manager` + `tray_manager_winui` in pubspec | ☐ |
| Tray-Icon mit `trayManager.setIcon()` | ☐ |
| Menü mit `TrayManagerWinUI.instance.setContextMenu()` (nicht trayManager) | ☐ |
| `onTrayIconRightMouseDown()` → `TrayManagerWinUI.instance.showContextMenu()` | ☐ |
| Windows App SDK installiert (`winget install Microsoft.WindowsAppRuntime.1.5`) | ☐ |
