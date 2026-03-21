import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.menu});

  final Menu menu;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
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
                  'Opens the WinUI 3 context menu with all styling settings from the Styling tab.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildFeatureSection(context),
                const SizedBox(height: 24),
                const Text(
                  'Switch to the Styling tab to configure all options and copy the generated Dart code.',
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

  Widget _buildFeatureSection(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WinUI 3 Features',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
            ),
            const SizedBox(height: 12),
            const _FeatureItem(
              icon: Icons.image_outlined,
              label: 'Icons',
              description: 'FontIcon / SymbolIcon via WinUIIcon',
            ),
            const _FeatureItem(
              icon: Icons.radio_button_checked,
              label: 'Radio Items',
              description: 'RadioMenuFlyoutItem with group management',
            ),
            const _FeatureItem(
              icon: Icons.check_box_outlined,
              label: 'Checkbox Items',
              description: 'ToggleMenuFlyoutItem with checked state',
            ),
            const _FeatureItem(
              icon: Icons.keyboard,
              label: 'Accelerator Text',
              description: 'Keyboard shortcut hints (e.g. Ctrl+C)',
            ),
            const _FeatureItem(
              icon: Icons.info_outline,
              label: 'Tooltips',
              description: 'Hover tooltips for menu items',
            ),
            const _FeatureItem(
              icon: Icons.account_tree_outlined,
              label: 'Submenus',
              description: 'Nested MenuFlyoutSubItem with icons',
            ),
            const _FeatureItem(
              icon: Icons.palette_outlined,
              label: '25+ Style Properties',
              description: 'Colors, fonts, borders, shadows, animations',
            ),
            const _FeatureItem(
              icon: Icons.event_note,
              label: 'Lifecycle Events',
              description: 'Opening / Closing / Closed callbacks',
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.label,
    required this.description,
  });

  final IconData icon;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: '$label  ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: description,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
