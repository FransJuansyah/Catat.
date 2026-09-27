import 'package:supabase_flutter/supabase_flutter.dart';

import '../sync/sync_remote.dart';

/// Server sinkron di Supabase: tabel `sync_rows` + fungsi `push_rows` &
/// `delete_my_account` (supabase/migrations). RLS: hanya baris sendiri.
class SupabaseSyncRemote implements SyncRemote {
  SupabaseSyncRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<void> push(List<RemoteRow> rows) => _client.rpc(
    'push_rows',
    params: {
      'rows': [
        for (final r in rows)
          {
            'table': r.table,
            'id': r.id,
            'data': r.data,
            'changed_at': r.changedAt,
            'deleted': r.deleted,
          },
      ],
    },
  );

  @override
  Future<List<RemoteRow>> pull(int afterRev, {int limit = 500}) async {
    final rows = await _client
        .from('sync_rows')
        .select('table_name, id, data, changed_at, deleted, rev')
        .gt('rev', afterRev)
        .order('rev')
        .limit(limit);
    return [
      for (final r in rows)
        RemoteRow(
          table: r['table_name'] as String,
          id: r['id'] as String,
          data: (r['data'] as Map?)?.cast<String, Object?>(),
          changedAt: (r['changed_at'] as num).toInt(),
          deleted: r['deleted'] as bool,
          rev: (r['rev'] as num).toInt(),
        ),
    ];
  }

  @override
  Future<bool> hasData() async =>
      (await _client.from('sync_rows').select('id').limit(1)).isNotEmpty;

  @override
  Future<void> deleteAccount() async {
    await _client.rpc<void>('delete_my_account');
    await _client.auth.signOut(scope: SignOutScope.local);
  }
}
