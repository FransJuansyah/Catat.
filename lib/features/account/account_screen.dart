import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/list_card.dart';
import '../../data/account.dart';
import '../../data/app_lock.dart';
import '../../data/device_bridge.dart';
import '../../data/providers.dart';
import '../../domain/home_summary.dart';
import '../../domain/pro.dart';
import '../../domain/types.dart';
import '../pro/pro_screen.dart';
import 'account_sheets.dart';

/// Layar 17 / 38 · Akun. 49 = sudah masuk (status sinkron, hapus akun,
/// keluar), 50 = belum masuk (ajakan simpan ke akun). PIN menyusul.
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
      onResume: () => ref.invalidate(deviceStatusProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _editName(String current) async {
    final controller = TextEditingController(text: current);
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(sheet).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nama kamu', style: AppText.style(20, AppText.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
              style: AppText.style(16, AppText.w700),
              decoration: const InputDecoration(hintText: 'Mis. Frans'),
              onSubmitted: (v) => Navigator.pop(sheet, v),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Simpan',
              onPressed: () => Navigator.pop(sheet, controller.text),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await ref.read(budgetRepositoryProvider).setUserName(name);
  }

  Future<void> _setReminder(bool on) async {
    final bridge = ref.read(deviceBridgeProvider);
    if (on) await bridge.requestNotifications();
    await bridge.setReminder(on);
    ref.invalidate(deviceStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeSummaryProvider).value;
    final status =
        ref.watch(deviceStatusProvider).value ?? const DeviceStatus();
    final account = ref.watch(accountProvider);
    final pro = ref.watch(proStatusProvider).value;
    final lock = ref.watch(lockStateProvider).value ?? const AppLockState();

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
          if (cloudEnabled && !account.signedIn)
            _SaveToAccountCard(
              onTap: () => context.push('/masuk-email?dari=akun'),
            )
          else
            _ProfileCard(
              name: home?.userName ?? '',
              email: account.email,
              onTap: () => _editName(home?.userName ?? ''),
            ),
          if (pro != null && (pro.purchased || pro.trialStart != null)) ...[
            const SizedBox(height: 12),
            _ProCard(
              status: pro,
              price: ref.watch(proProvider).price ?? proPriceFallback,
              onTap: pro.purchased ? null : () => context.push('/pro'),
            ),
          ],
          const SizedBox(height: AppSpace.section),
          _label('Keuangan'),
          ListCard(
            children: [
              if (home != null) _incomeRow(context, home),
              _Row(
                icon: LucideIcons.scale,
                title: 'Sesuaikan saldo',
                subtitle: 'Samain sama uang aslimu',
                onTap: () => context.push('/sesuaikan-saldo'),
              ),
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
              // Layar 38: kamera & notifikasi di satu tempat.
              _Row(
                icon: LucideIcons.shieldCheck,
                title: 'Privasi & izin',
                subtitle: 'Kamera & notifikasi',
                onTap: () => context.push('/privasi'),
              ),
              _Row(
                icon: LucideIcons.lock,
                title: 'Keamanan',
                subtitle: switch (lock) {
                  AppLockState(enabled: false) => 'PIN & sidik jari',
                  AppLockState(biometric: true) => 'PIN · sidik jari aktif',
                  _ => 'PIN aktif',
                },
                onTap: () => context.push('/keamanan'),
              ),
            ],
          ),
          if (account.signedIn) ...[
            const SizedBox(height: AppSpace.section),
            _label('Akun'),
            ListCard(
              children: [
                _Row(
                  icon: LucideIcons.cloudCheck,
                  title: 'Tersimpan di akun',
                  subtitle: _syncText(account),
                  subtitleColor: account.failed ? AppColors.danger : null,
                  trailing: account.syncing
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.ink,
                          ),
                        )
                      : IconBadge(
                          icon: account.failed
                              ? LucideIcons.cloudOff
                              : LucideIcons.check,
                          background: account.failed
                              ? AppColors.dangerSoft
                              : AppColors.lime,
                          color: account.failed
                              ? AppColors.danger
                              : AppColors.ink,
                          size: 24,
                          iconSize: 14,
                        ),
                  onTap: () => ref.read(accountProvider.notifier).syncNow(),
                ),
                _Row(
                  icon: LucideIcons.trash2,
                  iconColor: AppColors.danger,
                  iconBackground: AppColors.dangerSoft,
                  title: 'Hapus akun & data',
                  titleColor: AppColors.danger,
                  subtitle: 'Hapus permanen dari akun & HP ini',
                  onTap: _deleteAccount,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Material(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.card),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _signOut,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.logOut,
                        size: 22,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Keluar',
                        style: AppText.style(
                          16,
                          AppText.w800,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _syncText(AccountState a) {
    if (a.syncing) return 'Lagi sinkron…';
    if (a.failed) return 'Belum tersinkron, dicoba lagi otomatis';
    final last = a.lastSync;
    if (last == null) return 'Belum pernah sinkron';
    String two(int n) => n.toString().padLeft(2, '0');
    final hm = '${two(last.hour)}.${two(last.minute)}';
    final now = DateTime.now();
    final today =
        last.year == now.year && last.month == now.month && last.day == now.day;
    return today
        ? 'Terakhir sinkron $hm'
        : 'Terakhir sinkron ${two(last.day)}/${two(last.month)} $hm';
  }

  Future<void> _signOut() async {
    if (!await showSignOutSheet(context)) return;
    final account = ref.read(accountProvider.notifier);
    try {
      await account.signOut();
    } on PendingChangesException catch (e) {
      if (!mounted || !await showUnsyncedSheet(context, e.count)) return;
      await account.signOut(force: true);
    }
    if (mounted) context.go('/masuk');
  }

  Future<void> _deleteAccount() async {
    if (!await showDeleteAccountSheet(context)) return;
    try {
      await ref.read(accountProvider.notifier).deleteAccount();
      if (mounted) context.go('/masuk');
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Akun belum bisa dihapus. Cek internet, lalu coba lagi.',
          ),
        ),
      );
    }
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
  const _ProfileCard({required this.name, this.email, this.onTap});

  final String name;
  final String? email;

  /// Ketuk = ubah nama.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shown = name.trim().isEmpty ? 'Kamu' : name.trim();
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.cardPad),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shown,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.style(18, AppText.w800),
                    ),
                    if (email != null)
                      Text(
                        email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.style(
                          13,
                          AppText.w500,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  LucideIcons.pencil,
                  size: 18,
                  color: AppColors.faint,
                ),
            ],
          ),
        ),
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
    this.titleColor,
    this.iconColor = AppColors.ink,
    this.iconBackground = AppColors.track,
  });

  final IconData icon;
  final String title;
  final Color? titleColor;
  final Color iconColor;
  final Color iconBackground;
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
              background: iconBackground,
              color: iconColor,
              size: AppSize.badge,
              iconSize: 20,
              square: true,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.style(
                      16,
                      AppText.w800,
                      color: titleColor ?? AppColors.ink,
                    ),
                  ),
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

/// Layar 50 · Belum masuk: ajakan simpan data ke akun.
class _SaveToAccountCard extends StatelessWidget {
  const _SaveToAccountCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.cardPad),
      decoration: BoxDecoration(
        color: AppColors.lime,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const IconBadge(
                icon: LucideIcons.cloudCheck,
                background: AppColors.ink,
                color: AppColors.lime,
                size: 44,
                iconSize: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simpan datamu ke akun',
                      style: AppText.style(16, AppText.w800),
                    ),
                    Text(
                      'Aman kalau HP hilang atau ganti HP',
                      style: AppText.style(
                        13,
                        AppText.w500,
                        color: AppColors.limeText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Masuk pakai email',
            icon: LucideIcons.mail,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

/// Layar 55 · Kartu catat. Pro: sisa trial / sudah beli.
class _ProCard extends StatelessWidget {
  const _ProCard({required this.status, required this.price, this.onTap});

  final ProStatus status;
  final String price;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = status.purchased
        ? ('catat. Pro selamanya', 'Scan, catat otomatis & export')
        : status.inTrial
        ? ('Trial Pro sisa ${status.daysLeft} hari', 'Buka selamanya $price')
        : ('Trial Pro habis', 'Buka selamanya $price');
    return Material(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.cardPad),
          child: Row(
            children: [
              const IconBadge(
                icon: LucideIcons.sparkles,
                background: AppColors.lime,
                color: AppColors.ink,
                size: 44,
                iconSize: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.style(
                        16,
                        AppText.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppText.style(
                        13,
                        AppText.w500,
                        color: status.trialOver
                            ? AppColors.danger
                            : AppColors.faint,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                status.purchased
                    ? LucideIcons.circleCheck
                    : LucideIcons.chevronRight,
                size: 20,
                color: AppColors.lime,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
