import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/app_shimmer.dart';

/// Kisanduku cha picha kinachovumilia hitilafu (404, faili la lokali
/// limefutwa, hakuna intaneti, n.k) kwa kuonyesha placeholder badala ya
/// kuvunja UI.
class ResilientImage extends StatelessWidget {
  final String? imageUrl;
  final String? imagePath;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final IconData placeholderIcon;
  final double placeholderIconSize;
  final Color placeholderBackground;
  final Color placeholderIconColor;

  const ResilientImage({
    super.key,
    this.imageUrl,
    this.imagePath,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.image_outlined,
    this.placeholderIconSize = 28,
    required this.placeholderBackground,
    required this.placeholderIconColor,
  });

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: placeholderBackground,
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Icon(placeholderIcon, size: placeholderIconSize, color: placeholderIconColor),
      ),
    );
  }

  Widget _loadingBox() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: placeholderBackground,
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: AppShimmerSpinner(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imagePath != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.file(
          File(imagePath!),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _placeholder(),
        ),
      );
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          imageUrl!,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _placeholder(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _loadingBox();
          },
        ),
      );
    }

    return _placeholder();
  }
}