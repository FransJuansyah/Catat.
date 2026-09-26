import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/icon_badge.dart';
import '../../data/providers.dart';
import '../../domain/payslip_parser.dart';

const _steps = ['Upload berhasil', 'Baca nominal gaji', 'Cek tanggal gajian'];

/// Layar 08 · Loading: Baca Slip Gaji. Selesai → kembali ke 02 membawa
/// [PayslipData] (bisa kosong kalau slip tidak kebaca).
class PayslipReadingScreen extends ConsumerStatefulWidget {
  const PayslipReadingScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  ConsumerState<PayslipReadingScreen> createState() =>
      _PayslipReadingScreenState();
}

class _PayslipReadingScreenState extends ConsumerState<PayslipReadingScreen> {
  /// Jumlah langkah yang sudah selesai (0–3).
  int _done = 0;
  PayslipData? _slip;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  /// Tiap langkah minimal sebentar supaya progresnya kebaca mata.
  Future<T> _step<T>(Future<T> work) async {
    final results = await Future.wait([
      work,
      Future<void>.delayed(const Duration(milliseconds: 650)),
    ]);
    if (mounted) setState(() => _done++);
    return results.first as T;
  }

  Future<void> _run() async {
    final reader = ref.read(payslipReaderProvider);
    await _step(Future<void>.value());
    PayslipData slip;
    try {
      slip = await _step(reader.read(widget.imagePath));
    } on Object {
      // OCR gagal (foto rusak dll.) → user isi manual.
      slip = const PayslipData();
      if (mounted) setState(() => _done++);
    }
    if (mounted) setState(() => _slip = slip);
    await _step(Future<void>.value());
    if (mounted) context.pop(slip);
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenX),
            child: Column(
              children: [
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: _SlipMock(
                    label: 'SLIP GAJI · ${monthYear(now).toUpperCase()}',
                    amount: _slip == null ? null : _slip!.netSalary ?? 0,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Lagi baca slip gajimu…',
                  textAlign: TextAlign.center,
                  style: AppText.style(26, AppText.w800, spacingPercent: -3),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bentar ya, cuma beberapa detik',
                  style: AppText.style(
                    14,
                    AppText.w500,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 28),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (_done + 0.5) / (_steps.length + 0.5)),
                    duration: const Duration(milliseconds: 500),
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 10,
                      color: AppColors.ink,
                      backgroundColor: AppColors.line,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                for (final (i, label) in _steps.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _StepRow(
                      label: label,
                      done: i < _done,
                      active: i == _done,
                    ),
                  ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ilustrasi slip: baris abu + sorotan "Gaji bersih". Nominal muncul
/// setelah terbaca ([amount] null = belum, 0 = tidak kebaca).
class _SlipMock extends StatelessWidget {
  const _SlipMock({required this.label, required this.amount});

  final String label;
  final int? amount;

  static final _number = NumberFormat.decimalPattern('id_ID');

  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widthFactor,
        child: Container(
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.track,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
    );

    final value = switch (amount) {
      null => '···',
      0 => '–',
      final v => _number.format(v),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const IconBadge(
                icon: LucideIcons.fileText,
                background: AppColors.track,
                color: AppColors.ink,
                size: AppSize.badgeSm,
                iconSize: 16,
                square: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.style(13, AppText.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          bar(0.75),
          bar(0.58),
          bar(0.84),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.lime.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.segment),
              border: Border.all(color: AppColors.lime, width: 1.5),
            ),
            child: Row(
              children: [
                Text('Gaji bersih', style: AppText.style(12, AppText.w700)),
                const Spacer(),
                Text(value, style: AppText.style(14, AppText.w800)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          bar(0.5),
          bar(0.66),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.done,
    required this.active,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: done
              ? Container(
                  decoration: const BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.check,
                    size: 16,
                    color: AppColors.lime,
                  ),
                )
              : active
              ? const CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.ink,
                  backgroundColor: AppColors.line,
                )
              : Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line, width: 3),
                  ),
                ),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: AppText.style(
            16,
            AppText.w700,
            color: done || active ? AppColors.ink : AppColors.faint,
          ),
        ),
      ],
    );
  }
}
