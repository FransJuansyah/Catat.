import 'package:catat/core/theme/app_theme.dart';
import 'package:catat/features/onboarding/allowance_setup_screen.dart';
import 'package:catat/features/onboarding/irregular_setup_screen.dart';
import 'package:catat/features/onboarding/opening_balance_screen.dart';
import 'package:catat/features/onboarding/salary_setup_screen.dart';
import 'package:catat/features/onboarding/source_screen.dart';
import 'package:catat/features/onboarding/template_screen.dart';
import 'package:catat/features/onboarding/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Memastikan layar onboarding bisa digambar tanpa error layout di ukuran HP
/// (bug nyata: LayoutBuilder di dalam SliverFillRemaining membuat layar 01 kosong).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    // Infinix X6880: 1080×2436 px, ±392 dp lebar.
    tester.view.physicalSize = const Size(1080, 2436);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: buildAppTheme(), home: screen),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  final screens = <String, (Widget, String)>{
    '01 Masuk': (const WelcomeScreen(), 'Daftar pakai Email'),
    '27 Sumber uang': (const SourceScreen(), 'Penghasilan tidak tetap'),
    '02 Atur gaji': (const SalarySetupScreen(), 'Tanggal gajian'),
    '28 Uang jajan': (const AllowanceSetupScreen(), 'Mingguan'),
    '29 Penghasilan': (const IrregularSetupScreen(), 'Ingetin catat pemasukan'),
    '19 Pilih template': (
      const TemplateScreen(),
      '2 sampai 6 kantong, atur sesukamu',
    ),
    '42 Uang kamu sekarang': (
      const OpeningBalanceScreen(),
      'Langsung dibagi ke 3 kantong',
    ),
  };

  for (final MapEntry(key: name, value: (screen, text)) in screens.entries) {
    testWidgets('$name tampil tanpa error', (tester) async {
      await pumpScreen(tester, screen);
      expect(tester.takeException(), isNull);
      expect(find.text(text), findsWidgets);
    });
  }
}
