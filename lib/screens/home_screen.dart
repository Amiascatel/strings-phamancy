import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'inventory_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  InventoryFilter _inventoryFilter = InventoryFilter.all;

  void _openInventory(InventoryFilter filter) => setState(() {
        _inventoryFilter = filter;
        _index = 1;
      });

  @override
  Widget build(BuildContext context) {
    // Tabs are rebuilt on switch so each one reloads fresh data from SQLite.
    final body = switch (_index) {
      0 => DashboardScreen(onOpenInventory: _openInventory),
      1 => InventoryScreen(
          key: ValueKey(_inventoryFilter), initialFilter: _inventoryFilter),
      _ => const HistoryScreen(),
    };
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          if (i == 1) _inventoryFilter = InventoryFilter.all;
          _index = i;
        }),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.medication_outlined),
              selectedIcon: Icon(Icons.medication),
              label: 'Inventory'),
          NavigationDestination(
              icon: Icon(Icons.history),
              label: 'History'),
        ],
      ),
    );
  }
}
