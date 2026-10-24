import 'package:flutter/material.dart';

import '../models/medicine.dart';

class StatusBadges extends StatelessWidget {
  final Medicine medicine;
  const StatusBadges({super.key, required this.medicine});

  @override
  Widget build(BuildContext context) {
    final m = medicine;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        if (m.isExpired) const _Badge('Expired', Colors.red),
        if (m.isExpiringSoon) const _Badge('Expiring soon', Colors.orange),
        if (m.isOutOfStock)
          const _Badge('Out of stock', Colors.red)
        else if (m.isLowStock)
          const _Badge('Low stock', Colors.amber),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final MaterialColor color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: dark ? color.shade200 : color.shade800,
        ),
      ),
    );
  }
}
