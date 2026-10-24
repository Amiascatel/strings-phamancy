import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(label, style: t.labelMedium),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: t.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              if (sub != null)
                Text(sub!,
                    style: t.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays out [children] as a responsive grid of equal-width cards.
class StatGrid extends StatelessWidget {
  final List<Widget> children;
  const StatGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 600 ? 3 : 2);
      final w = (c.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          ?trailing,
        ],
      ),
    );
  }
}
