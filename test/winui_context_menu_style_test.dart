import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager_winui/tray_manager_winui.dart';

void main() {
  group('WinUIContextMenuStyle', () {
    test('default style serializes only compactItemLayout', () {
      const style = WinUIContextMenuStyle();
      final json = style.toJson();
      expect(json, {'compactItemLayout': true});
    });

    test('color properties serialize as ARGB32 integers', () {
      const style = WinUIContextMenuStyle(
        backgroundColor: Color(0xFF1E1E1E),
        textColor: Color(0xFFFFFFFF),
        separatorColor: Color(0xFF555555),
        disabledTextColor: Color(0xFF888888),
        hoverBackgroundColor: Color(0xFF404040),
        subMenuOpenedBackgroundColor: Color(0xFF505050),
        subMenuOpenedTextColor: Color(0xFFEEEEEE),
        borderColor: Color(0xFF333333),
        checkedIndicatorColor: Color(0xFF4FC3F7),
      );
      final json = style.toJson();

      expect(json['backgroundColor'], 0xFF1E1E1E);
      expect(json['textColor'], 0xFFFFFFFF);
      expect(json['separatorColor'], 0xFF555555);
      expect(json['disabledTextColor'], 0xFF888888);
      expect(json['hoverBackgroundColor'], 0xFF404040);
      expect(json['subMenuOpenedBackgroundColor'], 0xFF505050);
      expect(json['subMenuOpenedTextColor'], 0xFFEEEEEE);
      expect(json['borderColor'], 0xFF333333);
      expect(json['checkedIndicatorColor'], 0xFF4FC3F7);
    });

    test('null color properties are omitted from json', () {
      const style = WinUIContextMenuStyle(
        backgroundColor: Color(0xFF000000),
      );
      final json = style.toJson();

      expect(json.containsKey('backgroundColor'), true);
      expect(json.containsKey('textColor'), false);
      expect(json.containsKey('separatorColor'), false);
    });

    test('numeric properties serialize correctly', () {
      const style = WinUIContextMenuStyle(
        fontSize: 14.0,
        cornerRadius: 8.0,
        minWidth: 200.0,
        borderThickness: 1.5,
        itemHeight: 36.0,
        shadowElevation: 32.0,
        maxHeight: 400.0,
      );
      final json = style.toJson();

      expect(json['fontSize'], 14.0);
      expect(json['cornerRadius'], 8.0);
      expect(json['minWidth'], 200.0);
      expect(json['borderThickness'], 1.5);
      expect(json['itemHeight'], 36.0);
      expect(json['shadowElevation'], 32.0);
      expect(json['maxHeight'], 400.0);
    });

    test('font properties serialize correctly', () {
      const style = WinUIContextMenuStyle(
        fontFamily: 'Segoe UI',
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      );
      final json = style.toJson();

      expect(json['fontFamily'], 'Segoe UI');
      expect(json['fontWeight'], 700);
      expect(json['fontStyle'], 'italic');
    });

    test('padding serializes as LTRB map', () {
      const style = WinUIContextMenuStyle(
        padding: EdgeInsets.fromLTRB(4, 8, 12, 16),
      );
      final json = style.toJson();

      expect(json['padding'], {
        'left': 4.0,
        'top': 8.0,
        'right': 12.0,
        'bottom': 16.0,
      });
    });

    test('themeMode serializes as string', () {
      expect(
        const WinUIContextMenuStyle(themeMode: WinUIThemeMode.dark)
            .toJson()['themeMode'],
        'dark',
      );
      expect(
        const WinUIContextMenuStyle(themeMode: WinUIThemeMode.light)
            .toJson()['themeMode'],
        'light',
      );
      expect(
        const WinUIContextMenuStyle(themeMode: WinUIThemeMode.system)
            .toJson()['themeMode'],
        'system',
      );
    });

    test('compactItemLayout defaults to true', () {
      const style = WinUIContextMenuStyle();
      expect(style.compactItemLayout, true);
      expect(style.toJson()['compactItemLayout'], true);
    });

    test('compactItemLayout false serializes correctly', () {
      const style = WinUIContextMenuStyle(compactItemLayout: false);
      expect(style.toJson()['compactItemLayout'], false);
    });

    test('enableOpenCloseAnimations serializes correctly', () {
      const enabled = WinUIContextMenuStyle(enableOpenCloseAnimations: true);
      expect(enabled.toJson()['enableOpenCloseAnimations'], true);

      const disabled = WinUIContextMenuStyle(enableOpenCloseAnimations: false);
      expect(disabled.toJson()['enableOpenCloseAnimations'], false);
    });

    test('null optional properties are omitted', () {
      const style = WinUIContextMenuStyle();
      final json = style.toJson();

      expect(json.containsKey('fontSize'), false);
      expect(json.containsKey('fontFamily'), false);
      expect(json.containsKey('fontWeight'), false);
      expect(json.containsKey('cornerRadius'), false);
      expect(json.containsKey('padding'), false);
      expect(json.containsKey('themeMode'), false);
      expect(json.containsKey('maxHeight'), false);
      expect(json.containsKey('enableOpenCloseAnimations'), false);
    });

    group('validation asserts', () {
      test('rejects negative fontSize', () {
        expect(
          () => WinUIContextMenuStyle(fontSize: -1),
          throwsA(isA<AssertionError>()),
        );
      });

      test('rejects zero fontSize', () {
        expect(
          () => WinUIContextMenuStyle(fontSize: 0),
          throwsA(isA<AssertionError>()),
        );
      });

      test('accepts positive fontSize', () {
        expect(
          () => const WinUIContextMenuStyle(fontSize: 12),
          returnsNormally,
        );
      });

      test('rejects negative cornerRadius', () {
        expect(
          () => WinUIContextMenuStyle(cornerRadius: -1),
          throwsA(isA<AssertionError>()),
        );
      });

      test('accepts zero cornerRadius', () {
        expect(
          () => const WinUIContextMenuStyle(cornerRadius: 0),
          returnsNormally,
        );
      });

      test('rejects negative borderThickness', () {
        expect(
          () => WinUIContextMenuStyle(borderThickness: -0.5),
          throwsA(isA<AssertionError>()),
        );
      });

      test('rejects negative itemHeight', () {
        expect(
          () => WinUIContextMenuStyle(itemHeight: -10),
          throwsA(isA<AssertionError>()),
        );
      });

      test('rejects negative shadowElevation', () {
        expect(
          () => WinUIContextMenuStyle(shadowElevation: -1),
          throwsA(isA<AssertionError>()),
        );
      });

      test('accepts zero shadowElevation', () {
        expect(
          () => const WinUIContextMenuStyle(shadowElevation: 0),
          returnsNormally,
        );
      });

      test('rejects negative minWidth', () {
        expect(
          () => WinUIContextMenuStyle(minWidth: -100),
          throwsA(isA<AssertionError>()),
        );
      });

      test('rejects negative maxHeight', () {
        expect(
          () => WinUIContextMenuStyle(maxHeight: -100),
          throwsA(isA<AssertionError>()),
        );
      });
    });
  });

  group('WinUIFlyoutPlacement', () {
    test('has all 14 placement values', () {
      expect(WinUIFlyoutPlacement.values.length, 14);
    });

    test('enum names match WinUI FlyoutPlacementMode', () {
      final expectedNames = [
        'top',
        'bottom',
        'left',
        'right',
        'full',
        'auto',
        'topEdgeAlignedLeft',
        'topEdgeAlignedRight',
        'bottomEdgeAlignedLeft',
        'bottomEdgeAlignedRight',
        'leftEdgeAlignedTop',
        'leftEdgeAlignedBottom',
        'rightEdgeAlignedTop',
        'rightEdgeAlignedBottom',
      ];
      final actualNames =
          WinUIFlyoutPlacement.values.map((v) => v.name).toList();
      expect(actualNames, expectedNames);
    });
  });

  group('WinUIThemeMode', () {
    test('has light, dark, system values', () {
      expect(WinUIThemeMode.values.length, 3);
      expect(WinUIThemeMode.light.name, 'light');
      expect(WinUIThemeMode.dark.name, 'dark');
      expect(WinUIThemeMode.system.name, 'system');
    });
  });
}
