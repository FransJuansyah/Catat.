import 'package:catat/core/theme/app_theme.dart';
import 'package:catat/data/chat_assistant.dart';
import 'package:catat/data/local/database.dart';
import 'package:catat/data/providers.dart';
import 'package:catat/data/repositories/bill_repository.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/bills.dart';
import 'package:catat/domain/onboard_profile.dart';
import 'package:catat/features/onboarding/ai_onboarding_screen.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/fake_chat.dart';

OnboardOutcome answer(Map<String, Object?> json) =>
    OnboardAnswered(OnboardReply.fromJson(json));

/// Layar 74–75: daftar sambil ngobrol dengan AI.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late AppDatabase db;
  final now = DateTime(2026, 10, 9, 10);

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => db.close());

  Future<GoRouter> pump(WidgetTester tester, FakeChat chat) async {
    tester.view.physicalSize = const Size(1080, 2436);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
        chatAssistantProvider.overrideWithValue(chat),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/daftar-ai',
      routes: [
        GoRoute(
          path: '/daftar-ai',
          builder: (_, _) => const AiOnboardingScreen(),
        ),
        for (final path in ['/sumber-uang', '/privasi-awal', '/beranda'])
          GoRoute(path: path, builder: (_, _) => Text('layar $path')),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
  }

  const profile = {
    'name': 'Frans',
    'mode': 'gaji',
    'amount': 6500000,
    'frequency': '',
    'payday': 25,
    'weekday': 0,
    'estimate': 0,
    'balance': 2000000,
    'template': 'klasik',
    'bills': [
      {'name': 'Kos', 'amount': 1500000, 'due_day': 1, 'remaining': null},
      {'name': 'Cicilan HP', 'amount': 500000, 'due_day': 10, 'remaining': 8},
    ],
  };

  testWidgets('ngobrol → pilihan cepat → rangkuman → tersimpan semua', (
    tester,
  ) async {
    final chat = FakeChat()
      ..onboardReplies.addAll([
        answer({
          'action': 'selesai',
          'reply': 'Sip, ini rangkuman obrolan kita. Cek dulu ya.',
          'chips': [],
          'step': 5,
          // AI lupa membawa nama → nama dari HP tetap dipakai.
          'profile': {...profile, 'name': ''},
        }),
      ]);
    final router = await pump(tester, chat);
    expect(find.textContaining('Mau dipanggil siapa?'), findsOneWidget);
    expect(find.text('Langkah 1 dari 5'), findsOneWidget);

    await type(tester, 'aku frans');
    // Nama dibaca di HP, AI belum dipanggil.
    expect(chat.sent, isEmpty);
    expect(
      find.text('Hai Frans! Uang kamu biasanya dari mana?'),
      findsOneWidget,
    );
    expect(find.text('Langkah 2 dari 5'), findsOneWidget);
    expect(find.text('Gaji bulanan'), findsOneWidget);

    await tester.tap(find.text('Gaji bulanan'));
    await tester.pumpAndSettle();
    // Riwayat dikirim lengkap: sapaan bot, nama, jawaban bot, pilihan cepat.
    expect(chat.sent.last.map((t) => t.text), [
      'Halo! Aku yang bantu siapin catat. kamu. Mau dipanggil siapa?',
      'aku frans',
      'Hai Frans! Uang kamu biasanya dari mana?',
      'Gaji bulanan',
    ]);
    expect(find.text('Langkah 5 dari 5'), findsOneWidget);
    expect(find.text('Gaji Rp 6,5jt · tgl 25'), findsOneWidget);
    expect(find.text('Rp 2.000.000'), findsOneWidget);
    expect(find.text('Wajib 50%'), findsOneWidget);
    expect(find.text('Cicilan HP'), findsOneWidget);

    await tester.tap(find.text('Mulai pakai catat.'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/privasi-awal');

    final budget = BudgetRepository(db, () => now);
    final home = await tester.runAsync(budget.loadHome);
    expect(home!.userName, 'Frans');
    expect(home.salary, 6500000);
    expect(home.remaining, 2000000);
    final bills = await tester.runAsync(
      BillRepository(db, budget, () => now).loadBills,
    );
    expect(bills!.map((b) => (b.name, b.kind)), [
      ('Kos', BillKind.rutin),
      ('Cicilan HP', BillKind.cicilan),
    ]);
  });

  testWidgets('AI tidak bisa dipakai → ajak isi formulir', (tester) async {
    final router = await pump(tester, FakeChat(session: false));
    expect(find.textContaining('Daftar pakai formulir aja'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Isi formulir').last);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/sumber-uang');
  });

  testWidgets('sinyal putus saat kirim: pesan tetap, bisa kirim ulang', (
    tester,
  ) async {
    final chat = FakeChat()
      ..onboardReplies.add(const OnboardProblem(ChatOffline()));
    await pump(tester, chat);
    await type(tester, 'Frans');
    await type(tester, 'Gaji bulanan');
    expect(find.textContaining('Sinyalnya putus'), findsOneWidget);
    expect(find.text('Gaji bulanan'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
  });
}
