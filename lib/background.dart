import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'data/auto_capture.dart';
import 'data/auto_record.dart';
import 'data/local/database.dart';
import 'data/pro_store.dart';
import 'data/repositories/budget_repository.dart';

/// Titik masuk mesin Flutter latar belakang (tanpa UI) untuk catat otomatis.
/// Dijalankan Android (BackgroundRecorder.kt) saat notifikasi bank masuk dan
/// aplikasi tidak perlu dibuka.
Future<void> runAutoRecorder() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  final repo = BudgetRepository(db, DateTime.now);
  final pro = ProRepository(db, DateTime.now);
  const channel = MethodChannel('id.catat.catat/background');
  channel.setMethodCallHandler((call) async {
    final args = call.arguments as Map<Object?, Object?>;
    switch (call.method) {
      case 'record':
        final t = detectedFromMap(args);
        if (t == null) return null; // bukan transaksi → Android diam
        // Catat otomatis = fitur Pro: trial habis & belum beli → diam.
        if (!(await pro.status()).unlocked) return null;
        try {
          final matched = {
            for (final id in (args['matched'] as List<Object?>? ?? const []))
              id! as String,
          };
          return (await recordDetected(repo, t, matched: matched))?.toMap();
        } catch (e, st) {
          debugPrint('catat.auto: gagal mencatat: $e\n$st');
          rethrow;
        }
      case 'undo':
        await undoRecord(
          repo,
          args['id']! as String,
          income: args['income'] == true,
        );
        return true;
    }
    throw MissingPluginException(call.method);
  });
  await channel.invokeMethod<void>('ready');
}
