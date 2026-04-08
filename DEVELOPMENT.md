# Development Guide – tray_manager_winui Example

> Internal development notes. **Not** shipped with releases.

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Flutter | 3.3+ | `flutter doctor` should pass for Windows |
| Visual Studio 2022 | latest | C++ Desktop Development workload required |
| Windows App SDK | 1.8+ | `winget install Microsoft.WindowsAppRuntime.1.8` |
| NuGet | in PATH | CMake auto-downloads WindowsAppSDK Foundation + WinUI + CppWinRT |
| Windows | 10 1903+ | XAML Islands support |

---

## Quick Start

```bash
cd tray_manager_winui/example
flutter pub get
flutter run -d windows
```

Right-click the tray icon to open the WinUI 3 context menu.

---

## Project Structure

```
example/
├── lib/
│   ├── main.dart                 # App entry point (MaterialApp + BotToast)
│   ├── main_tab_page.dart        # Root widget – tray setup, menu definition, tab host
│   └── pages/
│       ├── home.dart             # Info tab – feature overview
│       └── style_playground.dart # Styling tab – live editor for WinUIContextMenuStyle
├── images/
│   └── tray_icon.ico             # Tray icon asset
├── windows/                      # Flutter Windows runner (auto-generated)
├── pubspec.yaml
└── DEVELOPMENT.md                # ← this file
```

---

## Architecture

### Entry Point (`main.dart`)

Bootstraps Flutter, sets up `BotToast` for in-app toast notifications.

### Main Tab Page (`main_tab_page.dart`)

- Implements `TrayListener` (from `tray_manager`) for tray icon events
- Creates the full `Menu` tree with `WinUIMenuItem` items (icons, checkboxes, radio groups, submenus, accelerator text, tooltips)
- Manages `WinUIContextMenuStyle` state and passes it to the native layer via `TrayManagerWinUI.instance.setContextMenu()`
- Subscribes to lifecycle streams: `onMenuItemClick`, `onMenuOpening`, `onMenuClosing`, `onMenuClosed`
- Hosts two tabs: **Info** and **Styling**

### Home Page (`pages/home.dart`)

Static info page listing available WinUI 3 features (icons, radio items, checkboxes, accelerator text, tooltips, submenus, styling, lifecycle events).

### Style Playground (`pages/style_playground.dart`)

Interactive editor for all `WinUIContextMenuStyle` properties:

- **Colors** – background, text, separator, disabled, hover, submenu states, checkbox indicator, border
- **Font** – size, family, weight, style
- **Layout** – corner radius, padding, min width, border thickness, shadow elevation, item height, max height, compact mode
- **Theme** – light / dark / system
- **Animations** – open/close toggle
- **Presets** – Dark, Light, Minimal, Reset
- **Code export** – "Copy code" button generates ready-to-use Dart snippet
- **Lifecycle event log** – shows Opening/Closing/Closed events in real time

Changes apply immediately; right-click the tray icon to preview.

---

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `tray_manager` | Tray icon infrastructure (icon, tooltip, click events) |
| `tray_manager_winui` | WinUI 3 context menu rendering (path dependency to `../`) |
| `bot_toast` | In-app toast notifications for menu click feedback |

---

## Common Development Tasks

### Changing the menu structure

Edit `_setupWinUIMenu()` in `main_tab_page.dart`. Use `WinUIMenuItem` for enhanced items (icons, accelerator text, tooltips) or standard `MenuItem` for basic items and separators.

### Adding a new style property

1. Add the field to `WinUIContextMenuStyle` in the plugin (`lib/src/`)
2. Add a state variable + UI control in `style_playground.dart`
3. Wire it in `_buildStyle()` and `_applyStyle()`
4. Add it to `_generateDartCode()` for code export

### Testing radio items

Radio items use `WinUIMenuItem.radio()` with a shared `radioGroup` string. The example defines three radio items (`Small`, `Medium`, `Large`) in the "View" submenu. Click handling toggles `checked` state within the group manually in `_onRadioClick()`.

### Debugging

- `kDebugMode` guards are already in place for console output
- `showContextMenu()` prints a message when display fails (debug builds only)
- The lifecycle event log in the Styling tab shows Opening/Closing/Closed events with timestamps
- Check `flutter run -d windows --verbose` for native build issues

### Rebuilding after plugin C++ changes

```bash
flutter clean
flutter pub get
flutter run -d windows
```

CMake reconfigures automatically. If NuGet packages are missing, ensure `nuget` is in PATH.

---

## Known Quirks

- The `DropdownButtonFormField` for font family uses `initialValue` which may trigger a deprecation warning in newer Flutter versions – use `value` if migrating.
- `BotToast` must be initialized via `BotToastInit()` builder in `MaterialApp`, otherwise toasts don't render.
- The tray icon (`images/tray_icon.ico`) must be an `.ico` file; `.png` won't work for Windows system tray.
- Radio item state management is manual – `WinUIMenuItem.radio` does not auto-deselect siblings.
- The menu host window registers a custom `WNDCLASS` with `hCursor = IDC_ARROW`. Additionally, a thread-local `WH_CALLWNDPROC` hook forces the arrow cursor on all WinUI popup windows (flyout, submenus) while the menu is open, preventing the "app starting" (spinning) cursor on flyout borders.
