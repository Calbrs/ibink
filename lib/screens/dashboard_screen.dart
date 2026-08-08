import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/session.dart';
import '../core/local_storage.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../routes/app_routes.dart';
import 'dart:async';
import '../widgets/app_shimmer.dart';
import '../widgets/pos_scanner_sheet.dart';
import '../models/revenue_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoadingData = true;
  String _shopName = 'Duka Langu';
  List<OrderModel> _orders = [];
  double _totalRevenue = 0;      // orders + POS sales combined
  int _totalProductsCount = 0;
  int _totalOrdersCount = 0;
  int _totalSalesCount = 0;       // POS mauzo count

  Timer? _statusTimer;
  int _currentStatusIndex = 0;
  final List<OrderStatus> _cycleStatuses = [
    OrderStatus.pendingConfirmation,
    OrderStatus.processing,
    OrderStatus.shipped,
    OrderStatus.completed,
    OrderStatus.cancelled,
  ];

  @override
  void initState() {
    super.initState();
    _shopName = Session.instance.shopName ?? 'Duka Langu';
    _fetchData();
    _startStatusTimer();
  }

  void _startStatusTimer() {
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      setState(() {
        _currentStatusIndex = (_currentStatusIndex + 1) % _cycleStatuses.length;
      });
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoadingData = true);

    final shopName = Session.instance.shopName ?? _shopName;

    // Background Sync: Push pending offline sales
    final pendingSales = LocalStorage.instance.getPendingSales();
    if (pendingSales.isNotEmpty) {
      try {
        final syncResponse = await ApiClient.instance.post(
          ApiConfig.salesBatchEndpoint,
          {'sales': pendingSales},
        );
        if (syncResponse.success) {
          await LocalStorage.instance.clearPendingSales();
        }
      } catch (_) {}
    }

    List<ProductModel> products = [];
    List<OrderModel> orders = [];

    int totalProducts = 0;
    int totalOrders = 0;

    try {
      int currentPage = 1;
      int lastPage = 1;
      
      do {
        final productsResponse = await ApiClient.instance.get('${ApiConfig.productsEndpoint}?page=$currentPage&per_page=100');
        if (productsResponse.success) {
          final payload = productsResponse.data?['data'] ?? productsResponse.data?['products'];
          if (payload is Map<String, dynamic>) {
            final raw = payload['data'] as List? ?? [];
            products.addAll(raw.map((e) => ProductModel.fromJson(e as Map<String, dynamic>)));
            totalProducts = payload['total'] as int? ?? products.length;
            lastPage = payload['last_page'] as int? ?? 1;
          } else if (payload is List) {
            products.addAll(payload.map((e) => ProductModel.fromJson(e as Map<String, dynamic>)));
            totalProducts = products.length;
            lastPage = 1; // List payload means no pagination info
          } else {
            break;
          }
          currentPage++;
        } else {
          break;
        }
      } while (currentPage <= lastPage);

      // Cache all fetched products locally for offline scanning
      await LocalStorage.instance.saveProducts(products);
    } catch (_) {}

    try {
      final ordersResponse = await ApiClient.instance.get(ApiConfig.ordersEndpoint);
      if (ordersResponse.success) {
        final payload = ordersResponse.data?['data'];
        if (payload is Map<String, dynamic>) {
          final raw = payload['data'] as List? ?? [];
          orders = raw.whereType<Map<String, dynamic>>().map((e) => OrderModel.fromJson(e)).toList();
          totalOrders = payload['total'] as int? ?? orders.length;
        } else if (payload is List) {
          orders = payload.whereType<Map<String, dynamic>>().map((e) => OrderModel.fromJson(e)).toList();
          totalOrders = orders.length;
        }
      }
    } catch (_) {}

    final ordersRevenue = orders.fold<double>(0, (sum, o) => sum + o.totalAmount);

    // Vuta jumla ya mauzo ya POS scanner kwa mwezi huu
    double posRevenue = 0;
    int salesCount = 0;
    try {
      final salesRes = await ApiClient.instance.get(
        '${ApiConfig.revenueSummaryEndpoint}?range=month',
      );
      if (salesRes.success && salesRes.data != null) {
        final raw = salesRes.data!['data'] as Map<String, dynamic>? ?? salesRes.data!;
        final summary = RevenueSummary.fromJson(raw);
        posRevenue = summary.totalRevenue;
        salesCount = summary.totalSalesCount;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _shopName = shopName;
      _orders = orders;
      _totalRevenue = ordersRevenue + posRevenue;
      _totalProductsCount = totalProducts;
      _totalOrdersCount = totalOrders;
      _totalSalesCount = salesCount;
      _isLoadingData = false;
    });
  }

  /// Formats large numbers with comma separators e.g. 4820500 → "4,820,500"
  String _fmt(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendingConfirmation: return Icons.hourglass_top_rounded;
      case OrderStatus.pendingPayment: return Icons.payment_rounded;
      case OrderStatus.processing: return Icons.autorenew_rounded;
      case OrderStatus.shipped: return Icons.local_shipping_outlined;
      case OrderStatus.completed: return Icons.check_circle_outline_rounded;
      case OrderStatus.cancelled:
      case OrderStatus.rejected: return Icons.cancel_outlined;
    }
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

  @override
  Widget build(BuildContext context) {
    final currentStatus = _cycleStatuses[_currentStatusIndex];
    final currentStatusOrders = _orders.where((o) => o.status == currentStatus).toList();
    final statusColor = Color(int.parse(currentStatus.color.replaceAll('#', '0xFF')));

    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Habari za Asubuhi' : (hour < 17 ? 'Habari za Mchana' : 'Habari za Jioni');

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchData,
          color: AppColors.green,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(greeting, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          _shopName,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Material(
                        color: AppColors.panel,
                        shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
                        child: IconButton(
                          onPressed: _openScanner,
                          icon: Image.asset('assets/icons/barcode.png', width: 22, height: 22, color: AppColors.ink),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Material(
                        color: AppColors.panel,
                        shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
                        child: IconButton(
                          onPressed: () => context.push(AppRoutes.notifications),
                          icon: const Icon(Icons.notifications_outlined, color: AppColors.ink, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => context.push(AppRoutes.revenue),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: AppColors.green.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'MAPATO YA JUMLA',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.white, letterSpacing: 0.6),
                            ),
                          ),
                          const Spacer(),
                          if (_isLoadingData)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: AppShimmerSpinner(),
                            )
                          else
                            const Icon(Icons.chevron_right_rounded, color: AppColors.white, size: 22),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'TZS ${_fmt(_totalRevenue)}',
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.white),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Oda $_totalOrdersCount · POS $_totalSalesCount',
                              style: TextStyle(fontSize: 12.5, color: AppColors.white.withValues(alpha: 0.85)),
                            ),
                          ),
                          Text(
                            'Angalia Ripoti Kamili',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.white.withValues(alpha: 0.9)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.inventory_2_outlined,
                      value: '$_totalProductsCount',
                      label: 'Bidhaa',
                      onTap: () => context.go(AppRoutes.products),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.receipt_long_outlined,
                      value: '$_totalOrdersCount',
                      label: 'Oda Zote',
                      onTap: () => context.go(AppRoutes.orders),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity == null) return;
                        if (details.primaryVelocity! > 0) {
                          setState(() {
                            _currentStatusIndex = (_currentStatusIndex - 1 + _cycleStatuses.length) % _cycleStatuses.length;
                          });
                        } else if (details.primaryVelocity! < 0) {
                          setState(() {
                            _currentStatusIndex = (_currentStatusIndex + 1) % _cycleStatuses.length;
                          });
                        }
                        _statusTimer?.cancel();
                        _startStatusTimer();
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                        child: _StatTile(
                          key: ValueKey<OrderStatus>(currentStatus),
                          icon: _getStatusIcon(currentStatus),
                          value: '${currentStatusOrders.length}',
                          label: currentStatus.label,
                          accent: statusColor,
                          onTap: () => context.go('${AppRoutes.orders}?status=${currentStatus.name}'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (_isLoadingData && _orders.isEmpty) ...[
                Row(
                  children: [
                    Text('Oda: ${currentStatus.label}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  ],
                ),
                const SizedBox(height: 8),
                const _EmptyRow(icon: Icons.hourglass_empty_rounded, text: 'Inapakia...'),
                const SizedBox(height: 28),
              ] else ...[
                Row(
                  children: [
                    Text('Oda: ${currentStatus.label}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  ],
                ),
                const SizedBox(height: 8),
                if (currentStatusOrders.isEmpty)
                  _EmptyRow(icon: _getStatusIcon(currentStatus), text: 'Hakuna oda yoyote kwenye kundi hili.')
                else
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < currentStatusOrders.take(3).length; i++) ...[
                          if (i != 0) const Divider(height: 1, color: AppColors.line),
                          _OrderRow(order: currentStatusOrders[i]),
                        ],
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? accent;
  final VoidCallback? onTap;

  const _StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.greenDeep;
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final OrderModel order;
  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.receipt_long_outlined, color: AppColors.amber, size: 18),
      ),
      title: Text(
        order.product?.productName ?? order.orderNumber,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
      ),
      subtitle: Text(
        'Oda #${order.id}',
        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
      ),
      trailing: Text(
        'TZS ${order.totalAmount.toStringAsFixed(0)}',
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.greenDeep),
      ),
    );
  }
}


class _EmptyRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.inkFaint, size: 26),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}