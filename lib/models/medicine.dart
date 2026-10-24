class Medicine {
  final int? id;
  final String name;
  final String genericName;
  final String category;
  final String batchNo;
  final String supplier;
  final String unit;
  final int quantity;
  final int reorderLevel;
  final double costPrice;
  final double sellingPrice;
  final DateTime? expiryDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Medicine({
    this.id,
    required this.name,
    this.genericName = '',
    this.category = '',
    this.batchNo = '',
    this.supplier = '',
    this.unit = 'pcs',
    this.quantity = 0,
    this.reorderLevel = 10,
    this.costPrice = 0,
    this.sellingPrice = 0,
    this.expiryDate,
    this.createdAt,
    this.updatedAt,
  });

  static const expiringSoonDays = 30;

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get isLowStock => quantity <= reorderLevel;
  bool get isOutOfStock => quantity <= 0;
  bool get isExpired => expiryDate != null && expiryDate!.isBefore(_today);
  bool get isExpiringSoon =>
      expiryDate != null &&
      !isExpired &&
      expiryDate!.difference(_today).inDays <= expiringSoonDays;

  double get stockValue => quantity * costPrice;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'generic_name': genericName,
        'category': category,
        'batch_no': batchNo,
        'supplier': supplier,
        'unit': unit,
        'quantity': quantity,
        'reorder_level': reorderLevel,
        'cost_price': costPrice,
        'selling_price': sellingPrice,
        'expiry_date': expiryDate?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory Medicine.fromMap(Map<String, Object?> m) => Medicine(
        id: m['id'] as int?,
        name: m['name'] as String,
        genericName: (m['generic_name'] as String?) ?? '',
        category: (m['category'] as String?) ?? '',
        batchNo: (m['batch_no'] as String?) ?? '',
        supplier: (m['supplier'] as String?) ?? '',
        unit: (m['unit'] as String?) ?? 'pcs',
        quantity: (m['quantity'] as int?) ?? 0,
        reorderLevel: (m['reorder_level'] as int?) ?? 0,
        costPrice: ((m['cost_price'] as num?) ?? 0).toDouble(),
        sellingPrice: ((m['selling_price'] as num?) ?? 0).toDouble(),
        expiryDate: _parseDate(m['expiry_date']),
        createdAt: _parseDate(m['created_at']),
        updatedAt: _parseDate(m['updated_at']),
      );

  static DateTime? _parseDate(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

  Medicine copyWith({
    int? id,
    String? name,
    String? genericName,
    String? category,
    String? batchNo,
    String? supplier,
    String? unit,
    int? quantity,
    int? reorderLevel,
    double? costPrice,
    double? sellingPrice,
    DateTime? expiryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Medicine(
        id: id ?? this.id,
        name: name ?? this.name,
        genericName: genericName ?? this.genericName,
        category: category ?? this.category,
        batchNo: batchNo ?? this.batchNo,
        supplier: supplier ?? this.supplier,
        unit: unit ?? this.unit,
        quantity: quantity ?? this.quantity,
        reorderLevel: reorderLevel ?? this.reorderLevel,
        costPrice: costPrice ?? this.costPrice,
        sellingPrice: sellingPrice ?? this.sellingPrice,
        expiryDate: expiryDate ?? this.expiryDate,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
