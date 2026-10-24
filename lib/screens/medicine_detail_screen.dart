import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database_helper.dart';
import '../models/medicine.dart';
import '../models/stock_transaction.dart';
import '../utils/format.dart';
import '../widgets/status_badges.dart';
import 'dashboard_screen.dart';
import 'medicine_form_screen.dart';

class MedicineDetailScreen extends StatefulWidget {
  final int medicineId;
  const MedicineDetailScreen({super.key, required this.medicineId});

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  Medicine? _med;
  List<StockTransaction> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final med = await db.getMedicine(widget.medicineId);
    final history = await db.getTransactions(medicineId: widget.medicineId);
    if (!mounted) return;
    setState(() {
      _med = med;
      _history = history;
      _loading = false;
    });
  }

  Future<void> _edit() async {
    final saved = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => MedicineFormScreen(medicine: _med)));
    if (saved == true) _load();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete medicine?'),
        content: Text(
            '"${_med!.name}" will be removed from inventory. Its stock history is kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await DatabaseHelper.instance.deleteMedicine(_med!.id!);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _stockDialog(TransactionType type) async {
    final m = _med!;
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<(int, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${type.label} — ${m.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current stock: ${m.quantity} ${m.unit}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: type == TransactionType.adjust
                      ? 'New quantity (physical count)'
                      : 'Quantity (${m.unit})',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null) return 'Enter a number';
                  if (type != TransactionType.adjust && n <= 0) {
                    return 'Must be greater than 0';
                  }
                  if (type == TransactionType.stockOut && n > m.quantity) {
                    return 'Only ${m.quantity} available';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: switch (type) {
                    TransactionType.stockIn => 'e.g. Invoice #, supplier',
                    TransactionType.stockOut => 'e.g. Sold, damaged, returned',
                    TransactionType.adjust => 'e.g. Stock take',
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(
                    ctx, (int.parse(qtyCtrl.text), noteCtrl.text.trim()));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    qtyCtrl.dispose();
    noteCtrl.dispose();
    if (result == null) return;

    try {
      await DatabaseHelper.instance.adjustStock(
        medicineId: m.id!,
        type: type,
        quantity: result.$1,
        note: result.$2,
      );
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
    final m = _med;
    if (m == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Medicine not found.')));
    }
    final t = Theme.of(context).textTheme;
    final margin = m.costPrice > 0
        ? ((m.sellingPrice - m.costPrice) / m.costPrice * 100)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(m.name),
        actions: [
          IconButton(
              tooltip: 'Edit', onPressed: _edit, icon: const Icon(Icons.edit)),
          IconButton(
              tooltip: 'Delete',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${m.quantity}',
                          style: t.displaySmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('${m.unit} in stock', style: t.titleMedium),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StatusBadges(medicine: m),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _stockDialog(TransactionType.stockIn),
                        icon: const Icon(Icons.add),
                        label: const Text('Stock in'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: m.quantity > 0
                            ? () => _stockDialog(TransactionType.stockOut)
                            : null,
                        icon: const Icon(Icons.remove),
                        label: const Text('Stock out'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _stockDialog(TransactionType.adjust),
                        icon: const Icon(Icons.tune),
                        label: const Text('Adjust'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _info('Generic name', m.genericName),
                _info('Category', m.category),
                _info('Batch no.', m.batchNo),
                _info('Supplier', m.supplier),
                _info('Expiry date', date(m.expiryDate)),
                _info('Reorder level', '${m.reorderLevel} ${m.unit}'),
                _info('Cost price', money(m.costPrice)),
                _info('Selling price', money(m.sellingPrice)),
                if (margin != null)
                  _info('Margin', '${margin.toStringAsFixed(1)}%'),
                _info('Stock value (cost)', money(m.stockValue)),
                _info('Last updated',
                    m.updatedAt == null ? '—' : dateTime(m.updatedAt!)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Stock history', style: t.titleMedium),
          const SizedBox(height: 8),
          if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No stock movements yet.'),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final tx in _history)
                    TransactionTile(tx, showName: false),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) => ListTile(
        dense: true,
        title: Text(label),
        trailing: Text(value.isEmpty ? '—' : value,
            style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}
