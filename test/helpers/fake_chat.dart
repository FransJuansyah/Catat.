import 'package:catat/data/chat_assistant.dart';
import 'package:catat/domain/chat_reply.dart';
import 'package:catat/domain/home_summary.dart';

/// AI palsu: jawaban diantre, permintaan dicatat.
class FakeChat implements ChatAssistant {
  FakeChat({this.online = true, this.session = true});

  bool online;

  /// Akun tamu bisa dibuat (login anonim aktif).
  bool session;
  final replies = <ChatOutcome>[];
  final sent = <List<ChatTurn>>[];
  final onboardReplies = <OnboardOutcome>[];

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

  @override
  Future<bool> ensureSession() async => session;

  @override
  Future<OnboardOutcome> onboard({
    required List<ChatTurn> turns,
    required DateTime today,
  }) async {
    sent.add(turns);
    return onboardReplies.removeAt(0);
  }
}
