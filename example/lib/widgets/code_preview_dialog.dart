import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CodePreviewDialog extends StatelessWidget {
  const CodePreviewDialog({super.key, required this.code});

  final String code;

  static Future<void> show(BuildContext context, String code) {
    return showDialog(
      context: context,
      builder: (_) => CodePreviewDialog(code: code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Generated Dart Code'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Code copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            Navigator.pop(context);
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copy'),
        ),
      ],
    );
  }
}
