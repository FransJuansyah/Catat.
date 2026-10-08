import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/chat_reply.dart';
import '../domain/home_summary.dart';
import '../domain/onboard_profile.dart';
import 'account.dart';

/// Hasil satu kali tanya ke chat AI.
sealed class ChatOutcome {
  const ChatOutcome();
}

class ChatAnswered extends ChatOutcome {
  const ChatAnswered(this.reply);
  final AssistantReply reply;
}

/// Tidak ada internet.
class ChatOffline extends ChatOutcome {
  const ChatOffline();
}

/// Chat AI butuh akun (batas harian per akun).
class ChatNeedsLogin extends ChatOutcome {
  const ChatNeedsLogin();
}

/// Jatah pesan AI hari ini habis.
class ChatLimit extends ChatOutcome {
  const ChatLimit(this.limit);
  final int limit;
}

/// Server/AI lagi gangguan atau belum diaktifkan.
class ChatFailed extends ChatOutcome {
  const ChatFailed();
}

/// Hasil satu kali tanya saat daftar pakai AI (layar 74–75).
sealed class OnboardOutcome {
  const OnboardOutcome();
}

class OnboardAnswered extends OnboardOutcome {
  const OnboardAnswered(this.reply);
  final OnboardReply reply;
}

/// Gagal (offline, jatah habis, server gangguan) — alasannya di [problem].
class OnboardProblem extends OnboardOutcome {
  const OnboardProblem(this.problem);
  final ChatOutcome problem;
}

/// Chat AI pencatat lewat edge function `catat-chat` (kunci AI di server).
/// Di-override di test.
abstract class ChatAssistant {
  /// Cek internet cepat (≤ 3 detik).
  Future<bool> isOnline();

  Future<ChatOutcome> send({
    required List<ChatTurn> turns,
    required List<PocketView> pockets,
    required DateTime today,
  });

  /// Pastikan ada sesi untuk AI: akun yang sedang masuk, atau akun tamu
  /// (anonim) untuk user baru yang sedang daftar. false = tidak bisa.
  Future<bool> ensureSession();

  /// Daftar sambil ngobrol: AI menanyakan data satu per satu.
  Future<OnboardOutcome> onboard({
    required List<ChatTurn> turns,
    required DateTime today,
  });
}

class SupabaseChatAssistant implements ChatAssistant {
  @override
  Future<bool> isOnline() async {
    if (!cloudEnabled) return false;
    final host = Uri.parse(supabaseUrl).host;
    // Dua kali coba: jaringan HP yang baru bangun kadang lambat menjawab.
    for (var i = 0; i < 2; i++) {
      try {
        final found = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 4));
        if (found.isNotEmpty) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> ensureSession() async {
    if (!cloudEnabled) return false;
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession != null) return true;
    try {
      await auth.signInAnonymously();
      return auth.currentSession != null;
    } catch (_) {
      // Login tamu belum dinyalakan di Supabase / offline.
      return false;
    }
  }

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Panggil fungsi `catat-chat`. Berhasil → Map jawaban; gagal → alasannya.
  Future<Object> _invoke(Map<String, Object?> body) async {
    if (!cloudEnabled) return const ChatFailed();
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) return const ChatNeedsLogin();
    try {
      final res = await client.functions.invoke(
        'catat-chat',
        body: body,
        abortSignal: Future<void>.delayed(const Duration(seconds: 25)),
      );
      final data = res.data;
      return data is Map ? Map<String, dynamic>.from(data) : const ChatFailed();
    } on FunctionException catch (e) {
      return switch (e.status) {
        401 => const ChatNeedsLogin(),
        429 => ChatLimit(
          (e.details is Map ? (e.details as Map)['limit'] as num? : null)
                  ?.toInt() ??
              50,
        ),
        _ => const ChatFailed(),
      };
    } on SocketException {
      return const ChatOffline();
    } on TimeoutException {
      return const ChatOffline();
    } catch (_) {
      // Mis. http.ClientException / RequestAbortedException saat sinyal hilang.
      return await isOnline() ? const ChatFailed() : const ChatOffline();
    }
  }

  @override
  Future<ChatOutcome> send({
    required List<ChatTurn> turns,
    required List<PocketView> pockets,
    required DateTime today,
  }) async {
    final r = await _invoke({
      'messages': [for (final t in turns) t.toJson()],
      'pockets': [
        for (final p in pockets) {'name': p.name, 'type': p.type.name},
      ],
      'today': _day(today),
      'v': 2, // + cicilan & tagihan
    });
    return r is Map<String, dynamic>
        ? ChatAnswered(AssistantReply.fromJson(r))
        : r as ChatOutcome;
  }

  @override
  Future<OnboardOutcome> onboard({
    required List<ChatTurn> turns,
    required DateTime today,
  }) async {
    final r = await _invoke({
      'mode': 'daftar',
      'messages': [for (final t in turns) t.toJson()],
      'today': _day(today),
    });
    return r is Map<String, dynamic>
        ? OnboardAnswered(OnboardReply.fromJson(r))
        : OnboardProblem(r as ChatOutcome);
  }
}
