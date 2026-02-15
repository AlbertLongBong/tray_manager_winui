# tray_manager_winui – Ideas for Future Options

Overview of possible extensions for the plugin. No priorities – just a collection of implementable options.

---

## Styling (WinUIContextMenuStyle)

| Option | Description | Effort |
|--------|-------------|--------|
| ~~`borderColor` / `borderThickness`~~ | ~~Border around menu~~ | Done |
| ~~`shadowElevation`~~ | ~~Shadow effect~~ | Done |
| ~~`itemHeight` / `minItemHeight`~~ | ~~Minimum height per menu item~~ | Done |
| `checkedForegroundColor` / `checkedBackgroundColor` | Styling for checkbox in checked state | Medium – ToggleMenuFlyoutItem resource keys |
| `iconColor` | Color for icons (preparatory for Phase 2) | Low |
| ~~`fontStyle`~~ | ~~Italic/Normal~~ | Done |
| `keyboardAcceleratorColor` | Color for keyboard shortcuts (e.g. "Ctrl+C") | Medium – resource keys in WinUI |

---

## Menu Items (MenuItem API)

| Option | Description | Dependency |
|--------|-------------|------------|
| **Icons** | `MenuItem(icon: 'path/to/icon.ico')` – WinUI MenuFlyoutItem.Icon | Phase 2, may need menu_base extension |
| **accelerator** | `MenuItem(accelerator: 'Ctrl+C')` – Text to the right of label | menu_base extension, WinUI KeyboardAcceleratorTextOverride |
| **tooltip** | `MenuItem(tooltip: 'Longer description')` | menu_base + WinUI ToolTipService.SetToolTip |

---

## Menu Behavior (API Extensions)

| Option | Description | Effort |
|--------|-------------|--------|
| ~~`showContextMenuAt(x, y)`~~ | ~~Menu at explicit position instead of cursor~~ | Done (x, y as optional parameters of showContextMenu) |
| ~~`placement`~~ | ~~Where menu appears relative to anchor (Top/Bottom/Left/Right)~~ | Done (parameter of showContextMenu, WinUIFlyoutPlacement) |
| `inputDevicePrefersRightSide` | Menu to the right of cursor for left-handed users | Not available – API does not exist in WinUI 3 (only InputDevicePrefersPrimaryCommands, read-only) |

---

## Other Native WinUI Options

| Option | Description |
|--------|-------------|
| `maxHeight` | Maximum menu height with scrollbar |
| `exclusionRect` | Areas the menu should avoid (e.g. taskbar) |

---

## Prioritization (optional)

**Quick to implement:** ~~borderColor/borderThickness~~, ~~fontStyle~~, ~~showContextMenuAt(x,y)~~, ~~itemHeight~~ (done). inputDevicePrefersRightSide: not in WinUI 3 API.

**High value:** Icons (Phase 2), accelerator (keyboard shortcuts), ~~placement~~ (done)

**Nice-to-have:** ~~Shadow~~ (done), checkbox styling, tooltip
