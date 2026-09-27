import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/icon_badge.dart';

/// Kerangka bottom sheet merah (layar 51 & 52): handle, ikon, judul, pesan.
Future<T?> _dangerSheet<T>(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required Widget Function(BuildContext, StateSetter) actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    // Di atas bottom nav (layar Akun ada di dalam shell).
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.disabledBg,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 14),
                IconBadge(
                  icon: icon,
                  background: AppColors.dangerSoft,
                  color: AppColors.danger,
                  size: 56,
                  iconSize: 26,
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppText.style(22, AppText.w800, spacingPercent: -2),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppText.style(
                    14,
                    AppText.w500,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 16),
                actions(context, setState),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Layar 51 · Keluar. `true` = keluar.
Future<bool> showSignOutSheet(BuildContext context) async =>
    await _dangerSheet<bool>(
      context,
      icon: LucideIcons.logOut,
      title: 'Keluar dari akun?',
      message: 'Datamu tetap aman di akun. Catatan di HP ini dihapus, masuk lagi buat buka.',
      actions: (context, _) => Column(
        children: [
          AppButton(
            label: 'Keluar',
            icon: LucideIcons.logOut,
            style: AppButtonStyle.dangerFilled,
            onPressed: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Batal',
            style: AppButtonStyle.secondary,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    ) ??
    false;

/// Masih ada perubahan yang belum terkirim (offline) saat mau keluar.
Future<bool> showUnsyncedSheet(BuildContext context, int count) async =>
    await _dangerSheet<bool>(
      context,
      icon: LucideIcons.cloudOff,
      title: 'Ada yang belum tersimpan',
      message:
          '$count perubahan belum masuk ke akun karena lagi offline. Keluar sekarang = perubahan itu hilang.',
      actions: (context, _) => Column(
        children: [
          AppButton(
            label: 'Tetap keluar',
            style: AppButtonStyle.dangerFilled,
            onPressed: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Batal',
            style: AppButtonStyle.secondary,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    ) ??
    false;

/// Layar 52 · Hapus akun. Harus ketik HAPUS dulu. `true` = hapus.
Future<bool> showDeleteAccountSheet(BuildContext context) async {
  final typed = TextEditingController();
  try {
    return await _dangerSheet<bool>(
          context,
          icon: LucideIcons.trash2,
          title: 'Hapus akun & semua data?',
          message: 'Semua catatan, kantong & foto struk dihapus permanen dari akun dan HP ini. Nggak bisa dibalikin.',
          actions: (context, setState) {
            final ok = typed.text.trim().toUpperCase() == 'HAPUS';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ketik HAPUS buat lanjut',
                  style: AppText.style(
                    13,
                    AppText.w700,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: TextField(
                    controller: typed,
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    style: AppText.style(16, AppText.w700),
                    cursorColor: AppColors.danger,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'HAPUS',
                      hintStyle: AppText.style(
                        16,
                        AppText.w700,
                        color: AppColors.faint,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Hapus permanen',
                  icon: LucideIcons.trash2,
                  style: AppButtonStyle.dangerFilled,
                  onPressed: ok ? () => Navigator.pop(context, true) : null,
                ),
                const SizedBox(height: 10),
                AppButton(
                  label: 'Batal',
                  style: AppButtonStyle.secondary,
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            );
          },
        ) ??
        false;
  } finally {
    typed.dispose();
  }
}
