import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/medicine.dart';
import '../models/report.dart';
import '../models/sale.dart';
import '../utils/app_settings.dart';
import '../utils/format.dart';
import '../widgets/range_selector.dart';
import '../widgets/stat_card.dart';
import 'history_screen.dart';
import 'inventory_screen.dart';
import 'sale_detail_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(InventoryFilter filter) onOpenInventory;
  final VoidCallback onNewSale;
  final VoidCallback onOpenSales;
  const DashboardScreen({
    super.key,
    required this.onOpenInventory,
    required this.onNewSale,
    required this.onOpenSales,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Medicine> _meds = [];
  SalesSummary _today = const SalesSummary();
  SalesSummary _month = const SalesSummary();
  List<Sale> _recentSales = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final today = DateSpan.preset(RangePreset.today);
    final month = DateSpan.preset(RangePreset.thisMonth);
    final meds = await db.getMedicines();
    final t = await db.getSalesSummary(today.from, today.to);
    final m = await db.getSalesSummary(month.from, month.to);
    final recent = await db.getSales(limit: 5);
    if (!mounted) return;
    setState(() {
      _meds = meds;
      _today = t;
      _month = m;
      _recentSales = recent;
      _loading = false;
    });
  }

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final stockValue = _meds.fold<double>(0, (s, m) => s + m.stockValue);
    final low = _meds.where((m) => m.isLowStock).length;
    final expiring = _meds.where((m) => m.isExpiringSoon).length;
    final expired = _meds.where((m) => m.isExpired).length;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppSettings.pharmacyName),
        actions: [
          IconButton(
              tooltip: 'Stock history',
              onPressed: () => _push(const HistoryScreen()),
              icon: const Icon(Icons.history)),
          IconButton(
              tooltip: 'Settings',
              onPressed: () => _push(const SettingsScreen()),
              icon: const Icon(Icons.settings_outlined)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FilledButton.icon(
                    onPressed: widget.onNewSale,
                    icon: const Icon(Icons.point_of_sale),
                    label: const Text('New sale'),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                  const SectionTitle('Sales'),
                  StatGrid(children: [
                    StatCard(
                      icon: Icons.today,
                      label: "Today's sales",
                      value: money(_today.revenue),
                      sub: '${_today.salesCount} sale(s)',
                      color: Colors.indigo,
                      onTap: widget.onOpenSales,
                    ),
                    StatCard(
                      icon: Icons.trending_up,
                      label: "Today's profit",
                      value: money(_today.profit),
                      sub: 'Margin ${percent(_today.margin)}',
                      color: Colors.green,
                      onTap: widget.onOpenSales,
                    ),
                    StatCard(
                      icon: Icons.calendar_month,
                      label: 'This month',
                      value: money(_month.revenue),
                      sub: '${_month.salesCount} sale(s)',
                      color: Colors.blue,
                    ),
                    StatCard(
                      icon: Icons.savings_outlined,
                      label: 'Profit this month',
                      value: money(_month.profit),
                      sub: 'Margin ${percent(_month.margin)}',
                      color: Colors.teal,
                    ),
                  ]),
                  const SectionTitle('Inventory'),
                  StatGrid(children: [
                    StatCard(
                      icon: Icons.medication,
                      label: 'Products',
                      value: '${_meds.length}',
                      sub: 'Stock value ${money(stockValue)}',
                      color: Colors.teal,
                      onTap: () => widget.onOpenInventory(InventoryFilter.all),
                    ),
                    StatCard(
                      icon: Icons.trending_down,
                      label: 'Low stock',
                      value: '$low',
                      sub: 'Need reordering',
                      color: Colors.amber.shade700,
                      onTap: () =>
                          widget.onOpenInventory(InventoryFilter.lowStock),
                    ),
                    StatCard(
                      icon: Icons.schedule,
                      label: 'Expiring soon',
                      value: '$expiring',
                      sub: 'Within ${Medicine.expiringSoonDays} days',
                      color: Colors.orange,
                      onTap: () =>
                          widget.onOpenInventory(InventoryFilter.expiring),
                    ),
                    StatCard(
                      icon: Icons.dangerous_outlined,
                      label: 'Expired',
                      value: '$expired',
                      sub: 'Remove from shelves',
                      color: Colors.red,
                      onTap: () =>
                          widget.onOpenInventory(InventoryFilter.expired),
                    ),
                  ]),
                  SectionTitle('Recent sales',
                      trailing: TextButton(
                          onPressed: widget.onOpenSales,
                          child: const Text('See all'))),
                  if (_recentSales.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No sales yet. Tap "New sale" to start.'),
                      ),
                    )
                  else
                    Card(
                      child: Column(children: [
                        for (final s in _recentSales)
                          ListTile(
                            onTap: () =>
                                _push(SaleDetailScreen(saleId: s.id)),
                            leading: Icon(
                                s.isVoided ? Icons.block : Icons.receipt_long),
                            title: Text(s.receiptNo),
                            subtitle: Text(
                                '${dateTime(s.createdAt)} • ${s.paymentMethod.label}'
                                '${s.isVoided ? ' • VOIDED' : ''}'),
                            trailing: Text(money(s.total),
                                style: t.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                          ),
                      ]),
                    ),
                ],
              ),
            ),
    );
  }
}
