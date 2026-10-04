import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/celebration.dart';

/// Layar 54 · Pro kebuka! (animasi perayaan seperti layar 10).
class ProUnlockedScreen extends StatefulWidget {
  const ProUnlockedScreen({super.key});

  @override
  State<ProUnlockedScreen> createState() => _ProUnlockedScreenState();
}

class _ProUnlockedScreenState extends State<ProUnlockedScreen> {
  final _badge = GlobalKey();

  static const _confetti = <ConfettiPiece>[
    (0.10, 0.18, 14.0, 6.0, 0.35, Color(0xFF6D5DFC)),
    (0.82, 0.15, 10.0, 10.0, 0.8, Color(0xFFFF4F7B)),
    (0.20, 0.36, 8.0, 8.0, 0.0, AppColors.ink),
    (0.77, 0.33, 16.0, 6.0, -0.5, Color(0xFF12A36B)),
    (0.49, 0.13, 6.0, 14.0, 0.26, AppColors.ink),
    (0.87, 0.45, 8.0, 8.0, 0.0, Color(0xFF6D5DFC)),
    (0.08, 0.50, 12.0, 6.0, 1.05, Color(0xFFFF4F7B)),
  ];

  void _done() => context.canPop() ? context.pop() : context.go('/beranda');

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.lime,
        body: Stack(
          children: [
            ConfettiLayer(pieces: _confetti, originKey: _badge),
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
                    PopIn(
                      key: _badge,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          color: AppColors.ink,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.sparkles,
                          size: 46,
                          color: AppColors.lime,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Appear(
                      delay: Appear.step(0),
                      child: Text(
                        'Pro kebuka!',
                        style: AppText.style(
                          40,
                          AppText.w800,
                          spacingPercent: -4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Appear(
                      delay: Appear.step(1),
                      child: Text(
                        'Scan struk otomatis & export bisa kamu pakai selamanya.',
                        textAlign: TextAlign.center,
                        style: AppText.style(
                          15,
                          AppText.w700,
                          color: AppColors.limeText,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Appear(
                      delay: Appear.step(3),
                      child: AppButton(label: 'Mantap', onPressed: _done),
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
