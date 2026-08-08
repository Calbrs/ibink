import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/order_model.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/notification_modals.dart';
import '../widgets/resilient_image.dart';

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
      setState(() {
        _statusFilter = widget.initialFilter;
      });
    }
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await ApiClient.instance.get(ApiConfig.ordersEndpoint);

    if (!mounted) return;

    if (!response.success) {
      setState(() {
        _isLoading = false;
        _error = response.error ?? 'Imeshindwa kupakia oda.';
      });
      return;
    }

    // SellerOrderController::index inarudisha paginated payload:
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
    });
  }

  List<OrderModel> get _visibleOrders {
    return _orders.where((o) {
      final matchesStatus = _statusFilter == null || o.status == _statusFilter;
      final matchesQuery = _query.isEmpty ||
          o.orderNumber.toLowerCase().contains(_query.toLowerCase()) ||
          o.buyerPhone.toLowerCase().contains(_query.toLowerCase()) ||
          (o.product?.productName.toLowerCase().contains(_query.toLowerCase()) ?? false);
      return matchesStatus && matchesQuery;
    }).toList();
  }

  Future<void> _deleteOrder(OrderModel order) async {
    final confirmed = await NotificationService.showConfirmation(
      context,
      title: 'Futa Oda?',
      message: 'Oda ${order.orderNumber} itafutwa kabisa. Hatua hii haiwezi kurudishwa.',
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

  @override
  Widget build(BuildContext context) {
    final orders = _visibleOrders;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_orders.length} oda',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.greenDeep,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search + filter
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Tafuta oda, simu au bidhaa...',
                        prefixIcon: Icon(Icons.search_rounded, color: AppColors.inkFaint, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _openQuickAccessModal,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _statusFilter != null ? AppColors.green : AppColors.line,
                            width: _statusFilter != null ? 1.4 : 1,
                          ),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: _statusFilter != null ? AppColors.green : AppColors.inkSoft,
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Active filter chip
            if (_statusFilter != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => setState(() => _statusFilter = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _statusColor(_statusFilter!),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _statusFilter!.label,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.white),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.close_rounded, size: 14, color: AppColors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            Expanded(child: _buildBody(orders)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<OrderModel> orders) {
    if (_isLoading) {
      return const Center(child: AppShimmerSpinner());
    }

    if (_error != null) {
      return _OrdersError(message: _error!, onRetry: _fetchOrders);
    }

    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchOrders,
        color: AppColors.green,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [SizedBox(height: 80), _EmptyOrders()],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      color: AppColors.green,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final order = orders[index];
          return _OrderRow(order: order, onTap: () => _openOrder(order));
        },
      ),
    );
  }
}

Color _statusColor(OrderStatus status) {
  final hex = status.color.replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}

// ── Error state ───────────────────────────────────────────────────────────────
class _OrdersError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _OrdersError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.showErrorBanner(
        context,
        title: 'Imeshindwa kupakia oda',
        message: message,
      );
    });

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              child: const Icon(Icons.wifi_off_rounded, size: 30, color: AppColors.danger),
            ),
            const SizedBox(height: 16),
            const Text('Imeshindwa kupakia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.4)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Jaribu Tena'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter sheet ──────────────────────────────────────────────────────────────
class _QuickAccessSheet extends StatelessWidget {
  final OrderStatus? activeStatus;
  final ValueChanged<OrderStatus?> onSelectStatus;
  const _QuickAccessSheet({required this.activeStatus, required this.onSelectStatus});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Chuja Oda', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Chagua hali ya oda unayotaka kuona', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
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
            Icon(icon, size: 17, color: active ? AppColors.white : AppColors.inkSoft),
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

// ── Order row (list item) ─────────────────────────────────────────────────────
class _OrderRow extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;
  const _OrderRow({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM · HH:mm');
    final statusColor = _statusColor(order.status);

    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              // Product image thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: order.product?.imageUrl != null
                      ? ResilientImage(
                          imageUrl: order.product!.imageUrl!,
                          fit: BoxFit.cover,
                          placeholderBackground: AppColors.greenSoft,
                          placeholderIconColor: AppColors.green,
                        )
                      : Container(
                          color: AppColors.greenSoft,
                          child: const Icon(Icons.inventory_2_outlined, size: 24, color: AppColors.green),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.orderNumber,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            order.status.label,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.product?.productName ?? '—',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 12, color: AppColors.inkFaint),
                        const SizedBox(width: 3),
                        Text(order.buyerPhone, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                        const Spacer(),
                        Text(
                          order.formattedTotal,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.greenDeep),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFmt.format(order.createdAt),
                      style: const TextStyle(fontSize: 11, color: AppColors.inkFaint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.inkSoft),
            SizedBox(height: 12),
            Text('Hakuna oda', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
            SizedBox(height: 4),
            Text(
              'Hakuna oda zinazolingana na kichujio hiki.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Order detail bottom sheet (READ-ONLY) ─────────────────────────────────────
class _OrderDetailSheet extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onDelete; // non-null only for completed orders
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
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    // ── Product image (full-width hero) ──────────────────
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
                          child: Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.green),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // ── Order number + status badge ──────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.orderNumber,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            order.status.label,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFmt.format(order.createdAt),
                      style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 20),

                    // ── Mteja ────────────────────────────────────────────
                    const _SheetLabel('MTEJA'),
                    const SizedBox(height: 8),
                    _InfoCard(children: [
                      _InfoRow(icon: Icons.phone_outlined, label: order.buyerPhone),
                      if (order.deliveryAddress.isNotEmpty)
                        _InfoRow(icon: Icons.location_on_outlined, label: order.deliveryAddress),
                    ]),
                    const SizedBox(height: 20),

                    // ── Bidhaa ───────────────────────────────────────────
                    const _SheetLabel('BIDHAA'),
                    const SizedBox(height: 8),
                    _InfoCard(children: [
                      if (order.product != null)
                        _InfoRow(icon: Icons.inventory_2_outlined, label: order.product!.productName),
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Text('Jumla ya Mauzo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
                          const Spacer(),
                          Text(order.formattedTotal, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.greenDeep)),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // ── Status info (read-only) ───────────────────────────
                    const _SheetLabel('HALI YA ODA'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(_iconForStatus(order.status), color: statusColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.status.label,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: statusColor),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _statusDescription(order.status),
                                  style: const TextStyle(fontSize: 12, color: AppColors.inkSoft, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Delete button (completed orders only) ────────────
                    if (onDelete != null) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: const Text('Futa Oda Hii'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger, width: 1.4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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

// ── Reusable sheet sub-widgets ────────────────────────────────────────────────
class _SheetLabel extends StatelessWidget {
  final String text;
  const _SheetLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkSoft, letterSpacing: 0.6),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
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
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, color: AppColors.ink, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}