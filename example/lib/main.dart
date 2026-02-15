import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager_winui_example/main_tab_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: BotToastInit(),
      navigatorObservers: [BotToastNavigatorObserver()],
      home: const MainTabPage(),
    );
  }
}
