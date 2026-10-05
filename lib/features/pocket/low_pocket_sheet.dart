import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/progress_track.dart';
import '../../domain/home_summary.dart';

/// Layar 24 · Peringatan kantong hampir habis (bottom sheet di Beranda).
Future<void> showLowPocketSheet(BuildContext context, PocketView pocket) {
  final color = Color(pocket.color);
  final b = pocket.balance;
  final pct = b.available <= 0 ? 0 : (b.remaining * 100 / b.available).round();
  final minus = b.remaining < 0;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
    ),
    builder: (sheet) => SafeArea(
      child: Padding(
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
            const SizedBox(height: 20),
            IconBadge(
              icon: LucideIcons.triangleAlert,
              background: PocketVisuals.soft(color),
              color: color,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              minus
                  ? 'Kantong ${pocket.name}\nudah minus'
                  : 'Kantong ${pocket.name}\ntinggal $pct%',
              textAlign: TextAlign.center,
              style: AppText.style(22, AppText.w800, spacingPercent: -2),
            ),
            const SizedBox(height: 8),
            Text(
              minus
                  ? 'Lewat ${rupiahShort(-b.remaining)} dari jatah ${rupiahShort(b.available)}. Mau diapain?'
                  : 'Sisa ${rupiahShort(b.remaining)} dari jatah ${rupiahShort(b.available)}. Mau diapain?',
              textAlign: TextAlign.center,
              style: AppText.style(14, AppText.w500, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            ProgressTrack(
              value: b.usedRatio,
              color: minus ? AppColors.danger : color,
            ),
            const SizedBox(height: 18),
            AppButton(
              label: 'Pindahin dari kantong lain',
              icon: LucideIcons.repeat,
              onPressed: () {
                Navigator.pop(sheet);
                context.push('/pindah-saldo?to=${pocket.id}');
              },
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Oke, siap hemat',
              style: AppButtonStyle.secondary,
              onPressed: () => Navigator.pop(sheet),
            ),
          ],
        ),
      ),
    ),
  );
}
