import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/sale.dart';
import '../utils/app_settings.dart';
import '../utils/format.dart';

class SaleDetailScreen extends StatefulWidget {
  final int saleId;

  /// Shows a "Sale complete" banner when opened straight after checkout.
  final bool justCreated;
  const SaleDetailScreen(
      {super.key, required this.saleId, this.justCreated = false});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  Sale? _sale;
  List<SaleItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final sale = await db.getSale(widget.saleId);
    final items = await db.getSaleItems(widget.saleId);
    if (!mounted) return;
    setState(() {
      _sale = sale;
      _items = items;
      _loading = false;
    });
  }

  Future<void> _void() async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Void ${_sale!.receiptNo}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('All items will be returned to stock and the sale '
                'will no longer count in reports.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Void sale')),
        ],
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (ok != true) return;
    try {
      await DatabaseHelper.instance.voidSale(widget.saleId, reason: reason);
      await _load();
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = _sale;
    if (s == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Sale not found.')));
    }
    final t = Theme.of(context).textTheme;
    final mono = t.bodyMedium?.copyWith(fontFeatures: const [
      FontFeature.tabularFigures(),
    ]);

    Widget line(String label, String value, {TextStyle? style}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(label, style: style ?? mono)),
            Text(value, style: style ?? mono),
          ]),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text('Receipt ${s.receiptNo}'),
        actions: [
          if (!s.isVoided)
            TextButton.icon(
              onPressed: _void,
              icon: const Icon(Icons.block, color: Colors.red),
              label:
                  const Text('Void', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.justCreated && !s.isVoided)
                Card(
                  color: Colors.green.withValues(alpha: 0.15),
                  child: ListTile(
                    leading:
                        const Icon(Icons.check_circle, color: Colors.green),
                    title: const Text('Sale complete'),
                    subtitle: s.changeDue > 0
                        ? Text('Change due: ${money(s.changeDue)}',
                            style: t.titleMedium)
                        : null,
                  ),
                ),
              if (s.isVoided)
                Card(
                  color: Colors.red.withValues(alpha: 0.15),
                  child: const ListTile(
                    leading: Icon(Icons.block, color: Colors.red),
                    title: Text('This sale was voided'),
                    subtitle: Text('Items were returned to stock.'),
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(AppSettings.pharmacyName,
                          textAlign: TextAlign.center,
                          style: t.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Receipt ${s.receiptNo}\n${dateTime(s.createdAt)}',
                          textAlign: TextAlign.center, style: t.bodySmall),
                      const Divider(height: 24),
                      if (s.customer.isNotEmpty) line('Customer', s.customer),
                      line('Payment', s.paymentMethod.label),
                      const Divider(height: 24),
                      for (final i in _items) ...[
                        Text(i.medicineName,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        line('  ${i.quantity} ${i.unit} × ${money(i.unitPrice)}',
                            money(i.lineTotal)),
                        const SizedBox(height: 6),
                      ],
                      const Divider(height: 24),
                      line('Subtotal', money(s.subtotal)),
                      if (s.discount > 0)
                        line('Discount', '-${money(s.discount)}'),
                      line('TOTAL', money(s.total),
                          style: t.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      line('Paid', money(s.amountPaid)),
                      if (s.changeDue > 0) line('Change', money(s.changeDue)),
                      if (s.note.isNotEmpty) ...[
                        const Divider(height: 24),
                        Text(s.note, style: t.bodySmall),
                      ],
                      if (AppSettings.receiptFooter.isNotEmpty) ...[
                        const Divider(height: 24),
                        Text(AppSettings.receiptFooter,
                            textAlign: TextAlign.center, style: t.bodySmall),
                      ],
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Profit (internal)', style: t.titleSmall),
                      const SizedBox(height: 8),
                      line('Revenue', money(s.total)),
                      line('Cost of goods', money(s.costTotal)),
                      line('Profit', money(s.profit),
                          style: mono?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: s.profit >= 0 ? Colors.green : Colors.red)),
                      line('Margin', percent(s.margin)),
                      const Divider(height: 20),
                      for (final i in _items)
                        line(i.medicineName, money(i.profit),
                            style: t.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
