import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/chat_reply.dart';
import '../domain/home_summary.dart';
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
  Future<ChatOutcome> send({
    required List<ChatTurn> turns,
    required List<PocketView> pockets,
    required DateTime today,
  }) async {
    if (!cloudEnabled) return const ChatFailed();
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) return const ChatNeedsLogin();
    final day =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    try {
      final res = await client.functions.invoke(
        'catat-chat',
        body: {
          'messages': [for (final t in turns) t.toJson()],
          'pockets': [
            for (final p in pockets) {'name': p.name, 'type': p.type.name},
          ],
          'today': day,
          'v': 2, // + cicilan & tagihan
        },
        abortSignal: Future<void>.delayed(const Duration(seconds: 25)),
      );
      final data = res.data;
      if (data is! Map) return const ChatFailed();
      return ChatAnswered(
        AssistantReply.fromJson(Map<String, dynamic>.from(data)),
      );
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
}
