import 'dart:math';

import '../models/cart.dart';
import '../models/medicine.dart';
import '../models/sale.dart';
import 'database_helper.dart';

/// Fills the database with demo medicines and ~2 weeks of sales so the
/// reports have something to show.
Future<void> loadSampleData() async {
  final db = DatabaseHelper.instance;
  final now = DateTime.now();
  DateTime inDays(int d) => DateTime(now.year, now.month, now.day + d);

  final samples = [
    Medicine(name: 'Panadol 500mg', genericName: 'Paracetamol', category: 'Painkiller', unit: 'tablets', quantity: 600, reorderLevel: 100, costPrice: 1.5, sellingPrice: 3, supplier: 'GSK', batchNo: 'PN2401', expiryDate: inDays(400)),
    Medicine(name: 'Brufen 400mg', genericName: 'Ibuprofen', category: 'Painkiller', unit: 'tablets', quantity: 300, reorderLevel: 60, costPrice: 2, sellingPrice: 4.5, supplier: 'Abbott', batchNo: 'BR882', expiryDate: inDays(250)),
    Medicine(name: 'Amoxil 500mg', genericName: 'Amoxicillin', category: 'Antibiotic', unit: 'capsules', quantity: 400, reorderLevel: 80, costPrice: 4, sellingPrice: 8, supplier: 'GSK', batchNo: 'AM551', expiryDate: inDays(20)),
    Medicine(name: 'Augmentin 625mg', genericName: 'Amoxicillin/Clavulanate', category: 'Antibiotic', unit: 'tablets', quantity: 150, reorderLevel: 40, costPrice: 18, sellingPrice: 30, supplier: 'GSK', batchNo: 'AU301', expiryDate: inDays(300)),
    Medicine(name: 'Flagyl 400mg', genericName: 'Metronidazole', category: 'Antibiotic', unit: 'tablets', quantity: 250, reorderLevel: 50, costPrice: 1.2, sellingPrice: 3, supplier: 'Sanofi', batchNo: 'FL110', expiryDate: inDays(500)),
    Medicine(name: 'Coartem 80/480', genericName: 'Artemether/Lumefantrine', category: 'Antimalarial', unit: 'packs', quantity: 60, reorderLevel: 15, costPrice: 250, sellingPrice: 400, supplier: 'Novartis', batchNo: 'CO77', expiryDate: inDays(365)),
    Medicine(name: 'Piriton 4mg', genericName: 'Chlorphenamine', category: 'Antihistamine', unit: 'tablets', quantity: 300, reorderLevel: 50, costPrice: 0.8, sellingPrice: 2, supplier: 'GSK', batchNo: 'PR19', expiryDate: inDays(600)),
    Medicine(name: 'Cetrizine 10mg', genericName: 'Cetirizine', category: 'Antihistamine', unit: 'tablets', quantity: 200, reorderLevel: 40, costPrice: 1, sellingPrice: 2.5, supplier: 'Cosmos', batchNo: 'CT42', expiryDate: inDays(15)),
    Medicine(name: 'ORS Sachets', genericName: 'Oral rehydration salts', category: 'Rehydration', unit: 'sachets', quantity: 120, reorderLevel: 30, costPrice: 15, sellingPrice: 30, supplier: 'Dawa', batchNo: 'OR5', expiryDate: inDays(700)),
    Medicine(name: 'Benylin Syrup 100ml', genericName: 'Diphenhydramine', category: 'Cough & Cold', unit: 'bottles', quantity: 40, reorderLevel: 10, costPrice: 220, sellingPrice: 350, supplier: 'J&J', batchNo: 'BN09', expiryDate: inDays(330)),
    Medicine(name: 'Vitamin C 1000mg', genericName: 'Ascorbic acid', category: 'Supplement', unit: 'tablets', quantity: 180, reorderLevel: 30, costPrice: 5, sellingPrice: 10, supplier: 'Bayer', batchNo: 'VC12', expiryDate: inDays(420)),
    Medicine(name: 'Metformin 500mg', genericName: 'Metformin', category: 'Diabetes', unit: 'tablets', quantity: 30, reorderLevel: 60, costPrice: 2.5, sellingPrice: 5, supplier: 'Merck', batchNo: 'MT66', expiryDate: inDays(380)),
    Medicine(name: 'Eye drops (old batch)', genericName: 'Chloramphenicol', category: 'Eye care', unit: 'bottles', quantity: 8, reorderLevel: 5, costPrice: 80, sellingPrice: 150, supplier: 'Dawa', batchNo: 'ED01', expiryDate: inDays(-10)),
  ];

  final meds = <Medicine>[];
  for (final m in samples) {
    final id = await db.insertMedicine(m);
    meds.add(m.copyWith(id: id));
  }

  // Sales over the last 14 days, busier towards today.
  final rnd = Random(42);
  final sellable = meds.where((m) => !m.isExpired).toList();
  final methods = PaymentMethod.values;
  for (var day = 13; day >= 0; day--) {
    final salesToday = 3 + rnd.nextInt(5) + (13 - day) ~/ 4;
    for (var n = 0; n < salesToday; n++) {
      final at = DateTime(now.year, now.month, now.day - day,
          8 + rnd.nextInt(11), rnd.nextInt(60));
      if (at.isAfter(now)) continue;
      final lines = <int, CartItem>{};
      for (var l = 0; l < 1 + rnd.nextInt(3); l++) {
        final m = sellable[rnd.nextInt(sellable.length)];
        final qty = m.unit == 'tablets' || m.unit == 'capsules'
            ? 5 + rnd.nextInt(20)
            : 1 + rnd.nextInt(2);
        lines[m.id!] = CartItem(m, quantity: qty);
      }
      try {
        await db.createSale(
          items: lines.values.toList(),
          discount: rnd.nextInt(10) == 0 ? 5 : 0,
          paymentMethod: methods[rnd.nextInt(3)],
          at: at,
        );
      } on StateError {
        // Ran out of stock for this random basket — skip it.
      }
    }
  }
}
