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
import '../../data/auto_capture.dart';
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

  AutoCaptureBridge get _bridge => ref.read(autoCaptureProvider);

  @override
  void initState() {
    super.initState();
    // Kembali dari Pengaturan Android → cek izin lagi.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(autoStatusProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  static bool isOn(PrivacyItem item, AutoStatus s) => switch (item) {
    PrivacyItem.camera => s.cameraGranted,
    PrivacyItem.notifications => s.reminder && s.canNotify,
    _ => s.sources.contains(item.source),
  };

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } finally {
      ref.invalidate(autoStatusProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// Catat otomatis = fitur Pro: trial habis & belum beli → layar 53.
  Future<bool> _proUnlocked() async {
    final status = await ref.read(proRepositoryProvider).status();
    if (status.unlocked) return true;
    if (mounted) await context.push('/pro');
    return false;
  }

  /// Sumber catat otomatis: selalu jelaskan dulu (sheet ⓘ), baru minta izin.
  Future<void> _enableSources(
    List<PrivacyItem> items,
    AutoStatus status,
  ) async {
    await _bridge.requestNotifications();
    for (final item in items) {
      await _bridge.setSource(item.source!, true);
    }
    if (!status.listenerAccess) await _bridge.openAccessSettings();
  }

  Future<void> _toggle(
    PrivacyItem item,
    bool on,
    AutoStatus status,
  ) => _run(() async {
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
      default:
        if (!on) {
          await _bridge.setSource(item.source!, false);
        } else if (!await _proUnlocked()) {
          return;
        } else if (mounted && await showPrivacyInfo(context, item, on: false)) {
          await _enableSources([item], status);
        }
    }
  });

  Future<void> _enableRecommended(AutoStatus status) => _run(() async {
    if (!await _proUnlocked() || !mounted) return;
    if (!await showPrivacyInfo(context, PrivacyItem.financeApp, on: false)) {
      return;
    }
    await _bridge.requestCamera();
    await _bridge.setReminder(true);
    await _enableSources([PrivacyItem.financeApp], status);
  });

  Future<void> _info(PrivacyItem item, AutoStatus status) async {
    final on = isOn(item, status);
    if (await showPrivacyInfo(context, item, on: on) && !on) {
      await _toggle(item, true, status);
    }
  }

  void _continue() {
    ref.read(appReadyProvider.notifier).markReady();
    context.go(widget.next ?? '/beranda');
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(autoStatusProvider).value ?? const AutoStatus();

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
                subtitle: widget.onboarding || item.source == null
                    ? item.description
                    : (isOn(item, status) ? 'Aktif' : 'Mati'),
                onInfo: () => _info(item, status),
                onChanged: _busy ? null : (on) => _toggle(item, on, status),
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
                    group('Catat otomatis', PrivacyItem.autoCapture),
                    if (status.needsAccess) ...[
                      const SizedBox(height: AppSpace.sectionTight),
                      _AccessWarning(onTap: _bridge.openAccessSettings),
                    ],
                    const SizedBox(height: AppSpace.sectionTight),
                    group('Fitur lain', PrivacyItem.others),
                    const SizedBox(height: AppSpace.sectionTight),
                    const _NeverCard(),
                    if (widget.onboarding) ...[
                      const Spacer(),
                      const SizedBox(height: AppSpace.sectionTight),
                      Center(
                        child: TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _enableRecommended(status),
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

class _AccessWarning extends StatelessWidget {
  const _AccessWarning({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warnBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(
                LucideIcons.triangleAlert,
                size: 18,
                color: AppColors.warnIcon,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Izin "Akses notifikasi" Android belum nyala. Ketuk buat '
                  'atur.',
                  style: AppText.style(
                    13,
                    AppText.w700,
                    color: AppColors.warnText,
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
              'Nggak pernah diakses: chat (WhatsApp dll.), kontak, lokasi, '
              'mikrofon. Data tersimpan di HP ini aja.',
              style: AppText.style(12, AppText.w500, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
