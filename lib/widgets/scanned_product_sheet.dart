import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/product_model.dart';
import '../widgets/resilient_image.dart';

class ScannedProductSheet extends StatelessWidget {
  final ProductModel product;
  const ScannedProductSheet({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bidhaa Imepatikana',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Barcode Scanned',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.greenDeep),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: ResilientImage(
                        imageUrl: product.imageUrl ?? 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?q=80&w=600&auto=format&fit=crop',
                        fit: BoxFit.cover,
                        placeholderBackground: AppColors.greenSoft,
                        placeholderIconColor: AppColors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          product.formattedPrice,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.greenDeep),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 14, color: AppColors.inkSoft),
                            const SizedBox(width: 4),
                            Text(
                              'Stock: ${product.quantity}',
                              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft, fontWeight: FontWeight.w600),
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
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              product.description,
              style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Funga', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
