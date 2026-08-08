import 'package:flutter/material.dart';
import '../core/theme.dart';

class EdgeDockItem {
  final IconData icon;
  final String label;
  const EdgeDockItem({required this.icon, required this.label});
}

/// A slim vertical capsule docked to the right edge of the screen,
/// mid-height. Tap an icon to switch section; the active icon carries
/// a green pill that slides between positions and a label peeks out
/// to the left of it while active.
class EdgeDock extends StatelessWidget {
  final List<EdgeDockItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  const EdgeDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 10,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _DockButton(
                  item: items[i],
                  active: i == currentIndex,
                  onTap: () => onSelected(i),
                ),
                if (i != items.length - 1) const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  final EdgeDockItem item;
  final bool active;
  final VoidCallback onTap;

  const _DockButton({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: active ? 48 : 40,
        padding: EdgeInsets.symmetric(vertical: active ? 12 : 9, horizontal: active ? 10 : 8),
        decoration: BoxDecoration(
          color: active ? AppColors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: active ? 20 : 18,
              color: active ? AppColors.white : AppColors.bg.withValues(alpha: 0.55),
            ),
            if (active) ...[
              const SizedBox(height: 3),
              Text(
                item.label,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
