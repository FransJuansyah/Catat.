import 'package:catat/core/theme/app_theme.dart';
import 'package:catat/data/local/database.dart';
import 'package:catat/data/providers.dart';
import 'package:catat/data/repositories/bill_repository.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/bills.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/features/bills/bill_edit_screen.dart';
import 'package:catat/features/bills/bills_screen.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Layar 69–70: daftar tagihan, bayar, tambah tagihan.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late AppDatabase db;
  late BillRepository bills;
  final now = DateTime(2026, 10, 9, 10);

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    final budget = BudgetRepository(db, () => now);
    bills = BillRepository(db, budget, () => now);
    await budget.setupBudget(
      netSalary: 6500000,
      payday: 25,
      template: PocketTemplates.klasik,
    );
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1080, 2436);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/tagihan',
          builder: (_, _) => const BillsScreen(),
          routes: [
            GoRoute(
              path: 'baru',
              builder: (_, state) =>
                  BillEditScreen(draft: state.extra as BillDraft?),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('daftar: total, besok, lalu Udah bayar → pindah ke lunas', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await bills.addBill(
        name: 'Cicilan HP',
        iconKey: 'phone',
        amount: 500000,
        dueDay: 10,
        kind: BillKind.cicilan,
        remaining: 8,
      );
      await bills.addBill(
        name: 'Kartu kredit',
        iconKey: 'card',
        amount: 1250000,
        dueDay: 15,
        kind: BillKind.rutin,
      );
    });
    await pump(tester, '/tagihan');
    expect(find.text('Rp 1.750.000'), findsOneWidget);
    expect(find.text('Belum dibayar'), findsOneWidget);
    expect(find.text('Besok'), findsOneWidget);
    expect(find.text('6 hari lagi'), findsOneWidget);
    expect(find.text('Tgl 10 · sisa 8x'), findsOneWidget);

    await tester.tap(find.text('Cicilan HP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Udah bayar'));
    await tester.pumpAndSettle();
    expect(find.text('Udah lunas'), findsOneWidget);
    expect(find.text('Lunas'), findsOneWidget);
    expect(find.text('Tgl 10 · sisa 7x'), findsOneWidget);
    expect(find.text('Rp 500.000 udah lunas'), findsOneWidget);
  });

  testWidgets('kosong: ajakan tambah tagihan', (tester) async {
    await pump(tester, '/tagihan');
    expect(find.text('Belum ada tagihan'), findsOneWidget);
    expect(find.text('Tambah tagihan'), findsOneWidget);
  });

  testWidgets('tambah tagihan: nama → ikon ditebak, lunas dihitung, simpan', (
    tester,
  ) async {
    await pump(tester, '/tagihan');
    await tester.tap(find.text('Tambah tagihan'));
    await tester.pumpAndSettle();
    // Isi nominal lewat keypad.
    await tester.tap(find.text('Rp 0'));
    await tester.pumpAndSettle();
    for (final k in ['5', '0', '0', '0', '0', '0']) {
      await tester.tap(find.text(k).last);
      await tester.pump();
    }
    await tester.tap(find.text('Simpan').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Cicilan HP');
    await tester.pumpAndSettle();
    // Tanggal default = hari ini (9) → jatuh tempo bulan ini; 12x → Sep 2027.
    expect(find.text('Lunas Sep 2027'), findsOneWidget);
    await tester.tap(find.text('Simpan tagihan'));
    await tester.pumpAndSettle();
    final saved = await tester.runAsync(bills.loadBills);
    expect(saved!.single.name, 'Cicilan HP');
    expect(saved.single.amount, 500000);
    expect(saved.single.iconKey, 'card');
    expect(saved.single.remaining, 12);
    expect(find.text('Cicilan HP'), findsOneWidget);
  });
}
