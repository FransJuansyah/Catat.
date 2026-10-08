/// Daftar sambil ngobrol dengan AI (layar 74–75): profil yang dikumpulkan &
/// jawaban server (supabase/functions/catat-chat, mode 'daftar').
library;

import 'chat_reply.dart';
import 'templates.dart';
import 'types.dart';

/// Isian daftar dari obrolan. Yang belum diketahui: string kosong / 0,
/// [balance] −1.
class OnboardProfile {
  const OnboardProfile({
    this.name = '',
    this.mode,
    this.amount = 0,
    this.frequency,
    this.payday = 0,
    this.weekday = 0,
    this.estimate = 0,
    this.balance = -1,
    this.template,
    this.bills = const [],
  });

  final String name;
  final IncomeMode? mode;

  /// Gaji per bulan / uang jajan per siklus.
  final int amount;
  final IncomeFrequency? frequency;

  /// Tanggal gajian / uang jajan bulanan (1–31), 0 = belum.
  final int payday;

  /// Hari uang jajan mingguan (1 = Senin), 0 = belum.
  final int weekday;

  /// Perkiraan sebulan (penghasilan tidak tetap).
  final int estimate;

  /// Uang sekarang; −1 = belum ditanya.
  final int balance;
  final PocketTemplate? template;
  final List<AiBill> bills;

  static const _modes = {
    'gaji': IncomeMode.salary,
    'jajan': IncomeMode.allowance,
    'tidak_tentu': IncomeMode.irregular,
  };
  static const _freq = {
    'harian': IncomeFrequency.daily,
    'mingguan': IncomeFrequency.weekly,
    'bulanan': IncomeFrequency.monthly,
  };
  static const _templates = {
    'klasik': PocketTemplates.klasik,
    'anak_kos': PocketTemplates.anakKos,
    'pejuang_nabung': PocketTemplates.pejuangNabung,
    'pelajar': PocketTemplates.pelajar,
    'freelancer': PocketTemplates.freelancer,
  };

  factory OnboardProfile.fromJson(Map<String, dynamic> j) {
    int n(String k, [int fallback = 0]) => (j[k] as num?)?.round() ?? fallback;
    return OnboardProfile(
      name: (j['name'] as String? ?? '').trim(),
      mode: _modes[j['mode']],
      amount: n('amount').clamp(0, 100000000000),
      frequency: _freq[j['frequency']],
      payday: n('payday').clamp(0, 31),
      weekday: n('weekday').clamp(0, 7),
      estimate: n('estimate').clamp(0, 100000000000),
      balance: n('balance', -1).clamp(-1, 100000000000),
      template: _templates[j['template']],
      bills: AiBill.listFrom(j['bills']),
    );
  }

  /// Template kantong: pilihan AI, selain itu default tipe pemasukan.
  PocketTemplate get pocketTemplate =>
      template ?? PocketTemplates.forMode(mode ?? IncomeMode.salary).first;

  IncomeFrequency get cycle => mode == IncomeMode.salary
      ? IncomeFrequency.monthly
      : frequency ?? IncomeFrequency.monthly;

  /// Sudah cukup untuk mulai pakai (tombol "Mulai pakai catat.").
  bool get complete =>
      name.isNotEmpty &&
      mode != null &&
      (mode == IncomeMode.irregular || amount > 0) &&
      balance >= 0;
}

/// Jawaban AI saat daftar.
class OnboardReply {
  const OnboardReply({
    required this.done,
    required this.reply,
    required this.profile,
    this.chips = const [],
    this.step = 1,
    this.offTopic = false,
  });

  /// AI sudah selesai bertanya → tampilkan ringkasan (layar 75).
  final bool done;
  final String reply;
  final List<String> chips;

  /// Pertanyaan ke berapa (1–5) untuk "Langkah n dari 5".
  final int step;
  final OnboardProfile profile;
  final bool offTopic;

  factory OnboardReply.fromJson(Map<String, dynamic> j) {
    final p = j['profile'];
    final profile = p is Map
        ? OnboardProfile.fromJson(Map<String, dynamic>.from(p))
        : const OnboardProfile();
    final chips = j['chips'];
    return OnboardReply(
      done: j['action'] == 'selesai' && profile.complete,
      offTopic: j['action'] == 'tolak',
      reply: (j['reply'] as String? ?? '').trim().isEmpty
          ? 'Lanjut ya, ceritain lagi.'
          : (j['reply'] as String).trim(),
      chips: [
        for (final c in chips is List ? chips : const [])
          if (c is String && c.trim().isNotEmpty) c.trim(),
      ].take(3).toList(),
      step: ((j['step'] as num?)?.round() ?? 1).clamp(1, 5),
      profile: profile,
    );
  }
}
