import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Lingkaran (atau kotak membulat) berisi ikon. Ukuran ikon = 46% badge.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.background,
    required this.color,
    this.size = AppSize.badge,
    this.iconSize,
    this.square = false,
    this.border,
  });

  final IconData icon;
  final Color background;
  final Color color;
  final double size;
  final double? iconSize;
  final bool square;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(size * 0.32) : null,
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Icon(
        icon,
        size: iconSize ?? (size * 0.46).roundToDouble(),
        color: color,
      ),
    );
  }
}

/// Tombol bulat 40–44 putih ber-border (lonceng, back, edit).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = AppSize.topBarButton,
    this.iconSize = 20,
    this.iconColor = AppColors.ink,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: iconSize,
            color: onTap == null ? AppColors.faint : iconColor,
          ),
        ),
      ),
    );
  }
}
