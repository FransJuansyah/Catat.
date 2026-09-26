import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/icon_badge.dart';
import 'privacy_items.dart';

/// Layar 36 · sheet ⓘ: apa yang dibaca, buat apa, kalau dimatikan, dan yang
/// nggak pernah dilakukan. Juga jadi penjelasan wajib (Play) sebelum minta
/// izin. Mengembalikan `true` kalau user menekan "Nyalakan".
Future<bool> showPrivacyInfo(
  BuildContext context,
  PrivacyItem item, {
  required bool on,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.disabledBg,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 14),
            IconBadge(
              icon: item.icon,
              background: AppColors.track,
              color: AppColors.ink,
              size: 56,
              iconSize: 26,
              square: true,
            ),
            const SizedBox(height: 14),
            Text(
              item.infoTitle,
              textAlign: TextAlign.center,
              style: AppText.style(20, AppText.w800, spacingPercent: -2),
            ),
            const SizedBox(height: 14),
            for (final kind in InfoKind.values) ...[
              _Point(item: item, kind: kind),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 2),
            if (on)
              AppButton(
                label: 'Oke',
                onPressed: () => Navigator.pop(context, false),
              )
            else ...[
              AppButton(
                label: 'Nyalakan',
                onPressed: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Nanti aja',
                style: AppButtonStyle.secondary,
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

class _Point extends StatelessWidget {
  const _Point({required this.item, required this.kind});

  final PrivacyItem item;
  final InfoKind kind;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (kind) {
      InfoKind.off => (LucideIcons.triangleAlert, AppColors.warnIcon),
      InfoKind.never => (LucideIcons.x, AppColors.danger),
      _ => (LucideIcons.check, AppColors.ink),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.infoLabel(kind),
                style: AppText.style(14, AppText.w800),
              ),
              const SizedBox(height: 2),
              Text(
                item.infoText(kind),
                style: AppText.style(13, AppText.w500, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
