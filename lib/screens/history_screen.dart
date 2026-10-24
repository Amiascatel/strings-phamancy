import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/stock_transaction.dart';
import '../widgets/transaction_tile.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<StockTransaction> _all = [];
  TransactionType? _type;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tx = await DatabaseHelper.instance.getTransactions();
    if (!mounted) return;
    setState(() {
      _all = tx;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        _type == null ? _all : _all.where((t) => t.type == _type).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Stock history')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _type == null,
                    onSelected: (_) => setState(() => _type = null),
                  ),
                ),
                for (final t in TransactionType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t.label),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                    ? const Center(child: Text('No stock movements yet.'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) => TransactionTile(visible[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
