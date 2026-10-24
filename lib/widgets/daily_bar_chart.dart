import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/report.dart';
import '../utils/format.dart';

/// Grouped bar chart of revenue and profit per day.
class DailyBarChart extends StatelessWidget {
  final List<DailySales> days;
  const DailyBarChart({super.key, required this.days});

  static const _chartHeight = 180.0;
  static const _groupWidth = 34.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final revenueColor = scheme.primary;
    final profitColor = Colors.green.shade500;
    final maxV = days.fold<double>(0, (m, d) => math.max(m, d.revenue));
    final labelFmt = DateFormat(days.length > 14 ? 'd/M' : 'EEE\nd/M');

    Widget legend(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, color: c),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          legend(revenueColor, 'Revenue'),
          const SizedBox(width: 16),
          legend(profitColor, 'Profit'),
          const Spacer(),
          if (maxV > 0)
            Text('Peak ${compact(maxV)}',
                style: Theme.of(context).textTheme.bodySmall),
        ]),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final width = math.max(c.maxWidth, days.length * _groupWidth);
          final groupW = width / math.max(days.length, 1);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // start scrolled to the most recent days
            child: SizedBox(
              width: width,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in days)
                    SizedBox(
                      width: groupW,
                      child: Tooltip(
                        message: '${dayShort(d.day)}\n'
                            'Revenue: ${money(d.revenue)}\n'
                            'Profit: ${money(d.profit)}\n'
                            '${d.salesCount} sale(s)',
                        child: Column(
                          children: [
                            SizedBox(
                              height: _chartHeight,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _bar(d.revenue, maxV, revenueColor, groupW),
                                  const SizedBox(width: 2),
                                  _bar(d.profit, maxV, profitColor, groupW),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              labelFmt.format(d.day),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _bar(double v, double maxV, Color color, double groupW) {
    final h = maxV <= 0 ? 0.0 : (math.max(v, 0) / maxV) * _chartHeight;
    return Container(
      width: math.min(14, (groupW - 8) / 2),
      height: math.max(h, v > 0 ? 2 : 0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }
}
