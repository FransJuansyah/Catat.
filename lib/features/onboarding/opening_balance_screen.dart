import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/amount_keypad.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../data/providers.dart';
import '../../domain/income_schedule.dart';
import '../../domain/types.dart';
import 'onboarding_widgets.dart';

/// Layar 42 · Uang Kamu Sekarang (langkah 5 dari 5). Jarang ada yang daftar
/// pas hari gajian, jadi yang dibagi ke kantong di periode pertama adalah
/// uang aslinya sekarang. Gajian berikutnya baru dibagi normal.
class OpeningBalanceScreen extends ConsumerStatefulWidget {
  const OpeningBalanceScreen({super.key});

  @override
  ConsumerState<OpeningBalanceScreen> createState() =>
      _OpeningBalanceScreenState();
}

class _OpeningBalanceScreenState extends ConsumerState<OpeningBalanceScreen> {
  int _amount = 0;
  bool _saving = false;

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await ref.read(onboardingProvider.notifier).finish(opening: _amount);
      if (!mounted) return;
      // Langkah terakhir: Privasi & Izin (35), lalu Beranda.
      context.go(
        Uri(
          path: '/privasi-awal',
          queryParameters: {'next': '/beranda'},
        ).toString(),
      );
    } on StateError {
      // Sudah terdaftar (onboarding terbuka lagi) → data lama dipertahankan.
      if (mounted) context.go('/beranda');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan. Coba lagi ya.')),
      );
    }
  }

  /// "Gajian tgl 25 nanti, Rp 6,5jt dibagi lagi".
  static String _nextIncome(OnboardingDraft d) {
    if (d.mode == IncomeMode.irregular) {
      return 'Duit masuk berikutnya tinggal dicatat, langsung kebagi';
    }
    final amount = rupiahShort(d.amount);
    if (d.mode == IncomeMode.salary) {
      return 'Gajian tgl ${d.payday} nanti, $amount dibagi lagi';
    }
    final when = switch (d.frequency) {
      IncomeFrequency.daily => 'besok',
      IncomeFrequency.weekly => '${weekdayName(d.weekday)} nanti',
      IncomeFrequency.monthly => 'tgl ${d.payday} nanti',
    };
    return 'Uang jajan $when, $amount dibagi lagi';
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingProvider);
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
                    const AppTopBar(title: 'Langkah 5 dari 5'),
                    const SizedBox(height: 14),
                    Text(
                      'Uang kamu\nsekarang berapa?',
                      style: AppText.style(
                        26,
                        AppText.w800,
                        spacingPercent: -3,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total di rekening, e-wallet & tunai. Nggak harus pas banget.',
                      style: AppText.style(
                        14,
                        AppText.w500,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          rupiah(_amount),
                          style: AppText.style(
                            40,
                            AppText.w800,
                            color: _amount == 0
                                ? AppColors.faint
                                : AppColors.ink,
                            spacingPercent: -3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SplitPreviewCard(
                      template: draft.template,
                      amount: _amount,
                      title:
                          'Langsung dibagi ke ${draft.template.pockets.length} kantong',
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.calendar,
                            size: 16,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _nextIncome(draft),
                              style: AppText.style(
                                12,
                                AppText.w500,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 16),
                    AmountKeypad(
                      onKey: (k) =>
                          setState(() => _amount = applyAmountKey(_amount, k)),
                      onClear: () => setState(() => _amount = 0),
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Mulai catat',
                      loading: _saving,
                      onPressed: _amount > 0 ? _finish : null,
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
