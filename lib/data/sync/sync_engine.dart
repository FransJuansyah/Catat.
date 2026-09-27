import 'package:drift/drift.dart';

import '../local/database.dart';
import 'sync_remote.dart';

/// Hasil satu kali sinkron (untuk status di layar Akun).
class SyncReport {
  const SyncReport({this.pushed = 0, this.pulled = 0});

  final int pushed;
  final int pulled;
}

/// Sinkron local-first (F8): perubahan lokal dicatat trigger ke
/// `sync_outbox` → [push]; perubahan dari HP lain → [pull].
///
/// Konflik: "yang terakhir menang" per baris. Baris yang masih menunggu
/// dikirim dari HP ini tidak ditimpa data akun (akan dikirim & menang).
class SyncEngine {
  SyncEngine(this._db, this._remote);

  final AppDatabase _db;
  final SyncRemote _remote;

  static const _revKey = 'last_rev';
  static const _lastSyncKey = 'last_sync';
  static const _pushBatch = 200;

  /// Kirim dulu, baru tarik.
  Future<SyncReport> sync() async {
    final pushed = await push();
    final pulled = await pull();
    await _setMeta(_lastSyncKey, '${DateTime.now().millisecondsSinceEpoch}');
    return SyncReport(pushed: pushed, pulled: pulled);
  }

  /// Terakhir sinkron berhasil (layar 49).
  Future<DateTime?> lastSyncAt() async {
    final ms = int.tryParse(await _meta(_lastSyncKey) ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Jumlah perubahan yang belum terkirim.
  Future<int> pendingCount() async {
    final count = _db.syncOutbox.rowId.count();
    final row = await (_db.selectOnly(_db.syncOutbox)..addColumns([count]))
        .getSingle();
    return row.read(count) ?? 0;
  }

  Stream<int> watchPending() {
    final count = _db.syncOutbox.rowId.count();
    return (_db.selectOnly(_db.syncOutbox)..addColumns([count]))
        .watchSingle()
        .map((r) => r.read(count) ?? 0);
  }

  // ------------------------------------------------------------------ push

  Future<int> push() async {
    var total = 0;
    while (true) {
      final batch =
          await (_db.select(_db.syncOutbox)
                ..orderBy([(t) => OrderingTerm.asc(t.seq)])
                ..limit(_pushBatch))
              .get();
      if (batch.isEmpty) return total;
      final rows = <RemoteRow>[];
      for (final o in batch) {
        final data = await _readRow(o.tableName_, o.rowId);
        rows.add(
          RemoteRow(
            table: o.tableName_,
            id: o.rowId,
            data: data,
            changedAt: o.changedAt,
            deleted: data == null,
          ),
        );
      }
      await _remote.push(rows);
      // Hapus hanya yang tidak berubah lagi selama dikirim.
      await _db.transaction(() async {
        for (final o in batch) {
          await (_db.delete(_db.syncOutbox)..where(
                (t) =>
                    t.tableName_.equals(o.tableName_) &
                    t.rowId.equals(o.rowId) &
                    t.seq.equals(o.seq),
              ))
              .go();
        }
      });
      total += batch.length;
    }
  }

  Future<Map<String, Object?>?> _readRow(String table, String id) async {
    _checkTable(table);
    final rows = await _db
        .customSelect(
          'SELECT * FROM $table WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    return rows.isEmpty ? null : Map.of(rows.first.data);
  }

  /// Semua baris lokal masuk antrian (login pertama, akun masih kosong:
  /// data yang sudah ada di HP ikut tersimpan ke akun).
  Future<void> enqueueAll() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _db.transaction(() async {
      var seq = 0;
      for (final t in syncedTables) {
        final ids = await _db.customSelect('SELECT id FROM $t').get();
        for (final r in ids) {
          await _db
              .into(_db.syncOutbox)
              .insertOnConflictUpdate(
                SyncOutboxCompanion.insert(
                  tableName_: t,
                  rowId: r.read<String>('id'),
                  seq: ++seq,
                  changedAt: now,
                ),
              );
        }
      }
    });
  }

  // ------------------------------------------------------------------ pull

  Future<int> pull() async {
    var total = 0;
    var rev = await _lastRev();
    while (true) {
      final rows = await _remote.pull(rev);
      if (rows.isEmpty) return total;
      await _apply(rows);
      rev = rows.map((r) => r.rev).reduce((a, b) => a > b ? a : b);
      await _setMeta(_revKey, '$rev');
      total += rows.length;
    }
  }

  Future<void> _apply(List<RemoteRow> rows) async {
    final ordered = [...rows]
      ..sort((a, b) {
        final byTable = syncedTables
            .indexOf(a.table)
            .compareTo(syncedTables.indexOf(b.table));
        return byTable != 0 ? byTable : a.rev.compareTo(b.rev);
      });
    await _db.transaction(() async {
      // Anak bisa datang sebelum induknya → cek FK saat commit saja.
      await _db.customStatement('PRAGMA defer_foreign_keys = ON');
      for (final r in ordered) {
        if (!syncedTables.contains(r.table)) continue; // tabel versi baru
        if (await _pendingLocally(r.table, r.id)) continue;
        // Bentrok kunci unik dengan baris lokal ber-id lain: rapikan dulu
        // (perubahan ini ikut antrian supaya HP lain juga tahu).
        if (!r.deleted) await _resolveUnique(r);
        await _setMeta('applying', '1');
        try {
          if (r.deleted) {
            await _db.customStatement(
              'UPDATE ${r.table} SET deleted_at = ? WHERE id = ? '
              'AND deleted_at IS NULL',
              [DateTime.now().millisecondsSinceEpoch ~/ 1000, r.id],
            );
          } else {
            await _upsert(r.table, r.data!);
          }
        } finally {
          await _setMeta('applying', '0');
        }
      }
    });
    // Tulisan lewat SQL mentah tidak memicu stream drift → kabari layar.
    _db.markTablesUpdated(_db.allTables);
  }

  Future<bool> _pendingLocally(String table, String id) async =>
      await (_db.select(_db.syncOutbox)..where(
            (t) => t.tableName_.equals(table) & t.rowId.equals(id),
          ))
          .getSingleOrNull() !=
      null;

  final _columns = <String, Set<String>>{};

  Future<void> _upsert(String table, Map<String, Object?> data) async {
    _checkTable(table);
    final known = _columns[table] ??= {
      for (final r in await _db.customSelect('PRAGMA table_info($table)').get())
        r.read<String>('name'),
    };
    // Kolom dari versi app lain yang tidak dikenal HP ini dilewati.
    final cols = [
      for (final c in data.keys)
        if (known.contains(c)) c,
    ];
    if (!cols.contains('id')) return;
    final updates = [
      for (final c in cols)
        if (c != 'id') '$c = excluded.$c',
    ];
    await _db.customStatement(
      'INSERT INTO $table (${cols.join(', ')}) '
      'VALUES (${List.filled(cols.length, '?').join(', ')}) '
      'ON CONFLICT (id) DO '
      '${updates.isEmpty ? 'NOTHING' : 'UPDATE SET ${updates.join(', ')}'}',
      [for (final c in cols) data[c]],
    );
  }

  /// Kunci unik selain id: periode per tanggal mulai, satu jatah per
  /// (periode, kantong), satu bagian per (pemasukan, kantong).
  Future<void> _resolveUnique(RemoteRow r) async {
    final d = r.data!;
    switch (r.table) {
      case 'periods':
        final old = await _db
            .customSelect(
              'SELECT id FROM periods WHERE start_date = ? AND id != ?',
              variables: [
                Variable(d['start_date']),
                Variable.withString(r.id),
              ],
            )
            .getSingleOrNull();
        if (old == null) return;
        final from = old.read<String>('id');
        // Baris periode akun dulu, baru anak-anaknya dipindah ke sana.
        await _setMeta('applying', '1');
        await _db.customStatement(
          'UPDATE periods SET start_date = start_date - 1 WHERE id = ?',
          [from],
        );
        await _upsert('periods', d);
        await _setMeta('applying', '0');
        for (final (table, col) in const [
          ('expenses', 'period_id'),
          ('incomes', 'period_id'),
          ('transfers', 'period_id'),
          ('transfers', 'to_period_id'),
        ]) {
          await _db.customStatement(
            'UPDATE $table SET $col = ? WHERE $col = ?',
            [r.id, from],
          );
        }
        await _db.customStatement(
          'DELETE FROM period_allocations WHERE period_id = ?',
          [from],
        );
        await _db.customStatement('DELETE FROM periods WHERE id = ?', [from]);
      case 'period_allocations':
        await _db.customStatement(
          'DELETE FROM period_allocations '
          'WHERE period_id = ? AND pocket_id = ? AND id != ?',
          [d['period_id'], d['pocket_id'], r.id],
        );
      case 'income_allocations':
        await _db.customStatement(
          'DELETE FROM income_allocations '
          'WHERE income_id = ? AND pocket_id = ? AND id != ?',
          [d['income_id'], d['pocket_id'], r.id],
        );
    }
  }

  // ----------------------------------------------------------------- akun

  /// Keluar / hapus akun: kosongkan semua data di HP ini tanpa masuk antrian.
  Future<void> wipeLocal() async {
    await _db.transaction(() async {
      await _setMeta('applying', '1');
      await _db.customStatement('PRAGMA defer_foreign_keys = ON');
      for (final t in syncedTables.reversed) {
        await _db.customStatement('DELETE FROM $t');
      }
      await _db.delete(_db.syncOutbox).go();
      await _db.delete(_db.syncMeta).go();
    });
    _db.markTablesUpdated(_db.allTables);
  }

  Future<void> deleteAccount() async {
    await _remote.deleteAccount();
    await wipeLocal();
  }

  // ------------------------------------------------------------------ meta

  Future<int> _lastRev() async =>
      int.tryParse(await _meta(_revKey) ?? '') ?? 0;

  Future<String?> _meta(String key) async =>
      (await (_db.select(
        _db.syncMeta,
      )..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  Future<void> _setMeta(String key, String value) => _db
      .into(_db.syncMeta)
      .insertOnConflictUpdate(SyncMetaCompanion.insert(key: key, value: value));

  static void _checkTable(String table) {
    if (!syncedTables.contains(table)) {
      throw ArgumentError.value(table, 'table');
    }
  }
}
