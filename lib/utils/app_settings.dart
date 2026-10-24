import '../db/database_helper.dart';

/// App-wide preferences, stored in the SQLite `settings` table.
class AppSettings {
  AppSettings._();

  static String pharmacyName = 'Strings Pharmacy';
  static String currency = '';
  static String receiptFooter = 'Thank you for your purchase. Get well soon!';

  static Future<void> load() async {
    final s = await DatabaseHelper.instance.getSettings();
    pharmacyName = s['pharmacy_name'] ?? pharmacyName;
    currency = s['currency'] ?? currency;
    receiptFooter = s['receipt_footer'] ?? receiptFooter;
  }

  static Future<void> save({
    required String pharmacyName,
    required String currency,
    required String receiptFooter,
  }) async {
    final db = DatabaseHelper.instance;
    await db.setSetting('pharmacy_name', pharmacyName);
    await db.setSetting('currency', currency);
    await db.setSetting('receipt_footer', receiptFooter);
    AppSettings.pharmacyName = pharmacyName;
    AppSettings.currency = currency;
    AppSettings.receiptFooter = receiptFooter;
  }
}
