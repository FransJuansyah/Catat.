import 'package:catat/domain/chat_reply.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catat: catatan keluar & masuk dari jawaban server', () {
    final r = AssistantReply.fromJson({
      'action': 'catat',
      'reply': 'Siap, 2 catatan.',
      'notes': [
        {
          'kind': 'keluar',
          'amount': 25000,
          'title': 'Kopi susu',
          'pocket': 'Keinginan',
          'days_ago': 1,
        },
        {
          'kind': 'masuk',
          'amount': 150000,
          'title': 'Dimas bayar utang',
          'pocket': 'Wajib',
          'days_ago': 0,
        },
      ],
      'remaining': 48,
    });
    expect(r.action, ChatAction.catat);
    expect(r.notes, hasLength(2));
    expect(r.notes.first.pocketName, 'Keinginan');
    expect(r.notes.first.daysAgo, 1);
    // Uang masuk tidak masuk kantong mana pun.
    expect(r.notes.last.income, isTrue);
    expect(r.notes.last.pocketName, isNull);
    expect(r.remaining, 48);
  });

  test('catat tanpa catatan sah = masih bertanya', () {
    final r = AssistantReply.fromJson({
      'action': 'catat',
      'reply': '',
      'notes': [
        {'kind': 'keluar', 'amount': 0, 'title': 'Kopi'},
      ],
    });
    expect(r.action, ChatAction.tanya);
    expect(r.notes, isEmpty);
    expect(r.reply, isNotEmpty);
  });

  test('jawaban rusak tidak bikin error', () {
    final r = AssistantReply.fromJson({'action': 'apa', 'notes': 'x'});
    expect(r.action, ChatAction.tanya);
    expect(r.notes, isEmpty);
  });

  test('giliran obrolan dikirim sebagai role user/assistant', () {
    expect(const ChatTurn.user('beli kopi').toJson(), {
      'role': 'user',
      'text': 'beli kopi',
    });
    expect(const ChatTurn.bot('Berapa?').toJson()['role'], 'assistant');
  });
}
