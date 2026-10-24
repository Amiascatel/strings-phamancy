enum TransactionType {
  stockIn('IN', 'Stock In'),
  stockOut('OUT', 'Stock Out'),
  adjust('ADJUST', 'Adjustment'),
  sale('SALE', 'Sale'),
  saleReturn('RETURN', 'Sale voided');

  final String code;
  final String label;
  const TransactionType(this.code, this.label);

  /// Whether this movement adds to stock (vs. removes or sets it).
  bool get isIncrease => this == stockIn || this == saleReturn;

  static TransactionType fromCode(String code) =>
      values.firstWhere((t) => t.code == code, orElse: () => adjust);
}

class StockTransaction {
  final int? id;
  final int? medicineId;
  final String medicineName;
  final TransactionType type;

  /// Always positive for movements; for ADJUST it's the new absolute quantity.
  final int quantity;
  final int balanceAfter;
  final String note;
  final DateTime createdAt;

  const StockTransaction({
    this.id,
    required this.medicineId,
    required this.medicineName,
    required this.type,
    required this.quantity,
    required this.balanceAfter,
    this.note = '',
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'medicine_id': medicineId,
        'medicine_name': medicineName,
        'type': type.code,
        'quantity': quantity,
        'balance_after': balanceAfter,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory StockTransaction.fromMap(Map<String, Object?> m) => StockTransaction(
        id: m['id'] as int?,
        medicineId: m['medicine_id'] as int?,
        medicineName: m['medicine_name'] as String,
        type: TransactionType.fromCode(m['type'] as String),
        quantity: m['quantity'] as int,
        balanceAfter: (m['balance_after'] as int?) ?? 0,
        note: (m['note'] as String?) ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
