import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager_winui_example/main.dart';

void main() {
  testWidgets('App starts without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('tray_manager_winui'), findsOneWidget);
  });
}
