import 'package:flutter/material.dart';

class SliderRow extends StatelessWidget {
  const SliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onClear,
    this.suffix = '',
  });

  final String label;
  final double? value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final VoidCallback? onClear;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final isSet = value != null;
    final displayValue = isSet ? value!.clamp(min, max) : min;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(label)),
          Expanded(
            child: Slider(
              value: displayValue,
              min: min,
              max: max,
              divisions: (max - min).round().clamp(1, 1000),
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              isSet ? '${value!.toStringAsFixed(1)}$suffix' : '—',
              style: TextStyle(
                fontSize: 12,
                color: isSet ? null : Theme.of(context).disabledColor,
              ),
            ),
          ),
          if (isSet && onClear != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}
