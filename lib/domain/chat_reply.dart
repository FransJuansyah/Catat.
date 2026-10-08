/// Chat AI pencatat (layar 65–67): giliran obrolan & jawaban server
/// (supabase/functions/catat-chat).
library;

import 'installment.dart';

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

  /// Simulasi kredit barang (layar 72) → [AssistantReply.sim].
  cicilan,

  /// Tagihan/cicilan rutin baru (layar 73) → [AssistantReply.bills].
  tagihan,

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

/// Tagihan rutin dari AI. [remaining] null = rutin terus (kos, langganan).
class AiBill {
  const AiBill({
    required this.name,
    required this.amount,
    required this.dueDay,
    this.remaining,
    this.pocketName,
  });

  final String name;
  final int amount;
  final int dueDay;
  final int? remaining;
  final String? pocketName;

  static List<AiBill> listFrom(Object? raw) => [
    for (final b in raw is List ? raw : const [])
      if (b is Map &&
          (b['amount'] as num? ?? 0) > 0 &&
          (b['due_day'] as num? ?? 0) >= 1 &&
          (b['name'] as String? ?? '').trim().isNotEmpty)
        AiBill(
          name: (b['name'] as String).trim(),
          amount: (b['amount'] as num).round(),
          dueDay: (b['due_day'] as num).round().clamp(1, 31),
          remaining: (b['remaining'] as num?)?.round(),
          pocketName: b['pocket'] as String?,
        ),
  ];
}

class AssistantReply {
  const AssistantReply({
    required this.action,
    required this.reply,
    this.notes = const [],
    this.sim,
    this.bills = const [],
    this.remaining,
  });

  final ChatAction action;
  final String reply;
  final List<AiNote> notes;
  final InstallmentSim? sim;
  final List<AiBill> bills;

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
    final s = json['sim'];
    final sim = s is Map
        ? InstallmentSim(
            item: (s['item'] as String? ?? '').trim(),
            price: (s['price'] as num? ?? 0).round(),
            dp: (s['dp'] as num? ?? 0).round(),
            months: (s['months'] as num? ?? 0).round(),
            ratePercent: (s['rate'] as num? ?? 0).toDouble().clamp(0, 100),
            perYear: s['rate_per'] == 'tahun',
          )
        : null;
    final validSim = sim != null && sim.principal > 0 && sim.months > 0;
    if (action == ChatAction.cicilan && !validSim) action = ChatAction.tanya;
    final bills = AiBill.listFrom(json['bills']);
    if (action == ChatAction.tagihan && bills.isEmpty) {
      action = ChatAction.tanya;
    }
    final reply = (json['reply'] as String? ?? '').trim();
    return AssistantReply(
      action: action,
      reply: reply.isNotEmpty
          ? reply
          : switch (action) {
              ChatAction.catat => 'Siap, ini catatannya.',
              ChatAction.cicilan => 'Ini hitungannya.',
              ChatAction.tagihan => 'Siap, cek dulu ya.',
              ChatAction.tanya => 'Bisa jelasin lagi? Buat apa dan berapa?',
              ChatAction.tolak =>
                'Aku cuma bisa bantu catat uang keluar & masuk.',
            },
      notes: action == ChatAction.catat ? notes : const [],
      sim: action == ChatAction.cicilan ? sim : null,
      bills: action == ChatAction.tagihan ? bills : const [],
      remaining: (json['remaining'] as num?)?.toInt(),
    );
  }
}
