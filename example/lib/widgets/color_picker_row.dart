import 'package:flutter/material.dart';

const presetColors = [
  Color(0xFF1E1E1E),
  Color(0xFF2D2D2D),
  Color(0xFF3D3D3D),
  Color(0xFF1A1A2E),
  Color(0xFF16213E),
  Color(0xFF0F3460),
  Color(0xFFFFFFFF),
  Color(0xFFF5F5F5),
  Color(0xFFE0E0E0),
  Color(0xFFBDBDBD),
  Color(0xFF9E9E9E),
  Color(0xFF757575),
  Color(0xFF2196F3),
  Color(0xFF4CAF50),
  Color(0xFFFF9800),
  Color(0xFFE91E63),
];

class ColorPickerRow extends StatelessWidget {
  const ColorPickerRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onClear,
  });

  final String label;
  final Color? value;
  final ValueChanged<Color> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 160, child: Text(label)),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in presetColors)
                  _ColorChip(
                    color: c,
                    isSelected: value != null && value == c,
                    onTap: () => onChanged(c),
                  ),
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey),
              ),
            ),
          ],
          if (value != null && onClear != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade400,
            width: isSelected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}
