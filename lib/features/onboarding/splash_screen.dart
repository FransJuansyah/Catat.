import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../data/providers.dart';

/// Layar 00 · Splash. Menentukan tujuan: Beranda (sudah setup) atau onboarding.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void initState() {
    super.initState();
    unawaited(_route());
  }

  Future<void> _route() async {
    final (setUp, _) = await (
      ref.read(budgetRepositoryProvider).isSetUp(),
      Future<void>.delayed(const Duration(milliseconds: 1100)),
    ).wait;
    if (mounted) context.go(setUp ? '/beranda' : '/masuk');
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(31),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x59D4FF4F),
                      offset: Offset(0, 12),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.wallet,
                  size: 46,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'catat.',
                style: AppText.style(
                  44,
                  AppText.w800,
                  color: Colors.white,
                  spacingPercent: -4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Duit gajian, kebagi rapi.',
                style: AppText.style(15, AppText.w500, color: AppColors.faint),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _dots,
                builder: (context, _) {
                  final active = (_dots.value * 3).floor() % 3;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == active ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == active
                                ? AppColors.lime
                                : const Color(0xFF3A3A40),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
