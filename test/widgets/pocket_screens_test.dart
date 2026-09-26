import 'package:catat/core/theme/app_theme.dart';
import 'package:catat/data/local/database.dart';
import 'package:catat/data/providers.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/features/pocket/pocket_budget_screen.dart';
import 'package:catat/features/pocket/pocket_edit_screen.dart';
import 'package:catat/features/pocket/pocket_settings_screen.dart';
import 'package:catat/features/pocket/transfer_screen.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Layar Atur Kantong (20–25) bisa digambar di ukuran HP tanpa error layout.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late AppDatabase db;
  late BudgetRepository repo;
  final now = DateTime(2026, 9, 26, 10);

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    repo = BudgetRepository(db, () => now);
    await repo.setupBudget(
      netSalary: 6500000,
      payday: 25,
      template: PocketTemplates.klasik,
    );
  });
  tearDown(() => db.close());

  Future<ProviderContainer> pump(WidgetTester tester, Widget screen) async {
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
    // Layar 21/22/25 hidup di atas layar 20 → draft & beranda tetap didengar.
    final draftSub = container.listen(pocketDraftProvider, (_, _) {});
    addTearDown(draftSub.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildAppTheme(), home: screen),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return container;
  }

  Future<String> lastPocketId() async =>
      (await repo.loadPocketSetup()).pockets.last.id;

  testWidgets('20 Atur Kantong', (tester) async {
    await pump(tester, const PocketSettingsScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('100% teralokasi'), findsOneWidget);
    expect(find.text('Pas!'), findsOneWidget);
    expect(find.text('Keinginan'), findsOneWidget);
  });

  testWidgets('23 Atur Kantong kelebihan → Rapiin otomatis', (tester) async {
    final c = await pump(tester, const PocketSettingsScreen());
    final draft = c.read(pocketDraftProvider).value!;
    c
        .read(pocketDraftProvider.notifier)
        .updatePocket(draft.current.pockets.last.copyWith(percent: 40));
    await tester.pump();
    expect(find.text('110% teralokasi'), findsOneWidget);
    expect(find.textContaining('Kelebihan Rp 650.000'), findsOneWidget);
    await tester.tap(find.text('Rapiin otomatis'));
    await tester.pump();
    expect(find.text('100% teralokasi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('21 Edit Kantong', (tester) async {
    final id = await lastPocketId();
    await pump(tester, PocketEditScreen(pocketId: id));
    expect(tester.takeException(), isNull);
    expect(find.text('Tipe: Keinginan'), findsOneWidget);
    expect(find.text('Jatah & rentang'), findsOneWidget);
  });

  testWidgets('22 Atur Jatah & Rentang', (tester) async {
    final id = await lastPocketId();
    await pump(tester, PocketBudgetScreen(pocketId: id));
    expect(tester.takeException(), isNull);
    expect(find.text('Rp 1.950.000'), findsOneWidget);
    expect(find.text('Rentang jatah'), findsOneWidget);
    await tester.tap(find.text('40%'));
    await tester.pump();
    expect(find.text('Rp 2.600.000'), findsOneWidget);
  });

  testWidgets('25 Pindahin Saldo', (tester) async {
    final id = await lastPocketId();
    await pump(tester, TransferScreen(toId: id));
    expect(tester.takeException(), isNull);
    expect(find.text('Pindahin Saldo'), findsOneWidget);
    await tester.tap(find.text('Rp 200rb'));
    await tester.pump();
    expect(find.text('Rp 200.000'), findsOneWidget);
  });
}
