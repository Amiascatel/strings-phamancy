import 'package:flutter/foundation.dart';

import 'medicine.dart';

class CartItem {
  final Medicine medicine;
  int quantity;
  double unitPrice;

  CartItem(this.medicine, {this.quantity = 1, double? unitPrice})
      : unitPrice = unitPrice ?? medicine.sellingPrice;

  double get lineTotal => quantity * unitPrice;
  double get lineCost => quantity * medicine.costPrice;
}

/// The point-of-sale cart. Lives above the Sell tab so it survives tab
/// switches.
class Cart extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get unitCount => _items.fold(0, (s, i) => s + i.quantity);
  double get subtotal => _items.fold(0, (s, i) => s + i.lineTotal);
  double get costTotal => _items.fold(0, (s, i) => s + i.lineCost);

  /// Adds one unit. Returns an error message if it can't be added.
  String? add(Medicine m) {
    if (m.isExpired) return '${m.name} is expired and cannot be sold.';
    final existing = _items.where((i) => i.medicine.id == m.id).firstOrNull;
    final inCart = existing?.quantity ?? 0;
    if (inCart + 1 > m.quantity) {
      return m.quantity == 0
          ? '${m.name} is out of stock.'
          : 'Only ${m.quantity} ${m.unit} of ${m.name} in stock.';
    }
    if (existing != null) {
      existing.quantity++;
    } else {
      _items.add(CartItem(m));
    }
    notifyListeners();
    return null;
  }

  /// Sets the quantity (clamped to stock). Removes the line at 0.
  void setQuantity(CartItem item, int qty) {
    if (qty <= 0) {
      _items.remove(item);
    } else {
      item.quantity = qty.clamp(1, item.medicine.quantity);
    }
    notifyListeners();
  }

  void setPrice(CartItem item, double price) {
    item.unitPrice = price < 0 ? 0 : price;
    notifyListeners();
  }

  void remove(CartItem item) {
    _items.remove(item);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
