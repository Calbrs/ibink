import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/session.dart';
import '../models/product_model.dart';
import '../routes/app_routes.dart';
import '../widgets/resilient_image.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<ProductModel> _products = [];
  bool _isLoading = true;
  String? _error;
  String _query = '';
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (!ApiClient.instance.hasToken) {
        setState(() {
          _isLoading = false;
          _error = 'Haujaingia. Tafadhali ingia tena.';
        });
        return;
      }

      final response = await ApiClient.instance.get(ApiConfig.productsEndpoint);

      if (!mounted) return;

      if (response.success) {
        final data = response.data ?? {};
        final inner = data['data'] ?? data['products'] ?? [];
        final List<dynamic> productsData = inner is Map
            ? (inner['data'] as List<dynamic>? ?? [])
            : (inner is List<dynamic> ? inner : []);
        setState(() {
          _products = productsData.map((e) => ProductModel.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        if (response.statusCode == 401) {
          setState(() {
            _isLoading = false;
            _error = 'Kipindi chako kimeisha. Tafadhali ingia tena.';
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Session.instance.logout();
              context.go(AppRoutes.auth);
            }
          });
        } else {
          setState(() {
            _isLoading = false;
            _error = response.error ?? 'Imeshindwa kupata bidhaa.';
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Hitilafu ya mtandao: $e';
      });
    }
  }

  List<String> get _categories =>
      _products.map((p) => p.category ?? 'Nyingine').toSet().toList();

  List<ProductModel> get _visible {
    return _products.where((p) {
      final matchesQuery =
          _query.isEmpty || p.name.toLowerCase().contains(_query.toLowerCase());
      final matchesCategory =
          _categoryFilter == null || (p.category ?? 'Nyingine') == _categoryFilter;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  Future<void> _openProductForm({ProductModel? product}) async {
    final result = await context.push<ProductModel>(AppRoutes.productForm, extra: product);
    if (result != null) {
      final index = _products.indexWhere((p) => p.id == result.id);
      if (index == -1) {
        setState(() => _products.add(result));
      } else {
        setState(() => _products[index] = result);
      }
      await _fetchProducts();
    }
  }

  Future<void> _openProductDetail(ProductModel product) async {
    final action = await context.push<String>('${AppRoutes.products}/${product.id}', extra: product);
    if (action == 'edit') {
      _openProductForm(product: product);
    } else if (action == 'delete') {
      setState(() => _products.removeWhere((p) => p.id == product.id));
    }
  }

  void _openQuickAccessModal() {
    showModalBottomSheet(useRootNavigator: true, context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickAccessSheet(
        categories: _categories,
        activeCategory: _categoryFilter,
        onSelectCategory: (c) {
          setState(() => _categoryFilter = c);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _visible;
    final shopName = Session.instance.shopName ?? 'Duka';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchProducts,
          color: AppColors.green,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bidhaa Zangu',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '@$shopName',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.greenSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_products.length} bidhaa',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.greenDeep,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: AppColors.green,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _openProductForm(),
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(Icons.add_rounded, color: AppColors.white, size: 19),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          hintText: 'Tafuta bidhaa...',
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
                            border: Border.all(color: AppColors.line),
                          ),
                          child: const Icon(Icons.tune_rounded, color: AppColors.inkSoft, size: 21),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _isLoading
                      ? const _ProductsSkeletonList(key: ValueKey('skeleton'))
                      : _error != null
                          ? _buildErrorView()
                          : products.isEmpty
                              ? const _EmptyProducts(key: ValueKey('empty'))
                              : ListView.separated(
                                  key: const ValueKey('list'),
                                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                                  itemCount: products.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final p = products[index];
                                    return _ProductRow(
                                      product: p,
                                      onTap: () => _openProductDetail(p),
                                      onEdit: () => _openProductForm(product: p),
                                    );
                                  },
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchProducts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Jaribu Tena'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// SHIMMER SKELETON LOADING
/// ============================================================================

class _ShimmerGradient extends StatefulWidget {
  final Widget child;
  const _ShimmerGradient({required this.child});

  @override
  State<_ShimmerGradient> createState() => _ShimmerGradientState();
}

class _ShimmerGradientState extends State<_ShimmerGradient> with SingleTickerProviderStateMixin {
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
                AppColors.white.withValues(alpha: 0.9),
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
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.line.withValues(alpha: 0.55),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    );
  }
}

class _SkeletonProductRow extends StatelessWidget {
  const _SkeletonProductRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _SkeletonBox(width: 56, height: 56, borderRadius: BorderRadius.circular(12)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: double.infinity, height: 14, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 8),
                _SkeletonBox(width: 80, height: 11, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _SkeletonBox(width: 60, height: 13, borderRadius: BorderRadius.circular(4)),
                    const SizedBox(width: 8),
                    _SkeletonBox(width: 56, height: 18, borderRadius: BorderRadius.circular(6)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductsSkeletonList extends StatelessWidget {
  const _ProductsSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerGradient(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => const _SkeletonProductRow(),
      ),
    );
  }
}

class _QuickAccessSheet extends StatelessWidget {
  final List<String> categories;
  final String? activeCategory;
  final ValueChanged<String?> onSelectCategory;

  const _QuickAccessSheet({
    required this.categories,
    required this.activeCategory,
    required this.onSelectCategory,
  });

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
            child: Row(
              children: [
                Text('Ufikiaji wa Haraka', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Chuja bidhaa kwa kategoria', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
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
                  active: activeCategory == null,
                  onTap: () => onSelectCategory(null),
                ),
                for (final c in categories)
                  _QuickButton(
                    label: c,
                    icon: _iconForCategory(c),
                    active: activeCategory == c,
                    onTap: () => onSelectCategory(c),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Electronics':
        return Icons.headphones;
      case 'Fashion':
        return Icons.shopping_bag;
      case 'Home':
        return Icons.chair_outlined;
      case 'Beauty':
        return Icons.spa_outlined;
      case 'Food':
        return Icons.emoji_food_beverage;
      case 'Health':
        return Icons.favorite_border_rounded;
      default:
        return Icons.category_outlined;
    }
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _QuickButton({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.green : AppColors.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? AppColors.green : AppColors.line),
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

class _ProductRow extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ProductRow({required this.product, required this.onTap, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isOut = product.quantity <= 0;

    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              ResilientImage(
                imageUrl: product.imageUrl,
                imagePath: product.imagePath,
                width: 56,
                height: 56,
                borderRadius: BorderRadius.circular(12),
                placeholderBackground: AppColors.greenSoft,
                placeholderIconColor: AppColors.green,
                placeholderIconSize: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.category ?? 'Nyingine',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          product.formattedPrice,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.greenDeep,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOut
                                ? AppColors.danger.withValues(alpha: 0.12)
                                : AppColors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isOut ? 'Imeisha' : 'Stock: ${product.quantity}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isOut ? AppColors.danger : AppColors.greenDeep,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onEdit,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(
                      'Edit',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.green),
                    ),
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

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.inkSoft),
            const SizedBox(height: 12),
            const Text(
              'Hakuna bidhaa',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              'Hakuna bidhaa zinazolingana na utafutaji wako.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}