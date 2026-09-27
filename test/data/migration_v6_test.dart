import 'dart:io';

import 'package:catat/data/local/database.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/data/sync/sync_engine.dart';
import 'package:catat/domain/templates.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_engine_test.dart' show FakeRemote;

/// HP yang sudah dipakai (schema v5) update ke app F8 (v6): data utuh,
/// trigger antrian sinkron langsung jalan.
void main() {
  test('migrasi v5 → v7', () async {
    final dir = await Directory.systemTemp.createTemp('catat_mig');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/catat.sqlite');
    final now = DateTime(2026, 9, 27, 10);

    // "App lama": data + buang semua jejak v6.
    var db = AppDatabase(NativeDatabase(file));
    var repo = BudgetRepository(db, () => now);
    await repo.setupBudget(
      netSalary: 6500000,
      payday: 25,
      template: PocketTemplates.klasik,
    );
    final k = (await repo.loadPocketSetup()).pockets.last;
    await repo.addExpense(pocketId: k.id, amount: 45000, title: 'Makan');
    final before = (await repo.loadHome()).remaining;
    for (final t in syncedTables) {
      for (final op in ['insert', 'update', 'delete']) {
        await db.customStatement('DROP TRIGGER sync_${t}_$op');
      }
    }
    for (final c in ['trial_started_at', 'pro_purchased_at', 'pro_token']) {
      await db.customStatement('ALTER TABLE profiles DROP COLUMN $c');
    }
    await db.customStatement('DROP TABLE sync_outbox');
    await db.customStatement('DROP TABLE sync_meta');
    await db.customStatement('PRAGMA user_version = 5');
    await db.close();

    // "App baru".
    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    repo = BudgetRepository(db, () => now);
    expect((await repo.loadHome()).remaining, before);
    final sync = SyncEngine(db, FakeRemote());
    // User lama dapat trial 7 hari dari update (v7).
    final profile = await db.select(db.profiles).getSingle();
    expect(profile.trialStartedAt, isNotNull);
    expect(profile.proPurchasedAt, isNull);
    await db.delete(db.syncOutbox).go();
    await repo.addExpense(pocketId: k.id, amount: 5000, title: 'Parkir');
    expect(await sync.pendingCount(), greaterThan(0));
    await sync.enqueueAll();
    await sync.sync();
    expect(await sync.pendingCount(), 0);
  });
}
