import 'package:catat/core/theme/app_theme.dart';
import 'package:catat/core/widgets/pocket_card.dart';
import 'package:catat/data/local/database.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/home_summary.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/features/pocket/low_pocket_sheet.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Kantong yang dipakai melebihi jatahnya (minus). Meniru setelan user
/// 5 Okt 2026: gaji Rp 5 jt tiap tgl 5, Wajib 30% · tabungan 48% ·
/// Transport 22%.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late AppDatabase db;
  late DateTime now;
  late BudgetRepository repo;

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    now = DateTime(2026, 10, 5, 9);
    repo = BudgetRepository(db, () => now);
    await repo.setupBudget(
      netSalary: 5000000,
      payday: 5,
      template: PocketTemplates.klasik,
    );
    final [w, d, k] = (await repo.loadPocketSetup()).pockets;
    await repo.savePockets([
      w.copyWith(percent: 30),
      d.copyWith(percent: 48, name: 'tabungan'),
      k.copyWith(percent: 22, name: 'Transport'),
    ]);
  });
  tearDown(() => db.close());

  Future<PocketView> pocket(String name) async =>
      (await repo.loadHome()).pockets.firstWhere((p) => p.name == name);

  test('Wajib dipakai sampai minus: sisa kantong & sisa total', () async {
    final w = await pocket('Wajib');
    expect(w.balance.allocation, 1500000);

    // (judul, nominal, sisa Wajib, hampir habis?, sisa total)
    final steps = [
      ('Bayar kos', 1000000, 500000, false, 4000000),
      ('Belanja bulanan', 400000, 100000, true, 3600000),
      ('Listrik', 300000, -200000, true, 3300000),
      ('Bensin', 250000, -450000, true, 3050000),
    ];
    for (final (title, amount, left, low, total) in steps) {
      await repo.addExpense(pocketId: w.id, amount: amount, title: title);
      final home = await repo.loadHome();
      final now = home.pockets.firstWhere((p) => p.id == w.id);
      expect(now.balance.remaining, left, reason: title);
      expect(now.isLow, low, reason: title);
      // Sisa total = gaji − semua pengeluaran; kantong lain tidak berubah.
      expect(home.remaining, total, reason: title);
      expect(
        home.pockets.where((p) => p.id != w.id).map((p) => p.balance.remaining),
        [2400000, 1100000],
      );
    }
    final last = await pocket('Wajib');
    expect(last.balance.usedRatio, 1.0);
    expect((await repo.loadHome()).level, closeTo(3050000 / 5000000, 1e-9));
  });

  test('pindahin saldo menutup minus', () async {
    final w = await pocket('Wajib');
    final t = await pocket('tabungan');
    await repo.addExpense(pocketId: w.id, amount: 1950000, title: 'Kos');
    await repo.transferBalance(
      fromPocketId: t.id,
      toPocketId: w.id,
      amount: 450000,
    );
    expect((await pocket('Wajib')).balance.remaining, 0);
    expect((await pocket('tabungan')).balance.remaining, 1950000);
    expect((await repo.loadHome()).remaining, 3050000);
  });

  test('gajian berikutnya: Wajib mulai lagi dari jatah penuh', () async {
    final w = await pocket('Wajib');
    await repo.addExpense(pocketId: w.id, amount: 1950000, title: 'Kos');
    now = DateTime(2026, 11, 5, 9);
    final next = await pocket('Wajib');
    // Anggaran per periode: minus bulan lalu tidak dibawa ke periode baru.
    expect(next.balance.allocation, 1500000);
    expect(next.balance.remaining, 1500000);
  });

  group('tampilan saat minus', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(1080, 2436);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: child),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('kartu kantong: "Minus Rp 450rb", bukan "Sisa -Rp"', (
      tester,
    ) async {
      final w = await tester.runAsync(() async {
        final p = await pocket('Wajib');
        await repo.addExpense(pocketId: p.id, amount: 1950000, title: 'Kos');
        return pocket('Wajib');
      });
      await pump(tester, PocketCard(pocket: w!));
      expect(find.text('Minus Rp 450rb'), findsOneWidget);
      expect(find.textContaining('Sisa -'), findsNothing);
    });

    testWidgets('peringatan: "udah minus", bukan "tinggal -13%"', (
      tester,
    ) async {
      final w = await tester.runAsync(() async {
        final p = await pocket('Wajib');
        await repo.addExpense(pocketId: p.id, amount: 1700000, title: 'Kos');
        return pocket('Wajib');
      });
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showLowPocketSheet(context, w!),
            child: const Text('buka'),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      expect(find.text('Kantong Wajib\nudah minus'), findsOneWidget);
      expect(
        find.text('Lewat Rp 200rb dari jatah Rp 1,5jt. Mau diapain?'),
        findsOneWidget,
      );
      expect(find.textContaining('-'), findsNothing);
    });
  });
}
