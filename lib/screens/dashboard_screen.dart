import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/medicine.dart';
import '../models/stock_transaction.dart';
import '../utils/format.dart';
import 'inventory_screen.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(InventoryFilter filter) onOpenInventory;
  const DashboardScreen({super.key, required this.onOpenInventory});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Medicine> _meds = [];
  List<StockTransaction> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final meds = await db.getMedicines();
    final recent = await db.getTransactions(limit: 8);
    if (!mounted) return;
    setState(() {
      _meds = meds;
      _recent = recent;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalUnits = _meds.fold<int>(0, (s, m) => s + m.quantity);
    final stockValue = _meds.fold<double>(0, (s, m) => s + m.stockValue);
    final retailValue =
        _meds.fold<double>(0, (s, m) => s + m.quantity * m.sellingPrice);
    final low = _meds.where((m) => m.isLowStock).length;
    final expiring = _meds.where((m) => m.isExpiringSoon).length;
    final expired = _meds.where((m) => m.isExpired).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Strings Pharmacy'),
        actions: [
          IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  LayoutBuilder(builder: (context, c) {
                    final cols = c.maxWidth > 700 ? 3 : 2;
                    final w = (c.maxWidth - (cols - 1) * 12) / cols;
                    Widget card(Widget child) => SizedBox(width: w, child: child);
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        card(_StatCard(
                          icon: Icons.medication,
                          label: 'Products',
                          value: '${_meds.length}',
                          sub: '$totalUnits units in stock',
                          color: Colors.teal,
                          onTap: () =>
                              widget.onOpenInventory(InventoryFilter.all),
                        )),
                        card(_StatCard(
                          icon: Icons.payments_outlined,
                          label: 'Stock value (cost)',
                          value: money(stockValue),
                          sub: 'Retail: ${money(retailValue)}',
                          color: Colors.indigo,
                        )),
                        card(_StatCard(
                          icon: Icons.trending_down,
                          label: 'Low stock',
                          value: '$low',
                          sub: 'At or below reorder level',
                          color: Colors.amber,
                          onTap: () =>
                              widget.onOpenInventory(InventoryFilter.lowStock),
                        )),
                        card(_StatCard(
                          icon: Icons.schedule,
                          label: 'Expiring soon',
                          value: '$expiring',
                          sub: 'Within ${Medicine.expiringSoonDays} days',
                          color: Colors.orange,
                          onTap: () =>
                              widget.onOpenInventory(InventoryFilter.expiring),
                        )),
                        card(_StatCard(
                          icon: Icons.dangerous_outlined,
                          label: 'Expired',
                          value: '$expired',
                          sub: 'Remove from shelves',
                          color: Colors.red,
                          onTap: () =>
                              widget.onOpenInventory(InventoryFilter.expired),
                        )),
                      ],
                    );
                  }),
                  const SizedBox(height: 24),
                  Text('Recent activity',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_recent.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                          child: Text(
                              'No activity yet. Add medicines from the Inventory tab.')),
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final t in _recent) TransactionTile(t),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final MaterialColor color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
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
              Text(sub,
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

class TransactionTile extends StatelessWidget {
  final StockTransaction t;
  final bool showName;
  const TransactionTile(this.t, {super.key, this.showName = true});

  @override
  Widget build(BuildContext context) {
    final (icon, color, qtyText) = switch (t.type) {
      TransactionType.stockIn => (Icons.add_circle, Colors.green, '+${t.quantity}'),
      TransactionType.stockOut => (Icons.remove_circle, Colors.red, '-${t.quantity}'),
      TransactionType.adjust => (Icons.tune, Colors.blueGrey, '=${t.quantity}'),
    };
    final subtitle = [
      if (showName) t.type.label,
      dateTime(t.createdAt),
      if (t.note.isNotEmpty) t.note,
    ].join(' • ');
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(showName ? t.medicineName : t.type.label),
      subtitle: Text(subtitle),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(qtyText,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text('Bal: ${t.balanceAfter}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
