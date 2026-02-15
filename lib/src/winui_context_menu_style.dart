import 'package:flutter/material.dart' show Color, EdgeInsets, FontStyle, FontWeight;

/// Styling options for the WinUI 3 context menu.
///
/// All properties are optional. When null, WinUI defaults are used.
/// Pass to [TrayManagerWinUI.setContextMenu] via the [style] parameter.
class WinUIContextMenuStyle {
  const WinUIContextMenuStyle({
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.fontFamily,
    this.fontWeight,
    this.fontStyle,
    this.cornerRadius,
    this.padding,
    this.minWidth,
    this.themeMode,
    this.separatorColor,
    this.disabledTextColor,
    this.hoverBackgroundColor,
    this.subMenuOpenedBackgroundColor,
    this.subMenuOpenedTextColor,
    this.borderColor,
    this.borderThickness,
    this.itemHeight,
    this.shadowElevation,
    this.checkedIndicatorColor,
    this.compactItemLayout = true,
  });

  /// Background color of the menu popup.
  final Color? backgroundColor;

  /// Text color (foreground) of menu items.
  final Color? textColor;

  /// Font size in logical pixels.
  final double? fontSize;

  /// Font family name (e.g. "Segoe UI", "Arial").
  final String? fontFamily;

  /// Font weight (100=thin, 400=normal, 700=bold).
  final FontWeight? fontWeight;

  /// Font style: normal or italic.
  final FontStyle? fontStyle;

  /// Corner radius of the menu popup in logical pixels.
  final double? cornerRadius;

  /// Padding inside the menu popup (left, top, right, bottom).
  final EdgeInsets? padding;

  /// Minimum width of the menu in logical pixels.
  final double? minWidth;

  /// Theme mode: 'light', 'dark', or 'system'.
  final WinUIThemeMode? themeMode;

  /// Color of separator lines between menu items.
  final Color? separatorColor;

  /// Text color for disabled menu items.
  final Color? disabledTextColor;

  /// Background color when hovering over menu items (Phase 3).
  final Color? hoverBackgroundColor;

  /// Background color when a submenu is open (parent item selected state).
  final Color? subMenuOpenedBackgroundColor;

  /// Text color when a submenu is open (parent item selected state).
  final Color? subMenuOpenedTextColor;

  /// Border color around the menu popup.
  final Color? borderColor;

  /// Border thickness in logical pixels.
  final double? borderThickness;

  /// Minimum height per menu item in logical pixels.
  final double? itemHeight;

  /// Shadow elevation in logical pixels. 0 = shadow off, null = WinUI default.
  final double? shadowElevation;

  /// When true (default), menu items use a compact layout without icon placeholder
  /// space. Use false if you plan to add icons (Phase 2) for consistent alignment.
  final bool compactItemLayout;

  /// Color of the indicator stripe for checkbox items. When set, a thin colored
  /// stripe on the left is shown instead of the checkmark; when null, the
  /// checkmark appears on the far right.
  final Color? checkedIndicatorColor;

  /// Serializes this style to a Map for the native method channel.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (backgroundColor != null) {
      map['backgroundColor'] = backgroundColor!.value;
    }
    if (textColor != null) {
      map['textColor'] = textColor!.value;
    }
    if (fontSize != null) {
      map['fontSize'] = fontSize;
    }
    if (fontFamily != null) {
      map['fontFamily'] = fontFamily;
    }
    if (fontWeight != null) {
      map['fontWeight'] = fontWeight!.value;
    }
    if (cornerRadius != null) {
      map['cornerRadius'] = cornerRadius;
    }
    if (padding != null) {
      map['padding'] = {
        'left': padding!.left,
        'top': padding!.top,
        'right': padding!.right,
        'bottom': padding!.bottom,
      };
    }
    if (minWidth != null) {
      map['minWidth'] = minWidth;
    }
    if (themeMode != null) {
      map['themeMode'] = themeMode!.name;
    }
    if (separatorColor != null) {
      map['separatorColor'] = separatorColor!.value;
    }
    if (disabledTextColor != null) {
      map['disabledTextColor'] = disabledTextColor!.value;
    }
    if (hoverBackgroundColor != null) {
      map['hoverBackgroundColor'] = hoverBackgroundColor!.value;
    }
    if (subMenuOpenedBackgroundColor != null) {
      map['subMenuOpenedBackgroundColor'] = subMenuOpenedBackgroundColor!.value;
    }
    if (subMenuOpenedTextColor != null) {
      map['subMenuOpenedTextColor'] = subMenuOpenedTextColor!.value;
    }
    if (borderColor != null) {
      map['borderColor'] = borderColor!.value;
    }
    if (borderThickness != null) {
      map['borderThickness'] = borderThickness;
    }
    if (fontStyle != null) {
      map['fontStyle'] = fontStyle!.name;
    }
    if (itemHeight != null) {
      map['itemHeight'] = itemHeight;
    }
    if (shadowElevation != null) {
      map['shadowElevation'] = shadowElevation;
    }
    if (checkedIndicatorColor != null) {
      map['checkedIndicatorColor'] = checkedIndicatorColor!.value;
    }
    map['compactItemLayout'] = compactItemLayout;
    return map;
  }
}

/// Theme mode for the WinUI context menu.
enum WinUIThemeMode {
  /// Light theme.
  light,

  /// Dark theme.
  dark,

  /// Follow system setting.
  system,
}
