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
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    // Preview + pilihan Jenis.
    expect(find.text('Keinginan'), findsWidgets);
    expect(find.text('Jenis'), findsOneWidget);
    expect(find.text('Jatah & rentang'), findsOneWidget);

    // Layar 45: hapus → pilih kantong tujuan.
    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Keinginan?'), findsOneWidget);
    expect(find.text('Sisa Rp 1.950.000 dipindah ke:'), findsOneWidget);
    expect(find.text('Hapus & pindahin'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('20 Tambah kantong sampai 6', (tester) async {
    final c = await pump(tester, const PocketSettingsScreen());
    expect(find.text('Tambah kantong'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      c.read(pocketDraftProvider.notifier).addPocket();
    }
    await tester.pump();
    expect(c.read(pocketDraftProvider).value!.current.pockets, hasLength(6));
    expect(find.text('Tambah kantong'), findsNothing);
    expect(c.read(pocketDraftProvider.notifier).addPocket(), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('43 Bikin Kantong Sendiri saat daftar', (tester) async {
    // DB baru, belum daftar → draft dari template onboarding.
    await db.close();
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    final c = await pump(tester, const PocketSettingsScreen());
    expect(c.read(pocketDraftProvider).value!.onboarding, isTrue);
    expect(find.text('Bikin Sendiri'), findsOneWidget);
    expect(find.text('3 kantong'), findsOneWidget);
    expect(find.text('Maks 6'), findsOneWidget);
    expect(find.text('Pakai kantong ini'), findsOneWidget);
    expect(find.text('Persen'), findsNothing);
    expect(tester.takeException(), isNull);
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
