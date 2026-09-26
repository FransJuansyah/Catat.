import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/amount_keypad.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/icon_badge.dart';
import '../../data/providers.dart';
import '../../domain/types.dart';
import '../../domain/views.dart';

/// Layar 18 · Gajian Masuk. Muncul sekali tiap periode gaji baru.
/// Jika "Tambah otomatis" mati, user diminta mengisi gaji bulan ini dulu.
class PaydayScreen extends ConsumerStatefulWidget {
  const PaydayScreen({super.key});

  @override
  ConsumerState<PaydayScreen> createState() => _PaydayScreenState();
}

class _PaydayScreenState extends ConsumerState<PaydayScreen> {
  bool _busy = false;

  static const _confetti = [
    (0.10, 0.16, 14.0, 6.0, 0.35, Color(0xFF6D5DFC)),
    (0.82, 0.14, 10.0, 10.0, 0.8, Color(0xFFFF4F7B)),
    (0.18, 0.36, 8.0, 8.0, 0.0, AppColors.lime),
    (0.80, 0.31, 16.0, 6.0, -0.5, Color(0xFF12A36B)),
    (0.49, 0.12, 6.0, 14.0, 0.26, AppColors.lime),
    (0.88, 0.43, 8.0, 8.0, 0.0, Color(0xFF6D5DFC)),
    (0.06, 0.47, 12.0, 6.0, 1.05, Color(0xFFFF4F7B)),
  ];

  Future<void> _continue(PaydayInfo info) async {
    setState(() => _busy = true);
    await ref.read(budgetRepositoryProvider).markCelebrated(info.periodId);
    if (mounted) context.go('/beranda');
  }

  Future<void> _fillSalary(PaydayInfo info) async {
    final value = await showAmountSheet(
      context,
      title: info.mode == IncomeMode.allowance
          ? 'Uang jajan kali ini'
          : 'Gaji bulan ini',
      confirmLabel: 'Masukin gaji',
    );
    if (value == null) return;
    await ref
        .read(budgetRepositoryProvider)
        .setPeriodSalary(info.periodId, value);
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(paydayProvider).value;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.ink,
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
              if (info != null)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.screenX,
                      8,
                      AppSpace.screenX,
                      16,
                    ),
                    child: info.needsSalary
                        ? _askSalary(info)
                        : _celebrate(info),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(PaydayInfo info) => Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.calendar, size: 14, color: AppColors.lime),
            const SizedBox(width: 6),
            Text(
              fullDate(info.start),
              style: AppText.style(12, AppText.w700, color: Colors.white),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const IconBadge(
        icon: LucideIcons.wallet,
        background: AppColors.lime,
        color: AppColors.ink,
        size: 80,
        iconSize: 38,
        square: true,
      ),
      const SizedBox(height: 20),
    ],
  );

  Widget _celebrate(PaydayInfo info) => Column(
    children: [
      const Spacer(),
      _header(info),
      Text(
        info.mode == IncomeMode.allowance
            ? 'Uang jajan masuk!'
            : 'Gajian masuk!',
        style: AppText.style(
          32,
          AppText.w800,
          color: Colors.white,
          spacingPercent: -3,
        ),
      ),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '+${rupiah(info.salary)}',
          style: AppText.style(
            40,
            AppText.w800,
            color: AppColors.lime,
            spacingPercent: -3,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Otomatis dibagi ke ${info.allocations.length} kantong',
        style: AppText.style(14, AppText.w500, color: AppColors.faint),
      ),
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(AppRadius.cardLg),
        ),
        child: Column(
          children: [
            for (final (i, (pocket, amount)) in info.allocations.indexed) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFF3A3A40),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    IconBadge(
                      icon: PocketVisuals.icon(pocket.iconKey),
                      background: PocketVisuals.soft(Color(pocket.color)),
                      color: Color(pocket.color),
                      size: 36,
                      iconSize: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        pocket.name,
                        style: AppText.style(
                          15,
                          AppText.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      rupiah(amount),
                      style: AppText.style(
                        15,
                        AppText.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      const Spacer(),
      AppButton(
        label: 'Mantap, lanjut',
        loading: _busy,
        style: AppButtonStyle.lime,
        onPressed: () => _continue(info),
      ),
    ],
  );

  Widget _askSalary(PaydayInfo info) => Column(
    children: [
      const Spacer(),
      _header(info),
      Text(
        info.mode == IncomeMode.allowance
            ? 'Uang jajan udah masuk?'
            : 'Gajian udah masuk?',
        style: AppText.style(
          32,
          AppText.w800,
          color: Colors.white,
          spacingPercent: -3,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Isi gaji bulan ini, nanti langsung\ndibagi ke ${info.allocations.length} kantong.',
        textAlign: TextAlign.center,
        style: AppText.style(14, AppText.w500, color: AppColors.faint),
      ),
      const Spacer(),
      AppButton(
        label: info.mode == IncomeMode.allowance
            ? 'Isi uang jajan'
            : 'Isi gaji bulan ini',
        style: AppButtonStyle.lime,
        onPressed: () => _fillSalary(info),
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: () => context.go('/beranda'),
        child: Text(
          'Nanti aja',
          style: AppText.style(14, AppText.w700, color: AppColors.faint),
        ),
      ),
    ],
  );
}
