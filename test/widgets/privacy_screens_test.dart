import 'package:catat/core/theme/app_theme.dart';
import 'package:catat/core/widgets/controls.dart';
import 'package:catat/data/local/database.dart';
import 'package:catat/data/providers.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/features/account/account_screen.dart';
import 'package:catat/features/privacy/privacy_screen.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/fake_bridge.dart';

/// Layar Privasi & Izin (35/37), sheet ⓘ (36) & baris di Akun (38).
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

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    FakeBridge? bridge,
  }) async {
    tester.view.physicalSize = const Size(1080, 2436);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
        deviceBridgeProvider.overrideWithValue(bridge ?? FakeBridge()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<AppToggle> toggles(WidgetTester tester) =>
      tester.widgetList<AppToggle>(find.byType(AppToggle)).toList();

  testWidgets('35 onboarding: semua mati, ada Lanjut & disarankan', (
    tester,
  ) async {
    await pump(tester, const PrivacyScreen(onboarding: true));
    expect(find.text('Atur privasi kamu'), findsOneWidget);
    expect(find.text('Nyalakan yang disarankan'), findsOneWidget);
    expect(find.text('Lanjut'), findsOneWidget);
    expect(toggles(tester), hasLength(2));
    expect(find.text('Catat otomatis'), findsNothing);
    expect(toggles(tester).every((t) => !t.value), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nyalakan kamera: minta izin kamera', (tester) async {
    final bridge = FakeBridge();
    await pump(tester, const PrivacyScreen(onboarding: true), bridge: bridge);
    await tester.tap(find.byType(AppToggle).first); // Kamera
    await tester.pumpAndSettle();
    expect(bridge.calls, ['requestCamera']);
    expect(toggles(tester).first.value, isTrue);
  });

  testWidgets('"Nyalakan yang disarankan": kamera & pengingat', (tester) async {
    final bridge = FakeBridge();
    await pump(tester, const PrivacyScreen(onboarding: true), bridge: bridge);
    await tester.tap(find.text('Nyalakan yang disarankan'));
    await tester.pumpAndSettle();
    expect(bridge.calls, [
      'requestCamera',
      'requestNotifications',
      'setReminder true',
    ]);
    expect(toggles(tester).every((t) => t.value), isTrue);
  });

  testWidgets('sheet ⓘ kamera, "Nanti aja": tidak ada yang dinyalakan', (
    tester,
  ) async {
    final bridge = FakeBridge();
    await pump(tester, const PrivacyScreen(onboarding: true), bridge: bridge);
    await tester.tap(find.bySemanticsLabel('Kenapa Kamera?'));
    await tester.pumpAndSettle();
    expect(find.text('Kenapa perlu\nkamera?'), findsOneWidget);
    await tester.tap(find.text('Nanti aja'));
    await tester.pumpAndSettle();
    expect(bridge.calls, isEmpty);
    expect(toggles(tester).first.value, isFalse);
  });

  testWidgets('37 Akun: top bar, tanpa Lanjut', (tester) async {
    await pump(tester, const PrivacyScreen());
    expect(find.text('Privasi & Izin'), findsOneWidget);
    expect(find.text('Lanjut'), findsNothing);
  });

  testWidgets('38 Akun: baris Privasi & izin, pengingat jam 21:00', (
    tester,
  ) async {
    await pump(tester, const AccountScreen());
    expect(find.text('Privasi & izin'), findsOneWidget);
    expect(find.text('Kamera & notifikasi'), findsOneWidget);
    expect(find.text('Tiap jam 21:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
