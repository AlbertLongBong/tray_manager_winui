import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager_winui/tray_manager_winui.dart';
import 'package:menu_base/menu_base.dart';

void main() {
  group('WinUIGlyphIcon', () {
    test('toIconString returns padded uppercase hex', () {
      const icon = WinUIGlyphIcon(0xE8C8);
      expect(icon.toIconString(), '0xE8C8');
    });

    test('toIconString pads short codepoints to 4 digits', () {
      const icon = WinUIGlyphIcon(0x41);
      expect(icon.toIconString(), '0x0041');
    });

    test('stores fontFamily when provided', () {
      const icon = WinUIGlyphIcon(0xE710, fontFamily: 'My Custom Font');
      expect(icon.fontFamily, 'My Custom Font');
      expect(icon.codePoint, 0xE710);
    });

    test('fontFamily defaults to null', () {
      const icon = WinUIGlyphIcon(0xE710);
      expect(icon.fontFamily, isNull);
    });
  });

  group('WinUIIcon factory constructors', () {
    test('WinUIIcon.glyph creates WinUIGlyphIcon', () {
      const icon = WinUIIcon.glyph(0xE8C8);
      expect(icon, isA<WinUIGlyphIcon>());
      expect((icon as WinUIGlyphIcon).codePoint, 0xE8C8);
    });

    test('WinUIIcon.glyph with fontFamily', () {
      const icon = WinUIIcon.glyph(0xE710, fontFamily: 'Segoe MDL2 Assets');
      expect(icon, isA<WinUIGlyphIcon>());
      final glyph = icon as WinUIGlyphIcon;
      expect(glyph.codePoint, 0xE710);
      expect(glyph.fontFamily, 'Segoe MDL2 Assets');
    });

    test('WinUIIcon.symbol creates WinUIGlyphIcon with correct codepoint', () {
      final icon = WinUIIcon.symbol(WinUISymbol.copy);
      expect(icon, isA<WinUIGlyphIcon>());
      expect((icon as WinUIGlyphIcon).codePoint, 0xE8C8);
    });

    test('WinUIIcon.symbol maps correctly for various symbols', () {
      expect(
          WinUIIcon.symbol(WinUISymbol.add).toIconString(), '0xE710');
      expect(
          WinUIIcon.symbol(WinUISymbol.deleteIcon).toIconString(), '0xE74D');
      expect(
          WinUIIcon.symbol(WinUISymbol.save).toIconString(), '0xE74E');
      expect(
          WinUIIcon.symbol(WinUISymbol.setting).toIconString(), '0xE713');
    });
  });

  group('WinUISymbol', () {
    test('all enum values have non-zero codepoints', () {
      for (final symbol in WinUISymbol.values) {
        expect(symbol.codePoint, isNonZero,
            reason: '${symbol.name} should have a non-zero codepoint');
      }
    });

    test('known codepoints match expected values', () {
      expect(WinUISymbol.copy.codePoint, 0xE8C8);
      expect(WinUISymbol.cut.codePoint, 0xE8C6);
      expect(WinUISymbol.paste.codePoint, 0xE77F);
      expect(WinUISymbol.undo.codePoint, 0xE7A7);
      expect(WinUISymbol.redo.codePoint, 0xE7A6);
      expect(WinUISymbol.find.codePoint, 0xE721);
      expect(WinUISymbol.refresh.codePoint, 0xE72C);
      expect(WinUISymbol.share.codePoint, 0xE72D);
      expect(WinUISymbol.home.codePoint, 0xE80F);
      expect(WinUISymbol.mail.codePoint, 0xE715);
    });

    test('enum has expected number of values', () {
      expect(WinUISymbol.values.length, greaterThanOrEqualTo(50));
    });
  });

  group('WinUIMenuItem', () {
    test('default constructor creates normal item', () {
      final item = WinUIMenuItem(label: 'Test');
      expect(item.label, 'Test');
      expect(item.type, 'normal');
      expect(item.winuiIcon, isNull);
      expect(item.acceleratorText, isNull);
      expect(item.radioGroup, isNull);
    });

    test('toJson includes icon hex string', () {
      final item = WinUIMenuItem(
        label: 'Copy',
        winuiIcon: WinUIIcon.symbol(WinUISymbol.copy),
      );
      final json = item.toJson();
      expect(json['icon'], '0xE8C8');
      expect(json['type'], 'normal');
      expect(json.containsKey('iconFontFamily'), isFalse);
    });

    test('toJson includes iconFontFamily when set', () {
      final item = WinUIMenuItem(
        label: 'Custom',
        winuiIcon: const WinUIIcon.glyph(0xE710, fontFamily: 'My Font'),
      );
      final json = item.toJson();
      expect(json['icon'], '0xE710');
      expect(json['iconFontFamily'], 'My Font');
    });

    test('toJson includes acceleratorText', () {
      final item = WinUIMenuItem(
        label: 'Copy',
        acceleratorText: 'Ctrl+C',
      );
      final json = item.toJson();
      expect(json['acceleratorText'], 'Ctrl+C');
    });

    test('toJson omits null optional fields', () {
      final item = WinUIMenuItem(label: 'Plain');
      final json = item.toJson();
      expect(json.containsKey('icon'), isFalse);
      expect(json.containsKey('iconFontFamily'), isFalse);
      expect(json.containsKey('acceleratorText'), isFalse);
      expect(json.containsKey('radioGroup'), isFalse);
    });

    test('toJson includes toolTip from menu_base', () {
      final item = WinUIMenuItem(
        label: 'Help',
        toolTip: 'Get help',
      );
      final json = item.toJson();
      expect(json['toolTip'], 'Get help');
    });
  });

  group('WinUIMenuItem.checkbox', () {
    test('creates checkbox item', () {
      final item = WinUIMenuItem.checkbox(
        label: 'Dark Mode',
        checked: true,
      );
      expect(item.type, 'checkbox');
      expect(item.checked, true);
      expect(item.radioGroup, isNull);
    });

    test('toJson has checkbox type with icon', () {
      final item = WinUIMenuItem.checkbox(
        label: 'Option',
        checked: false,
        winuiIcon: WinUIIcon.symbol(WinUISymbol.setting),
      );
      final json = item.toJson();
      expect(json['type'], 'checkbox');
      expect(json['checked'], false);
      expect(json['icon'], '0xE713');
    });
  });

  group('WinUIMenuItem.submenu', () {
    test('creates submenu item', () {
      final item = WinUIMenuItem.submenu(
        label: 'File',
        submenu: Menu(items: [MenuItem(label: 'Open')]),
      );
      expect(item.type, 'submenu');
      expect(item.submenu, isNotNull);
      expect(item.acceleratorText, isNull);
    });

    test('toJson includes icon on submenu', () {
      final item = WinUIMenuItem.submenu(
        label: 'File',
        submenu: Menu(items: []),
        winuiIcon: WinUIIcon.symbol(WinUISymbol.folder),
      );
      final json = item.toJson();
      expect(json['type'], 'submenu');
      expect(json['icon'], '0xE8B7');
    });
  });

  group('WinUIMenuItem.radio', () {
    test('creates radio item with type and group', () {
      final item = WinUIMenuItem.radio(
        label: 'Small',
        radioGroup: 'size',
        checked: false,
      );
      expect(item.type, 'radio');
      expect(item.radioGroup, 'size');
      expect(item.checked, false);
    });

    test('toJson serializes radio type and group', () {
      final item = WinUIMenuItem.radio(
        label: 'Large',
        radioGroup: 'sizeGroup',
        checked: true,
      );
      final json = item.toJson();
      expect(json['type'], 'radio');
      expect(json['radioGroup'], 'sizeGroup');
      expect(json['checked'], true);
    });

    test('toJson includes all extras together', () {
      final item = WinUIMenuItem.radio(
        label: 'Landscape',
        radioGroup: 'orientation',
        checked: true,
        winuiIcon: WinUIIcon.symbol(WinUISymbol.rotate),
        acceleratorText: 'Ctrl+L',
        toolTip: 'Switch to landscape',
      );
      final json = item.toJson();
      expect(json['type'], 'radio');
      expect(json['radioGroup'], 'orientation');
      expect(json['checked'], true);
      expect(json['icon'], '0xE7AD');
      expect(json['acceleratorText'], 'Ctrl+L');
      expect(json['toolTip'], 'Switch to landscape');
    });

    test('radio checked defaults to false', () {
      final item = WinUIMenuItem.radio(
        label: 'Option',
        radioGroup: 'group',
      );
      expect(item.checked, false);
    });
  });

  group('WinUIMenuItem is a MenuItem', () {
    test('instances are assignable to MenuItem', () {
      final MenuItem item = WinUIMenuItem(label: 'Test');
      expect(item.label, 'Test');
    });

    test('can be placed in a Menu', () {
      final menu = Menu(items: [
        WinUIMenuItem(
          label: 'Copy',
          winuiIcon: WinUIIcon.symbol(WinUISymbol.copy),
          acceleratorText: 'Ctrl+C',
        ),
        MenuItem.separator(),
        WinUIMenuItem.radio(
          label: 'Small',
          radioGroup: 'size',
        ),
        WinUIMenuItem.radio(
          label: 'Large',
          radioGroup: 'size',
          checked: true,
        ),
      ]);
      expect(menu.items, hasLength(4));
      final json = menu.toJson();
      final items = json['items'] as List;
      expect(items[0]['icon'], '0xE8C8');
      expect(items[2]['type'], 'radio');
      expect(items[3]['radioGroup'], 'size');
    });
  });
}
