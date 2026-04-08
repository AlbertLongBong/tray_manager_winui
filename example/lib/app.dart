import 'package:flutter/material.dart';

import 'pages/overview_page.dart';
import 'pages/style_editor_page.dart';
import 'tray_controller.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final TrayController _controller;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _controller = TrayController();
    _controller.scaffoldMessengerKey = _scaffoldMessengerKey;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('tray_manager_winui'),
            centerTitle: false,
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Overview', icon: Icon(Icons.info_outline)),
                Tab(text: 'Style Editor', icon: Icon(Icons.palette_outlined)),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              OverviewPage(controller: _controller),
              StyleEditorPage(controller: _controller),
            ],
          ),
        ),
      ),
    );
  }
}
