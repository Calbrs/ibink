/// Model ya data ya mapato inayokuja kutoka API endpoint:
/// GET /seller/sales/summary?range=week|month|year
class RevenueSummary {
  final double totalRevenue;
  final int totalSalesCount;
  final int totalQuantitySold;
  final List<TopProductRevenue> topProducts;

  /// Trend data - mfululizo wa viwango vya siku/wiki
  /// Kila thamani ni [amount] (itanormalizwa kwenye UI)
  final List<TrendEntry> trendEntries;

  const RevenueSummary({
    required this.totalRevenue,
    required this.totalSalesCount,
    required this.totalQuantitySold,
    required this.topProducts,
    required this.trendEntries,
  });

  factory RevenueSummary.fromJson(Map<String, dynamic> json) {
    final topRaw = json['top_products'] as List? ?? [];
    final trendRaw = json['trend'] as List? ?? [];

    return RevenueSummary(
      totalRevenue: _toDouble(json['total_revenue']),
      totalSalesCount: (json['total_sales_count'] as num?)?.toInt() ?? 0,
      totalQuantitySold: (json['total_quantity_sold'] as num?)?.toInt() ?? 0,
      topProducts: topRaw.map((e) => TopProductRevenue.fromJson(e as Map<String, dynamic>)).toList(),
      trendEntries: trendRaw.map((e) => TrendEntry.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  /// Normalized trend values (0.0 – 1.0) kwa ajili ya grafu
  List<double> get normalizedTrend {
    if (trendEntries.isEmpty) return List.filled(7, 0.0);
    final amounts = trendEntries.map((e) => e.amount).toList();
    final maxVal = amounts.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return amounts.map((_) => 0.0).toList();
    return amounts.map((v) => (v / maxVal).clamp(0.05, 1.0)).toList();
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  bool get isEmpty => totalRevenue == 0 && totalSalesCount == 0;
}

class TopProductRevenue {
  final int productId;
  final String productName;
  final int unitsSold;
  final double revenue;

  const TopProductRevenue({
    required this.productId,
    required this.productName,
    required this.unitsSold,
    required this.revenue,
  });

  factory TopProductRevenue.fromJson(Map<String, dynamic> json) {
    return TopProductRevenue(
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      productName: json['product_name']?.toString() ?? '—',
      unitsSold: (json['units_sold'] as num?)?.toInt() ?? 0,
      revenue: RevenueSummary._toDouble(json['revenue']),
    );
  }
}

class TrendEntry {
  final String label; // e.g. "Mon", "Tue" or "Jan 1"
  final double amount;
  final TopProductRevenue? topProduct;

  const TrendEntry({required this.label, required this.amount, this.topProduct});

  factory TrendEntry.fromJson(Map<String, dynamic> json) {
    return TrendEntry(
      label: json['label']?.toString() ?? '',
      amount: RevenueSummary._toDouble(json['amount']),
      topProduct: json['top_product'] != null 
          ? TopProductRevenue.fromJson(json['top_product'] as Map<String, dynamic>) 
          : null,
    );
  }
}
