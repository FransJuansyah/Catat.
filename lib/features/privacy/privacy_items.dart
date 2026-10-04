import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Satu poin di sheet ⓘ (layar 36).
enum InfoKind { reads, purpose, off, never }

/// Izin di layar Privasi & Izin (35 / 37) + isi sheet ⓘ (36).
enum PrivacyItem {
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
    description: 'Pengingat catat jam 21:00',
    infoTitle: 'Kenapa perlu\nnotifikasi?',
    reads: 'Pengingat jam 21:00 kalau hari itu belum catat.',
    purpose: 'Biar nggak lupa catat.',
    off: 'Nggak ada pengingat. Catat tetap bisa kapan aja.',
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
}
