import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:tray_manager/tray_manager.dart';
import 'package:tray_manager_winui/tray_manager_winui.dart';

class TrayController extends ChangeNotifier implements TrayListener {
  TrayController() {
    trayManager.addListener(this);
    _listenToWinUIEvents();
    _buildMenu();
    _applyMenuAndStyle();

    if (Platform.isWindows) {
      trayManager.setIcon('images/tray_icon.ico');
      trayManager.setToolTip('tray_manager_winui example');
    }
  }

  // ---------------------------------------------------------------------------
  // Menu
  // ---------------------------------------------------------------------------

  late Menu _menu;
  Menu get menu => _menu;

  late WinUIMenuItem _radioSmall;
  late WinUIMenuItem _radioMedium;
  late WinUIMenuItem _radioLarge;

  bool _useExclusionRect = false;
  bool get useExclusionRect => _useExclusionRect;
  set useExclusionRect(bool value) {
    _useExclusionRect = value;
    notifyListeners();
  }

  void _buildMenu() {
    _radioSmall = WinUIMenuItem.radio(
      label: 'Small',
      radioGroup: 'viewSize',
      onClick: _onRadioClick,
    );
    _radioMedium = WinUIMenuItem.radio(
      label: 'Medium',
      radioGroup: 'viewSize',
      checked: true,
      onClick: _onRadioClick,
    );
    _radioLarge = WinUIMenuItem.radio(
      label: 'Large',
      radioGroup: 'viewSize',
      onClick: _onRadioClick,
    );

    _menu = Menu(
      items: [
        WinUIMenuItem(
          label: 'Cut',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.cut),
          acceleratorText: 'Ctrl+X',
          toolTip: 'Cut selection to clipboard',
          onClick: (_) => _showSnack('Cut'),
        ),
        WinUIMenuItem(
          label: 'Copy',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.copy),
          acceleratorText: 'Ctrl+C',
          toolTip: 'Copy selection to clipboard',
          onClick: (_) => _showSnack('Copy'),
        ),
        WinUIMenuItem(
          label: 'Paste',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.paste),
          acceleratorText: 'Ctrl+V',
          disabled: true,
          toolTip: 'Paste from clipboard (disabled demo)',
        ),
        MenuItem.separator(),
        WinUIMenuItem.checkbox(
          label: 'Dark Mode',
          checked: false,
          winuiIcon: const WinUIIcon.glyph(0xE793),
          onClick: (item) {
            item.checked = !(item.checked == true);
            _applyMenuAndStyle();
          },
        ),
        WinUIMenuItem.checkbox(
          label: 'Notifications',
          checked: true,
          winuiIcon: const WinUIIcon.glyph(0xEA8F),
          onClick: (item) {
            item.checked = !(item.checked == true);
            _applyMenuAndStyle();
          },
        ),
        MenuItem.separator(),
        WinUIMenuItem.submenu(
          label: 'View',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.zoom),
          submenu: Menu(items: [_radioSmall, _radioMedium, _radioLarge]),
        ),
        WinUIMenuItem.split(
          label: 'Share',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.share),
          onClick: (_) => _showSnack('Share (primary action)'),
          toolTip: 'Share via default method, or expand for more options',
          submenu: Menu(
            items: [
              WinUIMenuItem(
                label: 'E-Mail',
                winuiIcon: WinUIIcon.symbol(WinUISymbol.mail),
                onClick: (_) => _showSnack('Share via E-Mail'),
              ),
              WinUIMenuItem(
                label: 'Link kopieren',
                winuiIcon: WinUIIcon.symbol(WinUISymbol.link),
                onClick: (_) => _showSnack('Share via Link'),
              ),
              MenuItem.separator(),
              WinUIMenuItem(
                label: 'Bluetooth',
                winuiIcon: const WinUIIcon.glyph(0xE702),
                disabled: true,
                toolTip: 'Not available',
              ),
            ],
          ),
        ),
        WinUIMenuItem.submenu(
          label: 'More',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.more),
          submenu: Menu(
            items: [
              WinUIMenuItem(
                label: 'Settings',
                winuiIcon: WinUIIcon.symbol(WinUISymbol.setting),
                acceleratorText: 'Ctrl+,',
                onClick: (_) => _showSnack('Settings'),
              ),
              WinUIMenuItem(
                label: 'Refresh',
                winuiIcon: WinUIIcon.symbol(WinUISymbol.refresh),
                acceleratorText: 'F5',
                onClick: (_) => _showSnack('Refresh'),
              ),
              MenuItem.separator(),
              WinUIMenuItem(
                label: 'Help',
                winuiIcon: WinUIIcon.symbol(WinUISymbol.help),
                toolTip: 'Open help documentation',
                onClick: (_) => _showSnack('Help'),
              ),
            ],
          ),
        ),
        MenuItem.separator(),
        WinUIMenuItem(
          label: 'Open Log',
          onClick: (_) => _showSnack('Open Log (no icon)'),
        ),
        WinUIMenuItem(
          label: 'About',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.contact),
          onClick: (_) =>
              _showSnack('tray_manager_winui – WinUI 3 Context Menu'),
        ),
        WinUIMenuItem(
          label: 'Exit',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.cancel),
          acceleratorText: 'Alt+F4',
          onClick: (_) => exit(0),
        ),
      ],
    );
  }

  void _onRadioClick(MenuItem clicked) {
    for (final item in [_radioSmall, _radioMedium, _radioLarge]) {
      item.checked = (item == clicked);
    }
    _applyMenuAndStyle();
    if (kDebugMode) print('Radio selected: ${clicked.label}');
  }

  // ---------------------------------------------------------------------------
  // Style
  // ---------------------------------------------------------------------------

  WinUIContextMenuStyle? _style = const WinUIContextMenuStyle(
    backgroundColor: Color(0xFF2D2D2D),
    textColor: Color(0xFFFFFFFF),
    fontSize: 14,
    cornerRadius: 8,
    themeMode: WinUIThemeMode.dark,
  );

  WinUIContextMenuStyle? get style => _style;

  set style(WinUIContextMenuStyle? value) {
    _style = value;
    _applyMenuAndStyle();
    notifyListeners();
  }

  void _applyMenuAndStyle() {
    TrayManagerWinUI.instance.setContextMenu(_menu, style: _style);
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  final List<String> _eventLog = [];
  List<String> get eventLog => List.unmodifiable(_eventLog);

  final List<StreamSubscription<dynamic>> _subs = [];

  void _listenToWinUIEvents() {
    final winui = TrayManagerWinUI.instance;
    _subs.add(winui.onMenuItemClick.listen(_onMenuItemClick));
    _subs.add(winui.onMenuOpening.listen((_) => _addEvent('Opening')));
    _subs.add(winui.onMenuClosing.listen((_) => _addEvent('Closing')));
    _subs.add(winui.onMenuClosed.listen((_) => _addEvent('Closed')));
  }

  void _onMenuItemClick(MenuItem item) {
    if (kDebugMode) print('WinUI Menu clicked: ${item.label}');
    _addEvent('Click: ${item.label}');
  }

  void _addEvent(String name) {
    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    _eventLog.insert(0, '$ts  $name');
    if (_eventLog.length > 50) _eventLog.removeLast();
    notifyListeners();
  }

  void clearEventLog() {
    _eventLog.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // SnackBar bridge – set by the app shell so we can show messages from here.
  // ---------------------------------------------------------------------------

  GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  void _showSnack(String text) {
    scaffoldMessengerKey?.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Random menu generators
  // ---------------------------------------------------------------------------

  static const _randomLabels = [
    'Banana', 'Supernova', 'Yeet', 'Potato', '42', 'Boop', 'Spaghetti',
    'Turbo', 'Llama', 'Warp Drive', 'Cheese', 'Unicorn', 'Kaboom', 'Noodle',
    'Quantum', 'Pineapple', 'Bazinga', 'Flux', 'Wiggle', 'Glitch', 'Derp',
    'Zap', 'Brrr', 'Oink', 'Doge', 'Stonks', 'Vibe', 'Yolo', 'Bloop',
    'Burrito', 'Tornado', 'Platypus', 'Disco', 'Wombat', 'Pretzel',
  ];

  static const _randomSymbols = WinUISymbol.values;

  static const _fontFamilies = [
    'Segoe UI', 'Arial', 'Consolas', 'Calibri', 'Georgia',
    'Times New Roman', 'Comic Sans MS', 'Impact', 'Verdana', 'Courier New',
  ];

  static const _fontWeights = [
    FontWeight.w100, FontWeight.w300, FontWeight.w400,
    FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w900,
  ];

  Color _randomColor(Random rng) =>
      Color.fromARGB(255, rng.nextInt(256), rng.nextInt(256), rng.nextInt(256));

  Color? _maybeColor(Random rng, {int chance = 50}) =>
      rng.nextInt(100) < chance ? _randomColor(rng) : null;

  void generateTrueRandomMenu() {
    final rng = Random();
    final itemCount = rng.nextInt(12) + 4;
    final items = <MenuItem>[];

    for (var i = 0; i < itemCount; i++) {
      items.add(_randomItem(rng, depth: 0, maxDepth: 3));
    }

    _menu = Menu(items: items);
    _style = _trueRandomStyle(rng);
    _applyMenuAndStyle();
    notifyListeners();
    _addEvent('Menu: true random (${items.length} items)');
  }

  WinUIContextMenuStyle _trueRandomStyle(Random rng) {
    return WinUIContextMenuStyle(
      backgroundColor: _randomColor(rng),
      textColor: _randomColor(rng),
      fontSize: (rng.nextInt(24) + 9).toDouble(),
      fontFamily: rng.nextBool()
          ? _fontFamilies[rng.nextInt(_fontFamilies.length)]
          : null,
      fontWeight: rng.nextBool()
          ? _fontWeights[rng.nextInt(_fontWeights.length)]
          : null,
      fontStyle: rng.nextBool() ? FontStyle.italic : null,
      cornerRadius: rng.nextInt(25).toDouble(),
      padding: rng.nextBool()
          ? EdgeInsets.fromLTRB(
              rng.nextInt(20).toDouble(),
              rng.nextInt(20).toDouble(),
              rng.nextInt(20).toDouble(),
              rng.nextInt(20).toDouble(),
            )
          : null,
      minWidth: (rng.nextInt(250) + 150).toDouble(),
      itemHeight: rng.nextBool()
          ? (rng.nextInt(40) + 20).toDouble()
          : null,
      themeMode: WinUIThemeMode.values[rng.nextInt(WinUIThemeMode.values.length)],
      separatorColor: _maybeColor(rng, chance: 70),
      disabledTextColor: _maybeColor(rng),
      hoverBackgroundColor: _maybeColor(rng, chance: 70),
      subMenuOpenedBackgroundColor: _maybeColor(rng),
      subMenuOpenedTextColor: _maybeColor(rng),
      checkedIndicatorColor: _maybeColor(rng),
      checkedForegroundColor: _maybeColor(rng),
      checkedBackgroundColor: _maybeColor(rng),
      iconColor: _maybeColor(rng, chance: 70),
      keyboardAcceleratorColor: _maybeColor(rng, chance: 60),
      borderColor: _maybeColor(rng, chance: 60),
      borderThickness: rng.nextBool()
          ? (rng.nextInt(6) + 1).toDouble()
          : null,
      shadowElevation: rng.nextInt(50).toDouble(),
      maxHeight: rng.nextBool()
          ? (rng.nextInt(500) + 200).toDouble()
          : null,
      enableOpenCloseAnimations: rng.nextBool(),
      compactItemLayout: rng.nextBool(),
      dismissOnPointerMoveAway: rng.nextBool(),
      backdropType: rng.nextInt(100) < 30
          ? WinUIBackdropType.values[rng.nextInt(WinUIBackdropType.values.length)]
          : null,
    );
  }

  MenuItem _randomItem(Random rng, {required int depth, required int maxDepth}) {
    final roll = rng.nextInt(100);

    if (roll < 12) {
      return MenuItem.separator();
    }

    final label = _randomLabels[rng.nextInt(_randomLabels.length)];
    final hasIcon = rng.nextBool();
    final icon = hasIcon
        ? WinUIIcon.symbol(_randomSymbols[rng.nextInt(_randomSymbols.length)])
        : null;
    final disabled = rng.nextInt(100) < 15;
    final hasAccelerator = rng.nextInt(100) < 25;
    final accelerator = hasAccelerator
        ? '${['Ctrl', 'Alt', 'Shift'][rng.nextInt(3)]}+${String.fromCharCode(65 + rng.nextInt(26))}'
        : null;

    if (roll < 30 && depth < maxDepth) {
      final childCount = rng.nextInt(5) + 1;
      return WinUIMenuItem.submenu(
        label: label,
        winuiIcon: icon,
        submenu: Menu(
          items: List.generate(
            childCount,
            (_) => _randomItem(rng, depth: depth + 1, maxDepth: maxDepth),
          ),
        ),
      );
    }

    if (roll < 45) {
      return WinUIMenuItem.checkbox(
        label: label,
        checked: rng.nextBool(),
        winuiIcon: icon,
        disabled: disabled,
        acceleratorText: accelerator,
        onClick: (item) {
          item.checked = !(item.checked == true);
          _applyMenuAndStyle();
        },
      );
    }

    if (roll < 58) {
      return WinUIMenuItem.radio(
        label: label,
        radioGroup: 'rndGroup${rng.nextInt(3)}',
        checked: rng.nextInt(100) < 20,
        winuiIcon: icon,
        disabled: disabled,
        onClick: (_) => _showSnack('Radio: $label'),
      );
    }

    if (roll < 72 && depth < maxDepth) {
      final childCount = rng.nextInt(3) + 1;
      return WinUIMenuItem.split(
        label: label,
        winuiIcon: icon,
        disabled: disabled,
        acceleratorText: accelerator,
        onClick: (_) => _showSnack('Split: $label'),
        submenu: Menu(
          items: List.generate(
            childCount,
            (_) => _randomItem(rng, depth: depth + 1, maxDepth: maxDepth),
          ),
        ),
      );
    }

    return WinUIMenuItem(
      label: label,
      winuiIcon: icon,
      disabled: disabled,
      acceleratorText: accelerator,
      toolTip: rng.nextBool() ? 'Tooltip for $label' : null,
      onClick: (_) => _showSnack(label),
    );
  }

  void generateStructuredRandomMenu() {
    final rng = Random();

    final categories = <(String, WinUISymbol, List<_MenuEntry>)>[
      ('File', WinUISymbol.document, [
        _MenuEntry('New', WinUISymbol.add, 'Ctrl+N'),
        _MenuEntry('Open', WinUISymbol.openFile, 'Ctrl+O'),
        _MenuEntry('Save', WinUISymbol.save, 'Ctrl+S'),
        _MenuEntry('Print', WinUISymbol.print, 'Ctrl+P'),
        _MenuEntry('Export', WinUISymbol.download, null),
        _MenuEntry('Close', WinUISymbol.cancel, 'Ctrl+W'),
      ]),
      ('Edit', WinUISymbol.edit, [
        _MenuEntry('Undo', WinUISymbol.undo, 'Ctrl+Z'),
        _MenuEntry('Redo', WinUISymbol.redo, 'Ctrl+Y'),
        _MenuEntry('Cut', WinUISymbol.cut, 'Ctrl+X'),
        _MenuEntry('Copy', WinUISymbol.copy, 'Ctrl+C'),
        _MenuEntry('Paste', WinUISymbol.paste, 'Ctrl+V'),
        _MenuEntry('Find', WinUISymbol.find, 'Ctrl+F'),
        _MenuEntry('Rename', WinUISymbol.rename, 'F2'),
      ]),
      ('View', WinUISymbol.zoom, [
        _MenuEntry('Zoom In', WinUISymbol.zoomIn, 'Ctrl++'),
        _MenuEntry('Zoom Out', WinUISymbol.zoomOut, 'Ctrl+-'),
        _MenuEntry('Refresh', WinUISymbol.refresh, 'F5'),
        _MenuEntry('Sort', WinUISymbol.sort, null),
        _MenuEntry('Filter', WinUISymbol.filter, null),
      ]),
      ('Tools', WinUISymbol.repair, [
        _MenuEntry('Settings', WinUISymbol.setting, 'Ctrl+,'),
        _MenuEntry('Manage', WinUISymbol.manage, null),
        _MenuEntry('Scan', WinUISymbol.scan, null),
        _MenuEntry('Sync', WinUISymbol.sync, null),
        _MenuEntry('Permissions', WinUISymbol.permissions, null),
      ]),
      ('Share', WinUISymbol.share, [
        _MenuEntry('Mail', WinUISymbol.mail, null),
        _MenuEntry('Link', WinUISymbol.link, null),
        _MenuEntry('Upload', WinUISymbol.upload, null),
        _MenuEntry('Send', WinUISymbol.send, null),
      ]),
      ('Help', WinUISymbol.help, [
        _MenuEntry('Documentation', WinUISymbol.library, null),
        _MenuEntry('Contact', WinUISymbol.contact, null),
        _MenuEntry('About', WinUISymbol.globe, null),
      ]),
    ];

    categories.shuffle(rng);
    final picked = categories.take(rng.nextInt(3) + 3).toList();

    final items = <MenuItem>[];

    for (var ci = 0; ci < picked.length; ci++) {
      final (catLabel, catSymbol, entries) = picked[ci];
      final shuffled = List.of(entries)..shuffle(rng);
      final count = (rng.nextInt(shuffled.length) + 2).clamp(2, shuffled.length);
      final selected = shuffled.take(count).toList();

      final children = <MenuItem>[];
      for (var i = 0; i < selected.length; i++) {
        final e = selected[i];
        final disabled = rng.nextInt(100) < 10;

        if (rng.nextInt(100) < 15 && i > 0) {
          children.add(MenuItem.separator());
        }

        children.add(WinUIMenuItem(
          label: e.label,
          winuiIcon: WinUIIcon.symbol(e.symbol),
          acceleratorText: e.accelerator,
          disabled: disabled,
          onClick: (_) => _showSnack(e.label),
        ));
      }

      items.add(WinUIMenuItem.submenu(
        label: catLabel,
        winuiIcon: WinUIIcon.symbol(catSymbol),
        submenu: Menu(items: children),
      ));

      if (ci < picked.length - 1 && rng.nextBool()) {
        items.add(MenuItem.separator());
      }
    }

    final toggleLabels = ['Dark Mode', 'Notifications', 'Auto-Save', 'Compact'];
    toggleLabels.shuffle(rng);
    final toggleCount = rng.nextInt(2) + 1;

    items.add(MenuItem.separator());
    for (var i = 0; i < toggleCount; i++) {
      items.add(WinUIMenuItem.checkbox(
        label: toggleLabels[i],
        checked: rng.nextBool(),
        onClick: (item) {
          item.checked = !(item.checked == true);
          _applyMenuAndStyle();
        },
      ));
    }

    items.add(MenuItem.separator());
    items.add(WinUIMenuItem(
      label: 'Exit',
      winuiIcon: WinUIIcon.symbol(WinUISymbol.cancel),
      acceleratorText: 'Alt+F4',
      onClick: (_) => exit(0),
    ));

    _menu = Menu(items: items);
    _style = _structuredRandomStyle(rng);
    _applyMenuAndStyle();
    notifyListeners();
    _addEvent('Menu: structured random (${items.length} items)');
  }

  WinUIContextMenuStyle _structuredRandomStyle(Random rng) {
    final isDark = rng.nextBool();
    final hue = rng.nextInt(360);

    Color hsl(int h, double s, double l) =>
        HSLColor.fromAHSL(1, h.toDouble(), s, l).toColor();

    final bg = isDark
        ? hsl(hue, 0.1 + rng.nextDouble() * 0.15, 0.1 + rng.nextDouble() * 0.1)
        : hsl(hue, 0.05 + rng.nextDouble() * 0.1, 0.92 + rng.nextDouble() * 0.06);
    final fg = isDark
        ? hsl(hue, 0.05, 0.85 + rng.nextDouble() * 0.12)
        : hsl(hue, 0.1, 0.08 + rng.nextDouble() * 0.12);
    final accent = hsl(hue, 0.5 + rng.nextDouble() * 0.4, isDark ? 0.6 : 0.45);
    final hover = isDark
        ? hsl(hue, 0.15, 0.18 + rng.nextDouble() * 0.08)
        : hsl(hue, 0.1, 0.82 + rng.nextDouble() * 0.08);
    final sep = isDark
        ? hsl(hue, 0.08, 0.25 + rng.nextDouble() * 0.1)
        : hsl(hue, 0.05, 0.78 + rng.nextDouble() * 0.1);
    final disabled = isDark
        ? hsl(hue, 0.05, 0.4 + rng.nextDouble() * 0.1)
        : hsl(hue, 0.05, 0.55 + rng.nextDouble() * 0.1);

    final radius = [4.0, 6.0, 8.0, 10.0, 12.0][rng.nextInt(5)];
    final fontSize = [12.0, 13.0, 14.0, 15.0, 16.0][rng.nextInt(5)];

    final fonts = ['Segoe UI', 'Arial', 'Calibri', 'Verdana'];
    final font = rng.nextBool() ? fonts[rng.nextInt(fonts.length)] : null;
    final weight = rng.nextInt(100) < 30
        ? [FontWeight.w400, FontWeight.w500, FontWeight.w600][rng.nextInt(3)]
        : null;

    final useBackdrop = rng.nextInt(100) < 25;

    return WinUIContextMenuStyle(
      backgroundColor: useBackdrop ? null : bg,
      textColor: fg,
      fontSize: fontSize,
      fontFamily: font,
      fontWeight: weight,
      cornerRadius: radius,
      themeMode: isDark ? WinUIThemeMode.dark : WinUIThemeMode.light,
      separatorColor: sep,
      disabledTextColor: disabled,
      hoverBackgroundColor: hover,
      iconColor: accent,
      keyboardAcceleratorColor: disabled,
      checkedForegroundColor: accent,
      checkedBackgroundColor: isDark
          ? hsl(hue, 0.15, 0.15 + rng.nextDouble() * 0.05)
          : hsl(hue, 0.08, 0.88 + rng.nextDouble() * 0.05),
      borderColor: rng.nextBool() ? sep : null,
      borderThickness: rng.nextBool() ? 1 : null,
      shadowElevation: [0, 8, 16, 24, 32][rng.nextInt(5)].toDouble(),
      compactItemLayout: rng.nextBool(),
      enableOpenCloseAnimations: true,
      dismissOnPointerMoveAway: rng.nextBool(),
      backdropType: useBackdrop
          ? WinUIBackdropType.values[rng.nextInt(WinUIBackdropType.values.length)]
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Show menu (can be called from UI button too)
  // ---------------------------------------------------------------------------

  Future<void> showMenu() async {
    await TrayManagerWinUI.instance.showContextMenu(
      exclusionRect: _useExclusionRect
          ? const Rect.fromLTWH(0, 0, 400, 50)
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // TrayListener
  // ---------------------------------------------------------------------------

  @override
  void onTrayIconRightMouseDown() {
    if (kDebugMode) print('onTrayIconRightMouseDown');
    TrayManagerWinUI.instance.showContextMenu(
      exclusionRect: _useExclusionRect
          ? const Rect.fromLTWH(0, 0, 400, 50)
          : null,
    );
  }

  @override
  void onTrayIconRightMouseUp() {}
  @override
  void onTrayIconMouseDown() {}
  @override
  void onTrayIconMouseUp() {}
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {}

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    trayManager.removeListener(this);
    super.dispose();
  }
}

class _MenuEntry {
  const _MenuEntry(this.label, this.symbol, this.accelerator);
  final String label;
  final WinUISymbol symbol;
  final String? accelerator;
}
