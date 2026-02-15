import 'dart:io';

import 'package:flutter/material.dart';
import 'package:menu_base/menu_base.dart';

/// Info tab: explains how to use the tray context menu.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.menu});

  final Menu menu;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (Platform.isWindows) ...[
                const Icon(Icons.touch_app, size: 64, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'Right-click the tray icon',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Opens the WinUI 3 context menu with the current styling settings from the Styling tab.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Tip: Switch to the Styling tab to configure all options (colors, font, corners, etc.) and copy the code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ] else
                const Text(
                  'This plugin works only on Windows.',
                  style: TextStyle(color: Colors.orange, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
