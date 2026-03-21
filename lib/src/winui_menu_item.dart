import 'package:menu_base/menu_base.dart';

import 'winui_icon.dart';

/// Extended [MenuItem] with WinUI 3-specific features.
///
/// Adds support for [winuiIcon], [acceleratorText], and [radioGroup]
/// properties that are serialized into the JSON sent to the native side.
///
/// Use standard [MenuItem] constructors for basic items. Use [WinUIMenuItem]
/// when you need WinUI-specific features like icons or keyboard shortcut text.
class WinUIMenuItem extends MenuItem {
  /// Creates a normal menu item with optional WinUI extras.
  WinUIMenuItem({
    super.key,
    super.label,
    super.disabled,
    super.onClick,
    super.toolTip,
    this.winuiIcon,
    this.acceleratorText,
  }) : radioGroup = null;

  /// Creates a checkbox menu item with optional WinUI extras.
  ///
  /// Renders as a [ToggleMenuFlyoutItem] on the native side.
  WinUIMenuItem.checkbox({
    super.key,
    super.label,
    required super.checked,
    super.disabled,
    super.onClick,
    super.toolTip,
    this.winuiIcon,
    this.acceleratorText,
  })  : radioGroup = null,
        super.checkbox();

  /// Creates a submenu item with optional WinUI extras.
  WinUIMenuItem.submenu({
    super.key,
    super.label,
    required super.submenu,
    super.disabled,
    super.toolTip,
    this.winuiIcon,
  })  : radioGroup = null,
        acceleratorText = null,
        super.submenu();

  /// Creates a radio menu item that belongs to a mutual-exclusion group.
  ///
  /// Items with the same [radioGroup] name form a radio group — selecting one
  /// automatically deselects the others on the native side. Update the
  /// [checked] state in [onClick] and call [setContextMenu] again to sync.
  ///
  /// Renders as a [RadioMenuFlyoutItem] with [GroupName] on the native side.
  WinUIMenuItem.radio({
    super.key,
    super.label,
    required this.radioGroup,
    bool checked = false,
    super.disabled,
    super.onClick,
    super.toolTip,
    this.winuiIcon,
    this.acceleratorText,
  }) : super(type: 'radio', checked: checked);

  /// WinUI icon displayed to the left of the label.
  ///
  /// On the native side, a [FontIcon] is created from the glyph codepoint.
  /// Items with an icon skip the compact template and use the default WinUI
  /// template that supports icon rendering natively.
  final WinUIIcon? winuiIcon;

  /// Keyboard shortcut text displayed to the right of the label.
  ///
  /// This is display-only — no actual keyboard handling occurs because
  /// tray menus are not focused. Example: `'Ctrl+C'`, `'Alt+F4'`.
  ///
  /// Maps to [MenuFlyoutItem.KeyboardAcceleratorTextOverride] on the native side.
  final String? acceleratorText;

  /// Radio group name for mutual exclusion.
  ///
  /// Only set when using [WinUIMenuItem.radio]. Items with the same group name
  /// form a radio group where only one can be checked at a time.
  final String? radioGroup;

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    if (winuiIcon != null) {
      json['icon'] = winuiIcon!.toIconString();
      if (winuiIcon is WinUIGlyphIcon) {
        final glyph = winuiIcon! as WinUIGlyphIcon;
        if (glyph.fontFamily != null) {
          json['iconFontFamily'] = glyph.fontFamily;
        }
      }
    }
    if (acceleratorText != null) {
      json['acceleratorText'] = acceleratorText;
    }
    if (radioGroup != null) {
      json['radioGroup'] = radioGroup;
    }
    return json;
  }
}
