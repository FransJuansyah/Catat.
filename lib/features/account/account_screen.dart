import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/list_card.dart';
import '../../data/auto_capture.dart';
import '../../data/providers.dart';
import '../../domain/home_summary.dart';
import '../../domain/types.dart';

/// Layar 17 · Akun. Login, Keamanan & Keluar menyusul di F8.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  late final AppLifecycleListener _lifecycle;

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

  Future<void> _setAuto(AutoStatus status, bool on) async {
    final bridge = ref.read(autoCaptureProvider);
    if (!on) {
      await bridge.setEnabled(false);
      ref.invalidate(autoStatusProvider);
      return;
    }
    // Penjelasan wajib sebelum minta akses notifikasi (kebijakan Play).
    final ok = await showConfirmSheet(
      context,
      title: 'Catat otomatis dari notifikasi',
      message:
          'Tiap ada notifikasi transaksi dari m-banking & e-wallet, atau SMS '
          'dan email dari bank, catat. langsung nyatet di belakang layar. '
          'Salah? Tinggal Batalkan dari notifnya. Chat (WhatsApp, dll.) & '
          'notifikasi lain nggak dibaca. Semua diproses di HP ini.\n\n'
          'Habis ini, nyalain izin "Akses notifikasi" buat catat.',
      confirmLabel: 'Buka pengaturan',
    );
    if (!ok) return;
    await bridge.requestNotifications();
    final next = await bridge.setEnabled(true);
    if (!next.listenerAccess) await bridge.openAccessSettings();
    ref.invalidate(autoStatusProvider);
  }

  Future<void> _setReminder(bool on) async {
    final bridge = ref.read(autoCaptureProvider);
    if (on) await bridge.requestNotifications();
    await bridge.setReminder(on);
    ref.invalidate(autoStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeSummaryProvider).value;
    final status = ref.watch(autoStatusProvider).value ?? const AutoStatus();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.screenX,
          8,
          AppSpace.screenX,
          24,
        ),
        children: [
          Text(
            'Akun',
            style: AppText.style(26, AppText.w800, spacingPercent: -3),
          ),
          const SizedBox(height: 16),
          _ProfileCard(name: home?.userName ?? ''),
          const SizedBox(height: AppSpace.section),
          _label('Keuangan'),
          ListCard(
            children: [
              if (home != null) _incomeRow(context, home),
              _Row(
                icon: LucideIcons.chartPie,
                title: 'Atur ${home?.pockets.length ?? 3} kantong',
                subtitle: home == null ? null : _pocketSplit(home),
                onTap: () => context.push('/kantong'),
              ),
              _Row(
                icon: LucideIcons.download,
                title: 'Export laporan',
                subtitle: 'PDF / Excel',
                onTap: () => context.push('/export'),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.section),
          _label('Aplikasi'),
          ListCard(
            children: [
              _Row(
                icon: LucideIcons.bell,
                title: 'Pengingat harian',
                subtitle:
                    'Tiap jam ${status.reminderHour.toString().padLeft(2, '0')}:00',
                trailing: AppToggle(
                  value: status.reminder,
                  onChanged: _setReminder,
                ),
              ),
              _Row(
                icon: LucideIcons.bellRing,
                title: 'Catat otomatis',
                subtitle: !status.enabled || status.active
                    ? 'Dari m-banking, SMS & email'
                    : 'Izin belum nyala, ketuk buat atur',
                subtitleColor: status.enabled && !status.active
                    ? AppColors.danger
                    : null,
                onTap: status.enabled && !status.active
                    ? () => _setAuto(status, true)
                    : null,
                trailing: AppToggle(
                  value: status.enabled,
                  onChanged: (on) => _setAuto(status, on),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _incomeRow(BuildContext context, HomeSummary home) {
    final (title, subtitle, route) = switch (home.mode) {
      IncomeMode.salary => (
        'Gaji & slip gaji',
        rupiahShort(home.salary),
        '/gajian-masuk',
      ),
      IncomeMode.allowance => (
        'Uang jajan',
        '${rupiahShort(home.salary)} / ${home.perNoun}',
        '/gajian-masuk',
      ),
      IncomeMode.irregular => (
        'Pemasukan',
        'Penghasilan tidak tetap',
        '/pemasukan',
      ),
    };
    return _Row(
      icon: LucideIcons.wallet,
      title: title,
      subtitle: subtitle,
      onTap: () => context.push(route),
    );
  }

  String _pocketSplit(HomeSummary home) => home.pockets
      .map(
        (p) => p.mode == AllocationMode.percent
            ? '${p.percent}%'
            : rupiahShort(p.balance.allocation),
      )
      .join(' · ');

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: AppText.style(13, AppText.w700, color: AppColors.muted),
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final shown = name.trim().isEmpty ? 'Kamu' : name.trim();
    return Container(
      padding: const EdgeInsets.all(AppSpace.cardPad),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.lime,
              shape: BoxShape.circle,
            ),
            child: Text(
              shown.characters.first.toUpperCase(),
              style: AppText.style(22, AppText.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              shown,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.style(18, AppText.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris kartu Akun: ikon kotak abu, judul, keterangan, chevron / toggle.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
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
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppText.style(
                        13,
                        AppText.w500,
                        color: subtitleColor ?? AppColors.muted,
                      ),
                    ),
                  ],
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
