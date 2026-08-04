// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';

class PanelStatChip extends StatelessWidget {
  const PanelStatChip({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value', style: theme.textTheme.labelMedium),
    );
  }
}
