import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';
import 'icon_badge.dart';

/// Top bar: [tombol bulat back/tutup] — judul — [aksi opsional].
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.close = false,
    this.onLeading,
    this.trailingIcon,
    this.onTrailing,
    this.trailingColor = AppColors.ink,
  });

  final String title;

  /// `true` = ikon X (layar modal seperti Catat Manual), `false` = ikon back.
  final bool close;
  final VoidCallback? onLeading;
  final IconData? trailingIcon;
  final VoidCallback? onTrailing;

  /// Warna ikon kanan, mis. merah untuk hapus.
  final Color trailingColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleIconButton(
          icon: close ? LucideIcons.x : LucideIcons.chevronLeft,
          onTap: onLeading ?? () => context.pop(),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: AppText.style(17, AppText.w700),
          ),
        ),
        if (trailingIcon != null)
          CircleIconButton(
            icon: trailingIcon!,
            onTap: onTrailing,
            iconColor: trailingColor,
          )
        else
          const SizedBox(width: AppSize.topBarButton),
      ],
    );
  }
}
