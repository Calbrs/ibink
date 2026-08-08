import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/product_model.dart';
import '../widgets/resilient_image.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/notification_modals.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isDeleting = false;

  static const double _imageHeight = 280;
  static const double _imageMargin = 2;

  static const _swahiliMonths = [
    'Januari', 'Februari', 'Machi', 'Aprili', 'Mei', 'Juni',
    'Julai', 'Agosti', 'Septemba', 'Oktoba', 'Novemba', 'Desemba',
  ];



  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final local = date.toLocal();
    final month = _swahiliMonths[local.month - 1];
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day} $month ${local.year}, $hh:$mm';
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await NotificationService.showConfirmation(
      context,
      title: 'Futa Bidhaa?',
      message: 'Una uhakika unataka kufuta "${widget.product.name}"? Hatua hii haiwezi kutenduliwa.',
      confirmText: 'Futa',
      cancelText: 'Ghairi',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      await _deleteProduct();
    }
  }

  Future<void> _deleteProduct() async {
    setState(() => _isDeleting = true);
    try {
      final response = await ApiClient.instance.delete(
        '${ApiConfig.productsEndpoint}/${widget.product.id}',
      );
      if (!mounted) return;
      if (response.success) {
        if (mounted) context.pop('delete');
      } else {
        _showError(response.error ?? 'Imeshindwa kufuta bidhaa.');
      }
    } catch (e) {
      _showError('Hitilafu: $e');
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _showError(String msg) {
    NotificationService.showErrorBanner(context, message: msg);
  }

  Widget _buildImageBox(ProductModel product) {
    final hasImage = product.imageUrl != null || product.imagePath != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(_imageMargin, 0, _imageMargin, 0),
      height: _imageHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (hasImage)
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: ResilientImage(
        imageUrl: product.imageUrl,
        imagePath: product.imagePath,
        width: double.infinity,
        height: _imageHeight,
        borderRadius: BorderRadius.circular(24),
        placeholderBackground: AppColors.greenSoft.withValues(alpha: 0.4),
        placeholderIcon: Icons.image_outlined,
        placeholderIconSize: 48,
        placeholderIconColor: AppColors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isOut = product.quantity <= 0;
    final topInset = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            SafeArea(
              top: false,
              bottom: false,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                        SizedBox(height: topInset + _imageMargin),
                        _buildImageBox(product),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Text(
                                    product.formattedPrice,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.greenDeep,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Divider(color: AppColors.line, height: 1),
                              const SizedBox(height: 20),
                              if (product.description.isNotEmpty) ...[
                                const Text(
                                  'MAELEZO',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.inkFaint,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  product.description,
                                  style: const TextStyle(fontSize: 14.5, color: AppColors.inkSoft, height: 1.6),
                                ),
                                const SizedBox(height: 24),
                              ],
                              const Text(
                                'TAARIFA ZA MUDA',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.inkFaint,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.inkFaint),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Imeundwa: ${_formatDate(product.createdAt)}',
                                    style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.update_rounded, size: 16, color: AppColors.inkFaint),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ilibadilishwa: ${_formatDate(product.updatedAt)}',
                                    style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 100), // padding for floating buttons
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            Positioned(
              bottom: 10 + MediaQuery.of(context).padding.bottom,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Expanded(
                    flex: 8,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => context.pop('edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          elevation: 8,
                          shadowColor: AppColors.green.withValues(alpha: 0.4),
                        ),
                        child: const Text('Hariri Bidhaa', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isDeleting ? null : () => _confirmDelete(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger.withValues(alpha: 0.1),
                          foregroundColor: AppColors.danger,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                        child: _isDeleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: AppShimmerSpinner(),
                              )
                            : const Icon(Icons.delete_outline_rounded, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: topInset + 8,
              left: 12,
              child: Material(
                color: AppColors.white.withValues(alpha: 0.9),
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.green, size: 20),
                ),
              ),
            ),
            Positioned(
              top: topInset + 8,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isOut ? 'Imeisha' : 'Available ${product.quantity}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isOut ? AppColors.danger : AppColors.greenDeep,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}