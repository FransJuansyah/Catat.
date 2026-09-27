/// Satu baris data di akun (F8). Disimpan per tabel sebagai dokumen JSON,
/// jadi perubahan skema lokal tidak butuh migrasi SQL di server.
class RemoteRow {
  const RemoteRow({
    required this.table,
    required this.id,
    required this.data,
    required this.changedAt,
    this.deleted = false,
    this.rev = 0,
  });

  final String table;
  final String id;

  /// Kolom SQLite apa adanya (nama snake_case, tanggal = detik unix).
  /// null kalau [deleted].
  final Map<String, Object?>? data;

  /// Waktu perubahan di HP (detik unix): yang terakhir menang.
  final int changedAt;
  final bool deleted;

  /// Nomor urut dari server, naik tiap baris berubah (kursor tarik).
  final int rev;
}

/// Server sinkron. Implementasi asli: Supabase; di test: server palsu.
abstract class SyncRemote {
  /// Kirim perubahan. Server hanya menimpa kalau [RemoteRow.changedAt] tidak
  /// lebih lama dari yang tersimpan.
  Future<void> push(List<RemoteRow> rows);

  /// Perubahan dengan rev > [afterRev], urut rev, maksimal [limit] baris.
  Future<List<RemoteRow>> pull(int afterRev, {int limit = 500});

  /// Akun sudah punya data (login di HP kedua / setelah ganti HP).
  Future<bool> hasData();

  /// Hapus semua data & akun (Play Store: hapus akun dari dalam app).
  Future<void> deleteAccount();
}
