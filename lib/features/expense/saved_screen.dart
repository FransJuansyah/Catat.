import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/pocket_card.dart';
import '../../data/providers.dart';
import '../../domain/types.dart';

/// Layar 10 · Berhasil Tercatat.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key, required this.expenseId});

  final String expenseId;

  static const _confetti = [
    (0.10, 0.18, 14.0, 6.0, 0.35, Color(0xFF6D5DFC)),
    (0.82, 0.15, 10.0, 10.0, 0.8, Color(0xFFFF4F7B)),
    (0.20, 0.36, 8.0, 8.0, 0.0, AppColors.ink),
    (0.77, 0.33, 16.0, 6.0, -0.5, Color(0xFF12A36B)),
    (0.49, 0.13, 6.0, 14.0, 0.26, AppColors.ink),
    (0.87, 0.45, 8.0, 8.0, 0.0, Color(0xFF6D5DFC)),
    (0.08, 0.50, 12.0, 6.0, 1.05, Color(0xFFFF4F7B)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(expenseDetailProvider(expenseId)).value;
    final pockets = ref.watch(homeSummaryProvider).value?.pockets;
    final pocket = pockets
        ?.where((p) => p.id == detail?.entry.pocket.id)
        .firstOrNull;
    final fromScan = detail?.entry.source == ExpenseSource.scan;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.lime,
        body: LayoutBuilder(
          builder: (context, box) => Stack(
            children: [
              for (final (x, y, w, h, angle, color) in _confetti)
                Positioned(
                  left: box.maxWidth * x,
                  top: box.maxHeight * y,
                  child: Transform.rotate(
                    angle: angle,
                    child: Container(
                      width: w,
                      height: h,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.screenX,
                    8,
                    AppSpace.screenX,
                    16,
                  ),
                  child: Column(
                    children: [
                      const Spacer(),
                      Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          color: AppColors.ink,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.check,
                          size: 48,
                          color: AppColors.lime,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Tercatat!',
                        style: AppText.style(
                          40,
                          AppText.w800,
                          spacingPercent: -4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (detail != null)
                        Text(
                          '${rupiah(detail.entry.amount)} masuk ke kantong ${detail.entry.pocket.name}',
                          textAlign: TextAlign.center,
                          style: AppText.style(
                            15,
                            AppText.w700,
                            color: const Color(0xFF3F4A12),
                          ),
                        ),
                      const SizedBox(height: 32),
                      if (pocket != null) PocketCard(pocket: pocket),
                      const Spacer(),
                      AppButton(
                        label: 'Ke beranda',
                        onPressed: () => context.go('/beranda'),
                      ),
                      const SizedBox(height: 10),
                      AppButton(
                        label: fromScan ? 'Scan struk lagi' : 'Catat lagi',
                        icon: fromScan
                            ? LucideIcons.scanLine
                            : LucideIcons.plus,
                        style: AppButtonStyle.secondary,
                        onPressed: () => context.pushReplacement(
                          fromScan ? '/scan' : '/catat',
                        ),
                      ),
                    ],
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
