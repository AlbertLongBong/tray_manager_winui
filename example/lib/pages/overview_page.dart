import 'dart:io';

import 'package:flutter/material.dart';

import '../tray_controller.dart';
import '../widgets/section_card.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key, required this.controller});

  final TrayController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!Platform.isWindows)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('This plugin works only on Windows.'),
                  ),
                ),
              if (Platform.isWindows) ...[
                _buildHeroSection(context),
                const SizedBox(height: 24),
                _buildShowMenuButton(context),
                const SizedBox(height: 16),
                _buildRandomMenuButtons(context),
                const SizedBox(height: 24),
                _buildFeatureSection(context),
                const SizedBox(height: 24),
                _buildEventLogSection(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          Icons.widgets_outlined,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          'WinUI 3 Context Menu',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Modern Fluent Design context menu for your system tray icon. '
          'Right-click the tray icon or use the button below to test.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildShowMenuButton(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: controller.showMenu,
        icon: const Icon(Icons.menu_open),
        label: const Text('Show Context Menu'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildRandomMenuButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: controller.generateTrueRandomMenu,
          icon: const Icon(Icons.shuffle, size: 18),
          label: const Text('True Random'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: controller.generateStructuredRandomMenu,
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text('Structured Random'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureSection(BuildContext context) {
    return const SectionCard(
      title: 'Features',
      children: [
        _FeatureItem(
          icon: Icons.image_outlined,
          label: 'Icons',
          description: 'FontIcon / SymbolIcon via WinUIIcon with iconColor',
        ),
        _FeatureItem(
          icon: Icons.radio_button_checked,
          label: 'Radio Items',
          description: 'RadioMenuFlyoutItem with group management',
        ),
        _FeatureItem(
          icon: Icons.check_box_outlined,
          label: 'Checkbox Items',
          description: 'ToggleMenuFlyoutItem with checked state styling',
        ),
        _FeatureItem(
          icon: Icons.call_split,
          label: 'Split Items',
          description:
              'SplitMenuFlyoutItem – primary action + submenu (SDK 1.8+)',
        ),
        _FeatureItem(
          icon: Icons.keyboard,
          label: 'Accelerator Text',
          description: 'Keyboard shortcut hints with custom color',
        ),
        _FeatureItem(
          icon: Icons.info_outline,
          label: 'Tooltips',
          description: 'Hover tooltips for menu items',
        ),
        _FeatureItem(
          icon: Icons.account_tree_outlined,
          label: 'Submenus',
          description: 'Nested MenuFlyoutSubItem with icons',
        ),
        _FeatureItem(
          icon: Icons.blur_on,
          label: 'Acrylic / Mica Backdrop',
          description: 'System material as menu background (Win11)',
        ),
        _FeatureItem(
          icon: Icons.block,
          label: 'Exclusion Rect',
          description: 'Avoid specific screen areas when showing menu',
        ),
        _FeatureItem(
          icon: Icons.mouse_outlined,
          label: 'Dismiss on Pointer Away',
          description: 'Auto-close when cursor leaves the menu',
        ),
        _FeatureItem(
          icon: Icons.palette_outlined,
          label: '30+ Style Properties',
          description: 'Colors, fonts, borders, shadows, backdrops, animations',
        ),
        _FeatureItem(
          icon: Icons.event_note,
          label: 'Lifecycle Events',
          description: 'Opening / Closing / Closed callbacks',
        ),
      ],
    );
  }

  Widget _buildEventLogSection(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final log = controller.eventLog;
        return SectionCard(
          title: 'Event Log',
          trailing: log.isNotEmpty
              ? TextButton.icon(
                  onPressed: controller.clearEventLog,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                )
              : null,
          children: [
            if (log.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No events yet – right-click the tray icon or press the button above.',
                  style: TextStyle(color: Theme.of(context).disabledColor),
                ),
              )
            else
              SizedBox(
                height: (log.length.clamp(1, 8) * 28.0).clamp(28.0, 224.0),
                child: ListView.builder(
                  itemCount: log.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log[index],
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Consolas',
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: '$label  ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: description,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
