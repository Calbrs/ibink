import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/pdf_report.dart';
import '../models/revenue_model.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/notification_modals.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

enum _RangeFilter { week, month, year }

class _RevenueScreenState extends State<RevenueScreen> {
  _RangeFilter _range = _RangeFilter.month;
  bool _isLoading = true;
  bool _isDownloading = false;
  RevenueSummary? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRevenue();
  }

  Future<void> _fetchRevenue() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final rangeStr = switch (_range) {
      _RangeFilter.week  => 'week',
      _RangeFilter.month => 'month',
      _RangeFilter.year  => 'year',
    };

    try {
      final res = await ApiClient.instance.get(
        '${ApiConfig.revenueSummaryEndpoint}?range=$rangeStr',
      );

      if (!mounted) return;

      if (res.success && res.data != null) {
        final raw = res.data!['data'] as Map<String, dynamic>? ?? res.data!;
        setState(() {
          _summary = RevenueSummary.fromJson(raw);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = res.error ?? 'Imeshindwa kupata data ya mapato.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Hitilafu ya mtandao. Angalia intaneti yako.';
        _isLoading = false;
      });
    }
  }

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

  void _showTrendDetails(TrendEntry entry, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kipindi: ${entry.label}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 16),
              _MetricTile(
                icon: Icons.attach_money_rounded,
                label: 'Mapato',
                value: 'TZS ${_fmt(entry.amount)}',
                color: AppColors.greenDeep,
              ),
              const SizedBox(height: 16),
              if (entry.topProduct != null) ...[
                const Text(
                  'Bidhaa Iliyouza Zaidi',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.greenSoft,
                      child: Icon(Icons.star_rounded, color: AppColors.amber),
                    ),
                    title: Text(
                      entry.topProduct!.productName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    subtitle: Text('${entry.topProduct!.unitsSold} zimeuzwa'),
                    trailing: Text(
                      'TZS ${_fmt(entry.topProduct!.revenue)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.greenDeep),
                    ),
                  ),
                ),
              ] else ...[
                const Text(
                  'Hakuna mauzo katika kipindi hiki.',
                  style: TextStyle(color: AppColors.inkSoft),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Funga', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _rangeLabel => switch (_range) {
    _RangeFilter.week  => 'Wiki Hii',
    _RangeFilter.month => 'Mwezi Huu',
    _RangeFilter.year  => 'Mwaka Huu',
  };

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
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _RangeFilter.values.map((r) {
                final isActive = r == _range;
                final label = switch (r) {
                  _RangeFilter.week  => 'Wiki',
                  _RangeFilter.month => 'Mwezi',
                  _RangeFilter.year  => 'Mwaka',
                };
                return GestureDetector(
                  onTap: () {
                    setState(() => _range = r);
                    _fetchRevenue();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.green : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isActive ? AppColors.white : AppColors.inkSoft,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRevenue,
        color: AppColors.green,
        backgroundColor: AppColors.bg,
        child: Column(
          children: [
            // ─── Main body ───
            Expanded(
              child: _isLoading
                  ? _buildShimmer()
                  : _error != null
                      ? _buildError()
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        _ShimmerBox(height: 160, radius: 24),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _ShimmerBox(height: 90, radius: 16)),
          const SizedBox(width: 12),
          Expanded(child: _ShimmerBox(height: 90, radius: 16)),
        ]),
        const SizedBox(height: 28),
        _ShimmerBox(height: 200, radius: 16),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              onPressed: _fetchRevenue,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Jaribu Tena'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final s = _summary!;
    final trend = s.normalizedTrend;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        // ─── Hero revenue card ───
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.green,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.green.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MAPATO YA JUMLA · $_rangeLabel'.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'TZS ${_fmt(s.totalRevenue)}',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kutoka mauzo ${s.totalSalesCount} · Bidhaa ${s.totalQuantitySold} zimeuzwa',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.white.withValues(alpha: 0.85),
                ),
              ),
              if (trend.isNotEmpty) ...[
                const SizedBox(height: 18),
                SizedBox(
                  height: 60,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: s.trendEntries.asMap().entries.map((mapEntry) {
                      final i = mapEntry.key;
                      final e = mapEntry.value;
                      final hFactor = trend[i];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _showTrendDetails(e, i),
                          child: Container(
                            color: Colors.transparent, // Ili kufanya column yote iwe clickable
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: FractionallySizedBox(
                                      heightFactor: hFactor,
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.white.withValues(alpha: 0.85),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  e.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ─── Stat tiles ───
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
        const SizedBox(height: 28),

        // ─── Top products ───
        if (s.topProducts.isNotEmpty) ...[
          const Text(
            'Bidhaa Zinazouza Sana',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'Kwa $_rangeLabel — kulingana na mauzo ya POS scanner',
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                for (int i = 0; i < s.topProducts.length; i++) ...[
                  if (i != 0) const Divider(height: 1, color: AppColors.line),
                  _TopProductRow(rank: i + 1, product: s.topProducts[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],

        if (s.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                const Icon(Icons.bar_chart_rounded, size: 48, color: AppColors.inkFaint),
                const SizedBox(height: 12),
                const Text(
                  'Hakuna Mauzo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bado haujafanya mauzo $_rangeLabel. Tumia POS Scanner kurekodi mauzo yako.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),

        // ─── Download CTA ───
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _isDownloading ? null : _downloadReport,
            icon: _isDownloading
                ? const SizedBox(width: 16, height: 16, child: AppShimmerSpinner())
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(_isDownloading ? 'Inapakua...' : 'Pakua Ripoti Kamili'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.green,
              side: const BorderSide(color: AppColors.green, width: 1.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TopProductRow extends StatelessWidget {
  final int rank;
  final TopProductRevenue product;
  const _TopProductRow({required this.rank, required this.product});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
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
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: rank == 1 ? AppColors.amber : AppColors.greenDeep,
          ),
        ),
      ),
      title: Text(
        product.productName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
      ),
      subtitle: Text(
        '${product.unitsSold} vimeuzwa',
        style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
      ),
      trailing: Text(
        'TZS ${_fmt(product.revenue)}',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.greenDeep),
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
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