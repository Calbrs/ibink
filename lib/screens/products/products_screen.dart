import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/session.dart';
import '../../models/product_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/resilient_image.dart';

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
  bool _showSearch = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchProducts();
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

  Future<void> _fetchProducts({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      if (!ApiClient.instance.hasToken) {
        _fail('Haujaingia. Tafadhali ingia tena.');
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
          _products =
              productsData.map((e) => ProductModel.fromJson(e)).toList();
          _isLoading = false;
          _error = null;
        });
      } else if (response.statusCode == 401) {
        _fail('Kipindi chako kimeisha. Tafadhali ingia tena.');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Session.instance.logout();
            context.go(AppRoutes.auth);
          }
        });
      } else {
        _fail(response.error ?? 'Imeshindwa kupata bidhaa.', silent: silent);
      }
    } catch (e) {
      if (!mounted) return;
      _fail('Hitilafu ya mtandao: $e', silent: silent);
    }
  }

  void _fail(String message, {bool silent = false}) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (!(silent && _products.isNotEmpty)) _error = message;
    });
  }

  List<ProductModel> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _products;
    return _products
        .where((p) => p.name.toLowerCase().contains(q))
        .toList();
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
  // Navigation
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _openProductForm({ProductModel? product}) async {
    final result = await context.push<ProductModel>(
      AppRoutes.productForm,
      extra: product,
    );
    if (result == null || !mounted) return;

    final index = _products.indexWhere((p) => p.id == result.id);
    setState(() {
      if (index == -1) {
        _products.add(result);
      } else {
        _products[index] = result;
      }
    });
    await _fetchProducts(silent: true);
  }

  Future<void> _openProductDetail(ProductModel product) async {
    final action = await context.push<String>(
      '${AppRoutes.products}/${product.id}',
      extra: product,
    );
    if (!mounted) return;

    if (action == 'edit') {
      _openProductForm(product: product);
    } else if (action == 'delete') {
      setState(() => _products.removeWhere((p) => p.id == product.id));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final products = _visible;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (_showSearch) _buildSearchBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchProducts(silent: true),
                color: AppColors.green,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _buildContent(products),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<ProductModel> products) {
    if (_isLoading) {
      return const _ProductsSkeletonList(key: ValueKey('skeleton'));
    }
    if (_error != null) {
      return _ScrollableCenter(
        key: const ValueKey('error'),
        child: _ErrorState(message: _error!, onRetry: _fetchProducts),
      );
    }
    if (products.isEmpty) {
      return _ScrollableCenter(
        key: const ValueKey('empty'),
        child: _EmptyState(
          hasProducts: _products.isNotEmpty,
          onAdd: () => _openProductForm(),
        ),
      );
    }
    return ListView.separated(
      key: const ValueKey('list'),
      physics: const AlwaysScrollableScrollPhysics(),
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
    );
  }

  Widget _buildHeader() {
    final session = Session.instance;
    final handle = (session.shopSlug != null && session.shopSlug!.isNotEmpty)
        ? '@${session.shopSlug}'
        : (session.shopName ?? 'Duka');

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
                  'Stock',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$handle  •  ${_products.length} bidhaa',
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
          Material(
            color: AppColors.green,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openProductForm(),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.add_rounded, color: AppColors.white, size: 24),
              ),
            ),
          ),
        ],
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
            hintText: 'Tafuta bidhaa...',
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
            child: const Icon(Icons.error_outline_rounded,
                size: 30, color: AppColors.danger),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
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
  final bool hasProducts;
  final VoidCallback onAdd;
  const _EmptyState({required this.hasProducts, required this.onAdd});

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
            child: const Icon(Icons.inventory_2_outlined,
                size: 28, color: AppColors.green),
          ),
          const SizedBox(height: 16),
          Text(
            hasProducts ? 'Hakuna bidhaa' : 'Bado huna bidhaa',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasProducts
                ? 'Hakuna bidhaa zinazolingana na utafutaji wako.'
                : 'Ongeza bidhaa yako ya kwanza ili uanze kuuza.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.inkSoft,
              height: 1.45,
            ),
          ),
          if (!hasProducts) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Ongeza Bidhaa',
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
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Product row — layout matches the sketch (same row):
//
//   ┌───────┐  ┌──────────────────────────────┐
//   │       │  │ 4. Title                     │
//   │ 1.    │  │                              │
//   │ image │  │ 2. Stock          5. [Hariri]│
//   │       │  │ 3. Price                     │
//   └───────┘  └──────────────────────────────┘
// ═══════════════════════════════════════════════════════════════════════════

const double _kRowImageSize = 87;

class _ProductRow extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ProductRow({
    required this.product,
    required this.onTap,
    required this.onEdit,
  });

  /// "TZS 5,000" → "bei: 5,000"
  String get _priceLabel {
    final clean = product.formattedPrice
        .replaceAll(RegExp(r'^TZS\s*', caseSensitive: false), '')
        .trim();
    return 'bei: $clean';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── 1. Independent product image (left, same row) ──
        GestureDetector(
          onTap: onTap,
          child: ResilientImage(
            imageUrl: product.imageUrl,
            imagePath: product.imagePath,
            width: _kRowImageSize,
            height: _kRowImageSize,
            borderRadius: BorderRadius.circular(12),
            placeholderBackground: AppColors.greenSoft,
            placeholderIconColor: AppColors.green,
            placeholderIconSize: 32,
          ),
        ),
        const SizedBox(width: 12),

        // ── Card: title on top; stock/price (left) + Hariri (right) ──
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
                    // ── 4. Product title ──
                    Text(
                      product.name,
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── 2 & 3. Stock + price (stacked, left) ──
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PricePill(label: _priceLabel),
                              const SizedBox(height: 4),
                              _StockBadge(quantity: product.quantity),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ── 5. Hariri button (right) ──
                        _EditLabel(onTap: onEdit),
                      ],
                    ),
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

/// "Hariri" pill button.
class _EditLabel extends StatelessWidget {
  final VoidCallback onTap;
  const _EditLabel({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.greenSoft.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            'Hariri',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppColors.greenDeep,
            ),
          ),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final int quantity;
  const _StockBadge({required this.quantity});

  @override
  Widget build(BuildContext context) {
    final isOut = quantity <= 0;
    return _InfoPill(
      text: isOut ? 'Imeisha' : 'Stock: $quantity',
      color: isOut ? AppColors.danger : AppColors.greenDeep,
      background: isOut
          ? AppColors.danger.withValues(alpha: 0.12)
          : AppColors.green.withValues(alpha: 0.12),
    );
  }
}

class _PricePill extends StatelessWidget {
  final String label;
  const _PricePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return _InfoPill(
      text: label,
      color: AppColors.greenDeep,
      background: AppColors.green.withValues(alpha: 0.12),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shimmer skeleton
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

/// Mirrors [_ProductRow]: image on the left, card on the right.
class _SkeletonProductRow extends StatelessWidget {
  const _SkeletonProductRow();

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
                _SkeletonBox(height: 15),
                SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonBox(width: 54, height: 18),
                          SizedBox(height: 4),
                          _SkeletonBox(width: 60, height: 18),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    _SkeletonBox(width: 56, height: 26, radius: 8),
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

class _ProductsSkeletonList extends StatelessWidget {
  const _ProductsSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerGradient(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => const _SkeletonProductRow(),
      ),
    );
  }
}