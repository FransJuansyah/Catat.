import 'package:catat/core/theme/app_theme.dart';
import 'package:catat/core/widgets/controls.dart';
import 'package:catat/data/auto_capture.dart';
import 'package:catat/data/local/database.dart';
import 'package:catat/data/providers.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/bank_notification_parser.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/domain/types.dart';
import 'package:catat/features/account/account_screen.dart';
import 'package:catat/features/expense/expense_form_screen.dart';
import 'package:catat/features/privacy/privacy_screen.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Jembatan Android palsu: menyimpan status & mencatat panggilan.
class FakeBridge implements AutoCaptureBridge {
  FakeBridge([this.state = const AutoStatus()]);

  AutoStatus state;
  final calls = <String>[];

  AutoStatus _copy({
    Set<NotificationSource>? sources,
    bool? cameraGranted,
    bool? canNotify,
    bool? reminder,
  }) => state = AutoStatus(
    sources: sources ?? state.sources,
    cameraGranted: cameraGranted ?? state.cameraGranted,
    listenerAccess: state.listenerAccess,
    canNotify: canNotify ?? state.canNotify,
    reminder: reminder ?? state.reminder,
  );

  @override
  Future<AutoStatus> status() async => state;

  @override
  Future<AutoStatus> setSource(NotificationSource source, bool on) async {
    calls.add('setSource ${source.name} $on');
    return _copy(
      sources: on
          ? {...state.sources, source}
          : ({...state.sources}..remove(source)),
    );
  }

  @override
  Future<AutoStatus> setReminder(bool on) async {
    calls.add('setReminder $on');
    return _copy(reminder: on);
  }

  @override
  Future<void> openAccessSettings() async => calls.add('openAccessSettings');

  @override
  Future<void> openAppSettings() async => calls.add('openAppSettings');

  @override
  Future<bool> requestNotifications() async {
    calls.add('requestNotifications');
    _copy(canNotify: true);
    return true;
  }

  @override
  Future<bool> requestCamera() async {
    calls.add('requestCamera');
    _copy(cameraGranted: true);
    return true;
  }

  @override
  Future<LaunchAction?> takeLaunch() async => null;

  @override
  Stream<void> get launches => const Stream.empty();

  @override
  Stream<void> get dataChanges => const Stream.empty();
}

/// F6.5: layar Privasi & Izin (35/37), sheet ⓘ (36), Akun (38) & form Catat
/// yang terisi dari notifikasi.
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
        autoCaptureProvider.overrideWithValue(bridge ?? FakeBridge()),
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
    expect(toggles(tester), hasLength(5));
    expect(toggles(tester).every((t) => !t.value), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nyalakan SMS: jelaskan dulu (sheet), baru minta izin', (
    tester,
  ) async {
    final bridge = FakeBridge();
    await pump(tester, const PrivacyScreen(onboarding: true), bridge: bridge);
    await tester.tap(find.byType(AppToggle).at(1)); // SMS dari bank
    await tester.pumpAndSettle();
    expect(find.text('Kenapa baca\nSMS dari bank?'), findsOneWidget);
    expect(bridge.calls, isEmpty); // belum minta izin apa pun

    await tester.tap(find.text('Nyalakan'));
    await tester.pumpAndSettle();
    expect(bridge.calls, [
      'requestNotifications',
      'setSource sms true',
      'openAccessSettings',
    ]);
    expect(toggles(tester)[1].value, isTrue);
  });

  testWidgets('"Nanti aja" di sheet: tidak ada yang dinyalakan', (
    tester,
  ) async {
    final bridge = FakeBridge();
    await pump(tester, const PrivacyScreen(onboarding: true), bridge: bridge);
    await tester.tap(find.byType(AppToggle).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nanti aja'));
    await tester.pumpAndSettle();
    expect(bridge.calls, isEmpty);
    expect(toggles(tester).first.value, isFalse);
  });

  testWidgets('37 Akun: status Aktif/Mati & peringatan izin Android', (
    tester,
  ) async {
    final bridge = FakeBridge(
      const AutoStatus(
        sources: {NotificationSource.financeApp},
        canNotify: true,
      ),
    );
    await pump(tester, const PrivacyScreen(), bridge: bridge);
    expect(find.text('Privasi & Izin'), findsOneWidget);
    expect(find.text('Aktif'), findsOneWidget);
    expect(find.text('Mati'), findsNWidgets(2));
    expect(find.textContaining('Akses notifikasi'), findsOneWidget);
    expect(find.text('Lanjut'), findsNothing);
  });

  testWidgets('38 Akun: baris Privasi & izin, pengingat jam 21:00', (
    tester,
  ) async {
    await pump(tester, const AccountScreen());
    expect(find.text('Privasi & izin'), findsOneWidget);
    expect(find.text('Catat otomatis, kamera, notifikasi'), findsOneWidget);
    expect(find.text('Tiap jam 21:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('form Catat terisi dari notifikasi bank', (tester) async {
    await pump(
      tester,
      ExpenseFormScreen(
        initialAmount: 32500,
        initialTitle: 'Kopi Kenangan',
        initialPocketType: PocketType.keinginan,
        initialTime: DateTime(2026, 9, 26, 9, 41),
        source: ExpenseSource.notif,
      ),
    );
    expect(find.textContaining('32.500'), findsOneWidget);
    expect(find.text('Kopi Kenangan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
