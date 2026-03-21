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
| ~~`maxHeight`~~ | ~~Maximum menu height with scrollbar~~ | Done |
| ~~`enableOpenCloseAnimations`~~ | ~~Enable/disable open/close animations~~ | Done |

---

## Menu Items (MenuItem API)

| Option | Description | Dependency |
|--------|-------------|------------|
| ~~**Icons**~~ | ~~FontIcon via glyph codepoints – WinUIIcon.glyph / WinUIIcon.symbol~~ | Done (WinUIMenuItem.winuiIcon, also reads menu_base icon field) |
| ~~**accelerator**~~ | ~~Shortcut text right of label – KeyboardAcceleratorTextOverride~~ | Done (WinUIMenuItem.acceleratorText) |
| ~~**tooltip**~~ | ~~Tooltip on hover – ToolTipService.SetToolTip~~ | Done (reads menu_base toolTip field natively) |

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
| ~~`maxHeight`~~ | ~~Maximum menu height with scrollbar~~ (Done – moved to Styling) |
| `exclusionRect` | Areas the menu should avoid (e.g. taskbar) |
| ~~`RadioMenuFlyoutItem`~~ | ~~Radio button items with mutual exclusion groups~~ (Done – WinUIMenuItem.radio with GroupName) |
| ~~`MenuFlyout Events`~~ | ~~Expose Opening/Closing/Closed events to Dart~~ (Done – onMenuOpening/onMenuClosing/onMenuClosed streams) |
| `Acrylic/Mica Backdrop` | System backdrop materials for the menu popup (complex with XAML Islands) |

---

## Prioritization (optional)

**Quick to implement:** ~~borderColor/borderThickness~~, ~~fontStyle~~, ~~showContextMenuAt(x,y)~~, ~~itemHeight~~, ~~maxHeight~~, ~~enableOpenCloseAnimations~~ (done). inputDevicePrefersRightSide: not in WinUI 3 API.

**High value:** ~~Icons~~ (done), ~~accelerator~~ (done), ~~placement~~ (done), ~~RadioMenuFlyoutItem~~ (done)

**Nice-to-have:** ~~Shadow~~ (done), checkbox styling, ~~tooltip~~ (done), Acrylic/Mica backdrop, ~~MenuFlyout events~~ (done)
