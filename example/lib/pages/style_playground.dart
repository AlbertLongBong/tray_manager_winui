import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:menu_base/menu_base.dart';
import 'package:tray_manager_winui/tray_manager_winui.dart';

/// Preset colors for quick selection (no external color picker dependency).
const _presetColors = [
  Color(0xFF1E1E1E),
  Color(0xFF2D2D2D),
  Color(0xFF3D3D3D),
  Color(0xFF1A1A2E),
  Color(0xFF16213E),
  Color(0xFF0F3460),
  Color(0xFFFFFFFF),
  Color(0xFFF5F5F5),
  Color(0xFFE0E0E0),
  Color(0xFFBDBDBD),
  Color(0xFF9E9E9E),
  Color(0xFF757575),
  Color(0xFF2196F3),
  Color(0xFF4CAF50),
  Color(0xFFFF9800),
  Color(0xFFE91E63),
];

class StylePlaygroundPage extends StatefulWidget {
  const StylePlaygroundPage({
    super.key,
    required this.menu,
    required this.initialStyle,
    required this.onStyleChanged,
  });

  final Menu menu;
  final WinUIContextMenuStyle? initialStyle;
  final ValueChanged<WinUIContextMenuStyle?> onStyleChanged;

  @override
  State<StylePlaygroundPage> createState() => _StylePlaygroundPageState();
}

class _StylePlaygroundPageState extends State<StylePlaygroundPage> {
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
  bool _compactItemLayout = true;

  static const _fontFamilies = [
    'Segoe UI',
    'Arial',
    'Consolas',
    'Calibri',
    'Georgia',
    'Times New Roman',
  ];

  @override
  void initState() {
    super.initState();
    _applyStyle(widget.initialStyle);
  }

  @override
  void didUpdateWidget(covariant StylePlaygroundPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStyle != widget.initialStyle) {
      _applyStyle(widget.initialStyle);
    }
  }

  void _applyStyle(WinUIContextMenuStyle? style) {
    if (style == null) {
      setState(() {
        _backgroundColor = null;
        _textColor = null;
        _fontSize = null;
        _fontFamily = null;
        _fontWeight = null;
        _fontStyle = null;
        _cornerRadius = null;
        _paddingLeft = null;
        _paddingTop = null;
        _paddingRight = null;
        _paddingBottom = null;
        _minWidth = null;
        _itemHeight = null;
        _themeMode = null;
        _separatorColor = null;
        _disabledTextColor = null;
        _hoverBackgroundColor = null;
        _subMenuOpenedBackgroundColor = null;
        _subMenuOpenedTextColor = null;
        _checkedIndicatorColor = null;
        _borderColor = null;
        _borderThickness = null;
        _shadowElevation = null;
        _compactItemLayout = true;
      });
    } else {
      setState(() {
        _backgroundColor = style.backgroundColor;
        _textColor = style.textColor;
        _fontSize = style.fontSize;
        _fontFamily = style.fontFamily;
        _fontWeight = style.fontWeight;
        _fontStyle = style.fontStyle;
        _cornerRadius = style.cornerRadius;
        _paddingLeft = style.padding?.left;
        _paddingTop = style.padding?.top;
        _paddingRight = style.padding?.right;
        _paddingBottom = style.padding?.bottom;
        _minWidth = style.minWidth;
        _itemHeight = style.itemHeight;
        _themeMode = style.themeMode;
        _separatorColor = style.separatorColor;
        _disabledTextColor = style.disabledTextColor;
        _hoverBackgroundColor = style.hoverBackgroundColor;
        _subMenuOpenedBackgroundColor = style.subMenuOpenedBackgroundColor;
        _subMenuOpenedTextColor = style.subMenuOpenedTextColor;
        _checkedIndicatorColor = style.checkedIndicatorColor;
        _borderColor = style.borderColor;
        _borderThickness = style.borderThickness;
        _shadowElevation = style.shadowElevation;
        _compactItemLayout = style.compactItemLayout;
      });
    }
  }

  WinUIContextMenuStyle _buildStyle() {
    return WinUIContextMenuStyle(
      backgroundColor: _backgroundColor,
      textColor: _textColor,
      fontSize: _fontSize,
      fontFamily: _fontFamily?.isEmpty == true ? null : _fontFamily,
      fontWeight: _fontWeight,
      fontStyle: _fontStyle,
      cornerRadius: _cornerRadius,
      padding: (_paddingLeft != null ||
              _paddingTop != null ||
              _paddingRight != null ||
              _paddingBottom != null)
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
      compactItemLayout: _compactItemLayout,
    );
  }

  void _notifyStyleChanged() {
    widget.onStyleChanged(_buildStyle());
  }

  String _generateDartCode() {
    final sb = StringBuffer();
    sb.writeln("// Required: import 'package:flutter/material.dart';");
    sb.writeln("// import 'package:tray_manager_winui/tray_manager_winui.dart';");
    sb.writeln('');
    sb.writeln('TrayManagerWinUI.instance.setContextMenu(menu, style: WinUIContextMenuStyle(');
    if (_backgroundColor != null) {
      sb.writeln(
        '  backgroundColor: Color(0x${_backgroundColor!.value.toRadixString(16).padLeft(8, '0')}),',
      );
    }
    if (_textColor != null) {
      sb.writeln(
        '  textColor: Color(0x${_textColor!.value.toRadixString(16).padLeft(8, '0')}),',
      );
    }
    if (_fontSize != null) {
      sb.writeln('  fontSize: ${_fontSize!.toStringAsFixed(1)},');
    }
    if (_fontFamily != null && _fontFamily!.isNotEmpty) {
      sb.writeln('  fontFamily: \'${_fontFamily!.replaceAll("'", "\\'")}\',');
    }
    if (_fontWeight != null) {
      sb.writeln('  fontWeight: FontWeight.w${_fontWeight!.value},');
    }
    if (_fontStyle != null) {
      sb.writeln('  fontStyle: FontStyle.${_fontStyle!.name},');
    }
    if (_borderColor != null) {
      sb.writeln(
        '  borderColor: Color(0x${_borderColor!.value.toRadixString(16).padLeft(8, '0')}),',
      );
    }
    if (_borderThickness != null) {
      sb.writeln('  borderThickness: ${_borderThickness!.toStringAsFixed(1)},');
    }
    if (_itemHeight != null) {
      sb.writeln('  itemHeight: ${_itemHeight!.toStringAsFixed(1)},');
    }
    if (_cornerRadius != null) {
      sb.writeln('  cornerRadius: ${_cornerRadius!.toStringAsFixed(1)},');
    }
    if (_paddingLeft != null ||
        _paddingTop != null ||
        _paddingRight != null ||
        _paddingBottom != null) {
      final l = _paddingLeft ?? 0;
      final t = _paddingTop ?? 0;
      final r = _paddingRight ?? 0;
      final b = _paddingBottom ?? 0;
      sb.writeln('  padding: EdgeInsets.fromLTRB($l, $t, $r, $b),');
    }
    if (_minWidth != null) {
      sb.writeln('  minWidth: ${_minWidth!.toStringAsFixed(1)},');
    }
    if (_themeMode != null) {
      sb.writeln('  themeMode: WinUIThemeMode.${_themeMode!.name},');
    }
    if (_separatorColor != null) {
      sb.writeln(
        '  separatorColor: Color(0x${_separatorColor!.value.toRadixString(16).padLeft(8, '0')}),',
      );
    }
    if (_disabledTextColor != null) {
      sb.writeln(
        '  disabledTextColor: Color(0x${_disabledTextColor!.value.toRadixString(16).padLeft(8, '0')}),',
      );
    }
    if (_hoverBackgroundColor != null) {
      sb.writeln(
        '  hoverBackgroundColor: Color(0x${_hoverBackgroundColor!.value.toRadixString(16).padLeft(8, '0')}),',
      );
    }
    if (_subMenuOpenedBackgroundColor != null) {
      sb.writeln(
        '  subMenuOpenedBackgroundColor: Color(0x${_subMenuOpenedBackgroundColor!.value.toRadixString(16).padLeft(8, '0')}),',
      );
    }
    if (_subMenuOpenedTextColor != null) {
      sb.writeln(
        '  subMenuOpenedTextColor: Color(0x${_subMenuOpenedTextColor!.value.toRadixString(16).padLeft(8, '0')}),',
      );
    }
    if (_checkedIndicatorColor != null) {
      sb.writeln(
        '  checkedIndicatorColor: Color(0x${_checkedIndicatorColor!.value.toRadixString(16).padLeft(8, '0')}),',
      );
    }
    if (_shadowElevation != null) {
      sb.writeln('  shadowElevation: ${_shadowElevation!.toStringAsFixed(1)},');
    }
    if (!_compactItemLayout) {
      sb.writeln('  compactItemLayout: false,');
    }
    sb.writeln('));');
    return sb.toString();
  }

  void _copyCode() {
    final code = _generateDartCode();
    Clipboard.setData(ClipboardData(text: code));
    BotToast.showText(text: 'Code in Zwischenablage kopiert');
  }

  void _applyPreset(String preset) {
    switch (preset) {
      case 'dark':
        setState(() {
          _backgroundColor = const Color(0xFF2D2D2D);
          _textColor = const Color(0xFFFFFFFF);
          _fontSize = 14.0;
          _cornerRadius = 8.0;
          _themeMode = WinUIThemeMode.dark;
          _separatorColor = const Color(0xFF555555);
          _disabledTextColor = const Color(0xFF888888);
        });
        break;
      case 'light':
        setState(() {
          _backgroundColor = const Color(0xFFFAFAFA);
          _textColor = const Color(0xFF212121);
          _fontSize = 14.0;
          _cornerRadius = 8.0;
          _themeMode = WinUIThemeMode.light;
          _separatorColor = const Color(0xFFE0E0E0);
          _disabledTextColor = const Color(0xFF9E9E9E);
        });
        break;
      case 'minimal':
        setState(() {
          _backgroundColor = const Color(0xFFFFFFFF);
          _textColor = const Color(0xFF000000);
          _fontSize = 13.0;
          _cornerRadius = 4.0;
          _themeMode = WinUIThemeMode.light;
          _minWidth = 180.0;
        });
        break;
      case 'reset':
        _applyStyle(null);
        break;
    }
    _notifyStyleChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Text(
              'Änderungen werden sofort übernommen. '
              'Rechtsklick auf das Tray-Icon zur Vorschau.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          _buildPresetButtons(),
          const SizedBox(height: 24),
          _buildSectionTitle('Farben'),
          _buildColorRow(
            'Hintergrund',
            _backgroundColor,
            (c) {
              setState(() => _backgroundColor = c);
              _notifyStyleChanged();
            },
            onClear: () => setState(() => _backgroundColor = null),
          ),
          _buildColorRow(
            'Textfarbe',
            _textColor,
            (c) {
              setState(() => _textColor = c);
              _notifyStyleChanged();
            },
            onClear: () => setState(() => _textColor = null),
          ),
          _buildColorRow(
            'Trennlinie',
            _separatorColor,
            (c) {
              setState(() => _separatorColor = c);
              _notifyStyleChanged();
            },
            onClear: () => setState(() => _separatorColor = null),
          ),
          _buildColorRow(
            'Text (deaktiviert)',
            _disabledTextColor,
            (c) {
              setState(() => _disabledTextColor = c);
              _notifyStyleChanged();
            },
            onClear: () => setState(() => _disabledTextColor = null),
          ),
          _buildColorRow(
            'Hover-Hintergrund',
            _hoverBackgroundColor,
            (c) {
              setState(() => _hoverBackgroundColor = c);
              _notifyStyleChanged();
            },
            onClear: () => setState(() => _hoverBackgroundColor = null),
          ),
          _buildColorRow(
            'Untermenü geöffnet (Hintergrund)',
            _subMenuOpenedBackgroundColor,
            (c) {
              setState(() => _subMenuOpenedBackgroundColor = c);
              _notifyStyleChanged();
            },
            onClear: () => setState(() => _subMenuOpenedBackgroundColor = null),
          ),
          _buildColorRow(
            'Untermenü geöffnet (Text)',
            _subMenuOpenedTextColor,
            (c) {
              setState(() => _subMenuOpenedTextColor = c);
              _notifyStyleChanged();
            },
            onClear: () => setState(() => _subMenuOpenedTextColor = null),
          ),
          _buildColorRow(
            'Checkbox-Stripe (statt Häkchen)',
            _checkedIndicatorColor,
            (c) {
              setState(() => _checkedIndicatorColor = c);
              _notifyStyleChanged();
            },
            onClear: () => setState(() => _checkedIndicatorColor = null),
          ),
          _buildColorRow(
            'Rahmen',
            _borderColor,
            (c) {
              setState(() => _borderColor = c);
              _notifyStyleChanged();
            },
            onClear: () => setState(() => _borderColor = null),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Schrift'),
          _buildDoubleSlider('Schriftgröße', _fontSize, 8, 32, (v) {
            setState(() => _fontSize = v);
            _notifyStyleChanged();
          }),
          _buildFontFamilyRow(),
          _buildFontWeightRow(),
          _buildFontStyleRow(),
          const SizedBox(height: 24),
          _buildSectionTitle('Layout'),
          _buildDoubleSlider('Eckenradius', _cornerRadius, 0, 24, (v) {
            setState(() => _cornerRadius = v);
            _notifyStyleChanged();
          }),
          _buildPaddingRow(),
          _buildDoubleSlider('Mindestbreite', _minWidth, 120, 400, (v) {
            setState(() => _minWidth = v);
            _notifyStyleChanged();
          }),
          _buildDoubleSlider('Rahmendicke', _borderThickness, 0, 8, (v) {
            setState(() => _borderThickness = v);
            _notifyStyleChanged();
          }),
          _buildDoubleSlider('Schatten (Elevation)', _shadowElevation, 0, 64, (v) {
            setState(() => _shadowElevation = v);
            _notifyStyleChanged();
          }),
          _buildDoubleSlider('Zeilenhöhe (Item)', _itemHeight, 16, 64, (v) {
            setState(() => _itemHeight = v);
            _notifyStyleChanged();
          }),
          _buildCompactItemLayoutRow(),
          const SizedBox(height: 24),
          _buildSectionTitle('Theme'),
          _buildThemeModeRow(),
          const SizedBox(height: 24),
          _buildCopyButton(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildPresetButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonal(
          onPressed: () => _applyPreset('dark'),
          child: const Text('Dark'),
        ),
        FilledButton.tonal(
          onPressed: () => _applyPreset('light'),
          child: const Text('Light'),
        ),
        FilledButton.tonal(
          onPressed: () => _applyPreset('minimal'),
          child: const Text('Minimal'),
        ),
        OutlinedButton(
          onPressed: () => _applyPreset('reset'),
          child: const Text('Reset'),
        ),
      ],
    );
  }

  Widget _buildColorRow(
    String label,
    Color? value,
    ValueChanged<Color> onChanged, {
    VoidCallback? onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ..._presetColors.map(
                  (c) => _ColorChip(
                    color: c,
                    isSelected: value?.value == c.value,
                    onTap: () => onChanged(c),
                  ),
                ),
                if (value != null)
                  GestureDetector(
                    onTap: () {
                      setState(() {});
                      onChanged(value);
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: value,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (value != null && onClear != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () {
                onClear();
                _notifyStyleChanged();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDoubleSlider(
    String label,
    double? value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final effectiveValue = value ?? (min + max) / 2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label)),
          Expanded(
            child: Slider(
              value: effectiveValue.clamp(min, max),
              min: min,
              max: max,
              divisions: (max - min).round(),
              onChanged: (x) => onChanged(x),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              value != null ? value.toStringAsFixed(1) : '—',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontFamilyRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const SizedBox(width: 140, child: Text('Schriftart')),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _fontFamilies.contains(_fontFamily) ? _fontFamily : null,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              hint: const Text('WinUI-Default'),
              items: [
                const DropdownMenuItem(value: null, child: Text('WinUI-Default')),
                ..._fontFamilies.map(
                  (f) => DropdownMenuItem(value: f, child: Text(f)),
                ),
              ],
              onChanged: (v) {
                setState(() => _fontFamily = v);
                _notifyStyleChanged();
              },
            ),
          ),
          if (_fontFamily != null && _fontFamily!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () {
                setState(() => _fontFamily = null);
                _notifyStyleChanged();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFontWeightRow() {
    const weights = [
      (FontWeight.w100, 'Thin'),
      (FontWeight.w400, 'Normal'),
      (FontWeight.w500, 'Medium'),
      (FontWeight.w600, 'SemiBold'),
      (FontWeight.w700, 'Bold'),
      (FontWeight.w900, 'Black'),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const SizedBox(width: 140, child: Text('Schriftstärke')),
          Expanded(
            child: DropdownButtonFormField<FontWeight?>(
              value: _fontWeight,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              hint: const Text('WinUI-Default'),
              items: [
                const DropdownMenuItem(value: null, child: Text('WinUI-Default')),
                ...weights.map(
                  (w) => DropdownMenuItem(
                    value: w.$1,
                    child: Text(w.$2),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() => _fontWeight = v);
                _notifyStyleChanged();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontStyleRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const SizedBox(width: 140, child: Text('Schriftstil')),
          Expanded(
            child: DropdownButtonFormField<FontStyle?>(
              value: _fontStyle,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              hint: const Text('WinUI-Default'),
              items: const [
                DropdownMenuItem(value: null, child: Text('WinUI-Default')),
                DropdownMenuItem(value: FontStyle.normal, child: Text('Normal')),
                DropdownMenuItem(value: FontStyle.italic, child: Text('Kursiv')),
              ],
              onChanged: (v) {
                setState(() => _fontStyle = v);
                _notifyStyleChanged();
              },
            ),
          ),
          if (_fontStyle != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () {
                setState(() => _fontStyle = null);
                _notifyStyleChanged();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPaddingRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const SizedBox(width: 140, child: Text('Padding (L,T,R,B)')),
          Expanded(
            child: Row(
              children: [
                _buildPaddingField(_paddingLeft, (v) {
                  setState(() => _paddingLeft = v);
                }, 'L'),
                const SizedBox(width: 4),
                _buildPaddingField(_paddingTop, (v) {
                  setState(() => _paddingTop = v);
                }, 'T'),
                const SizedBox(width: 4),
                _buildPaddingField(_paddingRight, (v) {
                  setState(() => _paddingRight = v);
                }, 'R'),
                const SizedBox(width: 4),
                _buildPaddingField(_paddingBottom, (v) {
                  setState(() => _paddingBottom = v);
                }, 'B'),
              ],
            ),
          ),
          if (_paddingLeft != null ||
              _paddingTop != null ||
              _paddingRight != null ||
              _paddingBottom != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () {
                setState(() {
                  _paddingLeft = null;
                  _paddingTop = null;
                  _paddingRight = null;
                  _paddingBottom = null;
                });
                _notifyStyleChanged();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPaddingField(
    double? value,
    ValueChanged<double?> onChanged,
    String hint,
  ) {
    return Expanded(
      child: TextFormField(
        key: ValueKey('$hint-$value'),
        initialValue: value != null ? value.toInt().toString() : null,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        onChanged: (s) {
          final v = double.tryParse(s);
          onChanged(v);
          _notifyStyleChanged();
        },
      ),
    );
  }

  Widget _buildCompactItemLayoutRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 140,
            child: Text('Kompaktes Layout'),
          ),
          Expanded(
            child: SwitchListTile(
              value: _compactItemLayout,
              onChanged: (v) {
                setState(() => _compactItemLayout = v);
                _notifyStyleChanged();
              },
              title: const Text('Ohne Icon-Platz vor Einträgen'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const SizedBox(width: 140, child: Text('Theme')),
          Expanded(
            child: SegmentedButton<WinUIThemeMode?>(
              segments: const [
                ButtonSegment(value: WinUIThemeMode.light, label: Text('Light')),
                ButtonSegment(value: WinUIThemeMode.dark, label: Text('Dark')),
                ButtonSegment(value: WinUIThemeMode.system, label: Text('System')),
              ],
              selected: {_themeMode ?? WinUIThemeMode.system},
              onSelectionChanged: (s) {
                setState(() => _themeMode = s.first);
                _notifyStyleChanged();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyButton() {
    return FilledButton.icon(
      onPressed: _copyCode,
      icon: const Icon(Icons.copy),
      label: const Text('Code kopieren'),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade400,
            width: isSelected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}
