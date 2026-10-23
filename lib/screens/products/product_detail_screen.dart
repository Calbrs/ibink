import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../models/product_model.dart';
import '../../widgets/resilient_image.dart';
import '../../widgets/app_shimmer.dart';
import '../../widgets/notification_modals.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isDeleting = false;

  static const _swahiliMonths = [
    'Januari', 'Februari', 'Machi', 'Aprili', 'Mei', 'Juni',
    'Julai', 'Agosti', 'Septemba', 'Oktoba', 'Novemba', 'Desemba',
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // Actions
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _confirmDelete() async {
    final confirmed = await NotificationService.showConfirmation(
      context,
      title: 'Futa Bidhaa?',
      message:
          'Una uhakika unataka kufuta "${widget.product.name}"? Hatua hii haiwezi kutenduliwa.',
      confirmText: 'Futa',
      cancelText: 'Ghairi',
      isDestructive: true,
    );
    if (confirmed == true && mounted) await _deleteProduct();
  }

  Future<void> _deleteProduct() async {
    setState(() => _isDeleting = true);
    try {
      final response = await ApiClient.instance.delete(
        '${ApiConfig.productsEndpoint}/${widget.product.id}',
      );
      if (!mounted) return;
      if (response.success) {
        context.pop('delete');
      } else {
        _showError(response.error ?? 'Imeshindwa kufuta bidhaa.');
      }
    } catch (e) {
      if (mounted) _showError('Hitilafu: $e');
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _showError(String msg) {
    NotificationService.showErrorBanner(context, message: msg);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════════

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final l = date.toLocal();
    final hh = l.hour.toString().padLeft(2, '0');
    final mm = l.minute.toString().padLeft(2, '0');
    return '${l.day} ${_swahiliMonths[l.month - 1]} ${l.year}, $hh:$mm';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UI pieces
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context, bool isOut) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      color: AppColors.bg,
      padding: EdgeInsets.only(
        top: topInset + 8,
        left: 6,
        right: 12,
        bottom: 12,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.ink, size: 22),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Maelezo ya Bidhaa',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.2,
              ),
            ),
          ),
          _StatusPill(isOut: isOut),
        ],
      ),
    );
  }

  Widget _buildImageCard(ProductModel product) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: ResilientImage(
          imageUrl: product.imageUrl,
          imagePath: product.imagePath,
          width: double.infinity,
          height: double.infinity,
          borderRadius: BorderRadius.zero,
          placeholderBackground: AppColors.greenSoft.withValues(alpha: 0.4),
          placeholderIcon: Icons.image_outlined,
          placeholderIconSize: 40,
          placeholderIconColor: AppColors.green,
        ),
      ),
    );
  }

  Widget _buildBarcodeChip(String barcode) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.greenSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_rounded,
              size: 15, color: AppColors.greenDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              barcode,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.greenDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditButton() {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isDeleting ? null : () => context.pop('edit'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.green.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Hariri Bidhaa',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: TextButton(
        onPressed: _isDeleting ? null : _confirmDelete,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.danger,
          backgroundColor: AppColors.danger.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isDeleting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: AppShimmerSpinner(),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 20, color: AppColors.danger),
                  SizedBox(width: 8),
                  Text(
                    'Futa Bidhaa',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isOut = product.quantity <= 0;
    final barcode = product.barcode;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            _buildHeader(context, isOut),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  _buildImageCard(product),
                  const SizedBox(height: 24),

                  // ─── Name ──────────────────────────────────────────
                  const _FieldLabel('JINA LA BIDHAA'),
                  const SizedBox(height: 8),
                  _ValueBox(
                    text: product.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      height: 1.35,
                    ),
                  ),
                  if (barcode != null && barcode.isNotEmpty)
                    _buildBarcodeChip(barcode),

                  const SizedBox(height: 20),

                  // ─── Price + quantity ──────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('BEI (TSH)'),
                            const SizedBox(height: 8),
                            _ValueBox(
                              text: product.formattedPrice,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.greenDeep,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('IDADI (STOCK)'),
                            const SizedBox(height: 8),
                            _ValueBox(
                              text: '${product.quantity}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color:
                                    isOut ? AppColors.danger : AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ─── Description ───────────────────────────────────
                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const _FieldLabel('MAELEZO'),
                    const SizedBox(height: 8),
                    _ValueBox(
                      text: product.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.inkSoft,
                        height: 1.55,
                      ),
                    ),
                  ],

                  // ─── Timeline ──────────────────────────────────────
                  const SizedBox(height: 20),
                  const _FieldLabel('TAARIFA ZA MUDA'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      children: [
                        _TimeRow(
                          icon: Icons.add_circle_outline_rounded,
                          label: 'Imeundwa',
                          value: _formatDate(product.createdAt),
                        ),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.line,
                        ),
                        _TimeRow(
                          icon: Icons.update_rounded,
                          label: 'Ilibadilishwa',
                          value: _formatDate(product.updatedAt),
                        ),
                      ],
                    ),
                  ),

                  // ─── Actions (inline, scroll with content) ─────────
                  const SizedBox(height: 28),
                  _buildEditButton(),
                  const SizedBox(height: 12),
                  _buildDeleteButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Widgets
// ═══════════════════════════════════════════════════════════════════════

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.inkFaint,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// Read-only field: same panel tint, radius and border as the Profile cards.
class _ValueBox extends StatelessWidget {
  final String text;
  final TextStyle style;
  const _ValueBox({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(text, style: style),
    );
  }
}

/// Header pill, same shape as the form's "Socials" pill.
class _StatusPill extends StatelessWidget {
  final bool isOut;
  const _StatusPill({required this.isOut});

  @override
  Widget build(BuildContext context) {
    final color = isOut ? AppColors.danger : AppColors.greenDeep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isOut
            ? AppColors.danger.withValues(alpha: 0.08)
            : AppColors.greenSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isOut ? 'Imeisha' : 'Ipo',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TimeRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.inkFaint),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}