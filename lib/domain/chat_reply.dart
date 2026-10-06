/// Chat AI pencatat (layar 65–67): giliran obrolan & jawaban server
/// (supabase/functions/catat-chat).
library;

/// Satu giliran obrolan yang dikirim ke AI.
class ChatTurn {
  const ChatTurn.user(this.text) : fromUser = true;
  const ChatTurn.bot(this.text) : fromUser = false;

  final bool fromUser;
  final String text;

  Map<String, String> toJson() => {
    'role': fromUser ? 'user' : 'assistant',
    'text': text,
  };
}

enum ChatAction {
  /// Info lengkap → catatan siap disimpan.
  catat,

  /// Info kurang → bot bertanya balik.
  tanya,

  /// Bukan urusan catat uang.
  tolak,
}

/// Satu catatan dari AI. [pocketName] = nama kantong (null untuk uang masuk
/// atau kalau AI tidak yakin).
class AiNote {
  const AiNote({
    required this.income,
    required this.amount,
    required this.title,
    this.pocketName,
    this.daysAgo = 0,
  });

  final bool income;
  final int amount;
  final String title;
  final String? pocketName;
  final int daysAgo;
}

class AssistantReply {
  const AssistantReply({
    required this.action,
    required this.reply,
    this.notes = const [],
    this.remaining,
  });

  final ChatAction action;
  final String reply;
  final List<AiNote> notes;

  /// Sisa jatah pesan AI hari ini.
  final int? remaining;

  /// Baca jawaban server dengan hati-hati: field aneh dibuang, bukan error.
  factory AssistantReply.fromJson(Map<String, dynamic> json) {
    final notes = <AiNote>[];
    final rawNotes = json['notes'];
    for (final raw in rawNotes is List ? rawNotes : const []) {
      if (raw is! Map) continue;
      final amount = (raw['amount'] as num?)?.round() ?? 0;
      final title = (raw['title'] as String? ?? '').trim();
      if (amount <= 0) continue;
      final income = raw['kind'] == 'masuk';
      notes.add(
        AiNote(
          income: income,
          amount: amount,
          title: title.isEmpty ? (income ? 'Pemasukan' : 'Pengeluaran') : title,
          pocketName: income ? null : raw['pocket'] as String?,
          daysAgo: ((raw['days_ago'] as num?)?.round() ?? 0).clamp(0, 60),
        ),
      );
    }
    var action =
        ChatAction.values.where((a) => a.name == json['action']).firstOrNull ??
        ChatAction.tanya;
    // "catat" tanpa catatan yang sah = belum lengkap.
    if (action == ChatAction.catat && notes.isEmpty) action = ChatAction.tanya;
    final reply = (json['reply'] as String? ?? '').trim();
    return AssistantReply(
      action: action,
      reply: reply.isNotEmpty
          ? reply
          : switch (action) {
              ChatAction.catat => 'Siap, ini catatannya.',
              ChatAction.tanya => 'Bisa jelasin lagi? Buat apa dan berapa?',
              ChatAction.tolak =>
                'Aku cuma bisa bantu catat uang keluar & masuk.',
            },
      notes: action == ChatAction.catat ? notes : const [],
      remaining: (json['remaining'] as num?)?.toInt(),
    );
  }
}
