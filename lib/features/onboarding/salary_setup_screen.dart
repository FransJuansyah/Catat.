import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/amount_keypad.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/icon_badge.dart';
import '../../data/providers.dart';
import '../../domain/allocation.dart';

/// Layar 02 · Atur Gaji (langkah 2 dari 3 onboarding).
class SalarySetupScreen extends ConsumerWidget {
  const SalarySetupScreen({super.key});

  Future<void> _editSalary(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final value = await showAmountSheet(
      context,
      title: 'Gaji bersih per bulan',
      initial: current,
    );
    if (value != null) ref.read(onboardingProvider.notifier).setSalary(value);
  }

  Future<void> _editPayday(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final value = await showPaydaySheet(context, current);
    if (value != null) ref.read(onboardingProvider.notifier).setPayday(value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingProvider);
    final pockets = draft.template.pockets;
    final amounts = allocateAll(draft.salary, [
      for (final (i, p) in pockets.indexed)
        PocketRule(pocketId: '$i', percent: p.percent),
    ]);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.screenX,
                  8,
                  AppSpace.screenX,
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppTopBar(title: 'Atur Gaji'),
                    const SizedBox(height: 18),
                    Text(
                      'Gaji bersih per bulan',
                      style: AppText.style(
                        14,
                        AppText.w500,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () => _editSalary(context, ref, draft.salary),
                      child: Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                rupiah(draft.salary),
                                style: AppText.style(
                                  34,
                                  AppText.w800,
                                  color: draft.salary == 0
                                      ? AppColors.faint
                                      : AppColors.ink,
                                  spacingPercent: -3,
                                ),
                              ),
                            ),
                          ),
                          CircleIconButton(
                            icon: LucideIcons.pencil,
                            size: 36,
                            iconSize: 16,
                            onTap: () =>
                                _editSalary(context, ref, draft.salary),
                          ),
                        ],
                      ),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () =>
                                _editPayday(context, ref, draft.payday),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  const IconBadge(
                                    icon: LucideIcons.calendar,
                                    background: AppColors.bg,
                                    color: AppColors.ink,
                                    size: 36,
                                    iconSize: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Tanggal gajian',
                                      style: AppText.style(15, AppText.w700),
                                    ),
                                  ),
                                  Text(
                                    'Tiap tgl ${draft.payday}',
                                    style: AppText.style(
                                      14,
                                      AppText.w700,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    LucideIcons.chevronRight,
                                    size: 18,
                                    color: AppColors.faint,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.line,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                const IconBadge(
                                  icon: LucideIcons.repeat,
                                  background: AppColors.bg,
                                  color: AppColors.ink,
                                  size: 36,
                                  iconSize: 18,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tambah otomatis',
                                        style: AppText.style(15, AppText.w700),
                                      ),
                                      Text(
                                        'Saldo nambah sendiri tiap gajian',
                                        style: AppText.style(
                                          12,
                                          AppText.w500,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AppToggle(
                                  value: draft.autoAdd,
                                  onChanged: ref
                                      .read(onboardingProvider.notifier)
                                      .setAutoAdd,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Dibagi ke ${pockets.length} kantong',
                            style: AppText.style(
                              17,
                              AppText.w800,
                              spacingPercent: -1,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/pilih-template'),
                          child: Text(
                            'Ubah',
                            style: AppText.style(
                              12,
                              AppText.w700,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(AppSpace.cardPad),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Column(
                        children: [
                          SplitBar(
                            parts: [
                              for (final p in pockets) (p.percent, p.color),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (final (i, p) in pockets.indexed)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Color(p.color),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          p.name,
                                          style: AppText.style(
                                            12,
                                            AppText.w500,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      draft.salary == 0
                                          ? '${p.percent}%'
                                          : '${p.percent}% · ${rupiahShort(amounts['$i']!).substring(3)}',
                                      style: AppText.style(15, AppText.w800),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Lanjut',
                      onPressed: draft.salary > 0
                          ? () => context.push('/pilih-template')
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pilih tanggal gajian 1–31. `null` = batal.
Future<int?> showPaydaySheet(BuildContext context, int current) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
    ),
    builder: (context) => SafeArea(
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
            const SizedBox(height: 16),
            Text('Tanggal gajian', style: AppText.style(17, AppText.w800)),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var d = 1; d <= 31; d++)
                  Material(
                    color: d == current ? AppColors.ink : AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, d),
                      child: Center(
                        child: Text(
                          '$d',
                          style: AppText.style(
                            15,
                            AppText.w700,
                            color: d == current ? Colors.white : AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Tgl 29–31 otomatis jadi hari terakhir di bulan yang lebih pendek.',
              textAlign: TextAlign.center,
              style: AppText.style(12, AppText.w500, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
