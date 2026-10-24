import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/medicine.dart';
import '../utils/format.dart';
import '../widgets/status_badges.dart';
import 'medicine_detail_screen.dart';
import 'medicine_form_screen.dart';

enum InventoryFilter {
  all('All'),
  lowStock('Low stock'),
  expiring('Expiring soon'),
  expired('Expired');

  final String label;
  const InventoryFilter(this.label);

  bool matches(Medicine m) => switch (this) {
        all => true,
        lowStock => m.isLowStock,
        expiring => m.isExpiringSoon,
        expired => m.isExpired,
      };
}

class InventoryScreen extends StatefulWidget {
  final InventoryFilter initialFilter;
  const InventoryScreen(
      {super.key, this.initialFilter = InventoryFilter.all});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  late InventoryFilter _filter = widget.initialFilter;
  String? _category;
  List<Medicine> _meds = [];
  List<String> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final meds = await db.getMedicines(search: _searchCtrl.text);
    final cats = await db.getCategories();
    if (!mounted) return;
    setState(() {
      _meds = meds;
      _categories = cats;
      if (_category != null && !cats.contains(_category)) _category = null;
      _loading = false;
    });
  }

  Future<void> _addMedicine() async {
    final saved = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => const MedicineFormScreen()));
    if (saved == true) _load();
  }

  Future<void> _openDetail(Medicine m) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => MedicineDetailScreen(medicineId: m.id!)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _meds
        .where(_filter.matches)
        .where((m) => _category == null || m.category == _category)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMedicine,
        icon: const Icon(Icons.add),
        label: const Text('Add medicine'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search name, generic, batch, supplier…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _load();
                        },
                      ),
              ),
              onChanged: (_) => _load(),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final f in InventoryFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
                if (_categories.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: DropdownButton<String?>(
                      value: _category,
                      hint: const Text('Category'),
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('All categories')),
                        for (final c in _categories)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (v) => setState(() => _category = v),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                    ? Center(
                        child: Text(_meds.isEmpty
                            ? 'No medicines yet. Tap "Add medicine" to start.'
                            : 'No medicines match.'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) => _MedicineTile(
                            medicine: visible[i],
                            onTap: () => _openDetail(visible[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _MedicineTile extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback onTap;
  const _MedicineTile({required this.medicine, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = medicine;
    final t = Theme.of(context).textTheme;
    final details = [
      if (m.genericName.isNotEmpty) m.genericName,
      if (m.category.isNotEmpty) m.category,
      'Exp: ${date(m.expiryDate)}',
    ].join(' • ');
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase()),
      ),
      title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          StatusBadges(medicine: m),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${m.quantity}',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(m.unit, style: t.bodySmall),
          Text(money(m.sellingPrice), style: t.bodySmall),
        ],
      ),
    );
  }
}
