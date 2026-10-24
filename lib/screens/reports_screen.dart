import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/medicine.dart';
import '../models/report.dart';
import '../utils/format.dart';
import '../widgets/daily_bar_chart.dart';
import '../widgets/range_selector.dart';
import '../widgets/stat_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateSpan _span = DateSpan.preset(RangePreset.last7);
  SalesSummary _summary = const SalesSummary();
  SalesSummary _previous = const SalesSummary();
  List<DailySales> _daily = [];
  List<SalesBreakdown> _top = [];
  List<SalesBreakdown> _categories = [];
  List<SalesBreakdown> _payments = [];
  List<Medicine> _meds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final from = _span.from, to = _span.to;
    // Same-length period immediately before, for comparison.
    final prevFrom =
        DateTime(from.year, from.month, from.day - _span.dayCount);
    final results = await Future.wait([
      db.getSalesSummary(from, to),
      db.getSalesSummary(prevFrom, from),
      db.getDailySales(from, to),
      db.getTopProducts(from, to),
      db.getCategorySales(from, to),
      db.getPaymentBreakdown(from, to),
      db.getMedicines(),
    ]);
    if (!mounted) return;
    setState(() {
      _summary = results[0] as SalesSummary;
      _previous = results[1] as SalesSummary;
      _daily = results[2] as List<DailySales>;
      _top = results[3] as List<SalesBreakdown>;
      _categories = results[4] as List<SalesBreakdown>;
      _payments = results[5] as List<SalesBreakdown>;
      _meds = results[6] as List<Medicine>;
      _loading = false;
    });
  }

  String _vsPrevious(double now, double before) {
    if (before == 0) return now == 0 ? 'No change' : 'New vs previous period';
    final pct = (now - before) / before.abs() * 100;
    return '${pct >= 0 ? '▲' : '▼'} ${pct.abs().toStringAsFixed(0)}% vs previous';
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final t = Theme.of(context).textTheme;
    final bestDay = _daily.isEmpty
        ? null
        : _daily.reduce((a, b) => b.revenue > a.revenue ? b : a);
    final activeDays = _daily.where((d) => d.salesCount > 0).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          RangeSelector(
            value: _span,
            onChanged: (v) {
              setState(() => _span = v);
              _load();
            },
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        StatGrid(children: [
                          StatCard(
                            icon: Icons.payments,
                            label: 'Revenue',
                            value: money(s.revenue),
                            sub: _vsPrevious(s.revenue, _previous.revenue),
                            color: Colors.indigo,
                          ),
                          StatCard(
                            icon: Icons.trending_up,
                            label: 'Profit',
                            value: money(s.profit),
                            sub: _vsPrevious(s.profit, _previous.profit),
                            color: Colors.green,
                          ),
                          StatCard(
                            icon: Icons.inventory_2_outlined,
                            label: 'Cost of goods sold',
                            value: money(s.cost),
                            sub: 'Margin ${percent(s.margin)}',
                            color: Colors.brown,
                          ),
                          StatCard(
                            icon: Icons.receipt_long,
                            label: 'Sales',
                            value: '${s.salesCount}',
                            sub: '${s.unitsSold} units sold',
                            color: Colors.teal,
                          ),
                          StatCard(
                            icon: Icons.shopping_basket_outlined,
                            label: 'Average sale',
                            value: money(s.averageSale),
                            sub: activeDays > 0
                                ? '${money(s.revenue / activeDays)} / trading day'
                                : null,
                            color: Colors.blue,
                          ),
                          StatCard(
                            icon: Icons.discount_outlined,
                            label: 'Discounts given',
                            value: money(s.discount),
                            sub: s.subtotal > 0
                                ? '${percent(s.discount / s.subtotal * 100)} of gross'
                                : null,
                            color: Colors.orange,
                          ),
                        ]),
                        if (_span.dayCount > 1) ...[
                          SectionTitle('Daily sales',
                              trailing: bestDay != null && bestDay.revenue > 0
                                  ? Text('Best: ${dayShort(bestDay.day)}',
                                      style: t.bodySmall)
                                  : null),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: DailyBarChart(days: _daily),
                            ),
                          ),
                          const SectionTitle('Day by day'),
                          Card(child: _dailyTable(context)),
                        ],
                        const SectionTitle('Top products'),
                        _breakdownCard(_top, showProfit: true, unitLabel: 'units'),
                        const SectionTitle('Sales by category'),
                        _breakdownCard(_categories,
                            showProfit: true, unitLabel: 'units'),
                        const SectionTitle('Payment methods'),
                        _breakdownCard(_payments, unitLabel: 'sales'),
                        const SectionTitle('Inventory snapshot (now)'),
                        _inventoryCard(context),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _dailyTable(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rows = _daily.reversed.toList();
    TextStyle? head = t.labelMedium?.copyWith(fontWeight: FontWeight.bold);
    Widget cell(String s, {TextStyle? style, int flex = 2, bool end = true}) =>
        Expanded(
          flex: flex,
          child: Text(s,
              style: style,
              textAlign: end ? TextAlign.end : TextAlign.start,
              overflow: TextOverflow.ellipsis),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(children: [
            cell('Day', style: head, flex: 3, end: false),
            cell('Sales', style: head, flex: 1),
            cell('Revenue', style: head, flex: 3),
            cell('Profit', style: head, flex: 3),
          ]),
          const Divider(),
          for (final d in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                cell(dayShort(d.day), flex: 3, end: false, style: t.bodySmall),
                cell('${d.salesCount}', flex: 1, style: t.bodySmall),
                cell(money(d.revenue), flex: 3, style: t.bodySmall),
                cell(money(d.profit),
                    flex: 3,
                    style: t.bodySmall?.copyWith(
                        color: d.profit > 0 ? Colors.green : null)),
              ]),
            ),
          const Divider(),
          Row(children: [
            cell('Total', style: head, flex: 3, end: false),
            cell('${_summary.salesCount}', style: head, flex: 1),
            cell(money(_summary.revenue), style: head, flex: 3),
            cell(money(_summary.profit), style: head, flex: 3),
          ]),
        ],
      ),
    );
  }

  Widget _breakdownCard(List<SalesBreakdown> rows,
      {bool showProfit = false, required String unitLabel}) {
    if (rows.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No sales in this period.'),
        ),
      );
    }
    final maxRev = rows.map((r) => r.revenue).reduce((a, b) => a > b ? a : b);
    return Card(
      child: Column(
        children: [
          for (final (i, r) in rows.indexed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    SizedBox(
                        width: 24,
                        child: Text('${i + 1}.',
                            style: Theme.of(context).textTheme.bodySmall)),
                    Expanded(
                        child: Text(r.label,
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(money(r.revenue),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: maxRev > 0 ? r.revenue / maxRev : 0,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            '${r.count} $unitLabel',
                            if (_summary.revenue > 0)
                              '${percent(r.revenue / _summary.revenue * 100)} of revenue',
                            if (showProfit) 'profit ${money(r.profit)}',
                          ].join(' • '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _inventoryCard(BuildContext context) {
    final cost = _meds.fold<double>(0, (a, m) => a + m.stockValue);
    final retail =
        _meds.fold<double>(0, (a, m) => a + m.quantity * m.sellingPrice);
    final expiredValue = _meds
        .where((m) => m.isExpired)
        .fold<double>(0, (a, m) => a + m.stockValue);
    final low = _meds.where((m) => m.isLowStock).length;
    final out = _meds.where((m) => m.isOutOfStock).length;

    Widget row(String label, String value, {Color? color}) => ListTile(
          dense: true,
          title: Text(label),
          trailing: Text(value,
              style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        );

    return Card(
      child: Column(children: [
        row('Products', '${_meds.length}'),
        row('Units in stock',
            '${_meds.fold<int>(0, (a, m) => a + m.quantity)}'),
        row('Stock value at cost', money(cost)),
        row('Stock value at retail', money(retail)),
        row('Potential profit in stock', money(retail - cost),
            color: Colors.green),
        row('Value of expired stock', money(expiredValue),
            color: expiredValue > 0 ? Colors.red : null),
        row('Low stock / out of stock', '$low / $out',
            color: low > 0 ? Colors.orange : null),
      ]),
    );
  }
}
