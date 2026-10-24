import 'package:flutter_test/flutter_test.dart';
import 'package:strings_pharmacy/models/medicine.dart';

void main() {
  test('Medicine status flags', () {
    final now = DateTime.now();
    final m = Medicine(
      name: 'Amoxil',
      quantity: 5,
      reorderLevel: 10,
      costPrice: 2,
      expiryDate: now.add(const Duration(days: 10)),
    );
    expect(m.isLowStock, isTrue);
    expect(m.isExpiringSoon, isTrue);
    expect(m.isExpired, isFalse);
    expect(m.stockValue, 10);

    final roundTrip = Medicine.fromMap(m.toMap());
    expect(roundTrip.name, 'Amoxil');
    expect(roundTrip.quantity, 5);
  });
}
