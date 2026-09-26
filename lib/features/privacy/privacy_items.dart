import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/bank_notification_parser.dart';

/// Satu poin di sheet ⓘ (layar 36).
enum InfoKind { reads, purpose, off, never }

/// Item di layar Privasi & Izin (35 / 37) + isi sheet ⓘ.
enum PrivacyItem {
  financeApp(
    icon: LucideIcons.landmark,
    title: 'M-banking & e-wallet',
    description: 'GoPay, DANA, OVO, BCA, BRImo, dll.',
    infoTitle: 'Kenapa baca notifikasi\nm-banking & e-wallet?',
    reads: 'Cuma notifikasi transaksi dari aplikasi bank & e-wallet.',
    purpose:
        'Pengeluaran & pemasukan langsung tercatat di belakang layar, '
        'tanpa buka aplikasi. Salah? Tinggal Batalkan.',
    off: 'Tetap bisa catat manual atau scan struk.',
    never: 'Baca chat, kirim data ke server, atau nyimpen isi notifikasi lain.',
  ),
  sms(
    icon: LucideIcons.messageSquare,
    title: 'SMS dari bank',
    description: 'Cuma SMS transaksi dari bank',
    infoTitle: 'Kenapa baca\nSMS dari bank?',
    reads:
        'Cuma SMS transaksi dari pengirim bank. Iklan, OTP & tagihan '
        'dilewati.',
    purpose:
        'Transaksi yang cuma dikabari lewat SMS ikut tercatat di belakang '
        'layar. Salah? Tinggal Batalkan.',
    off: 'Tetap bisa catat manual atau scan struk.',
    never: 'Baca SMS pribadi, chat, atau kirim data ke server.',
  ),
  email(
    icon: LucideIcons.mail,
    title: 'Email dari bank',
    description: 'Cuma email transaksi dari bank',
    infoTitle: 'Kenapa baca\nemail dari bank?',
    reads: 'Cuma notifikasi email transaksi dari bank. Promo dilewati.',
    purpose:
        'Transaksi yang dikabari lewat email ikut tercatat di belakang '
        'layar. Salah? Tinggal Batalkan.',
    off: 'Tetap bisa catat manual atau scan struk.',
    never: 'Buka kotak masuk, baca email lain, atau kirim data ke server.',
  ),
  camera(
    icon: LucideIcons.camera,
    title: 'Kamera',
    description: 'Buat scan struk belanja',
    infoTitle: 'Kenapa perlu\nkamera?',
    reads: 'Cuma foto struk yang kamu ambil sendiri.',
    purpose: 'Total & item di struk kebaca otomatis, kamu tinggal cek.',
    off: 'Pilih foto struk dari galeri atau catat manual.',
    never: 'Motret atau merekam tanpa kamu tekan tombol.',
  ),
  notifications(
    icon: LucideIcons.bell,
    title: 'Notifikasi',
    description: 'Pengingat jam 21:00 & info tercatat',
    infoTitle: 'Kenapa perlu\nnotifikasi?',
    reads:
        'Pengingat jam 21:00 kalau hari itu belum catat, dan info '
        '"Tercatat" dari catat otomatis.',
    purpose: 'Biar nggak lupa catat & tahu kalau ada yang tercatat otomatis.',
    off: 'Nggak ada pengingat. Catat otomatis tetap jalan tanpa info.',
    never: 'Kirim promo atau iklan.',
  );

  const PrivacyItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.infoTitle,
    required this.reads,
    required this.purpose,
    required this.off,
    required this.never,
  });

  final IconData icon;
  final String title;

  /// Keterangan di layar onboarding (35).
  final String description;
  final String infoTitle;
  final String reads;
  final String purpose;
  final String off;
  final String never;

  /// Sumber catat otomatis (null untuk kamera & notifikasi).
  NotificationSource? get source => switch (this) {
    PrivacyItem.financeApp => NotificationSource.financeApp,
    PrivacyItem.sms => NotificationSource.sms,
    PrivacyItem.email => NotificationSource.email,
    _ => null,
  };

  /// Label poin di sheet ⓘ (notifikasi "dikirim", bukan "dibaca").
  String infoLabel(InfoKind kind) => switch (kind) {
    InfoKind.reads =>
      this == PrivacyItem.notifications ? 'Yang dikirim' : 'Yang dibaca',
    InfoKind.purpose => 'Buat apa',
    InfoKind.off => 'Kalau dimatikan',
    InfoKind.never => 'Nggak pernah',
  };

  String infoText(InfoKind kind) => switch (kind) {
    InfoKind.reads => reads,
    InfoKind.purpose => purpose,
    InfoKind.off => off,
    InfoKind.never => never,
  };

  static const autoCapture = [financeApp, sms, email];
  static const others = [camera, notifications];

  /// "Nyalakan yang disarankan": m-banking, kamera, notifikasi. SMS & email
  /// lebih pribadi, jadi dibiarkan pilihan user.
  static const recommended = [financeApp, camera, notifications];
}
