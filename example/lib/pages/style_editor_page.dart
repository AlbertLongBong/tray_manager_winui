import 'package:flutter/material.dart';
import 'package:tray_manager_winui/tray_manager_winui.dart';

import '../tray_controller.dart';
import '../widgets/code_preview_dialog.dart';
import '../widgets/color_picker_row.dart';
import '../widgets/section_card.dart';
import '../widgets/slider_row.dart';

// ---------------------------------------------------------------------------
// Preset definitions
// ---------------------------------------------------------------------------

const _presets = <String, WinUIContextMenuStyle?>{
  'Dark': WinUIContextMenuStyle(
    backgroundColor: Color(0xFF2D2D2D),
    textColor: Color(0xFFFFFFFF),
    fontSize: 14,
    cornerRadius: 8,
    themeMode: WinUIThemeMode.dark,
    separatorColor: Color(0xFF555555),
    disabledTextColor: Color(0xFF888888),
  ),
  'Light': WinUIContextMenuStyle(
    backgroundColor: Color(0xFFFAFAFA),
    textColor: Color(0xFF212121),
    fontSize: 14,
    cornerRadius: 8,
    themeMode: WinUIThemeMode.light,
    separatorColor: Color(0xFFE0E0E0),
    disabledTextColor: Color(0xFF9E9E9E),
  ),
  'Minimal': WinUIContextMenuStyle(
    backgroundColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF000000),
    fontSize: 13,
    cornerRadius: 4,
    themeMode: WinUIThemeMode.light,
    minWidth: 180,
  ),
  'Reset': null,
};

const _fontFamilies = [
  'Segoe UI',
  'Arial',
  'Consolas',
  'Calibri',
  'Georgia',
  'Times New Roman',
];

const _fontWeights = <(FontWeight, String)>[
  (FontWeight.w100, 'Thin'),
  (FontWeight.w400, 'Normal'),
  (FontWeight.w500, 'Medium'),
  (FontWeight.w600, 'SemiBold'),
  (FontWeight.w700, 'Bold'),
  (FontWeight.w900, 'Black'),
];

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class StyleEditorPage extends StatefulWidget {
  const StyleEditorPage({super.key, required this.controller});

  final TrayController controller;

  @override
  State<StyleEditorPage> createState() => _StyleEditorPageState();
}

class _StyleEditorPageState extends State<StyleEditorPage> {
  Color? _backgroundColor;
  Color? _textColor;
  double? _fontSize;
  String? _fontFamily;
  FontWeight? _fontWeight;
  FontStyle? _fontStyle;
  double? _cornerRadius;
  double? _paddingLeft;
  double? _paddingTop;
  double? _paddingRight;
  double? _paddingBottom;
  double? _minWidth;
  double? _itemHeight;
  WinUIThemeMode? _themeMode;
  Color? _separatorColor;
  Color? _disabledTextColor;
  Color? _hoverBackgroundColor;
  Color? _subMenuOpenedBackgroundColor;
  Color? _subMenuOpenedTextColor;
  Color? _checkedIndicatorColor;
  Color? _borderColor;
  double? _borderThickness;
  double? _shadowElevation;
  double? _maxHeight;
  bool? _enableOpenCloseAnimations;
  bool _compactItemLayout = true;

  @override
  void initState() {
    super.initState();
    _loadFromStyle(widget.controller.style);
  }

  // ---------------------------------------------------------------------------
  // Style <-> State mapping
  // ---------------------------------------------------------------------------

  void _loadFromStyle(WinUIContextMenuStyle? s) {
    _backgroundColor = s?.backgroundColor;
    _textColor = s?.textColor;
    _fontSize = s?.fontSize;
    _fontFamily = s?.fontFamily;
    _fontWeight = s?.fontWeight;
    _fontStyle = s?.fontStyle;
    _cornerRadius = s?.cornerRadius;
    _paddingLeft = s?.padding?.left;
    _paddingTop = s?.padding?.top;
    _paddingRight = s?.padding?.right;
    _paddingBottom = s?.padding?.bottom;
    _minWidth = s?.minWidth;
    _itemHeight = s?.itemHeight;
    _themeMode = s?.themeMode;
    _separatorColor = s?.separatorColor;
    _disabledTextColor = s?.disabledTextColor;
    _hoverBackgroundColor = s?.hoverBackgroundColor;
    _subMenuOpenedBackgroundColor = s?.subMenuOpenedBackgroundColor;
    _subMenuOpenedTextColor = s?.subMenuOpenedTextColor;
    _checkedIndicatorColor = s?.checkedIndicatorColor;
    _borderColor = s?.borderColor;
    _borderThickness = s?.borderThickness;
    _shadowElevation = s?.shadowElevation;
    _maxHeight = s?.maxHeight;
    _enableOpenCloseAnimations = s?.enableOpenCloseAnimations;
    _compactItemLayout = s?.compactItemLayout ?? true;
  }

  WinUIContextMenuStyle _buildStyle() {
    return WinUIContextMenuStyle(
      backgroundColor: _backgroundColor,
      textColor: _textColor,
      fontSize: _fontSize,
      fontFamily: (_fontFamily?.isNotEmpty ?? false) ? _fontFamily : null,
      fontWeight: _fontWeight,
      fontStyle: _fontStyle,
      cornerRadius: _cornerRadius,
      padding: (_paddingLeft ?? _paddingTop ?? _paddingRight ?? _paddingBottom) !=
              null
          ? EdgeInsets.fromLTRB(
              _paddingLeft ?? 0,
              _paddingTop ?? 0,
              _paddingRight ?? 0,
              _paddingBottom ?? 0,
            )
          : null,
      minWidth: _minWidth,
      itemHeight: _itemHeight,
      themeMode: _themeMode,
      separatorColor: _separatorColor,
      disabledTextColor: _disabledTextColor,
      hoverBackgroundColor: _hoverBackgroundColor,
      subMenuOpenedBackgroundColor: _subMenuOpenedBackgroundColor,
      subMenuOpenedTextColor: _subMenuOpenedTextColor,
      checkedIndicatorColor: _checkedIndicatorColor,
      borderColor: _borderColor,
      borderThickness: _borderThickness,
      shadowElevation: _shadowElevation,
      maxHeight: _maxHeight,
      enableOpenCloseAnimations: _enableOpenCloseAnimations,
      compactItemLayout: _compactItemLayout,
    );
  }

  void _pushStyle() {
    widget.controller.style = _buildStyle();
  }

  void _applyPreset(WinUIContextMenuStyle? preset) {
    setState(() => _loadFromStyle(preset));
    _pushStyle();
  }

  // ---------------------------------------------------------------------------
  // Code generation
  // ---------------------------------------------------------------------------

  String _generateDartCode() {
    final sb = StringBuffer()
      ..writeln("import 'package:flutter/material.dart';")
      ..writeln("import 'package:tray_manager_winui/tray_manager_winui.dart';")
      ..writeln()
      ..writeln(
          'TrayManagerWinUI.instance.setContextMenu(menu, style: WinUIContextMenuStyle(');

    void field(String name, String value) =>
        sb.writeln('  $name: $value,');

    String colorLiteral(Color c) =>
        'Color(0x${c.toARGB32().toRadixString(16).padLeft(8, '0')})';

    if (_backgroundColor != null) {
      field('backgroundColor', colorLiteral(_backgroundColor!));
    }
    if (_textColor != null) field('textColor', colorLiteral(_textColor!));
    if (_fontSize != null) {
      field('fontSize', _fontSize!.toStringAsFixed(1));
    }
    if (_fontFamily != null && _fontFamily!.isNotEmpty) {
      field('fontFamily', "'${_fontFamily!.replaceAll("'", "\\'")}'");
    }
    if (_fontWeight != null) {
      field('fontWeight', 'FontWeight.w${_fontWeight!.value}');
    }
    if (_fontStyle != null) {
      field('fontStyle', 'FontStyle.${_fontStyle!.name}');
    }
    if (_cornerRadius != null) {
      field('cornerRadius', _cornerRadius!.toStringAsFixed(1));
    }
    if (_paddingLeft != null ||
        _paddingTop != null ||
        _paddingRight != null ||
        _paddingBottom != null) {
      field(
        'padding',
        'EdgeInsets.fromLTRB(${_paddingLeft ?? 0}, ${_paddingTop ?? 0}, '
            '${_paddingRight ?? 0}, ${_paddingBottom ?? 0})',
      );
    }
    if (_minWidth != null) field('minWidth', _minWidth!.toStringAsFixed(1));
    if (_itemHeight != null) {
      field('itemHeight', _itemHeight!.toStringAsFixed(1));
    }
    if (_themeMode != null) {
      field('themeMode', 'WinUIThemeMode.${_themeMode!.name}');
    }
    if (_separatorColor != null) {
      field('separatorColor', colorLiteral(_separatorColor!));
    }
    if (_disabledTextColor != null) {
      field('disabledTextColor', colorLiteral(_disabledTextColor!));
    }
    if (_hoverBackgroundColor != null) {
      field('hoverBackgroundColor', colorLiteral(_hoverBackgroundColor!));
    }
    if (_subMenuOpenedBackgroundColor != null) {
      field('subMenuOpenedBackgroundColor',
          colorLiteral(_subMenuOpenedBackgroundColor!));
    }
    if (_subMenuOpenedTextColor != null) {
      field(
          'subMenuOpenedTextColor', colorLiteral(_subMenuOpenedTextColor!));
    }
    if (_checkedIndicatorColor != null) {
      field('checkedIndicatorColor', colorLiteral(_checkedIndicatorColor!));
    }
    if (_borderColor != null) {
      field('borderColor', colorLiteral(_borderColor!));
    }
    if (_borderThickness != null) {
      field('borderThickness', _borderThickness!.toStringAsFixed(1));
    }
    if (_shadowElevation != null) {
      field('shadowElevation', _shadowElevation!.toStringAsFixed(1));
    }
    if (_maxHeight != null) {
      field('maxHeight', _maxHeight!.toStringAsFixed(1));
    }
    if (_enableOpenCloseAnimations != null) {
      field('enableOpenCloseAnimations', '$_enableOpenCloseAnimations');
    }
    if (!_compactItemLayout) field('compactItemLayout', 'false');

    sb.writeln('));');
    return sb.toString();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInfoBanner(context),
              const SizedBox(height: 16),
              _buildPresetRow(),
              const SizedBox(height: 24),
              _buildColorsSection(),
              const SizedBox(height: 16),
              _buildFontSection(),
              const SizedBox(height: 16),
              _buildLayoutSection(),
              const SizedBox(height: 16),
              _buildThemeSection(),
              const SizedBox(height: 16),
              _buildTogglesSection(),
              const SizedBox(height: 24),
              _buildActions(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        'Changes apply immediately. Right-click the tray icon to preview.',
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Presets
  // ---------------------------------------------------------------------------

  Widget _buildPresetRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in _presets.entries)
          entry.value == null
              ? OutlinedButton(
                  onPressed: () => _applyPreset(null),
                  child: Text(entry.key),
                )
              : FilledButton.tonal(
                  onPressed: () => _applyPreset(entry.value),
                  child: Text(entry.key),
                ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Colors section
  // ---------------------------------------------------------------------------

  Widget _buildColorsSection() {
    return SectionCard(
      title: 'Colors',
      children: [
        _colorRow('Background', _backgroundColor, (c) {
          setState(() => _backgroundColor = c);
          _pushStyle();
        }, () {
          setState(() => _backgroundColor = null);
          _pushStyle();
        }),
        _colorRow('Text', _textColor, (c) {
          setState(() => _textColor = c);
          _pushStyle();
        }, () {
          setState(() => _textColor = null);
          _pushStyle();
        }),
        _colorRow('Separator', _separatorColor, (c) {
          setState(() => _separatorColor = c);
          _pushStyle();
        }, () {
          setState(() => _separatorColor = null);
          _pushStyle();
        }),
        _colorRow('Disabled text', _disabledTextColor, (c) {
          setState(() => _disabledTextColor = c);
          _pushStyle();
        }, () {
          setState(() => _disabledTextColor = null);
          _pushStyle();
        }),
        _colorRow('Hover background', _hoverBackgroundColor, (c) {
          setState(() => _hoverBackgroundColor = c);
          _pushStyle();
        }, () {
          setState(() => _hoverBackgroundColor = null);
          _pushStyle();
        }),
        _colorRow('Submenu bg', _subMenuOpenedBackgroundColor, (c) {
          setState(() => _subMenuOpenedBackgroundColor = c);
          _pushStyle();
        }, () {
          setState(() => _subMenuOpenedBackgroundColor = null);
          _pushStyle();
        }),
        _colorRow('Submenu text', _subMenuOpenedTextColor, (c) {
          setState(() => _subMenuOpenedTextColor = c);
          _pushStyle();
        }, () {
          setState(() => _subMenuOpenedTextColor = null);
          _pushStyle();
        }),
        _colorRow('Checked indicator', _checkedIndicatorColor, (c) {
          setState(() => _checkedIndicatorColor = c);
          _pushStyle();
        }, () {
          setState(() => _checkedIndicatorColor = null);
          _pushStyle();
        }),
        _colorRow('Border', _borderColor, (c) {
          setState(() => _borderColor = c);
          _pushStyle();
        }, () {
          setState(() => _borderColor = null);
          _pushStyle();
        }),
      ],
    );
  }

  Widget _colorRow(
    String label,
    Color? value,
    ValueChanged<Color> onChanged,
    VoidCallback onClear,
  ) {
    return ColorPickerRow(
      label: label,
      value: value,
      onChanged: onChanged,
      onClear: onClear,
    );
  }

  // ---------------------------------------------------------------------------
  // Font section
  // ---------------------------------------------------------------------------

  Widget _buildFontSection() {
    return SectionCard(
      title: 'Font',
      children: [
        SliderRow(
          label: 'Font size',
          value: _fontSize,
          min: 8,
          max: 32,
          suffix: 'px',
          onChanged: (v) {
            setState(() => _fontSize = v);
            _pushStyle();
          },
          onClear: () {
            setState(() => _fontSize = null);
            _pushStyle();
          },
        ),
        _buildDropdownRow<String?>(
          label: 'Font family',
          value: _fontFamilies.contains(_fontFamily) ? _fontFamily : null,
          items: [
            const DropdownMenuItem(value: null, child: Text('WinUI Default')),
            for (final f in _fontFamilies)
              DropdownMenuItem(value: f, child: Text(f)),
          ],
          onChanged: (v) {
            setState(() => _fontFamily = v);
            _pushStyle();
          },
        ),
        _buildDropdownRow<FontWeight?>(
          label: 'Font weight',
          value: _fontWeight,
          items: [
            const DropdownMenuItem(value: null, child: Text('WinUI Default')),
            for (final w in _fontWeights)
              DropdownMenuItem(value: w.$1, child: Text(w.$2)),
          ],
          onChanged: (v) {
            setState(() => _fontWeight = v);
            _pushStyle();
          },
        ),
        _buildDropdownRow<FontStyle?>(
          label: 'Font style',
          value: _fontStyle,
          items: const [
            DropdownMenuItem(value: null, child: Text('WinUI Default')),
            DropdownMenuItem(value: FontStyle.normal, child: Text('Normal')),
            DropdownMenuItem(value: FontStyle.italic, child: Text('Italic')),
          ],
          onChanged: (v) {
            setState(() => _fontStyle = v);
            _pushStyle();
          },
        ),
      ],
    );
  }

  Widget _buildDropdownRow<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(label)),
          Expanded(
            child: DropdownButtonFormField<T>(
              initialValue: value,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Layout section
  // ---------------------------------------------------------------------------

  Widget _buildLayoutSection() {
    return SectionCard(
      title: 'Layout',
      children: [
        SliderRow(
          label: 'Corner radius',
          value: _cornerRadius,
          min: 0,
          max: 24,
          onChanged: (v) {
            setState(() => _cornerRadius = v);
            _pushStyle();
          },
          onClear: () {
            setState(() => _cornerRadius = null);
            _pushStyle();
          },
        ),
        _buildPaddingRow(),
        SliderRow(
          label: 'Min width',
          value: _minWidth,
          min: 120,
          max: 400,
          onChanged: (v) {
            setState(() => _minWidth = v);
            _pushStyle();
          },
          onClear: () {
            setState(() => _minWidth = null);
            _pushStyle();
          },
        ),
        SliderRow(
          label: 'Border thickness',
          value: _borderThickness,
          min: 0,
          max: 8,
          onChanged: (v) {
            setState(() => _borderThickness = v);
            _pushStyle();
          },
          onClear: () {
            setState(() => _borderThickness = null);
            _pushStyle();
          },
        ),
        SliderRow(
          label: 'Shadow elevation',
          value: _shadowElevation,
          min: 0,
          max: 64,
          onChanged: (v) {
            setState(() => _shadowElevation = v);
            _pushStyle();
          },
          onClear: () {
            setState(() => _shadowElevation = null);
            _pushStyle();
          },
        ),
        SliderRow(
          label: 'Item height',
          value: _itemHeight,
          min: 16,
          max: 64,
          onChanged: (v) {
            setState(() => _itemHeight = v);
            _pushStyle();
          },
          onClear: () {
            setState(() => _itemHeight = null);
            _pushStyle();
          },
        ),
        SliderRow(
          label: 'Max height',
          value: _maxHeight,
          min: 100,
          max: 800,
          onChanged: (v) {
            setState(() => _maxHeight = v);
            _pushStyle();
          },
          onClear: () {
            setState(() => _maxHeight = null);
            _pushStyle();
          },
        ),
      ],
    );
  }

  Widget _buildPaddingRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const SizedBox(width: 160, child: Text('Padding (L, T, R, B)')),
          Expanded(
            child: Row(
              children: [
                _paddingField(_paddingLeft, (v) {
                  setState(() => _paddingLeft = v);
                  _pushStyle();
                }, 'L'),
                const SizedBox(width: 4),
                _paddingField(_paddingTop, (v) {
                  setState(() => _paddingTop = v);
                  _pushStyle();
                }, 'T'),
                const SizedBox(width: 4),
                _paddingField(_paddingRight, (v) {
                  setState(() => _paddingRight = v);
                  _pushStyle();
                }, 'R'),
                const SizedBox(width: 4),
                _paddingField(_paddingBottom, (v) {
                  setState(() => _paddingBottom = v);
                  _pushStyle();
                }, 'B'),
              ],
            ),
          ),
          if (_paddingLeft != null ||
              _paddingTop != null ||
              _paddingRight != null ||
              _paddingBottom != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  _paddingLeft = null;
                  _paddingTop = null;
                  _paddingRight = null;
                  _paddingBottom = null;
                });
                _pushStyle();
              },
            ),
        ],
      ),
    );
  }

  Widget _paddingField(
    double? value,
    ValueChanged<double?> onChanged,
    String hint,
  ) {
    return Expanded(
      child: TextFormField(
        key: ValueKey('pad_$hint${value?.toInt()}'),
        initialValue: value?.toInt().toString(),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        onChanged: (s) => onChanged(double.tryParse(s)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Theme section
  // ---------------------------------------------------------------------------

  Widget _buildThemeSection() {
    return SectionCard(
      title: 'Theme',
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const SizedBox(width: 160, child: Text('Theme mode')),
              Expanded(
                child: SegmentedButton<WinUIThemeMode?>(
                  segments: const [
                    ButtonSegment(
                        value: WinUIThemeMode.light, label: Text('Light')),
                    ButtonSegment(
                        value: WinUIThemeMode.dark, label: Text('Dark')),
                    ButtonSegment(
                        value: WinUIThemeMode.system, label: Text('System')),
                  ],
                  selected: {_themeMode ?? WinUIThemeMode.system},
                  onSelectionChanged: (s) {
                    setState(() => _themeMode = s.first);
                    _pushStyle();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Toggles section
  // ---------------------------------------------------------------------------

  Widget _buildTogglesSection() {
    return SectionCard(
      title: 'Options',
      children: [
        SwitchListTile(
          value: _enableOpenCloseAnimations ?? true,
          onChanged: (v) {
            setState(() => _enableOpenCloseAnimations = v);
            _pushStyle();
          },
          title: const Text('Open/close animations'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        SwitchListTile(
          value: _compactItemLayout,
          onChanged: (v) {
            setState(() => _compactItemLayout = v);
            _pushStyle();
          },
          title: const Text('Compact layout'),
          subtitle: const Text('Hide all icons for a denser menu'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: () =>
              CodePreviewDialog.show(context, _generateDartCode()),
          icon: const Icon(Icons.code, size: 18),
          label: const Text('View Code'),
        ),
        const SizedBox(width: 12),
        FilledButton.tonalIcon(
          onPressed: widget.controller.showMenu,
          icon: const Icon(Icons.menu_open, size: 18),
          label: const Text('Show Menu'),
        ),
      ],
    );
  }
}
