import 'package:catat/core/format.dart';
import 'package:catat/core/theme/app_theme.dart';
import 'package:catat/data/payslip_reader.dart';
import 'package:catat/data/providers.dart';
import 'package:catat/domain/payslip_parser.dart';
import 'package:catat/features/onboarding/payslip_reading_screen.dart';
import 'package:catat/features/onboarding/salary_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class FakeReader implements PayslipReader {
  FakeReader({this.path = '/cache/slip.png', this.slip, this.fail = false});

  final String? path;
  final PayslipData? slip;
  final bool fail;
  final readPaths = <String>[];

  @override
  Future<String?> pick() async {
    if (fail) throw PlatformException(code: 'SLIP');
    return path;
  }

  @override
  Future<PayslipData> read(String imagePath) async {
    readPaths.add(imagePath);
    return slip ?? const PayslipData();
  }
}

/// Layar 02 → pemilih file → 08 (baca slip) → kembali ke 02 terisi.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<ProviderContainer> pump(WidgetTester tester, FakeReader reader) async {
    tester.view.physicalSize = const Size(1080, 2436);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        payslipReaderProvider.overrideWithValue(reader),
        clockProvider.overrideWithValue(() => DateTime(2026, 9, 26)),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/atur-gaji',
      routes: [
        GoRoute(
          path: '/atur-gaji',
          builder: (_, _) => const SalarySetupScreen(),
        ),
        GoRoute(
          path: '/baca-slip',
          builder: (_, state) =>
              PayslipReadingScreen(imagePath: state.extra! as String),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return container;
  }

  Future<void> upload(WidgetTester tester) async {
    await tester.tap(find.text('Upload slip gaji'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('slip kebaca: gaji & tanggal gajian terisi', (tester) async {
    final reader = FakeReader(
      slip: const PayslipData(netSalary: 6500000, payday: 28),
    );
    final container = await pump(tester, reader);
    await upload(tester);

    expect(find.text('Lagi baca slip gajimu…'), findsOneWidget);
    expect(find.text('SLIP GAJI · SEP 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.text('6.500.000'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(reader.readPaths, ['/cache/slip.png']);
    final draft = container.read(onboardingProvider);
    expect(draft.amount, 6500000);
    expect(draft.payday, 28);
    expect(find.text('Tiap tgl 28'), findsOneWidget);
    expect(
      find.text(
        'Gaji bersih kebaca ${rupiah(6500000)}, gajian tgl 28. '
        'Cek lagi ya.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('slip tidak kebaca: minta isi manual', (tester) async {
    final container = await pump(tester, FakeReader());
    final before = container.read(onboardingProvider);
    await upload(tester);
    await tester.pumpAndSettle();

    expect(container.read(onboardingProvider).amount, before.amount);
    expect(
      find.text('Nominal gajinya nggak kebaca. Isi manual dulu ya.'),
      findsOneWidget,
    );
  });

  testWidgets('batal pilih file: tetap di layar 02', (tester) async {
    final reader = FakeReader(path: null);
    await pump(tester, reader);
    await upload(tester);
    await tester.pumpAndSettle();

    expect(find.text('Atur Gaji'), findsOneWidget);
    expect(reader.readPaths, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('file rusak: pesan jelas', (tester) async {
    await pump(tester, FakeReader(fail: true));
    await upload(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('File slipnya nggak bisa dibuka. Coba foto / PDF lain ya.'),
      findsOneWidget,
    );
  });
}
