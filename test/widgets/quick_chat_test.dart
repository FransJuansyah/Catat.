import 'package:catat/core/theme/app_theme.dart';
import 'package:catat/data/chat_assistant.dart';
import 'package:catat/data/local/database.dart';
import 'package:catat/data/providers.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/chat_reply.dart';
import 'package:catat/domain/home_summary.dart';
import 'package:catat/domain/pro.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/features/quick/quick_note_screen.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// AI palsu: jawaban diantre, permintaan dicatat.
class FakeChat implements ChatAssistant {
  FakeChat({this.online = true});

  bool online;
  final replies = <ChatOutcome>[];
  final sent = <List<ChatTurn>>[];

  @override
  Future<bool> isOnline() async => online;

  @override
  Future<ChatOutcome> send({
    required List<ChatTurn> turns,
    required List<PocketView> pockets,
    required DateTime today,
  }) async {
    sent.add(turns);
    return replies.removeAt(0);
  }
}

/// Layar 60, 65–67: kalimat jelas dibaca di HP, yang tidak jelas ke chat AI.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late AppDatabase db;
  final now = DateTime(2026, 10, 6, 10);

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await BudgetRepository(db, () => now).setupBudget(
      netSalary: 5000000,
      payday: 5,
      template: PocketTemplates.klasik,
    );
  });
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester,
    FakeChat chat, {
    bool pro = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2436);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
        chatAssistantProvider.overrideWithValue(chat),
        proStatusProvider.overrideWith(
          (ref) => Stream.value(
            pro
                ? ProStatus(trialStart: now, now: now)
                : ProStatus(trialStart: DateTime(2026, 1, 1), now: now),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const QuickNoteScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
  }

  testWidgets('kalimat jelas dibaca di HP, tanpa AI', (tester) async {
    final chat = FakeChat();
    await pump(tester, chat);
    await type(tester, 'kopi susu 25rb');
    expect(find.text('Kebaca 1 catatan'), findsOneWidget);
    expect(chat.sent, isEmpty);
  });

  testWidgets('tidak jelas → bot tanya balik → jawaban nyambung → tercatat', (
    tester,
  ) async {
    final chat = FakeChat()
      ..replies.addAll([
        const ChatAnswered(
          AssistantReply(action: ChatAction.tanya, reply: 'Kopinya berapa?'),
        ),
        const ChatAnswered(
          AssistantReply(
            action: ChatAction.catat,
            reply: 'Siap, kopi 25rb kucatat.',
            notes: [
              AiNote(
                income: false,
                amount: 25000,
                title: 'Kopi',
                pocketName: 'Keinginan',
              ),
            ],
          ),
        ),
      ]);
    await pump(tester, chat);
    await type(tester, 'beli kopi');
    expect(find.text('Kopinya berapa?'), findsOneWidget);
    expect(find.text('Jawab di sini…'), findsOneWidget);

    // "25rb" sendiri akan terbaca HP sebagai "Pengeluaran 25rb"; karena bot
    // sedang bertanya, jawabannya harus dikirim ke AI bersama konteksnya.
    await type(tester, '25rb');
    expect(chat.sent, hasLength(2));
    expect(chat.sent.last.map((t) => (t.fromUser, t.text)), [
      (true, 'beli kopi'),
      (false, 'Kopinya berapa?'),
      (true, '25rb'),
    ]);
    expect(find.text('Kebaca 1 catatan'), findsOneWidget);
    expect(find.text('Kopi'), findsOneWidget);
    expect(find.text('Keinginan'), findsWidgets);
    expect(find.text('Simpan 1 catatan'), findsOneWidget);
    expect(
      find.text('Siap, cek dulu ya. Udah pas? Ketuk Simpan.'),
      findsOneWidget,
    );
  });

  testWidgets('tanpa internet: penjelasan singkat + tombol Manual', (
    tester,
  ) async {
    final chat = FakeChat(online: false)..replies.add(const ChatOffline());
    await pump(tester, chat);
    expect(find.textContaining('Lagi offline.'), findsOneWidget);
    await type(tester, 'beli kopi');
    expect(find.textContaining('Nggak ada koneksi'), findsOneWidget);
    expect(find.text('Pakai Manual'), findsOneWidget);
    // Kalimat jelas tetap tercatat walau offline.
    await type(tester, 'kopi 25rb');
    expect(find.text('Kebaca 1 catatan'), findsOneWidget);
  });

  testWidgets('di luar urusan uang: bot menolak', (tester) async {
    final chat = FakeChat()
      ..replies.add(
        const ChatAnswered(
          AssistantReply(
            action: ChatAction.tolak,
            reply: 'Aku cuma bisa bantu catat uang keluar & masuk.',
          ),
        ),
      );
    await pump(tester, chat);
    await type(tester, 'besok hujan nggak');
    expect(
      find.text('Aku cuma bisa bantu catat uang keluar & masuk.'),
      findsOneWidget,
    );
    expect(find.textContaining('Simpan'), findsNothing);
  });

  testWidgets('belum Pro: tidak ke AI, diajak buka Pro', (tester) async {
    final chat = FakeChat(online: false);
    await pump(tester, chat, pro: false);
    expect(find.textContaining('Lagi offline.'), findsNothing);
    await type(tester, 'beli kopi');
    expect(chat.sent, isEmpty);
    expect(find.text('Berapa nominalnya?'), findsOneWidget);
    expect(find.textContaining('Buka catat. Pro'), findsOneWidget);
  });

  testWidgets('jatah habis & belum masuk akun', (tester) async {
    final chat = FakeChat()
      ..replies.addAll([const ChatLimit(50), const ChatNeedsLogin()]);
    await pump(tester, chat);
    await type(tester, 'beli kopi');
    expect(find.textContaining('udah habis (50 pesan)'), findsOneWidget);
    await type(tester, 'beli roti');
    expect(find.text('Masuk akun'), findsOneWidget);
  });
}
