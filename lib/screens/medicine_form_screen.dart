import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database_helper.dart';
import '../models/medicine.dart';
import '../utils/format.dart';

class MedicineFormScreen extends StatefulWidget {
  /// Null to add a new medicine.
  final Medicine? medicine;
  const MedicineFormScreen({super.key, this.medicine});

  @override
  State<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends State<MedicineFormScreen> {
  static const _units = [
    'pcs', 'tablets', 'capsules', 'strips', 'boxes', 'bottles', 'vials',
    'ampoules', 'tubes', 'sachets', 'packs',
  ];

  final _formKey = GlobalKey<FormState>();
  late final Medicine? _orig = widget.medicine;
  late final _name = TextEditingController(text: _orig?.name);
  late final _generic = TextEditingController(text: _orig?.genericName);
  late final _category = TextEditingController(text: _orig?.category);
  late final _batch = TextEditingController(text: _orig?.batchNo);
  late final _supplier = TextEditingController(text: _orig?.supplier);
  late final _qty =
      TextEditingController(text: (_orig?.quantity ?? 0).toString());
  late final _reorder =
      TextEditingController(text: (_orig?.reorderLevel ?? 10).toString());
  late final _cost = TextEditingController(
      text: _orig == null ? '' : _orig.costPrice.toStringAsFixed(2));
  late final _price = TextEditingController(
      text: _orig == null ? '' : _orig.sellingPrice.toStringAsFixed(2));
  late String _unit = _orig?.unit ?? 'pcs';
  late DateTime? _expiry = _orig?.expiryDate;
  List<String> _categories = [];
  bool _saving = false;

  bool get _isEdit => _orig != null;

  @override
  void initState() {
    super.initState();
    DatabaseHelper.instance.getCategories().then((c) {
      if (mounted) setState(() => _categories = c);
    });
  }

  @override
  void dispose() {
    for (final c in [
      _name, _generic, _category, _batch, _supplier, _qty, _reorder, _cost,
      _price,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 20),
      helpText: 'Expiry date',
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final m = Medicine(
      id: _orig?.id,
      name: _name.text.trim(),
      genericName: _generic.text.trim(),
      category: _category.text.trim(),
      batchNo: _batch.text.trim(),
      supplier: _supplier.text.trim(),
      unit: _unit,
      quantity: int.parse(_qty.text),
      reorderLevel: int.parse(_reorder.text),
      costPrice: double.tryParse(_cost.text) ?? 0,
      sellingPrice: double.tryParse(_price.text) ?? 0,
      expiryDate: _expiry,
      createdAt: _orig?.createdAt,
    );
    final db = DatabaseHelper.instance;
    try {
      if (_isEdit) {
        await db.updateMedicine(m);
      } else {
        await db.insertMedicine(m);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _intField(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final n = int.tryParse(v);
    if (n == null || n < 0) return 'Enter a whole number ≥ 0';
    return null;
  }

  String? _moneyField(String? v) {
    if (v == null || v.isEmpty) return null;
    final n = double.tryParse(v);
    if (n == null || n < 0) return 'Enter a valid amount';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12, width: 12);
    final intOnly = [FilteringTextInputFormatter.digitsOnly];
    final decimal = [
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
    ];

    Widget row(List<Widget> children) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) gap,
              Expanded(child: children[i]),
            ],
          ],
        );

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit medicine' : 'Add medicine')),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _name,
                  decoration:
                      const InputDecoration(labelText: 'Brand / product name *'),
                  textCapitalization: TextCapitalization.words,
                  validator: _required,
                ),
                gap,
                TextFormField(
                  controller: _generic,
                  decoration:
                      const InputDecoration(labelText: 'Generic name'),
                ),
                gap,
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: _category.text),
                  optionsBuilder: (v) => _categories.where((c) =>
                      c.toLowerCase().contains(v.text.toLowerCase())),
                  onSelected: (v) => _category.text = v,
                  fieldViewBuilder: (context, ctrl, focus, onSubmit) {
                    return TextFormField(
                      controller: ctrl,
                      focusNode: focus,
                      decoration: const InputDecoration(
                          labelText: 'Category',
                          hintText: 'e.g. Antibiotic, Painkiller'),
                      onChanged: (v) => _category.text = v,
                    );
                  },
                ),
                gap,
                row([
                  TextFormField(
                    controller: _batch,
                    decoration: const InputDecoration(labelText: 'Batch no.'),
                  ),
                  TextFormField(
                    controller: _supplier,
                    decoration: const InputDecoration(labelText: 'Supplier'),
                  ),
                ]),
                gap,
                row([
                  TextFormField(
                    controller: _qty,
                    decoration: InputDecoration(
                      labelText: 'Quantity *',
                      helperText: _isEdit
                          ? 'Changes are logged as an adjustment'
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: intOnly,
                    validator: _intField,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue:
                        _units.contains(_unit) ? _unit : _units.first,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: [
                      for (final u in _units)
                        DropdownMenuItem(value: u, child: Text(u)),
                    ],
                    onChanged: (v) => setState(() => _unit = v!),
                  ),
                ]),
                gap,
                TextFormField(
                  controller: _reorder,
                  decoration: const InputDecoration(
                    labelText: 'Reorder level *',
                    helperText: 'Flag as low stock at or below this quantity',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: intOnly,
                  validator: _intField,
                ),
                gap,
                row([
                  TextFormField(
                    controller: _cost,
                    decoration:
                        const InputDecoration(labelText: 'Cost price (per unit)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: decimal,
                    validator: _moneyField,
                  ),
                  TextFormField(
                    controller: _price,
                    decoration: const InputDecoration(
                        labelText: 'Selling price (per unit)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: decimal,
                    validator: _moneyField,
                  ),
                ]),
                gap,
                InkWell(
                  onTap: _pickExpiry,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Expiry date',
                      suffixIcon: _expiry == null
                          ? const Icon(Icons.calendar_today)
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _expiry = null),
                            ),
                    ),
                    child: Text(_expiry == null ? 'Not set' : date(_expiry)),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: Text(_isEdit ? 'Save changes' : 'Add to inventory'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
