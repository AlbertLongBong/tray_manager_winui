# tray_manager_winui – Ideas for Future Options

Overview of possible extensions for the plugin. No priorities – just a collection of implementable options.

---

## Styling (WinUIContextMenuStyle)

| Option | Description | Effort |
|--------|-------------|--------|
| ~~`borderColor` / `borderThickness`~~ | ~~Border around menu~~ | Done |
| ~~`shadowElevation`~~ | ~~Shadow effect~~ | Done |
| ~~`itemHeight` / `minItemHeight`~~ | ~~Minimum height per menu item~~ | Done |
| ~~`checkedForegroundColor` / `checkedBackgroundColor`~~ | ~~Styling for checkbox in checked state~~ | Done (WinAppSDK 1.8 – ToggleMenuFlyoutItem resource keys) |
| ~~`iconColor`~~ | ~~Color for icons~~ | Done (FontIcon.Foreground from style) |
| ~~`fontStyle`~~ | ~~Italic/Normal~~ | Done |
| ~~`keyboardAcceleratorColor`~~ | ~~Color for keyboard shortcuts (e.g. "Ctrl+C")~~ | Done (MenuFlyoutItemKeyboardAcceleratorTextForeground resource key) |
| ~~`dismissOnPointerMoveAway`~~ | ~~Close menu when pointer moves away~~ | Done (FlyoutShowMode.TransientWithDismissOnPointerMoveAway, fixed in 1.6) |
| ~~`backdropType`~~ | ~~System backdrop material (Acrylic/Mica/MicaAlt)~~ | Done (SystemBackdrop on MenuFlyoutPresenter) |
| ~~`maxHeight`~~ | ~~Maximum menu height with scrollbar~~ | Done |
| ~~`enableOpenCloseAnimations`~~ | ~~Enable/disable open/close animations~~ | Done |

---

## Menu Items (MenuItem API)

| Option | Description | Dependency |
|--------|-------------|------------|
| ~~**Icons**~~ | ~~FontIcon via glyph codepoints – WinUIIcon.glyph / WinUIIcon.symbol~~ | Done (WinUIMenuItem.winuiIcon, also reads menu_base icon field) |
| ~~**accelerator**~~ | ~~Shortcut text right of label – KeyboardAcceleratorTextOverride~~ | Done (WinUIMenuItem.acceleratorText) |
| ~~**tooltip**~~ | ~~Tooltip on hover – ToolTipService.SetToolTip~~ | Done (reads menu_base toolTip field natively) |
| ~~**SplitMenuFlyoutItem**~~ | ~~Split button with primary action + submenu~~ | Done (WinUIMenuItem.split, WinAppSDK 1.8.6+) |

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
| ~~`exclusionRect`~~ | ~~Areas the menu should avoid (e.g. taskbar)~~ (Done – FlyoutShowOptions.ExclusionRect via showContextMenu parameter) |
| ~~`RadioMenuFlyoutItem`~~ | ~~Radio button items with mutual exclusion groups~~ (Done – WinUIMenuItem.radio with GroupName; native RadioMenuFlyoutItem retried in 1.8 with fallback) |
| ~~`MenuFlyout Events`~~ | ~~Expose Opening/Closing/Closed events to Dart~~ (Done – onMenuOpening/onMenuClosing/onMenuClosed streams) |
| ~~`Acrylic/Mica Backdrop`~~ | ~~System backdrop materials for the menu popup~~ (Done – WinUIBackdropType.acrylic/mica/micaAlt via backdropType style) |

---

## Prioritization (optional)

**Quick to implement:** ~~borderColor/borderThickness~~, ~~fontStyle~~, ~~showContextMenuAt(x,y)~~, ~~itemHeight~~, ~~maxHeight~~, ~~enableOpenCloseAnimations~~ (done). inputDevicePrefersRightSide: not in WinUI 3 API.

**High value:** ~~Icons~~ (done), ~~accelerator~~ (done), ~~placement~~ (done), ~~RadioMenuFlyoutItem~~ (done)

**Nice-to-have:** ~~Shadow~~ (done), ~~checkbox styling~~ (done), ~~tooltip~~ (done), ~~Acrylic/Mica backdrop~~ (done), ~~MenuFlyout events~~ (done)
