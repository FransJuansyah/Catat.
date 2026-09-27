import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/list_card.dart';
import '../../data/app_lock.dart';
import '../../data/providers.dart';
import 'lock_screen.dart';

/// Layar 56 · Keamanan: PIN, sidik jari, kapan dikunci.
class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  Future<void> _togglePin(BuildContext context, WidgetRef ref, bool on) async {
    if (!on) {
      await context.push('/pin?mode=off');
      return;
    }
    final signedIn = ref.read(accountProvider).signedIn;
    if (!canUsePin(signedIn: signedIn)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Masuk akun dulu ya, biar bisa reset PIN kalau lupa.',
          ),
          action: SnackBarAction(
            label: 'Masuk',
            onPressed: () => context.push('/masuk-email?dari=akun'),
          ),
        ),
      );
      return;
    }
    await context.push('/pin?mode=create');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(lockStateProvider).value ?? const AppLockState();
    final app = ref.read(appLockProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screenX,
            8,
            AppSpace.screenX,
            24,
          ),
          children: [
            const AppTopBar(title: 'Keamanan'),
            const SizedBox(height: 16),
            ListCard(
              children: [
                _Row(
                  icon: LucideIcons.lock,
                  title: 'Kunci pakai PIN',
                  subtitle: 'Diminta tiap buka catat.',
                  trailing: AppToggle(
                    value: lock.enabled,
                    onChanged: (on) => _togglePin(context, ref, on),
                  ),
                ),
                if (lock.enabled && lock.biometricAvailable)
                  _Row(
                    icon: LucideIcons.fingerprint,
                    title: 'Buka pakai sidik jari',
                    subtitle: 'Lebih cepat dari ngetik PIN',
                    trailing: AppToggle(
                      value: lock.biometric,
                      onChanged: app.setBiometric,
                    ),
                  ),
                if (lock.enabled)
                  _Row(
                    icon: LucideIcons.keyRound,
                    title: 'Ganti PIN',
                    onTap: () => context.push('/pin?mode=change'),
                  ),
              ],
            ),
            if (lock.enabled) ...[
              const SizedBox(height: AppSpace.section),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Kunci setelah keluar dari app',
                  style: AppText.style(
                    13,
                    AppText.w700,
                    color: AppColors.muted,
                  ),
                ),
              ),
              SegmentedTabs<LockDelay>(
                items: [for (final d in LockDelay.values) (d, d.label)],
                value: lock.delay,
                onChanged: app.setDelay,
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEEEBFF),
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.info,
                    size: 18,
                    color: Color(0xFF6D5DFC),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Lupa PIN? Masuk lagi pakai email akunmu, lalu bikin PIN baru. Datamu nggak hilang.',
                      style: AppText.style(
                        13,
                        AppText.w700,
                        color: const Color(0xFF4B3FD1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.rowY),
        child: Row(
          children: [
            IconBadge(
              icon: icon,
              background: AppColors.track,
              color: AppColors.ink,
              size: AppSize.badge,
              iconSize: 20,
              square: true,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.style(16, AppText.w800)),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppText.style(
                        13,
                        AppText.w500,
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                const Icon(
                  LucideIcons.chevronRight,
                  size: 20,
                  color: AppColors.faint,
                ),
          ],
        ),
      ),
    );
  }
}
