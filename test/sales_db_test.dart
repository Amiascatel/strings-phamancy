import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:strings_pharmacy/db/database_helper.dart';
import 'package:strings_pharmacy/models/cart.dart';
import 'package:strings_pharmacy/models/medicine.dart';
import 'package:strings_pharmacy/models/sale.dart';

void main() {
  final db = DatabaseHelper.instance;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.deleteDatabase(await db.path);
  });

  test('sale deducts stock, records profit, void restores stock', () async {
    final id = await db.insertMedicine(const Medicine(
        name: 'Panadol', quantity: 100, costPrice: 2, sellingPrice: 5));
    final med = (await db.getMedicine(id))!;

    final saleId = await db.createSale(
      items: [CartItem(med, quantity: 10)],
      discount: 5,
      paymentMethod: PaymentMethod.mobile,
    );

    expect((await db.getMedicine(id))!.quantity, 90);
    final sale = (await db.getSale(saleId))!;
    expect(sale.subtotal, 50);
    expect(sale.total, 45);
    expect(sale.costTotal, 20);
    expect(sale.profit, 25);
    expect(sale.itemCount, 10);

    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = DateTime(now.year, now.month, now.day + 1);
    final summary = await db.getSalesSummary(from, to);
    expect(summary.revenue, 45);
    expect(summary.profit, 25);
    expect(summary.unitsSold, 10);
    final daily = await db.getDailySales(from, to);
    expect(daily.single.revenue, 45);
    final payments = await db.getPaymentBreakdown(from, to);
    expect(payments.single.label, 'Mobile money');

    await db.voidSale(saleId, reason: 'test');
    expect((await db.getMedicine(id))!.quantity, 100);
    expect((await db.getSale(saleId))!.isVoided, isTrue);
    expect((await db.getSalesSummary(from, to)).revenue, 0);
  });

  test('sale is rejected and rolled back when stock is short', () async {
    final id = await db.insertMedicine(
        const Medicine(name: 'Amoxil', quantity: 3, sellingPrice: 8));
    final med = (await db.getMedicine(id))!;
    final before = (await db.getSales()).length;

    await expectLater(
      db.createSale(items: [CartItem(med, quantity: 5)]),
      throwsA(isA<StateError>()),
    );
    expect((await db.getMedicine(id))!.quantity, 3);
    expect((await db.getSales()).length, before);
  });
}
