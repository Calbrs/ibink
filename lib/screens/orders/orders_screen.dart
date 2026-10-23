import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../models/order_model.dart';
import '../../widgets/notification_modals.dart';
import '../../widgets/resilient_image.dart';

class OrdersScreen extends StatefulWidget {
  final OrderStatus? initialFilter;
  const OrdersScreen({super.key, this.initialFilter});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  OrderStatus? _statusFilter;
  String _query = '';
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String? _error;
  bool _showSearch = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialFilter;
    _fetchOrders();
  }

  @override
  void didUpdateWidget(OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != oldWidget.initialFilter) {
      setState(() => _statusFilter = widget.initialFilter);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Data
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _fetchOrders({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response =
          await ApiClient.instance.get(ApiConfig.ordersEndpoint);
      if (!mounted) return;

      if (!response.success) {
        _fail(response.error ?? 'Imeshindwa kupakia oda.', silent: silent);
        return;
      }

      // SellerOrderController::index returns paginated payload:
      // { success: true, data: { data: [ ...orders ], ... } }
      final payload = response.data?['data'];
      final rawList = payload is Map<String, dynamic>
          ? (payload['data'] as List? ?? [])
          : (payload as List? ?? []);

      final orders = rawList
          .whereType<Map<String, dynamic>>()
          .map((e) => OrderModel.fromJson(e))
          .toList();

      setState(() {
        _orders = orders;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      _fail('Hitilafu ya mtandao: $e', silent: silent);
    }
  }

  void _fail(String message, {bool silent = false}) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (!(silent && _orders.isNotEmpty)) _error = message;
    });
  }

  List<OrderModel> get _visibleOrders {
    final q = _query.trim().toLowerCase();
    return _orders.where((o) {
      final matchesStatus = _statusFilter == null || o.status == _statusFilter;
      final matchesQuery = q.isEmpty ||
          o.orderNumber.toLowerCase().contains(q) ||
          o.buyerPhone.toLowerCase().contains(q) ||
          (o.product?.productName.toLowerCase().contains(q) ?? false);
      return matchesStatus && matchesQuery;
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Search
  // ═══════════════════════════════════════════════════════════════════════

  void _openSearch() {
    setState(() => _showSearch = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    setState(() {
      _showSearch = false;
      _query = '';
      _searchController.clear();
    });
    _searchFocus.unfocus();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Actions
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _deleteOrder(OrderModel order) async {
    final confirmed = await NotificationService.showConfirmation(
      context,
      title: 'Futa Oda?',
      message:
          'Oda ${order.orderNumber} itafutwa kabisa. Hatua hii haiwezi kurudishwa.',
      confirmText: 'Futa',
      cancelText: 'Ghairi',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    NotificationService.showLoading(context, message: 'Inafuta oda...');

    final response = await ApiClient.instance.delete(
      ApiConfig.orderDeleteEndpoint(order.id.toString()),
    );

    if (!mounted) return;
    NotificationService.hideLoading(context);

    if (response.success) {
      setState(() => _orders.removeWhere((o) => o.id == order.id));
      NotificationService.showSuccessBanner(
        context,
        title: 'Imefutwa',
        message: 'Oda ${order.orderNumber} imefutwa kikamilifu.',
      );
    } else {
      NotificationService.showErrorBanner(
        context,
        title: 'Imeshindwa',
        message: response.error ?? 'Imeshindwa kufuta oda.',
      );
    }
  }

  Future<void> _openOrder(OrderModel order) async {
    await showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(
        order: order,
        onDelete: order.isCompleted ? () => _deleteOrder(order) : null,
      ),
    );
  }

  void _openQuickAccessModal() {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickAccessSheet(
        activeStatus: _statusFilter,
        onSelectStatus: (s) {
          setState(() => _statusFilter = s);
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final orders = _visibleOrders;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (_statusFilter != null) _buildFilterChip(),
            if (_showSearch) _buildSearchBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchOrders(silent: true),
                color: AppColors.green,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _buildContent(orders),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<OrderModel> orders) {
    if (_isLoading) {
      return const _OrdersSkeletonList(key: ValueKey('skeleton'));
    }
    if (_error != null) {
      return _ScrollableCenter(
        key: const ValueKey('error'),
        child: _ErrorState(message: _error!, onRetry: _fetchOrders),
      );
    }
    if (orders.isEmpty) {
      return _ScrollableCenter(
        key: const ValueKey('empty'),
        child: _EmptyState(hasOrders: _orders.isNotEmpty),
      );
    }
    return ListView.separated(
      key: const ValueKey('list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final o = orders[index];
        return _OrderRow(order: o, onTap: () => _openOrder(o));
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Oda',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_orders.length} oda  •  ${_visibleOrders.length} zinaonekana',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (!_showSearch) ...[
            _HeaderIconButton(
              icon: Icons.search_rounded,
              onTap: _openSearch,
            ),
            const SizedBox(width: 10),
          ],
          // Filter button (mirrors the green "add" button in Products)
          Material(
            color: _statusFilter != null ? AppColors.green : AppColors.panel,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _openQuickAccessModal,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _statusFilter != null
                        ? AppColors.green
                        : AppColors.line,
                  ),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: _statusFilter != null
                      ? AppColors.white
                      : AppColors.inkSoft,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip() {
    final color = _statusColor(_statusFilter!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => setState(() => _statusFilter = null),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _statusFilter!.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.close_rounded,
                    size: 14, color: AppColors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: SizedBox(
        height: 48,
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _query = v),
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
          decoration: InputDecoration(
            hintText: 'Tafuta oda, simu au bidhaa...',
            hintStyle: const TextStyle(
              fontSize: 14,
              color: AppColors.inkFaint,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.inkFaint,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              color: AppColors.inkSoft,
              tooltip: 'Funga',
              onPressed: _closeSearch,
            ),
            filled: true,
            fillColor: AppColors.panel,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            border: border(AppColors.line),
            enabledBorder: border(AppColors.line),
            focusedBorder: border(AppColors.green, 1.5),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Colors
// ═══════════════════════════════════════════════════════════════════════════

Color _statusColor(OrderStatus status) {
  final hex = status.color.replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}

Color _paymentStatusColor(OrderPaymentStatus status) {
  final hex = status.color.replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}

// ═══════════════════════════════════════════════════════════════════════════
// Small building blocks
// ═══════════════════════════════════════════════════════════════════════════

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Icon(icon, size: 22, color: AppColors.inkSoft),
        ),
      ),
    );
  }
}

class _ScrollableCenter extends StatelessWidget {
  final Widget child;
  const _ScrollableCenter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded,
                size: 30, color: AppColors.danger),
          ),
          const SizedBox(height: 16),
          const Text(
            'Imeshindwa kupakia',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.inkSoft,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Jaribu Tena',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasOrders;
  const _EmptyState({required this.hasOrders});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.greenSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 28, color: AppColors.green),
          ),
          const SizedBox(height: 16),
          Text(
            hasOrders ? 'Hakuna oda' : 'Bado huna oda',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasOrders
                ? 'Hakuna oda zinazolingana na kichujio au utafutaji wako.'
                : 'Oda mpya zitaonekana hapa mara tu mnunuzi anapoweka.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.inkSoft,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Order row — same layout as Products:
//
//   ┌───────┐  ┌──────────────────────────────┐
//   │       │  │ ORD-1234          [Status]   │
//   │ image │  │ Product Name                 │
//   │       │  │ phone              total     │
//   └───────┘  └──────────────────────────────┘
// ═══════════════════════════════════════════════════════════════════════════

const double _kRowImageSize = 87;

class _OrderRow extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;
  const _OrderRow({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Product image (left, same row) ──
        GestureDetector(
          onTap: onTap,
          child: order.product?.imageUrl != null
              ? ResilientImage(
                  imageUrl: order.product!.imageUrl!,
                  width: _kRowImageSize,
                  height: _kRowImageSize,
                  borderRadius: BorderRadius.circular(12),
                  placeholderBackground: AppColors.greenSoft,
                  placeholderIconColor: AppColors.green,
                  placeholderIconSize: 32,
                )
              : Container(
                  width: _kRowImageSize,
                  height: _kRowImageSize,
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory_2_outlined,
                      size: 32, color: AppColors.green),
                ),
        ),
        const SizedBox(width: 12),

        // ── Card: order number + status on top, product name, then details ──
        Expanded(
          child: Material(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top: order number + status badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.orderNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkSoft,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _StatusPill(
                          label: order.status.label,
                          color: statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Product title
                    Text(
                      order.product?.productName ?? '—',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        height: 1.2,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Bottom row: phone (left) + total (right)
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined,
                            size: 12, color: AppColors.inkFaint),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            order.buyerPhone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PricePill(text: order.formattedTotal),
                      ],
                    ),

                    // Payment badge when unpaid
                    if (order.paymentStatus != OrderPaymentStatus.paid) ...[
                      const SizedBox(height: 6),
                      _InfoPill(
                        text: order.paymentStatus.label,
                        color: _paymentStatusColor(order.paymentStatus),
                        background: _paymentStatusColor(order.paymentStatus)
                            .withValues(alpha: 0.12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  final String text;
  const _PricePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return _InfoPill(
      text: text,
      color: AppColors.greenDeep,
      background: AppColors.green.withValues(alpha: 0.12),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  const _InfoPill({
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Filter sheet
// ═══════════════════════════════════════════════════════════════════════════

class _QuickAccessSheet extends StatelessWidget {
  final OrderStatus? activeStatus;
  final ValueChanged<OrderStatus?> onSelectStatus;
  const _QuickAccessSheet({
    required this.activeStatus,
    required this.onSelectStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Chuja Oda',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Chagua hali ya oda unayotaka kuona',
                style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _QuickButton(
                  label: 'Zote',
                  icon: Icons.apps_rounded,
                  color: AppColors.ink,
                  active: activeStatus == null,
                  onTap: () => onSelectStatus(null),
                ),
                for (final s in OrderStatus.values)
                  _QuickButton(
                    label: s.label,
                    icon: _iconForStatus(s),
                    color: _statusColor(s),
                    active: activeStatus == s,
                    onTap: () => onSelectStatus(s),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

IconData _iconForStatus(OrderStatus status) {
  switch (status) {
    case OrderStatus.pendingConfirmation:
      return Icons.hourglass_top_rounded;
    case OrderStatus.pendingPayment:
      return Icons.payment_rounded;
    case OrderStatus.processing:
      return Icons.sync_rounded;
    case OrderStatus.shipped:
      return Icons.local_shipping_outlined;
    case OrderStatus.completed:
      return Icons.check_circle_outline_rounded;
    case OrderStatus.cancelled:
      return Icons.cancel_outlined;
    case OrderStatus.rejected:
      return Icons.block_rounded;
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _QuickButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? color : AppColors.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? color : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 17,
                color: active ? AppColors.white : AppColors.inkSoft),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Order detail bottom sheet (READ-ONLY)
// ═══════════════════════════════════════════════════════════════════════════

class _OrderDetailSheet extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onDelete;
  const _OrderDetailSheet({required this.order, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEEE, d MMMM y · HH:mm');
    final statusColor = _statusColor(order.status);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    if (order.product?.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: ResilientImage(
                            imageUrl: order.product!.imageUrl!,
                            fit: BoxFit.cover,
                            placeholderBackground: AppColors.greenSoft,
                            placeholderIconColor: AppColors.green,
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: AppColors.greenSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Icon(Icons.inventory_2_outlined,
                              size: 48, color: AppColors.green),
                        ),
                      ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.orderNumber,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            order.status.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFmt.format(order.createdAt),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const _SheetLabel('MTEJA'),
                    const SizedBox(height: 8),
                    _InfoCard(children: [
                      _InfoRow(
                          icon: Icons.phone_outlined, label: order.buyerPhone),
                      if (order.deliveryAddress.isNotEmpty)
                        _InfoRow(
                            icon: Icons.location_on_outlined,
                            label: order.deliveryAddress),
                    ]),
                    const SizedBox(height: 20),

                    const _SheetLabel('BIDHAA'),
                    const SizedBox(height: 8),
                    _InfoCard(children: [
                      if (order.product != null)
                        _InfoRow(
                            icon: Icons.inventory_2_outlined,
                            label: order.product!.productName),
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Text(
                            'Jumla ya Mauzo',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            order.formattedTotal,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.greenDeep,
                            ),
                          ),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 20),

                    const _SheetLabel('HALI YA ODA'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(_iconForStatus(order.status),
                              color: statusColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.status.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _statusDescription(order.status),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.inkSoft,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (onDelete != null) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18),
                          label: const Text('Futa Oda Hii'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(
                                color: AppColors.danger, width: 1.4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusDescription(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendingConfirmation:
        return 'Oda inasubiri uthibitisho wako kupitia WhatsApp.';
      case OrderStatus.pendingPayment:
        return 'Umeithibitisha oda. Mnunuzi anasubiriwa kulipa.';
      case OrderStatus.processing:
        return 'Malipo yamepokelewa. Oda inachakatwa.';
      case OrderStatus.shipped:
        return 'Bidhaa imesafirishwa kuelekea kwa mnunuzi.';
      case OrderStatus.completed:
        return 'Oda imekamilika. Mnunuzi amepokea bidhaa.';
      case OrderStatus.cancelled:
        return 'Oda ilifutwa.';
      case OrderStatus.rejected:
        return 'Oda ilikataliwa.';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Reusable sheet sub-widgets
// ═══════════════════════════════════════════════════════════════════════════

class _SheetLabel extends StatelessWidget {
  final String text;
  const _SheetLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.inkSoft,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.inkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shimmer skeleton (mirrors products_screen.dart)
// ═══════════════════════════════════════════════════════════════════════════

class _ShimmerGradient extends StatefulWidget {
  final Widget child;
  const _ShimmerGradient({required this.child});

  @override
  State<_ShimmerGradient> createState() => _ShimmerGradientState();
}

class _ShimmerGradientState extends State<_ShimmerGradient>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = _controller.value * 2 - 1;
            return LinearGradient(
              begin: Alignment(-1 + dx, 0),
              end: Alignment(0 + dx, 0),
              colors: [
                AppColors.line.withValues(alpha: 0.55),
                AppColors.panel.withValues(alpha: 0.9),
                AppColors.line.withValues(alpha: 0.55),
              ],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const _SkeletonBox({this.width, required this.height, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.line.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _SkeletonOrderRow extends StatelessWidget {
  const _SkeletonOrderRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _SkeletonBox(
          width: _kRowImageSize,
          height: _kRowImageSize,
          radius: 12,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: _SkeletonBox(width: 90, height: 11)),
                    SizedBox(width: 6),
                    _SkeletonBox(width: 60, height: 16, radius: 8),
                  ],
                ),
                SizedBox(height: 8),
                _SkeletonBox(height: 15),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _SkeletonBox(width: 100, height: 12)),
                    SizedBox(width: 8),
                    _SkeletonBox(width: 70, height: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OrdersSkeletonList extends StatelessWidget {
  const _OrdersSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerGradient(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => const _SkeletonOrderRow(),
      ),
    );
  }
}