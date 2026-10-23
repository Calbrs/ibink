import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/pdf_report.dart';
import '../../models/order_model.dart';
import '../../models/revenue_model.dart';
import '../../widgets/app_shimmer.dart';
import '../../widgets/notification_modals.dart';

enum _Range { week, month, year }

/// Hali za oda zinazohesabiwa kama pesa iliyoingia / inayosubiri / iliyopotea.
/// Badilisha hapa kama mfumo wako wa biashara unahesabu tofauti.
const _receivedStatuses = {
  OrderStatus.processing,
  OrderStatus.shipped,
  OrderStatus.completed,
};
const _pendingStatuses = {
  OrderStatus.pendingConfirmation,
  OrderStatus.pendingPayment,
};
const _lostStatuses = {
  OrderStatus.cancelled,
  OrderStatus.rejected,
};

const _danger = Color(0xFFD64545);

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  _Range _range = _Range.month;
  bool _isLoading = true;
  bool _isDownloading = false;
  String? _error;

  RevenueSummary? _summary;
  List<OrderModel> _orders = [];

  // ───────────────────────── Lifecycle ─────────────────────────

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ───────────────────────── Data ─────────────────────────

  String get _rangeKey => switch (_range) {
        _Range.week => 'week',
        _Range.month => 'month',
        _Range.year => 'year',
      };

  String get _rangeLabel => switch (_range) {
        _Range.week => 'Wiki Hii',
        _Range.month => 'Mwezi Huu',
        _Range.year => 'Mwaka Huu',
      };

  DateTime get _rangeStart {
    final now = DateTime.now();
    return switch (_range) {
      _Range.week =>
        DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)),
      _Range.month => DateTime(now.year, now.month, 1),
      _Range.year => DateTime(now.year, 1, 1),
    };
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final (summary, orders) = await (_fetchSummary(), _fetchOrders()).wait;
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is _RevenueError
            ? e.message
            : 'Hitilafu ya mtandao. Angalia intaneti yako.';
        _isLoading = false;
      });
    }
  }

  Future<RevenueSummary> _fetchSummary() async {
    final res = await ApiClient.instance
        .get('${ApiConfig.revenueSummaryEndpoint}?range=$_rangeKey');
    if (res.success && res.data != null) {
      final raw = res.data!['data'] as Map<String, dynamic>? ?? res.data!;
      return RevenueSummary.fromJson(raw);
    }
    throw _RevenueError(res.error ?? 'Imeshindwa kupata data ya mapato.');
  }

  /// Oda zinaboresha picha ya fedha; zikishindwa, ukurasa bado unafanya kazi.
  Future<List<OrderModel>> _fetchOrders() async {
    try {
      final res = await ApiClient.instance.get(ApiConfig.ordersEndpoint);
      if (!res.success) return [];
      final payload = res.data?['data'];
      final raw = payload is Map<String, dynamic>
          ? (payload['data'] as List? ?? [])
          : (payload is List ? payload : []);
      return raw
          .whereType<Map<String, dynamic>>()
          .map(OrderModel.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ───────────────────────── Derived numbers ─────────────────────────

  /// Oda zilizo ndani ya kipindi kilichochaguliwa.
  /// MUHIMU: hii inatumia `OrderModel.createdAt`. Kama field yako ina jina
  /// tofauti (mf. `date`, `orderedAt`), badilisha mstari huu mmoja tu.
  DateTime? _orderDate(OrderModel o) => o.createdAt;

  List<OrderModel> get _ordersInRange {
    final start = _rangeStart;
    return _orders.where((o) {
      final d = _orderDate(o);
      return d != null && !d.isBefore(start);
    }).toList();
  }

  double _sumFor(Iterable<OrderModel> orders, Set<OrderStatus> statuses) =>
      orders
          .where((o) => statuses.contains(o.status))
          .fold<double>(0, (s, o) => s + o.totalAmount);

  // ───────────────────────── Actions ─────────────────────────

  Future<void> _downloadReport() async {
    if (_summary == null) return;
    setState(() => _isDownloading = true);
    try {
      await PdfReport.generateAndPrintRevenueReport(_summary!, _rangeLabel);
      if (!mounted) return;
      NotificationService.showSuccessBanner(
        context,
        title: 'Imepakuliwa',
        message: 'Ripoti imehifadhiwa kikamilifu.',
      );
    } catch (e) {
      if (!mounted) return;
      NotificationService.showError(
        context,
        title: 'Hitilafu',
        message: 'Imeshindwa kutengeneza ripoti: $e',
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _showTrendDetails(TrendEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                entry.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'TZS ${_fmt(entry.amount)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              if (entry.topProduct != null) ...[
                const Text(
                  'Bidhaa iliyouza zaidi',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 8),
                _Panel(
                  child: ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star_rounded,
                          color: AppColors.amber, size: 20),
                    ),
                    title: Text(
                      entry.topProduct!.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    subtitle: Text('${entry.topProduct!.unitsSold} zimeuzwa'),
                    trailing: Text(
                      'TZS ${_fmt(entry.topProduct!.revenue)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.greenDeep,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ] else
                const Text(
                  'Hakuna mauzo katika kipindi hiki.',
                  style: TextStyle(color: AppColors.inkSoft),
                ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Funga',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
        ),
        title: const Text(
          'Mapato',
          style: TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.green,
        backgroundColor: AppColors.bg,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            _RangeSwitch(
              value: _range,
              onChanged: (r) {
                if (r == _range) return;
                setState(() => _range = r);
                _load();
              },
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              ..._buildShimmer()
            else if (_error != null)
              _buildError()
            else
              ..._buildContent(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildShimmer() => const [
        _ShimmerBox(height: 190, radius: 24),
        SizedBox(height: 16),
        _ShimmerBox(height: 170, radius: 20),
        SizedBox(height: 16),
        _ShimmerBox(height: 150, radius: 20),
      ];

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.inkFaint),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Jaribu Tena'),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContent() {
    final s = _summary!;
    final orders = _ordersInRange;

    final posRevenue = s.totalRevenue;
    final ordersReceived = _sumFor(orders, _receivedStatuses);
    final ordersPending = _sumFor(orders, _pendingStatuses);
    final ordersLost = _sumFor(orders, _lostStatuses);

    final totalIn = posRevenue + ordersReceived;
    final avgSale =
        s.totalSalesCount > 0 ? posRevenue / s.totalSalesCount : 0.0;

    TrendEntry? best;
    for (final e in s.trendEntries) {
      if (e.amount > 0 && (best == null || e.amount > best.amount)) best = e;
    }

    final nothing = s.isEmpty && orders.isEmpty;

    if (nothing) {
      return [
        _Panel(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
            child: Column(
              children: [
                const Icon(Icons.bar_chart_rounded,
                    size: 48, color: AppColors.inkFaint),
                const SizedBox(height: 12),
                const Text(
                  'Hakuna Mapato',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bado hujapata mapato $_rangeLabel.\nTumia POS Scanner au pokea oda kuanza.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.inkSoft, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      // ─── 1. Hero ───
      _HeroCard(
        label: 'MAPATO YA JUMLA · ${_rangeLabel.toUpperCase()}',
        total: totalIn,
        posRevenue: posRevenue,
        ordersRevenue: ordersReceived,
      ),
      const SizedBox(height: 16),

      // ─── 2. Mzunguko wa pesa ───
      const _SectionTitle(
        title: 'Mzunguko wa Pesa',
        subtitle: 'Pesa iliyoingia, inayosubiri na iliyopotea',
      ),
      const SizedBox(height: 12),
      _CashFlowCard(
        received: totalIn,
        pending: ordersPending,
        lost: ordersLost,
      ),
      const SizedBox(height: 28),

      // ─── 3. Mwenendo ───
      if (s.trendEntries.isNotEmpty) ...[
        _SectionTitle(
          title: 'Mwenendo wa Mapato',
          subtitle: best != null
              ? 'Kipindi bora: ${best.label} · TZS ${_fmt(best.amount)}'
              : 'Gusa nguzo kuona undani',
        ),
        const SizedBox(height: 12),
        _TrendCard(
          entries: s.trendEntries,
          heights: s.normalizedTrend,
          bestLabel: best?.label,
          onTap: _showTrendDetails,
        ),
        const SizedBox(height: 28),
      ],

      // ─── 4. Vipimo ───
      const _SectionTitle(title: 'Vipimo vya Mauzo'),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _MetricTile(
              icon: Icons.receipt_long_outlined,
              label: 'Idadi ya Mauzo',
              value: '${s.totalSalesCount}',
              color: AppColors.amber,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricTile(
              icon: Icons.inventory_2_outlined,
              label: 'Bidhaa Zimeuzwa',
              value: '${s.totalQuantitySold}',
              color: AppColors.greenDeep,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _MetricTile(
              icon: Icons.payments_outlined,
              label: 'Wastani kwa Mauzo',
              value: 'TZS ${_fmt(avgSale)}',
              color: AppColors.greenDeep,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricTile(
              icon: Icons.shopping_bag_outlined,
              label: 'Oda za Kipindi',
              value: '${orders.length}',
              color: AppColors.amber,
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),

      // ─── 5. Top products ───
      if (s.topProducts.isNotEmpty) ...[
        _SectionTitle(
          title: 'Bidhaa Zinazouza Sana',
          subtitle: '$_rangeLabel · mauzo ya POS scanner',
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            children: [
              for (int i = 0; i < s.topProducts.length; i++) ...[
                if (i != 0)
                  const Divider(height: 1, color: AppColors.line),
                _TopProductRow(
                  rank: i + 1,
                  product: s.topProducts[i],
                  share: posRevenue > 0
                      ? (s.topProducts[i].revenue / posRevenue).clamp(0.0, 1.0)
                      : 0.0,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],

      // ─── 6. Download ───
      SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: _isDownloading ? null : _downloadReport,
          icon: _isDownloading
              ? const SizedBox(
                  width: 16, height: 16, child: AppShimmerSpinner())
              : const Icon(Icons.download_rounded, size: 18),
          label: Text(_isDownloading ? 'Inapakua...' : 'Pakua Ripoti Kamili'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.green,
            side: const BorderSide(color: AppColors.green, width: 1.4),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    ];
  }
}

// ───────────────────────── Sections ─────────────────────────

class _RangeSwitch extends StatelessWidget {
  final _Range value;
  final ValueChanged<_Range> onChanged;
  const _RangeSwitch({required this.value, required this.onChanged});

  static const _labels = {
    _Range.week: 'Wiki',
    _Range.month: 'Mwezi',
    _Range.year: 'Mwaka',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (final r in _Range.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: r == value ? AppColors.green : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _labels[r]!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: r == value ? AppColors.white : AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String label;
  final double total;
  final double posRevenue;
  final double ordersRevenue;

  const _HeroCard({
    required this.label,
    required this.total,
    required this.posRevenue,
    required this.ordersRevenue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: AppColors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'TZS ${_fmt(total)}',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _HeroSplit(label: 'POS / Duka', amount: posRevenue),
                  ),
                  VerticalDivider(
                    width: 24,
                    thickness: 1,
                    color: AppColors.white.withValues(alpha: 0.25),
                  ),
                  Expanded(
                    child: _HeroSplit(label: 'Oda', amount: ordersRevenue),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSplit extends StatelessWidget {
  final String label;
  final double amount;
  const _HeroSplit({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'TZS ${_fmt(amount)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _CashFlowCard extends StatelessWidget {
  final double received;
  final double pending;
  final double lost;

  const _CashFlowCard({
    required this.received,
    required this.pending,
    required this.lost,
  });

  @override
  Widget build(BuildContext context) {
    final sum = received + pending + lost;
    // flex haiwezi kuwa 0, kwa hiyo tunaficha sehemu zisizo na kitu.
    int flex(double v) => (v / sum * 1000).round().clamp(1, 1000);

    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            if (sum > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      if (received > 0)
                        Expanded(
                          flex: flex(received),
                          child: Container(color: AppColors.green),
                        ),
                      if (pending > 0)
                        Expanded(
                          flex: flex(pending),
                          child: Container(color: AppColors.amber),
                        ),
                      if (lost > 0)
                        Expanded(
                          flex: flex(lost),
                          child: Container(color: _danger),
                        ),
                    ],
                  ),
                ),
              )
            else
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            const SizedBox(height: 18),
            _FlowRow(
              color: AppColors.green,
              icon: Icons.south_west_rounded,
              label: 'Pesa Iliyoingia',
              amount: received,
            ),
            const SizedBox(height: 14),
            _FlowRow(
              color: AppColors.amber,
              icon: Icons.hourglass_top_rounded,
              label: 'Inasubiri Kuingia',
              amount: pending,
            ),
            const SizedBox(height: 14),
            _FlowRow(
              color: _danger,
              icon: Icons.block_rounded,
              label: 'Oda Zilizoghairiwa',
              amount: lost,
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final double amount;

  const _FlowRow({
    required this.color,
    required this.icon,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        Text(
          'TZS ${_fmt(amount)}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  final List<TrendEntry> entries;
  final List<double> heights;
  final String? bestLabel;
  final ValueChanged<TrendEntry> onTap;

  const _TrendCard({
    required this.entries,
    required this.heights,
    required this.bestLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
        child: SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < entries.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(entries[i]),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: FractionallySizedBox(
                              heightFactor: i < heights.length
                                  ? heights[i].clamp(0.04, 1.0)
                                  : 0.04,
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: entries[i].label == bestLabel
                                      ? AppColors.green
                                      : AppColors.green.withValues(alpha: 0.28),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entries[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: entries[i].label == bestLabel
                                ? AppColors.greenDeep
                                : AppColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopProductRow extends StatelessWidget {
  final int rank;
  final TopProductRevenue product;
  final double share; // 0..1

  const _TopProductRow({
    required this.rank,
    required this.product,
    required this.share,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank == 1
                  ? AppColors.amber.withValues(alpha: 0.16)
                  : AppColors.greenSoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: rank == 1 ? AppColors.amber : AppColors.greenDeep,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TZS ${_fmt(product.revenue)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.greenDeep,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 5,
                    backgroundColor: AppColors.line,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.green),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${product.unitsSold} vimeuzwa · ${(share * 100).toStringAsFixed(0)}% ya mapato',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Shared building blocks ─────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.line),
      ),
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double height;
  final double radius;
  const _ShimmerBox({required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.line,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _RevenueError implements Exception {
  final String message;
  const _RevenueError(this.message);
}

/// 4820500 → "4,820,500"
String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );