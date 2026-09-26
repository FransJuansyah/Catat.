import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Token desain dari design/tokens.json. Jangan hardcode warna/ukuran di widget.
abstract final class AppColors {
  static const ink = Color(0xFF0E0E10);
  static const lime = Color(0xFFD4FF4F);
  static const bg = Color(0xFFF6F6F1);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFF71717A);
  static const faint = Color(0xFFA1A1AA);
  static const line = Color(0xFFE7E7E1);
  static const darkSurface = Color(0xFF26262A);
  static const track = Color(0xFFF0F0EA);
  static const danger = Color(0xFFE5484D);
  static const success = Color(0xFF12A36B);
  static const disabledBg = Color(0xFFDADAD4);
  static const segmentBg = Color(0xFFE7E7E1);
  static const limeText = Color(0xFF4A5A12);

  /// Kartu peringatan kuning (layar 25, Privasi & Izin).
  static const warnBg = Color(0xFFFEF7DC);
  static const warnIcon = Color(0xFFA16207);
  static const warnText = Color(0xFF854D0E);
}

abstract final class AppRadius {
  static const hero = 28.0;
  static const card = 20.0;
  static const cardLg = 22.0;
  static const button = 18.0;
  static const input = 16.0;
  static const segment = 14.0;
  static const pill = 999.0;
}

abstract final class AppSpace {
  static const screenX = 20.0;
  static const section = 20.0;
  static const sectionTight = 14.0;
  static const cardPad = 16.0;
  static const cardPadSm = 14.0;
  static const rowY = 12.0;
}

abstract final class AppSize {
  static const badge = 44.0;
  static const badgeSm = 36.0;
  static const topBarButton = 40.0;
  static const fab = 54.0;
  static const buttonHeight = 56.0;

  /// Lebar isi layar maksimum. Tablet / HP lipat dibuka: isi di tengah.
  static const maxContent = 480.0;

  /// Sisi pendek layar (dp) mulai dianggap tablet / HP lipat dibuka:
  /// di bawahnya HP biasa dikunci tegak.
  static const tabletShortestSide = 600.0;
}

abstract final class AppShadow {
  static const card = [
    BoxShadow(color: Color(0x140E0E10), offset: Offset(0, 8), blurRadius: 20),
  ];
  static const fab = [
    BoxShadow(color: Color(0x400E0E10), offset: Offset(0, 6), blurRadius: 14),
  ];
}

/// Tipografi Plus Jakarta Sans. `tight` = letter spacing -3% (angka hero & judul layar).
abstract final class AppText {
  static TextStyle style(
    double size,
    FontWeight weight, {
    Color color = AppColors.ink,
    double spacingPercent = 0,
    double? height,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: size * spacingPercent / 100,
    height: height,
  );

  static const w500 = FontWeight.w500;
  static const w700 = FontWeight.w700;
  static const w800 = FontWeight.w800;
}

/// Ikon & warna kantong (disimpan di DB sebagai `iconKey` dan ARGB int).
abstract final class PocketVisuals {
  static const icons = <String, IconData>{
    'house': LucideIcons.house,
    'shield': LucideIcons.shield,
    'sparkles': LucideIcons.sparkles,
    'coffee': LucideIcons.coffee,
    'plane': LucideIcons.plane,
    'gamepad': LucideIcons.gamepad2,
    'music': LucideIcons.music,
    'gift': LucideIcons.gift,
    'heart': LucideIcons.heart,
    'shirt': LucideIcons.shirt,
    // Ikon kategori pengeluaran (ditebak dari judul).
    'bag': LucideIcons.shoppingBag,
    'food': LucideIcons.utensils,
    'bolt': LucideIcons.zap,
    'fuel': LucideIcons.fuel,
    'car': LucideIcons.car,
    'phone': LucideIcons.smartphone,
    'film': LucideIcons.film,
    'piggy': LucideIcons.piggyBank,
  };

  /// Teks gelap di atas latar lembut warna kantong (mis. kartu tips).
  static Color deep(Color color) => Color.lerp(color, AppColors.ink, 0.35)!;

  static IconData icon(String key) => icons[key] ?? LucideIcons.wallet;

  /// Latar lembut = warna kantong 12% di atas putih (mis. #6D5DFC → #EEEBFF).
  static Color soft(Color color) =>
      Color.alphaBlend(color.withValues(alpha: 0.12), Colors.white);

  /// Palet yang bisa dipilih user saat kustomisasi (layar 21).
  static const palette = [
    Color(0xFF6D5DFC),
    Color(0xFF12A36B),
    Color(0xFFFF4F7B),
    Color(0xFFFF8A00),
    Color(0xFF0EA5E9),
    Color(0xFFEAB308),
    Color(0xFF0E0E10),
  ];
}
