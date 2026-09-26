import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/amount_keypad.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/list_card.dart';
import '../../data/providers.dart';
import '../../domain/income_schedule.dart';
import '../../domain/types.dart';
import 'onboarding_widgets.dart';

/// Layar 28 · Atur Uang Jajan (pelajar, langkah 3 dari 5).
class AllowanceSetupScreen extends ConsumerWidget {
  const AllowanceSetupScreen({super.key});

  static const _short = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(onboardingProvider);
    final ctrl = ref.read(onboardingProvider.notifier);
    final per = switch (d.frequency) {
      IncomeFrequency.daily => 'hari',
      IncomeFrequency.weekly => 'minggu',
      IncomeFrequency.monthly => 'bulan',
    };
    final when = switch (d.frequency) {
      IncomeFrequency.daily => 'tiap hari',
      IncomeFrequency.weekly => 'tiap ${weekdayName(d.weekday)}',
      IncomeFrequency.monthly => 'tiap tgl ${d.payday}',
    };

    Future<void> editAmount() async {
      final v = await showAmountSheet(
        context,
        title: 'Uang jajan per $per',
        initial: d.amount,
      );
      if (v != null) ctrl.setAmount(v);
    }

    return OnboardingScaffold(
      title: 'Uang Jajan',
      canContinue: d.amountReady,
      children: [
        EditableAmount(
          label: 'Uang jajan per $per',
          amount: d.amount,
          onEdit: editAmount,
        ),
        const SizedBox(height: 16),
        SegmentedTabs<IncomeFrequency>(
          items: const [
            (IncomeFrequency.daily, 'Harian'),
            (IncomeFrequency.weekly, 'Mingguan'),
            (IncomeFrequency.monthly, 'Bulanan'),
          ],
          value: d.frequency,
          onChanged: ctrl.setFrequency,
        ),
        const SizedBox(height: 16),
        if (d.frequency == IncomeFrequency.weekly) ...[
          Container(
            padding: const EdgeInsets.all(AppSpace.cardPad),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dapat tiap hari apa?',
                  style: AppText.style(15, AppText.w800),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var w = 1; w <= 7; w++) ...[
                      if (w > 1) const SizedBox(width: 6),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => ctrl.setWeekday(w),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: w == d.weekday
                                  ? AppColors.ink
                                  : AppColors.bg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _short[w - 1],
                              style: AppText.style(
                                12,
                                w == d.weekday ? AppText.w800 : AppText.w700,
                                color: w == d.weekday
                                    ? Colors.white
                                    : AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        ListCard(
          children: [
            if (d.frequency == IncomeFrequency.monthly)
              SettingRow(
                icon: LucideIcons.calendar,
                title: 'Tanggal dapat',
                trailing: ValueChevron('Tiap tgl ${d.payday}'),
                onTap: () async {
                  final v = await showPaydaySheet(context, d.payday);
                  if (v != null) ctrl.setPayday(v);
                },
              ),
            SettingRow(
              icon: LucideIcons.repeat,
              title: 'Tambah otomatis',
              subtitle: 'Saldo nambah sendiri $when',
              trailing: AppToggle(value: d.autoAdd, onChanged: ctrl.setAutoAdd),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionTitle(
          title: 'Dibagi ke ${d.template.pockets.length} kantong',
          action: 'Ubah',
          onAction: () => context.push('/pilih-template'),
        ),
        const SizedBox(height: 14),
        SplitPreviewCard(template: d.template, amount: d.amount),
      ],
    );
  }
}
