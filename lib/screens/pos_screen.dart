import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database_helper.dart';
import '../models/cart.dart';
import '../models/medicine.dart';
import '../models/sale.dart';
import '../utils/format.dart';
import '../widgets/status_badges.dart';
import 'sale_detail_screen.dart';

class PosScreen extends StatefulWidget {
  final Cart cart;
  const PosScreen({super.key, required this.cart});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  List<Medicine> _meds = [];
  bool _loading = true;

  Cart get cart => widget.cart;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final meds = await DatabaseHelper.instance.getMedicines();
    if (!mounted) return;
    setState(() {
      _meds = meds;
      _loading = false;
    });
  }

  List<Medicine> get _results {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _meds;
    return _meds
        .where((m) =>
            m.name.toLowerCase().contains(q) ||
            m.genericName.toLowerCase().contains(q) ||
            m.category.toLowerCase().contains(q) ||
            m.batchNo.toLowerCase().contains(q))
        .toList();
  }

  void _add(Medicine m) {
    final error = cart.add(m);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'Added ${m.name}'),
      duration: const Duration(milliseconds: 900),
    ));
    if (error == null) {
      _searchCtrl.clear();
      _searchFocus.unfocus();
      setState(() {});
    }
  }

  Future<void> _editPrice(CartItem item) async {
    final ctrl =
        TextEditingController(text: item.unitPrice.toStringAsFixed(2));
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Price for ${item.medicine.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
          ],
          decoration: InputDecoration(
            labelText: 'Unit price',
            helperText: 'Cost: ${money(item.medicine.costPrice)}',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text)),
              child: const Text('OK')),
        ],
      ),
    );
    ctrl.dispose();
    if (v != null) cart.setPrice(item, v);
  }

  Future<void> _editQty(CartItem item) async {
    final ctrl = TextEditingController(text: '${item.quantity}');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quantity of ${item.medicine.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Quantity (${item.medicine.unit})',
            helperText: '${item.medicine.quantity} in stock',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
              child: const Text('OK')),
        ],
      ),
    );
    ctrl.dispose();
    if (v != null) cart.setQuantity(item, v);
  }

  Future<void> _checkout() async {
    final saleId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CheckoutSheet(cart: cart),
    );
    if (saleId == null || !mounted) return;
    cart.clear();
    await _load();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SaleDetailScreen(saleId: saleId, justCreated: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New sale'),
        actions: [
          ListenableBuilder(
            listenable: cart,
            builder: (_, _) => cart.isEmpty
                ? const SizedBox()
                : IconButton(
                    tooltip: 'Clear cart',
                    icon: const Icon(Icons.remove_shopping_cart_outlined),
                    onPressed: cart.clear,
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              decoration: InputDecoration(
                hintText: 'Search medicine to add…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(_searchCtrl.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                final r = _results;
                if (r.length == 1) _add(r.first);
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListenableBuilder(
                    listenable: cart,
                    builder: (context, _) {
                      final searching = _searchCtrl.text.isNotEmpty;
                      if (searching || cart.isEmpty) return _productList();
                      return _cartList();
                    },
                  ),
          ),
          ListenableBuilder(
            listenable: cart,
            builder: (context, _) => _TotalsBar(
              cart: cart,
              onCheckout: cart.isEmpty ? null : _checkout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productList() {
    final results = _results;
    if (_meds.isEmpty) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('No medicines in inventory yet.\n'
            'Add some from the Inventory tab first.',
            textAlign: TextAlign.center),
      ));
    }
    if (results.isEmpty) return const Center(child: Text('No matches.'));
    return ListView.separated(
      itemCount: results.length + (_searchCtrl.text.isEmpty ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (_searchCtrl.text.isEmpty && i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Tap a product to add it to the sale',
                style: Theme.of(context).textTheme.bodySmall),
          );
        }
        final m = results[_searchCtrl.text.isEmpty ? i - 1 : i];
        final sellable = !m.isExpired && m.quantity > 0;
        return ListTile(
          enabled: sellable,
          onTap: () => _add(m),
          title: Text(m.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text([
                if (m.genericName.isNotEmpty) m.genericName,
                '${m.quantity} ${m.unit} in stock',
              ].join(' • ')),
              if (m.isExpired || m.isLowStock || m.isExpiringSoon)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: StatusBadges(medicine: m),
                ),
            ],
          ),
          trailing: Text(money(m.sellingPrice),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Widget _cartList() {
    final items = cart.items;
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final item = items[i];
        final m = item.medicine;
        final t = Theme.of(context).textTheme;
        return Dismissible(
          key: ObjectKey(item),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => cart.remove(item),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name,
                          style: t.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      InkWell(
                        onTap: () => _editPrice(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${money(item.unitPrice)} / ${m.unit}',
                                  style: t.bodySmall),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit, size: 14),
                            ],
                          ),
                        ),
                      ),
                      Text(money(item.lineTotal),
                          style: t.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => cart.setQuantity(item, item.quantity - 1),
                ),
                InkWell(
                  onTap: () => _editQty(item),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('${item.quantity}', style: t.titleMedium),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: item.quantity >= m.quantity
                      ? null
                      : () => cart.setQuantity(item, item.quantity + 1),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TotalsBar extends StatelessWidget {
  final Cart cart;
  final VoidCallback? onCheckout;
  const _TotalsBar({required this.cart, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        '${cart.items.length} line(s) • ${cart.unitCount} unit(s)',
                        style: t.bodySmall),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(money(cart.subtotal),
                          style: t.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onCheckout,
                icon: const Icon(Icons.shopping_cart_checkout),
                label: const Text('Checkout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet that collects payment details and records the sale.
/// Pops with the new sale id.
class CheckoutSheet extends StatefulWidget {
  final Cart cart;
  const CheckoutSheet({super.key, required this.cart});

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  final _discount = TextEditingController();
  final _paid = TextEditingController();
  final _customer = TextEditingController();
  final _note = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_discount, _paid, _customer, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _subtotal => widget.cart.subtotal;
  double get _disc =>
      (double.tryParse(_discount.text) ?? 0).clamp(0, _subtotal).toDouble();
  double get _total => _subtotal - _disc;
  double? get _paidAmount => double.tryParse(_paid.text);

  Future<void> _complete() async {
    final paid = _paidAmount;
    if (_method == PaymentMethod.cash && paid != null && paid < _total) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Amount paid is less than the total.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await DatabaseHelper.instance.createSale(
        items: widget.cart.items,
        discount: _disc,
        paymentMethod: _method,
        customer: _customer.text.trim(),
        amountPaid: paid ?? _total,
        note: _note.text.trim(),
      );
      if (mounted) Navigator.pop(context, id);
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final decimal = [
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
    ];
    final paid = _paidAmount;
    final change = paid == null ? 0.0 : paid - _total;
    final profit = _total - widget.cart.costTotal;

    Widget line(String label, String value, {TextStyle? style}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(label, style: style)),
            Text(value, style: style),
          ]),
        );

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Checkout', style: t.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final p in PaymentMethod.values)
                  ChoiceChip(
                    label: Text(p.label),
                    selected: _method == p,
                    onSelected: (_) => setState(() => _method = p),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _discount,
                  decoration: const InputDecoration(
                      labelText: 'Discount', isDense: true),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: decimal,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _paid,
                  decoration: InputDecoration(
                    labelText: 'Amount paid',
                    hintText: _total.toStringAsFixed(2),
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: decimal,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _customer,
              decoration: const InputDecoration(
                  labelText: 'Customer (optional)', isDense: true),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                  labelText: 'Note / prescription ref (optional)',
                  isDense: true),
            ),
            const SizedBox(height: 16),
            line('Subtotal', money(_subtotal)),
            if (_disc > 0) line('Discount', '-${money(_disc)}'),
            line('Total', money(_total),
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            if (paid != null)
              line(change >= 0 ? 'Change' : 'Balance due',
                  money(change.abs()),
                  style: t.titleMedium?.copyWith(
                      color: change >= 0 ? Colors.green : Colors.red)),
            line('Estimated profit', money(profit),
                style: t.bodySmall?.copyWith(
                    color: profit >= 0 ? Colors.green : Colors.red)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _complete,
              icon: const Icon(Icons.check),
              label: const Text('Complete sale'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
