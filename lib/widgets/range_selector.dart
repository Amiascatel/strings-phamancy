import 'package:flutter/material.dart';

import '../utils/format.dart';

enum RangePreset {
  today('Today'),
  yesterday('Yesterday'),
  last7('Last 7 days'),
  thisMonth('This month'),
  last30('Last 30 days'),
  custom('Custom…');

  final String label;
  const RangePreset(this.label);
}

/// A half-open date range [from, to).
class DateSpan {
  final DateTime from;
  final DateTime to;
  final RangePreset preset;
  const DateSpan(this.from, this.to, this.preset);

  factory DateSpan.preset(RangePreset p) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return switch (p) {
      RangePreset.today => DateSpan(today, tomorrow, p),
      RangePreset.yesterday =>
        DateSpan(DateTime(today.year, today.month, today.day - 1), today, p),
      RangePreset.last7 => DateSpan(
          DateTime(today.year, today.month, today.day - 6), tomorrow, p),
      RangePreset.thisMonth =>
        DateSpan(DateTime(today.year, today.month, 1), tomorrow, p),
      RangePreset.last30 || RangePreset.custom => DateSpan(
          DateTime(today.year, today.month, today.day - 29), tomorrow, p),
    };
  }

  int get dayCount => to.difference(from).inHours ~/ 24;

  String get description {
    final last = DateTime(to.year, to.month, to.day - 1);
    return from == last ? date(from) : '${date(from)} – ${date(last)}';
  }
}

class RangeSelector extends StatelessWidget {
  final DateSpan value;
  final ValueChanged<DateSpan> onChanged;
  const RangeSelector(
      {super.key, required this.value, required this.onChanged});

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: value.from,
        end: DateTime(value.to.year, value.to.month, value.to.day - 1),
      ),
    );
    if (picked == null) return;
    final s = picked.start, e = picked.end;
    onChanged(DateSpan(DateTime(s.year, s.month, s.day),
        DateTime(e.year, e.month, e.day + 1), RangePreset.custom));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              for (final p in RangePreset.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p.label),
                    selected: value.preset == p,
                    onSelected: (_) => p == RangePreset.custom
                        ? _pickCustom(context)
                        : onChanged(DateSpan.preset(p)),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(value.description,
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
