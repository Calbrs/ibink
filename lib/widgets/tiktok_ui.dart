import 'package:flutter/material.dart';
import '../core/theme.dart';

// ============================================================
// tiktok_ui.dart
// Vipengele vya pamoja vya skrini zote za TikTok, vinavyofuata
// muonekano wa Profile Screen.
// ============================================================

final BoxDecoration ttCardDecoration = BoxDecoration(
  color: AppColors.panel,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: AppColors.line),
);

/// AppBar moja kwa skrini zote ndogo.
PreferredSizeWidget ttAppBar(
  BuildContext context, {
  String? title,
  List<Widget>? actions,
}) {
  return AppBar(
    backgroundColor: AppColors.bg,
    elevation: 0,
    scrolledUnderElevation: 0,
    leading: IconButton(
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
    ),
    title: title == null
        ? null
        : Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
    actions: actions,
  );
}

class TtAvatar extends StatelessWidget {
  final String initial;
  final double size;
  final String? imageUrl;

  const TtAvatar({
    super.key,
    required this.initial,
    this.size = 112,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.35),
          width: 2,
        ),
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.greenSoft,
          shape: BoxShape.circle,
          image: hasImage
              ? DecorationImage(
                  image: NetworkImage(imageUrl!),
                  fit: BoxFit.cover,
                  onError: (_, _) {},
                )
              : null,
        ),
        child: hasImage
            ? null
            : Text(
                initial,
                style: TextStyle(
                  fontSize: size * 0.41,
                  fontWeight: FontWeight.w800,
                  color: AppColors.greenDeep,
                ),
              ),
      ),
    );
  }
}

class TtPill extends StatelessWidget {
  final String text;
  const TtPill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.greenDeep,
        ),
      ),
    );
  }
}

class TtSectionLabel extends StatelessWidget {
  final String text;
  const TtSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: AppColors.inkFaint,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Kadi inayopanga safu kwa mistari myembamba ya kugawanya.
class TtGroupCard extends StatelessWidget {
  final List<Widget> children;
  final double dividerIndent;

  const TtGroupCard({
    super.key,
    required this.children,
    this.dividerIndent = 62,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: ttCardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.line,
                indent: dividerIndent,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class TtIconBadge extends StatelessWidget {
  final Widget child;
  const TtIconBadge({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class TtInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  const TtInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          TtIconBadge(
            child: Icon(icon, size: 18, color: iconColor ?? AppColors.green),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TtActionRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const TtActionRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            TtIconBadge(child: leading),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.inkFaint,
            ),
          ],
        ),
      ),
    );
  }
}

/// Kitufe kikuu (kijani) au cha mstari (outlined).
class TtButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool outlined;
  final bool expand;

  const TtButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 8)],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final size = Size(expand ? double.infinity : 0, 52);
    const pad = EdgeInsets.symmetric(horizontal: 22);

    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.green,
          minimumSize: size,
          padding: pad,
          side: const BorderSide(color: AppColors.green, width: 1.4),
          shape: shape,
        ),
        child: content,
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        minimumSize: size,
        padding: pad,
        shape: shape,
      ),
      child: content,
    );
  }
}

/// Hali ya kati: ikoni, kichwa, maelezo na kitufe (hitilafu / tupu).
class TtMessageState extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const TtMessageState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 36),
      children: [
        const SizedBox(height: 72),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.greenSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: iconColor ?? AppColors.green),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.25,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            color: AppColors.inkSoft,
            height: 1.5,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 24),
          Center(
            child: TtButton(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
            ),
          ),
        ],
      ],
    );
  }
}

/// Tangazo dogo lenye rangi (mf. onyo la akaunti ya faragha).
class TtNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const TtNotice({
    super.key,
    required this.icon,
    required this.text,
    this.color = AppColors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.ink,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}