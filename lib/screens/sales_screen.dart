import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/sale.dart';
import '../utils/format.dart';
import '../widgets/range_selector.dart';
import 'sale_detail_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  DateSpan _span = DateSpan.preset(RangePreset.today);
  List<Sale> _sales = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sales =
        await DatabaseHelper.instance.getSales(from: _span.from, to: _span.to);
    if (!mounted) return;
    setState(() {
      _sales = sales;
      _loading = false;
    });
  }

  Future<void> _open(Sale s) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: s.id)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final completed = _sales.where((s) => !s.isVoided);
    final revenue = completed.fold<double>(0, (a, s) => a + s.total);
    final profit = completed.fold<double>(0, (a, s) => a + s.profit);
    final t = Theme.of(context).textTheme;

    // Group by calendar day for section headers.
    final rows = <Object>[];
    DateTime? lastDay;
    for (final s in _sales) {
      final d = DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day);
      if (d != lastDay) {
        rows.add(d);
        lastDay = d;
      }
      rows.add(s);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      body: Column(
        children: [
          RangeSelector(
            value: _span,
            onChanged: (s) {
              setState(() => _span = s);
              _load();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              _Summary('Sales', '${completed.length}'),
              _Summary('Revenue', money(revenue)),
              _Summary('Profit', money(profit), color: Colors.green),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _sales.isEmpty
                    ? const Center(child: Text('No sales in this period.'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, i) {
                            final r = rows[i];
                            if (r is DateTime) {
                              return Container(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                child: Text(dayShort(r), style: t.labelLarge),
                              );
                            }
                            return _SaleTile(
                                sale: r as Sale, onTap: () => _open(r));
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Summary(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.labelSmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: t.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  final Sale sale;
  final VoidCallback onTap;
  const _SaleTile({required this.sale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = sale;
    final strike = s.isVoided
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: s.isVoided ? Colors.red.withValues(alpha: 0.2) : null,
        child: Icon(s.isVoided ? Icons.block : Icons.receipt_long, size: 20),
      ),
      title: Text(
          '${s.receiptNo}${s.customer.isEmpty ? '' : ' • ${s.customer}'}',
          style: strike),
      subtitle: Text([
        time(s.createdAt),
        s.paymentMethod.label,
        '${s.itemCount} item(s)',
        if (s.isVoided) 'VOIDED',
      ].join(' • ')),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(money(s.total),
              style: const TextStyle(fontWeight: FontWeight.bold)
                  .merge(strike)),
          if (!s.isVoided)
            Text('+${money(s.profit)}',
                style: TextStyle(
                    fontSize: 12,
                    color: s.profit >= 0 ? Colors.green : Colors.red)),
        ],
      ),
    );
  }
}
