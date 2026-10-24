import 'package:flutter/material.dart';

import '../models/cart.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'pos_screen.dart';
import 'reports_screen.dart';
import 'sales_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _dashboard = 0, _sell = 1, _inventory = 2, _sales = 3;

  final _cart = Cart();
  int _index = _dashboard;
  InventoryFilter _inventoryFilter = InventoryFilter.all;

  @override
  void dispose() {
    _cart.dispose();
    super.dispose();
  }

  void _go(int i) => setState(() => _index = i);

  void _openInventory(InventoryFilter filter) => setState(() {
        _inventoryFilter = filter;
        _index = _inventory;
      });

  @override
  Widget build(BuildContext context) {
    // Tabs are rebuilt on switch so each one reloads fresh data from SQLite.
    // The cart lives here so it survives switching tabs.
    final body = switch (_index) {
      _dashboard => DashboardScreen(
          onOpenInventory: _openInventory,
          onNewSale: () => _go(_sell),
          onOpenSales: () => _go(_sales),
        ),
      _sell => PosScreen(cart: _cart),
      _inventory => InventoryScreen(
          key: ValueKey(_inventoryFilter), initialFilter: _inventoryFilter),
      _sales => const SalesScreen(),
      _ => const ReportsScreen(),
    };
    return Scaffold(
      body: body,
      bottomNavigationBar: ListenableBuilder(
        listenable: _cart,
        builder: (context, _) => NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() {
            if (i == _inventory) _inventoryFilter = InventoryFilter.all;
            _index = i;
          }),
          destinations: [
            const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Home'),
            NavigationDestination(
                icon: Badge(
                  isLabelVisible: !_cart.isEmpty,
                  label: Text('${_cart.items.length}'),
                  child: const Icon(Icons.point_of_sale_outlined),
                ),
                selectedIcon: const Icon(Icons.point_of_sale),
                label: 'Sell'),
            const NavigationDestination(
                icon: Icon(Icons.medication_outlined),
                selectedIcon: Icon(Icons.medication),
                label: 'Inventory'),
            const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Sales'),
            const NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights),
                label: 'Reports'),
          ],
        ),
      ),
    );
  }
}
