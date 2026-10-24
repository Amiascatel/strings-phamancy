class SalesSummary {
  final int salesCount;
  final int unitsSold;
  final double subtotal;
  final double discount;
  final double revenue;
  final double cost;
  final double profit;

  const SalesSummary({
    this.salesCount = 0,
    this.unitsSold = 0,
    this.subtotal = 0,
    this.discount = 0,
    this.revenue = 0,
    this.cost = 0,
    this.profit = 0,
  });

  double get margin => revenue > 0 ? profit / revenue * 100 : 0;
  double get averageSale => salesCount > 0 ? revenue / salesCount : 0;
}

class DailySales {
  final DateTime day;
  final int salesCount;
  final double revenue;
  final double cost;
  final double profit;

  const DailySales({
    required this.day,
    this.salesCount = 0,
    this.revenue = 0,
    this.cost = 0,
    this.profit = 0,
  });
}

/// A grouped row for top products, categories or payment methods.
class SalesBreakdown {
  final String label;
  final int count;
  final double revenue;
  final double profit;

  const SalesBreakdown({
    required this.label,
    required this.count,
    required this.revenue,
    this.profit = 0,
  });
}
