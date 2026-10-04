import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/list_card.dart';
import '../../data/device_bridge.dart';
import '../../data/providers.dart';
import 'privacy_info_sheet.dart';
import 'privacy_items.dart';

/// Layar 35 (onboarding, langkah terakhir) & 37 (Akun → Privasi & Izin).
/// Semua mati sampai user menyalakan sendiri; pop-up izin Android baru muncul
/// saat item dinyalakan.
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key, this.onboarding = false, this.next});

  final bool onboarding;

  /// Tujuan tombol "Lanjut" (onboarding).
  final String? next;

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _busy = false;

  DeviceBridge get _bridge => ref.read(deviceBridgeProvider);

  @override
  void initState() {
    super.initState();
    // Kembali dari Pengaturan Android → cek izin lagi.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(deviceStatusProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  static bool isOn(PrivacyItem item, DeviceStatus s) => switch (item) {
    PrivacyItem.camera => s.cameraGranted,
    PrivacyItem.notifications => s.reminder && s.canNotify,
  };

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } finally {
      ref.invalidate(deviceStatusProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _toggle(PrivacyItem item, bool on) => _run(() async {
    switch (item) {
      case PrivacyItem.camera:
        if (on) {
          if (!await _bridge.requestCamera() && mounted) {
            _toast('Izin kamera ditolak. Nyalakan dari pengaturan aplikasi.');
          }
        } else {
          // Izin Android cuma bisa dicabut dari pengaturan aplikasi.
          if (mounted) _toast('Matikan izin Kamera di pengaturan aplikasi.');
          await _bridge.openAppSettings();
        }
      case PrivacyItem.notifications:
        if (on) await _bridge.requestNotifications();
        await _bridge.setReminder(on);
    }
  });

  /// "Nyalakan yang disarankan": kamera & pengingat.
  Future<void> _enableRecommended() => _run(() async {
    await _bridge.requestCamera();
    await _bridge.requestNotifications();
    await _bridge.setReminder(true);
  });

  Future<void> _info(PrivacyItem item, DeviceStatus status) async {
    final on = isOn(item, status);
    if (await showPrivacyInfo(context, item, on: on) && !on) {
      await _toggle(item, true);
    }
  }

  void _continue() {
    ref.read(appReadyProvider.notifier).markReady();
    context.go(widget.next ?? '/beranda');
  }

  @override
  Widget build(BuildContext context) {
    final status =
        ref.watch(deviceStatusProvider).value ?? const DeviceStatus();

    Widget group(String label, List<PrivacyItem> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: AppText.style(13, AppText.w700, color: AppColors.muted),
          ),
        ),
        ListCard(
          children: [
            for (final item in items)
              _PrivacyRow(
                item: item,
                on: isOn(item, status),
                subtitle: item.description,
                onInfo: () => _info(item, status),
                onChanged: _busy ? null : (on) => _toggle(item, on),
              ),
          ],
        ),
      ],
    );

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
                    if (widget.onboarding) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Atur privasi kamu',
                        style: AppText.style(
                          26,
                          AppText.w800,
                          spacingPercent: -3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Kamu yang pilih. Semua mati dulu, nyalain yang kamu '
                        'mau. Bisa diubah kapan aja di Akun.',
                        style: AppText.style(
                          13,
                          AppText.w500,
                          color: AppColors.muted,
                        ),
                      ),
                    ] else
                      const AppTopBar(title: 'Privasi & Izin'),
                    const SizedBox(height: AppSpace.sectionTight),
                    group('Izin', PrivacyItem.values),
                    const SizedBox(height: AppSpace.sectionTight),
                    const _NeverCard(),
                    if (widget.onboarding) ...[
                      const Spacer(),
                      const SizedBox(height: AppSpace.sectionTight),
                      Center(
                        child: TextButton.icon(
                          onPressed: _busy ? null : _enableRecommended,
                          icon: const Icon(
                            LucideIcons.check,
                            size: 16,
                            color: AppColors.ink,
                          ),
                          label: Text(
                            'Nyalakan yang disarankan',
                            style: AppText.style(14, AppText.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppButton(label: 'Lanjut', onPressed: _continue),
                    ],
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

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({
    required this.item,
    required this.on,
    required this.subtitle,
    required this.onInfo,
    required this.onChanged,
  });

  final PrivacyItem item;
  final bool on;
  final String subtitle;
  final VoidCallback onInfo;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          IconBadge(
            icon: item.icon,
            background: AppColors.track,
            color: AppColors.ink,
            size: 40,
            iconSize: 19,
            square: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.title,
                        style: AppText.style(15, AppText.w800),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Semantics(
                      button: true,
                      label: 'Kenapa ${item.title}?',
                      child: InkResponse(
                        onTap: onInfo,
                        radius: 18,
                        child: const Icon(
                          LucideIcons.info,
                          size: 16,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppText.style(
                    12,
                    AppText.w500,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppToggle(value: on, onChanged: onChanged ?? (_) {}),
        ],
      ),
    );
  }
}

class _NeverCard extends StatelessWidget {
  const _NeverCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.track,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.lock, size: 18, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nggak pernah diakses: notifikasi aplikasi lain, SMS, chat, '
              'kontak, lokasi, mikrofon. Data tersimpan di HP ini aja.',
              style: AppText.style(12, AppText.w500, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
