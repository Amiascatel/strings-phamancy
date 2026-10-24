enum PaymentMethod {
  cash('CASH', 'Cash'),
  mobile('MOBILE', 'Mobile money'),
  card('CARD', 'Card'),
  insurance('INSURANCE', 'Insurance'),
  credit('CREDIT', 'Credit');

  final String code;
  final String label;
  const PaymentMethod(this.code, this.label);

  static PaymentMethod fromCode(String? code) =>
      values.firstWhere((p) => p.code == code, orElse: () => cash);
}

enum SaleStatus {
  completed('COMPLETED'),
  voided('VOIDED');

  final String code;
  const SaleStatus(this.code);

  static SaleStatus fromCode(String? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => completed);
}

class Sale {
  final int id;
  final String customer;
  final PaymentMethod paymentMethod;
  final double subtotal;
  final double discount;
  final double total;
  final double costTotal;
  final double profit;
  final double amountPaid;
  final SaleStatus status;
  final String note;
  final DateTime createdAt;

  /// Number of units across all lines (only populated by list queries).
  final int itemCount;

  const Sale({
    required this.id,
    this.customer = '',
    this.paymentMethod = PaymentMethod.cash,
    required this.subtotal,
    this.discount = 0,
    required this.total,
    required this.costTotal,
    required this.profit,
    this.amountPaid = 0,
    this.status = SaleStatus.completed,
    this.note = '',
    required this.createdAt,
    this.itemCount = 0,
  });

  String get receiptNo => receiptNoFor(id);
  static String receiptNoFor(int id) => 'S${id.toString().padLeft(6, '0')}';

  bool get isVoided => status == SaleStatus.voided;
  double get changeDue => amountPaid > total ? amountPaid - total : 0;
  double get margin => total > 0 ? profit / total * 100 : 0;

  factory Sale.fromMap(Map<String, Object?> m) => Sale(
        id: m['id'] as int,
        customer: (m['customer'] as String?) ?? '',
        paymentMethod: PaymentMethod.fromCode(m['payment_method'] as String?),
        subtotal: _d(m['subtotal']),
        discount: _d(m['discount']),
        total: _d(m['total']),
        costTotal: _d(m['cost_total']),
        profit: _d(m['profit']),
        amountPaid: _d(m['amount_paid']),
        status: SaleStatus.fromCode(m['status'] as String?),
        note: (m['note'] as String?) ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
        itemCount: (m['item_count'] as num?)?.toInt() ?? 0,
      );
}

class SaleItem {
  final int id;
  final int saleId;
  final int? medicineId;
  final String medicineName;
  final String category;
  final String unit;
  final int quantity;
  final double unitPrice;
  final double unitCost;
  final double lineTotal;

  const SaleItem({
    required this.id,
    required this.saleId,
    this.medicineId,
    required this.medicineName,
    this.category = '',
    this.unit = '',
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    required this.lineTotal,
  });

  double get profit => lineTotal - quantity * unitCost;

  factory SaleItem.fromMap(Map<String, Object?> m) => SaleItem(
        id: m['id'] as int,
        saleId: m['sale_id'] as int,
        medicineId: m['medicine_id'] as int?,
        medicineName: m['medicine_name'] as String,
        category: (m['category'] as String?) ?? '',
        unit: (m['unit'] as String?) ?? '',
        quantity: m['quantity'] as int,
        unitPrice: _d(m['unit_price']),
        unitCost: _d(m['unit_cost']),
        lineTotal: _d(m['line_total']),
      );
}

double _d(Object? v) => ((v as num?) ?? 0).toDouble();
