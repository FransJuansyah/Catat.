import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/icon_badge.dart';
import '../../data/account.dart';

/// Layar 01 · Masuk / Daftar.
///
/// Email → layar 47 (akun Supabase, F8). Login Google menyusul. Tanpa kunci
/// Supabase (build lokal) semua tombol langsung ke pengaturan gaji, data di HP.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void start() => context.push('/sumber-uang');
    void email() => cloudEnabled ? context.push('/masuk-email') : start();
    void google() {
      if (!cloudEnabled) return start();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Masuk pakai Google segera hadir. Pakai email dulu ya.',
          ),
        ),
      );
    }

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
                    Row(
                      children: [
                        const IconBadge(
                          icon: LucideIcons.wallet,
                          background: AppColors.ink,
                          color: AppColors.lime,
                          size: 34,
                          iconSize: 18,
                          square: true,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'catat.',
                          style: AppText.style(
                            20,
                            AppText.w800,
                            spacingPercent: -2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Duit masuk,\nlangsung kebagi.',
                      style: AppText.style(
                        34,
                        AppText.w800,
                        spacingPercent: -3,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Gaji bulanan, uang jajan, atau hasil kerja harian. Semua otomatis kebagi ke 3 kantong.',
                      style: AppText.style(
                        15,
                        AppText.w500,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const _SalarySplitIllustration(),
                    const Spacer(),
                    const SizedBox(height: 24),
                    _GoogleButton(onPressed: google),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Daftar pakai Email',
                      icon: LucideIcons.mail,
                      onPressed: email,
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: GestureDetector(
                        onTap: email,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Sudah punya akun? ',
                                style: AppText.style(
                                  13,
                                  AppText.w500,
                                  color: AppColors.muted,
                                ),
                              ),
                              TextSpan(
                                text: 'Masuk',
                                style: AppText.style(13, AppText.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
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

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSize.buttonHeight,
      width: double.infinity,
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          side: const BorderSide(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'G',
                style: AppText.style(
                  18,
                  AppText.w800,
                  color: const Color(0xFF4285F4),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Lanjut dengan Google',
                    maxLines: 1,
                    style: AppText.style(16, AppText.w700),
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

/// Ilustrasi "Gajian masuk → otomatis kebagi ke 3 kantong" (desain 350×262).
class _SalarySplitIllustration extends StatelessWidget {
  const _SalarySplitIllustration();

  static const _tiles = [
    (LucideIcons.house, '50%', 'Wajib', Color(0xFF6D5DFC)),
    (LucideIcons.shield, '20%', 'Darurat', Color(0xFF12A36B)),
    (LucideIcons.sparkles, '30%', 'Keinginan', Color(0xFFFF4F7B)),
  ];

  @override
  Widget build(BuildContext context) {
    // Digambar di ukuran desain lalu diperkecil utuh (FittedBox) di layar
    // sempit: isi kotak kantong tidak terpotong. Hiasan → abaikan setelan
    // huruf besar.
    const w = 350.0;
    const cardH = 68.0;
    const lineH = 60.0;
    const tileW = 108.0;
    const tileH = 262 - cardH - lineH;
    return MediaQuery.withNoTextScaling(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: w,
            height: cardH + lineH + tileH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: cardH,
                  left: 0,
                  right: 0,
                  height: lineH,
                  child: CustomPaint(
                    painter: _FlowLinesPainter(tileCenters: [57, 175, 293]),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: cardH,
                    padding: const EdgeInsets.fromLTRB(14, 10, 20, 10),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x2E0E0E10),
                          offset: Offset(0, 10),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const IconBadge(
                          icon: LucideIcons.wallet,
                          background: AppColors.lime,
                          color: AppColors.ink,
                          size: 40,
                          iconSize: 20,
                          square: true,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Duit masuk',
                              style: AppText.style(
                                12,
                                AppText.w500,
                                color: AppColors.faint,
                              ),
                            ),
                            Text(
                              '+Rp 6.500.000',
                              style: AppText.style(
                                20,
                                AppText.w800,
                                color: Colors.white,
                                spacingPercent: -2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: -12,
                  right: w * 0.12,
                  child: Transform.rotate(
                    angle: -6 * math.pi / 180,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lime,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F0E0E10),
                            offset: Offset(0, 4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.check,
                            size: 12,
                            color: AppColors.ink,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Otomatis',
                            style: AppText.style(11, AppText.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                for (final (i, (icon, pct, name, color)) in _tiles.indexed)
                  Positioned(
                    top: cardH + lineH,
                    left: [3.0, 121.0, 239.0][i],
                    width: tileW,
                    height: tileH,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PocketVisuals.soft(color),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconBadge(
                            icon: icon,
                            background: Colors.white,
                            color: color,
                            size: 34,
                            iconSize: 17,
                          ),
                          const Spacer(),
                          Text(
                            pct,
                            style: AppText.style(
                              24,
                              AppText.w800,
                              color: color,
                              spacingPercent: -3,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              name,
                              style: AppText.style(13, AppText.w800),
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
      ),
    );
  }
}

/// Tiga garis titik-titik bercabang dari kartu gaji ke tiap kantong.
class _FlowLinesPainter extends CustomPainter {
  _FlowLinesPainter({required this.tileCenters});

  final List<double> tileCenters;
  static const _colors = [
    Color(0xFF6D5DFC),
    Color(0xFF12A36B),
    Color(0xFFFF4F7B),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    for (final (i, x) in tileCenters.indexed) {
      final path = Path()
        ..moveTo(cx, 4)
        ..cubicTo(
          cx,
          size.height * 0.55,
          x,
          size.height * 0.45,
          x,
          size.height - 4,
        );
      final paint = Paint()
        ..color = _colors[i]
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 8) {
          canvas.drawPath(metric.extractPath(d, d + 0.1), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlowLinesPainter old) =>
      old.tileCenters != tileCenters;
}
