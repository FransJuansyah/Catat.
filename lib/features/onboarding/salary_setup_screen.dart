import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/amount_keypad.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/list_card.dart';
import '../../data/providers.dart';
import 'onboarding_widgets.dart';

/// Layar 02 · Atur Gaji (langkah 3 dari 4, gaji bulanan).
class SalarySetupScreen extends ConsumerWidget {
  const SalarySetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingProvider);
    final ctrl = ref.read(onboardingProvider.notifier);

    Future<void> editAmount() async {
      final v = await showAmountSheet(
        context,
        title: 'Gaji bersih per bulan',
        initial: draft.amount,
      );
      if (v != null) ctrl.setAmount(v);
    }

    return OnboardingScaffold(
      title: 'Atur Gaji',
      canContinue: draft.amountReady,
      children: [
        EditableAmount(
          label: 'Gaji bersih per bulan',
          amount: draft.amount,
          onEdit: editAmount,
        ),
        const SizedBox(height: 18),
        DashedCard(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Baca slip otomatis segera hadir. Isi manual dulu ya.',
              ),
            ),
          ),
          child: Row(
            children: [
              const IconBadge(
                icon: LucideIcons.upload,
                background: AppColors.lime,
                color: AppColors.ink,
                size: 42,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload slip gaji',
                      style: AppText.style(15, AppText.w800),
                    ),
                    Text(
                      'Foto / PDF, angkanya kebaca otomatis',
                      style: AppText.style(
                        12,
                        AppText.w500,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ListCard(
          children: [
            SettingRow(
              icon: LucideIcons.calendar,
              title: 'Tanggal gajian',
              trailing: ValueChevron('Tiap tgl ${draft.payday}'),
              onTap: () async {
                final v = await showPaydaySheet(context, draft.payday);
                if (v != null) ctrl.setPayday(v);
              },
            ),
            SettingRow(
              icon: LucideIcons.repeat,
              title: 'Tambah otomatis',
              subtitle: 'Saldo nambah sendiri tiap gajian',
              trailing: AppToggle(
                value: draft.autoAdd,
                onChanged: ctrl.setAutoAdd,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionTitle(
          title: 'Dibagi ke ${draft.template.pockets.length} kantong',
          action: 'Ubah',
          onAction: () => context.push('/pilih-template'),
        ),
        const SizedBox(height: 14),
        SplitPreviewCard(template: draft.template, amount: draft.amount),
      ],
    );
  }
}
