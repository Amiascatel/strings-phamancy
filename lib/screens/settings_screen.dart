import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../db/sample_data.dart';
import '../utils/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _name = TextEditingController(text: AppSettings.pharmacyName);
  final _currency = TextEditingController(text: AppSettings.currency);
  final _footer = TextEditingController(text: AppSettings.receiptFooter);
  String _dbPath = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    DatabaseHelper.instance.path.then((p) {
      if (mounted) setState(() => _dbPath = p);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _currency.dispose();
    _footer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await AppSettings.save(
      pharmacyName: _name.text.trim().isEmpty
          ? 'Strings Pharmacy'
          : _name.text.trim(),
      currency: _currency.text.trim(),
      receiptFooter: _footer.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Settings saved')));
    Navigator.pop(context, true);
  }

  Future<void> _loadSamples() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load sample data?'),
        content: const Text(
            'Adds 13 demo medicines and about two weeks of demo sales so you '
            'can explore the reports. Your existing data is kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Load')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    await loadSampleData();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Sample data loaded')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Pharmacy name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _currency,
            decoration: const InputDecoration(
              labelText: 'Currency symbol',
              hintText: 'e.g. KSh, UGX, \$, €',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _footer,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Receipt footer'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save settings'),
          ),
          const Divider(height: 40),
          OutlinedButton.icon(
            onPressed: _busy ? null : _loadSamples,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.science_outlined),
            label: const Text('Load sample data'),
          ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.storage),
            title: const Text('Data storage'),
            subtitle: Text('All data is saved locally on this device in '
                'SQLite.\n$_dbPath'),
          ),
        ],
      ),
    );
  }
}
