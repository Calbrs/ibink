import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/payment_service.dart';
import '../../models/payment_confirmation.dart';
import '../../widgets/app_shimmer.dart';
import '../../widgets/resilient_image.dart';
import '../../routes/app_routes.dart';

class PaymentInboxScreen extends StatefulWidget {
  final PaymentConfirmationStatus? initialFilter;
  const PaymentInboxScreen({super.key, this.initialFilter});

  @override
  State<PaymentInboxScreen> createState() => _PaymentInboxScreenState();
}

class _PaymentInboxScreenState extends State<PaymentInboxScreen> {
  PaymentConfirmationStatus? _statusFilter;
  List<PaymentConfirmation> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialFilter;
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    final items = await PaymentService.instance.fetchConfirmations(status: _statusFilter);
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  List<PaymentConfirmation> get _visibleItems => _items;

  Color _statusColor(PaymentConfirmationStatus status) {
    switch (status) {
      case PaymentConfirmationStatus.pending:
        return const Color(0xFFF59E0B);
      case PaymentConfirmationStatus.confirmed:
        return AppColors.green;
      case PaymentConfirmationStatus.rejected:
        return AppColors.danger;
    }
  }

  void _openItem(PaymentConfirmation item) async {
    await context.push(AppRoutes.paymentReview, extra: item);
    _fetchItems();
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Malipo',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (!_isLoading)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.greenSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_items.length} maelezo',
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

            // Filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Zote',
                    active: _statusFilter == null,
                    color: AppColors.ink,
                    onTap: () => setState(() => _statusFilter = null),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Inasubiri',
                    active: _statusFilter == PaymentConfirmationStatus.pending,
                    color: const Color(0xFFF59E0B),
                    onTap: () => setState(() => _statusFilter = PaymentConfirmationStatus.pending),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Imethibitishwa',
                    active: _statusFilter == PaymentConfirmationStatus.confirmed,
                    color: AppColors.green,
                    onTap: () => setState(() => _statusFilter = PaymentConfirmationStatus.confirmed),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Imekataliwa',
                    active: _statusFilter == PaymentConfirmationStatus.rejected,
                    color: AppColors.danger,
                    onTap: () => setState(() => _statusFilter = PaymentConfirmationStatus.rejected),
                  ),
                ],
              ),
            ),

            Expanded(child: _buildBody(items)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<PaymentConfirmation> items) {
    if (_isLoading) {
      return const Center(child: AppShimmerSpinner());
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchItems,
        color: AppColors.green,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.payment_rounded, size: 40, color: AppColors.inkSoft),
                  SizedBox(height: 12),
                  Text('Hakuna malipo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  SizedBox(height: 4),
                  Text(
                    'Hakuna uthibitisho wa malipo kwa sasa.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchItems,
      color: AppColors.green,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          final color = _statusColor(item.status);

          return Material(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openItem(item),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    // Screenshot thumbnail or provider icon
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 54,
                        height: 54,
                        child: item.screenshotUrl != null
                            ? ResilientImage(
                                imageUrl: item.screenshotUrl!,
                                fit: BoxFit.cover,
                                placeholderBackground: AppColors.greenSoft,
                                placeholderIconColor: AppColors.green,
                              )
                            : Container(
                                color: color.withValues(alpha: 0.12),
                                child: Icon(Icons.payment_rounded, size: 24, color: color),
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
                                  'Oda #${item.orderNumber}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.status.label,
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.provider.label,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (item.senderPhone != null) ...[
                                const Icon(Icons.phone_outlined, size: 12, color: AppColors.inkFaint),
                                const SizedBox(width: 3),
                                Text(item.senderPhone!, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                              ] else ...[
                                const Icon(Icons.help_outline_rounded, size: 12, color: AppColors.inkFaint),
                                const SizedBox(width: 3),
                                const Text('Hakuna jina', style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                              ],
                              const Spacer(),
                              Text(
                                item.formattedAmount,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.greenDeep),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color : AppColors.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}
