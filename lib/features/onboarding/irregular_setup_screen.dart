import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/amount_keypad.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/list_card.dart';
import '../../data/providers.dart';
import 'onboarding_widgets.dart';

/// Layar 29 · Atur Penghasilan Tidak Tetap (langkah 3 dari 4).
class IrregularSetupScreen extends ConsumerWidget {
  const IrregularSetupScreen({super.key});

  static const _examples = [
    ('Sen', 'Ngojek', 150000),
    ('Rab', 'Jualan online', 200000),
    ('Sab', 'Project desain', 450000),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(onboardingProvider);
    final ctrl = ref.read(onboardingProvider.notifier);

    Future<void> editEstimate() async {
      final v = await showAmountSheet(
        context,
        title: 'Perkiraan pemasukan sebulan',
        initial: d.monthlyEstimate,
      );
      if (v != null) ctrl.setMonthlyEstimate(v);
    }

    return OnboardingScaffold(
      title: 'Penghasilan',
      children: [
        Text(
          'Penghasilan nggak\ntentu? Santai.',
          style: AppText.style(
            26,
            AppText.w800,
            spacingPercent: -3,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tiap dapat duit, tinggal masukin. catat. langsung bagi ke kantong.',
          style: AppText.style(14, AppText.w500, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contoh minggu ini',
                style: AppText.style(12, AppText.w700, color: AppColors.muted),
              ),
              for (final (day, title, amount) in _examples) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const IconBadge(
                      icon: LucideIcons.plus,
                      background: Color(0xFFE2F6EC),
                      color: AppColors.success,
                      size: 28,
                      iconSize: 14,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$day · $title',
                        style: AppText.style(14, AppText.w700),
                      ),
                    ),
                    Text(
                      '+${rupiahShort(amount)}',
                      style: AppText.style(
                        14,
                        AppText.w800,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        ListCard(
          children: [
            SettingRow(
              icon: LucideIcons.chartColumn,
              title: 'Perkiraan sebulan',
              subtitle: d.monthlyEstimate > 0
                  ? rupiah(d.monthlyEstimate)
                  : 'Opsional, buat bantu target',
              trailing: const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.faint,
              ),
              onTap: editEstimate,
            ),
            SettingRow(
              icon: LucideIcons.bell,
              title: 'Ingetin catat pemasukan',
              subtitle: 'Tiap malam jam 20:00',
              trailing: AppToggle(
                value: d.reminder,
                onChanged: ctrl.setReminder,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionTitle(
          title: 'Tiap duit masuk, dibagi ke',
          action: 'Ubah',
          onAction: () => context.push('/pilih-template'),
        ),
        const SizedBox(height: 14),
        SplitPreviewCard(template: d.template, amount: d.monthlyEstimate),
      ],
    );
  }
}
