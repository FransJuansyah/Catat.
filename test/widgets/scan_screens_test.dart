import 'package:catat/core/theme/app_theme.dart';
import 'package:catat/data/local/database.dart';
import 'package:catat/data/providers.dart';
import 'package:catat/data/receipt_scanner.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/receipt_parser.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/features/scan/scan_reading_screen.dart';
import 'package:catat/features/scan/scan_result_screen.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeScanner implements ReceiptScanner {
  _FakeScanner(this.data);

  final ReceiptData data;

  @override
  Future<ReceiptData> read(String imagePath) async => data;

  @override
  Future<String> keepPhoto(String imagePath) async => imagePath;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final now = DateTime(2026, 9, 26, 10);
  final indomaret = parseReceipt([
    'INDOMARET',
    '24.09.26-10:15',
    'SUSU UHT 1L  2  18,000  36,000',
    'ROTI TAWAR  1  16,000  16,000',
    'TOTAL :  52,000',
  ], now: now);

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await BudgetRepository(db, () => now).setupBudget(
      netSalary: 6500000,
      payday: 25,
      template: PocketTemplates.klasik,
    );
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, GoRouter router) async {
    tester.view.physicalSize = const Size(1080, 2436);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          receiptScannerProvider.overrideWithValue(_FakeScanner(indomaret)),
        ],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
  }

  testWidgets('05 Cek Hasil Scan: isi struk, tebakan kantong, simpan', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/hasil-scan',
      routes: [
        GoRoute(
          path: '/hasil-scan',
          builder: (_, _) => ScanResultScreen(
            result: ScanResult(imagePath: 'struk.jpg', data: indomaret),
          ),
        ),
        GoRoute(
          path: '/tercatat/:id',
          builder: (_, s) => Text('tercatat ${s.pathParameters['id']}'),
        ),
      ],
    );
    await pump(tester, router);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Struk kebaca! Cek bentar ya'), findsOneWidget);
    expect(find.text('Indomaret'), findsOneWidget);
    expect(find.text('Rp 52.000'), findsOneWidget);
    expect(find.text('Susu Uht 1L  x2'), findsOneWidget);
    expect(find.text('Tebakan kami: Wajib (kebutuhan pokok)'), findsOneWidget);

    await tester.tap(find.text('Simpan pengeluaran'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('tercatat '), findsOneWidget);
    final saved = await db.select(db.expenses).getSingle();
    expect(saved.amount, 52000);
    expect(saved.merchant, 'Indomaret');
    expect(saved.photoPath, 'struk.jpg');
    expect(saved.occurredAt, DateTime(2026, 9, 26, 10));
    expect(await db.select(db.expenseItems).get(), hasLength(2));
  });

  testWidgets('09 Baca struk → langkah selesai → lanjut ke 05', (tester) async {
    final router = GoRouter(
      initialLocation: '/baca',
      routes: [
        GoRoute(
          path: '/baca',
          builder: (_, _) => const ScanReadingScreen(imagePath: 'struk.jpg'),
        ),
        GoRoute(
          path: '/hasil-scan',
          builder: (_, s) =>
              Text('hasil ${(s.extra! as ScanResult).data.total}'),
        ),
      ],
    );
    await pump(tester, router);
    await tester.pump();
    expect(find.text('Lagi baca strukmu…'), findsOneWidget);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('hasil 52000'), findsOneWidget);
  });
}
