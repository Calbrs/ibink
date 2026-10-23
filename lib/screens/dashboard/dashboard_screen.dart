import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/session.dart';
import '../../core/local_storage.dart';
import '../../core/payment_service.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../models/revenue_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/pos_scanner_sheet.dart';

// Dashboard accents follow the splash/bottom-bar gold instead of green.
const _gold = AppColors.gold;
const _goldLight = AppColors.goldLight;
const _inkOnGold = Color(0xFF1E1E1E);
const _surface = Color(0xFFF9F3EA);
const _surfaceLine = Color(0xFFEDE0CF);

enum _FeedTab { recent, activity }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// Order statuses shown in the Recent feed, in display order.
  static const _feedStatuses = [
    OrderStatus.pendingConfirmation,
    OrderStatus.pendingPayment,
    OrderStatus.processing,
    OrderStatus.shipped,
    OrderStatus.completed,
    OrderStatus.cancelled,
    OrderStatus.rejected,
  ];

  bool _isLoading = true;
  String _shopName = 'Duka Langu';
  List<OrderModel> _orders = [];
  double _totalRevenue = 0; // orders + POS sales combined
  int _productsCount = 0;
  int _ordersCount = 0;
  int _salesCount = 0; // POS mauzo count
  int _pendingPayments = 0; // payment confirmations awaiting review

  _FeedTab _feedTab = _FeedTab.recent;

  // ───────────────────────── Lifecycle ─────────────────────────

  @override
  void initState() {
    super.initState();
    _shopName = Session.instance.shopName ?? _shopName;
    _fetchData();
  }

  // ───────────────────────── Data loading ─────────────────────────

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    await _syncPendingSales();

    // Independent requests, so run them together.
    final (products, orders, pos, pending) = await (
      _loadProducts(),
      _loadOrders(),
      _loadPosRevenue(),
      _loadPendingPayments(),
    ).wait;

    if (!mounted) return;
    setState(() {
      _shopName = Session.instance.shopName ?? _shopName;
      _orders = orders.orders;
      _ordersCount = orders.total;
      _productsCount = products;
      _totalRevenue = orders.revenue + pos.revenue;
      _salesCount = pos.count;
      _pendingPayments = pending;
      _isLoading = false;
    });
  }

  /// Pushes offline POS sales queued locally.
  Future<void> _syncPendingSales() async {
    final pending = LocalStorage.instance.getPendingSales();
    if (pending.isEmpty) return;
    try {
      final res = await ApiClient.instance.post(ApiConfig.salesBatchEndpoint, {
        'sales': pending,
      });
      if (res.success) await LocalStorage.instance.clearPendingSales();
    } catch (_) {}
  }

  /// Fetches every product page, caches them for offline scanning and
  /// returns the total count.
  Future<int> _loadProducts() async {
    final products = <ProductModel>[];
    var total = 0;
    try {
      var page = 1;
      var lastPage = 1;
      do {
        final res = await ApiClient.instance.get(
          '${ApiConfig.productsEndpoint}?page=$page&per_page=100',
        );
        if (!res.success) break;

        final payload = res.data?['data'] ?? res.data?['products'];
        if (payload is Map<String, dynamic>) {
          final raw = payload['data'] as List? ?? [];
          products.addAll(
            raw.map((e) => ProductModel.fromJson(e as Map<String, dynamic>)),
          );
          total = payload['total'] as int? ?? products.length;
          lastPage = payload['last_page'] as int? ?? 1;
        } else if (payload is List) {
          products.addAll(
            payload.map(
              (e) => ProductModel.fromJson(e as Map<String, dynamic>),
            ),
          );
          total = products.length;
          lastPage = 1; // plain list means no pagination info
        } else {
          break;
        }
        page++;
      } while (page <= lastPage);

      await LocalStorage.instance.saveProducts(products);
    } catch (_) {}
    return total;
  }

  Future<({List<OrderModel> orders, int total, double revenue})>
  _loadOrders() async {
    var orders = <OrderModel>[];
    var total = 0;
    try {
      final res = await ApiClient.instance.get(ApiConfig.ordersEndpoint);
      if (res.success) {
        final payload = res.data?['data'];
        if (payload is Map<String, dynamic>) {
          final raw = payload['data'] as List? ?? [];
          orders = raw
              .whereType<Map<String, dynamic>>()
              .map(OrderModel.fromJson)
              .toList();
          total = payload['total'] as int? ?? orders.length;
        } else if (payload is List) {
          orders = payload
              .whereType<Map<String, dynamic>>()
              .map(OrderModel.fromJson)
              .toList();
          total = orders.length;
        }
      }
    } catch (_) {}
    final revenue = orders.fold<double>(0, (sum, o) => sum + o.totalAmount);
    return (orders: orders, total: total, revenue: revenue);
  }

  /// POS scanner sales for the current month.
  Future<({double revenue, int count})> _loadPosRevenue() async {
    try {
      final res = await ApiClient.instance.get(
        '${ApiConfig.revenueSummaryEndpoint}?range=month',
      );
      if (res.success && res.data != null) {
        final raw = res.data!['data'] as Map<String, dynamic>? ?? res.data!;
        final summary = RevenueSummary.fromJson(raw);
        return (revenue: summary.totalRevenue, count: summary.totalSalesCount);
      }
    } catch (_) {}
    return (revenue: 0.0, count: 0);
  }

  Future<int> _loadPendingPayments() async {
    try {
      return await PaymentService.instance.countPending();
    } catch (_) {
      return 0;
    }
  }

  // ───────────────────────── Helpers ─────────────────────────

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Habari za Asubuhi';
    if (hour < 17) return 'Habari za Mchana';
    return 'Habari za Jioni';
  }

  Color _statusColor(OrderStatus s) =>
      Color(int.parse(s.color.replaceAll('#', '0xFF')));

  IconData _statusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendingConfirmation:
        return Icons.hourglass_top_rounded;
      case OrderStatus.pendingPayment:
        return Icons.payment_rounded;
      case OrderStatus.processing:
        return Icons.autorenew_rounded;
      case OrderStatus.shipped:
        return Icons.local_shipping_outlined;
      case OrderStatus.completed:
        return Icons.check_circle_outline_rounded;
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return Icons.cancel_outlined;
    }
  }

  int _countFor(OrderStatus status) =>
      _orders.where((o) => o.status == status).length;

  void _openOrders([OrderStatus? status]) {
    context.go(
      status == null
          ? AppRoutes.orders
          : '${AppRoutes.orders}?status=${status.name}',
    );
  }

  Future<void> _openScanner() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PosScannerSheet(),
    );
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          children: [
            // ── Fixed header (does not scroll) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: _Header(
                greeting: _greeting(),
                shopName: _shopName,
                onScan: _openScanner,
                onNotifications: () => context.push(AppRoutes.notifications),
              ),
            ),
            // ── Scrollable content ──
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchData,
                color: _gold,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: [
                    _RevenueCard(
                      amount: _totalRevenue,
                      ordersCount: _ordersCount,
                      salesCount: _salesCount,
                      isLoading: _isLoading,
                      onTap: () => context.push(AppRoutes.revenue),
                    ),
                    const SizedBox(height: 16),
                    _StatStrip(
                      productsCount: _productsCount,
                      ordersCount: _ordersCount,
                      onProducts: () => context.go(AppRoutes.products),
                      onOrders: () => _openOrders(),
                    ),
                    if (_pendingPayments > 0) ...[
                      const SizedBox(height: 16),
                      _PendingPaymentsBanner(
                        count: _pendingPayments,
                        onTap: () => context.push(AppRoutes.payments),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _FeedSwitch(
                        value: _feedTab,
                        onChanged: (tab) => setState(() => _feedTab = tab),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeed(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Feed area under the Recent / Activity switch.
  Widget _buildFeed() {
    switch (_feedTab) {
      case _FeedTab.recent:
        return _buildStatusList();
      case _FeedTab.activity:
        // TODO: activity feed. Nothing to show yet.
        return const SizedBox.shrink();
    }
  }

  /// One clickable row per order status, with its total.
  /// Rows with zero orders are hidden.
  Widget _buildStatusList() {
    if (_isLoading && _orders.isEmpty) {
      return const _EmptyCard(
        icon: Icons.hourglass_empty_rounded,
        text: 'Inapakia...',
      );
    }

    // Only keep statuses that actually have orders.
    final visible = _feedStatuses
        .where((status) => _countFor(status) > 0)
        .toList(growable: false);

    if (visible.isEmpty) {
      return const _EmptyCard(
        icon: Icons.inbox_outlined,
        text: 'Hakuna oda kwa sasa',
      );
    }

    return _GroupCard(
      children: [
        for (final status in visible)
          _StatusRow(
            label: status.label,
            icon: _statusIcon(status),
            color: _statusColor(status),
            count: _countFor(status),
            onTap: () => _openOrders(status),
          ),
      ],
    );
  }
}

// ───────────────────────── Sections ─────────────────────────

class _Header extends StatelessWidget {
  final String greeting;
  final String shopName;
  final VoidCallback onScan;
  final VoidCallback onNotifications;

  const _Header({
    required this.greeting,
    required this.shopName,
    required this.onScan,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                shopName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _RoundButton(
          onTap: onScan,
          child: Image.asset(
            'assets/icons/barcode.png',
            width: 20,
            height: 20,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(width: 10),
        _RoundButton(
          onTap: onNotifications,
          child: const Icon(
            Icons.notifications_outlined,
            size: 20,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final double amount;
  final int ordersCount;
  final int salesCount;
  final bool isLoading;
  final VoidCallback onTap;

  const _RevenueCard({
    required this.amount,
    required this.ordersCount,
    required this.salesCount,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_gold, _goldLight],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'MAPATO YA JUMLA',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: _inkOnGold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _inkOnGold,
                        ),
                      )
                    else
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: _inkOnGold,
                        size: 22,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'TZS ${_fmt(amount)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: _inkOnGold,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Oda $ordersCount · POS $salesCount',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _inkOnGold.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                    Text(
                      'Ripoti kamili',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _inkOnGold.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two stats in one card, split by a hairline divider.
class _StatStrip extends StatelessWidget {
  final int productsCount;
  final int ordersCount;
  final VoidCallback onProducts;
  final VoidCallback onOrders;

  const _StatStrip({
    required this.productsCount,
    required this.ordersCount,
    required this.onProducts,
    required this.onOrders,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
              icon: Icons.inventory_2_outlined,
              value: '$productsCount',
              label: 'Bidhaa',
              onTap: onProducts,
            ),
          ),
          Expanded(
            child: _StatCell(
              icon: Icons.receipt_long_outlined,
              value: '$ordersCount',
              label: 'Oda Zote',
              onTap: onOrders,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;

  const _StatCell({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _gold, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
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

class _PendingPaymentsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _PendingPaymentsBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.amber.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.amber.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.payment_rounded,
                  size: 18,
                  color: AppColors.amber,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Malipo Yanayosubiri',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count thibitisho linasubiri ukaguzi wako',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.amber,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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

/// Small transparent pill switch (Recent / Activity).
class _FeedSwitch extends StatelessWidget {
  final _FeedTab value;
  final ValueChanged<_FeedTab> onChanged;

  const _FeedSwitch({required this.value, required this.onChanged});

  static const _labels = {
    _FeedTab.recent: 'Recent',
    _FeedTab.activity: 'Activity',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _surfaceLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tab in _FeedTab.values)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: tab == value
                      ? _gold.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _labels[tab]!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tab == value ? _gold : AppColors.inkFaint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────── Rows ─────────────────────────

/// Clickable row: status icon, status name and its total.
class _StatusRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;

  const _StatusRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              constraints: const BoxConstraints(minWidth: 30),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: count > 0 ? 0.12 : 0.06),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: count > 0 ? color : AppColors.inkFaint,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.inkFaint,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, color: AppColors.inkFaint, size: 26),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Shared building blocks ─────────────────────────

/// Number with thousands separators, e.g. 4820500 → "4,820,500".
String _fmt(double v) => v
    .toStringAsFixed(0)
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// Bordered panel. Uses Material so InkWell splashes show on children.
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _surfaceLine),
      ),
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

/// Card that stacks rows with hairline dividers between them.
class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: _surfaceLine),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _RoundButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      shape: const CircleBorder(side: BorderSide(color: _surfaceLine)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Center(child: child)),
      ),
    );
  }
}
