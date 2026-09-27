import 'package:catat/app.dart';
import 'package:catat/core/theme/app_theme.dart';
import 'package:catat/core/theme/tokens.dart';
import 'package:catat/core/widgets/app_frame.dart';
import 'package:catat/data/export/report_exporter.dart';
import 'package:catat/data/local/database.dart';
import 'package:catat/data/payslip_reader.dart';
import 'package:catat/data/providers.dart';
import 'package:catat/data/receipt_scanner.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/payslip_parser.dart';
import 'package:catat/domain/receipt_parser.dart';
import 'package:catat/domain/report.dart';
import 'package:catat/domain/templates.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/fake_bridge.dart';

/// Ukuran layar yang harus rapi (tanpa overflow). HP selalu tegak (dikunci);
/// tablet & HP lipat yang dibuka boleh diputar.
class ScreenCase {
  const ScreenCase(this.name, this.size, {this.textScale = 1});

  final String name;

  /// Ukuran logis (dp).
  final Size size;
  final double textScale;
}

const cases = [
  ScreenCase('HP kecil 320dp', Size(320, 640)),
  ScreenCase('HP biasa, huruf 130%', Size(392, 886), textScale: 1.3),
  ScreenCase('HP besar', Size(412, 915)),
  ScreenCase('HP lipat ditutup', Size(344, 882)),
  ScreenCase('HP lipat dibuka', Size(673, 841)),
  ScreenCase('HP lipat dibuka mendatar', Size(841, 673)),
  ScreenCase('tablet tegak', Size(800, 1280)),
  ScreenCase('tablet mendatar', Size(1280, 800)),
];

class _Scanner implements ReceiptScanner {
  @override
  Future<ReceiptData> read(String imagePath) async =>
      const ReceiptData(merchant: 'Indomaret', total: 52000);

  @override
  Future<String> keepPhoto(String imagePath) async => imagePath;
}

class _Slip implements PayslipReader {
  @override
  Future<String?> pick() async => null;

  @override
  Future<PayslipData> read(String imagePath) async =>
      const PayslipData(netSalary: 6500000, payday: 25);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final now = DateTime(2026, 9, 26, 10);

  /// Rute + extra. Id diisi dari data contoh (lihat [seed]).
  List<(String, Object?)> routes(
    String expenseId,
    String incomeId,
    String pocketId,
  ) => [
    ('/masuk', null),
    ('/sumber-uang', null),
    ('/atur-gaji', null),
    ('/atur-jajan', null),
    ('/atur-penghasilan', null),
    ('/pilih-template', null),
    ('/beranda', null),
    ('/catatan', null),
    ('/laporan', null),
    ('/akun', null),
    ('/export', null),
    (
      '/export/siap',
      const ExportResult(
        fileName: 'Laporan_catat_Sep_2026.pdf',
        format: ExportFormat.pdf,
        localPath: '/tmp/x.pdf',
        sizeBytes: 86240,
        detail: '1 bulan · 12 transaksi',
        location: 'Download',
      ),
    ),
    ('/pemasukan', null),
    ('/pemasukan?edit=$incomeId', null),
    ('/pemasukan-masuk/$incomeId', null),
    ('/catat', null),
    ('/catat?edit=$expenseId', null),
    ('/tercatat/$expenseId', null),
    ('/transaksi/$expenseId', null),
    ('/kantong', null),
    ('/kantong/$pocketId', null),
    ('/edit-kantong/$pocketId', null),
    ('/jatah-kantong/$pocketId', null),
    ('/pindah-saldo', null),
    ('/gajian-masuk', null),
    ('/privasi-awal?next=/beranda', null),
    ('/privasi', null),
    ('/pro', null),
    ('/pro-kebuka', null),
    ('/masuk-email', null),
    ('/masuk-kode?email=frans@email.com', null),
    ('/sesuaikan-saldo', null),
    ('/baca-struk', '/tmp/struk.jpg'),
    (
      '/hasil-scan',
      const ScanResult(
        imagePath: '/tmp/struk.jpg',
        data: ReceiptData(merchant: 'Indomaret', total: 52000),
      ),
    ),
    ('/baca-slip', '/tmp/slip.png'),
  ];

  Future<(AppDatabase, String, String, String)> seed() async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    final repo = BudgetRepository(db, () => now);
    await repo.setupBudget(
      netSalary: 6500000,
      payday: 25,
      template: PocketTemplates.klasik,
    );
    await repo.ensureCurrentPeriod();
    final pocketId = (await repo.loadHome()).pockets.first.id;
    final expenseId = await repo.addExpense(
      pocketId: pocketId,
      amount: 52000,
      title: 'Belanja bulanan Indomaret Fatmawati',
    );
    final incomeId = await repo.addIncome(amount: 750000, title: 'Freelance');
    return (db, expenseId, incomeId, pocketId);
  }

  Future<void> pumpRoute(
    WidgetTester tester,
    AppDatabase db,
    ScreenCase c,
    String location,
    Object? extra,
  ) async {
    tester.view.devicePixelRatio = 2.75;
    tester.view.physicalSize = c.size * 2.75;
    tester.platformDispatcher.textScaleFactorTestValue = c.textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
        autoCaptureProvider.overrideWithValue(FakeBridge()),
        receiptScannerProvider.overrideWithValue(_Scanner()),
        payslipReaderProvider.overrideWithValue(_Slip()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: buildAppTheme(),
          routerConfig: createRouter(
            initialLocation: location,
            initialExtra: extra,
          ),
          builder: appBuilder,
        ),
      ),
    );
    // Beberapa frame: data DB & animasi awal. Layar loading (baca struk /
    // slip) pindah sendiri setelah ±2 dtk, jadi tidak ditunggu habis.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final c in cases) {
    group(c.name, () {
      late AppDatabase db;
      late List<(String, Object?)> all;

      setUp(() async {
        final (d, expenseId, incomeId, pocketId) = await seed();
        db = d;
        all = routes(expenseId, incomeId, pocketId);
      });
      tearDown(() => db.close());

      // Satu test per ukuran, semua layar: laporan gagal menyebut rutenya.
      testWidgets('semua layar tanpa overflow', (tester) async {
        final failures = <String>[];
        final original = FlutterError.onError;
        String? current;
        FlutterError.onError = (details) {
          final text = details.exceptionAsString().split('\n').first;
          failures.add('$current → $text');
        };
        try {
          for (final (location, extra) in all) {
            current = location;
            await pumpRoute(tester, db, c, location, extra);
            // Bersihkan sebelum layar berikutnya (timer layar loading).
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 3));
          }
        } finally {
          FlutterError.onError = original;
        }
        expect(failures, isEmpty, reason: failures.join('\n'));
      });
    });
  }

  group('bingkai tablet', () {
    late AppDatabase db;
    setUp(() async => db = (await seed()).$1);
    tearDown(() => db.close());

    testWidgets('tablet: isi layar selebar HP besar di tengah', (tester) async {
      await pumpRoute(tester, db, cases.last, '/beranda', null);
      final scaffold = tester.getRect(find.byType(Scaffold).first);
      expect(scaffold.width, AppSize.maxContent);
      expect(scaffold.center.dx, closeTo(1280 / 2, 0.5));
    });

    testWidgets('HP: isi selebar layar', (tester) async {
      await pumpRoute(tester, db, cases[2], '/beranda', null);
      expect(tester.getRect(find.byType(Scaffold).first).width, 412);
    });
  });

  test('HP dikunci tegak, tablet & HP lipat dibuka bebas diputar', () {
    expect(isCompactScreen(const Size(320, 640)), isTrue);
    expect(isCompactScreen(const Size(412, 915)), isTrue);
    expect(isCompactScreen(const Size(915, 412)), isTrue); // HP mendatar
    expect(isCompactScreen(const Size(344, 882)), isTrue); // lipat ditutup
    expect(isCompactScreen(const Size(673, 841)), isFalse); // lipat dibuka
    expect(isCompactScreen(const Size(1280, 800)), isFalse);
  });
}
