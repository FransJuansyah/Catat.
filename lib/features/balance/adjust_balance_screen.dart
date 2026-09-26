import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/amount_keypad.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/pocket_chip.dart';
import '../../data/providers.dart';
import '../../domain/home_summary.dart';
import '../../domain/types.dart';

/// Sesuaikan Saldo (Akun → Keuangan): user ketik uang aslinya sekarang,
/// selisihnya dicatat sebagai "Penyesuaian saldo" (tidak dihitung sebagai
/// jajan di insight).
class AdjustBalanceScreen extends ConsumerStatefulWidget {
  const AdjustBalanceScreen({super.key});

  @override
  ConsumerState<AdjustBalanceScreen> createState() =>
      _AdjustBalanceScreenState();
}

class _AdjustBalanceScreenState extends ConsumerState<AdjustBalanceScreen> {
  int _actual = 0;
  String? _pocketId;
  bool _saving = false;

  Future<void> _save(HomeSummary home, String pocketId) async {
    setState(() => _saving = true);
    try {
      final diff = await ref
          .read(budgetRepositoryProvider)
          .adjustBalance(actual: _actual, pocketId: pocketId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            diff == 0
                ? 'Saldo udah sama, nggak ada yang diubah.'
                : 'Saldo disesuaikan jadi ${rupiah(_actual)}.',
          ),
        ),
      );
      context.pop();
    } on StateError {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeSummaryProvider).value;
    final pockets = home?.pockets ?? const <PocketView>[];
    final recorded = home?.remaining ?? 0;
    final diff = _actual - recorded;
    // Kurangi dari kantong pilihan; bawaan: kantong Keinginan / terakhir.
    final pocketId =
        _pocketId ??
        (pockets.where((p) => p.type == PocketType.keinginan).firstOrNull ??
                pockets.lastOrNull)
            ?.id;

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
                  children: [
                    const AppTopBar(title: 'Sesuaikan Saldo'),
                    const SizedBox(height: 20),
                    Text(
                      'Saldo di catat. ${rupiah(recorded)}',
                      style: AppText.style(
                        13,
                        AppText.w500,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Uang aslimu sekarang',
                      style: AppText.style(
                        13,
                        AppText.w500,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        rupiah(_actual),
                        style: AppText.style(
                          44,
                          AppText.w800,
                          color: _actual == 0 ? AppColors.faint : AppColors.ink,
                          spacingPercent: -3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DiffCard(diff: diff, touched: _actual > 0),
                    if (diff < 0 && _actual > 0) ...[
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Kurangi dari kantong',
                          style: AppText.style(
                            13,
                            AppText.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ChipRows(
                        children: [
                          for (final p in pockets)
                            PocketChip(
                              pocket: p,
                              selected: p.id == pocketId,
                              onTap: () => setState(() => _pocketId = p.id),
                            ),
                        ],
                      ),
                    ],
                    const Spacer(),
                    const SizedBox(height: 16),
                    AmountKeypad(
                      onKey: (k) =>
                          setState(() => _actual = applyAmountKey(_actual, k)),
                      onClear: () => setState(() => _actual = 0),
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Sesuaikan',
                      loading: _saving,
                      onPressed:
                          home != null &&
                              pocketId != null &&
                              _actual > 0 &&
                              diff != 0
                          ? () => _save(home, pocketId)
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

/// Selisih uang asli vs catatan, dan apa yang akan dicatat.
class _DiffCard extends StatelessWidget {
  const _DiffCard({required this.diff, required this.touched});

  final int diff;
  final bool touched;

  @override
  Widget build(BuildContext context) {
    final (title, body, color) = !touched
        ? (
            'Ketik uang aslimu',
            'Gabungan saldo rekening, e-wallet & uang tunai yang kamu pakai '
                'buat kantong.',
            AppColors.muted,
          )
        : diff == 0
        ? ('Udah sama', 'Nggak ada yang perlu disesuaikan.', AppColors.success)
        : diff > 0
        ? (
            'Kurang tercatat +${rupiah(diff)}',
            'Dicatat sebagai pemasukan "Penyesuaian saldo", dibagi ke kantong.',
            AppColors.success,
          )
        : (
            'Kelebihan tercatat -${rupiah(-diff)}',
            'Dicatat sebagai "Penyesuaian saldo" dari kantong di bawah. Nggak '
                'dihitung sebagai jajan.',
            AppColors.danger,
          );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.cardPadSm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.style(15, AppText.w800, color: color)),
          const SizedBox(height: 4),
          Text(
            body,
            style: AppText.style(12, AppText.w500, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
