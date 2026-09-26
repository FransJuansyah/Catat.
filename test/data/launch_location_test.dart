import 'package:catat/data/auto_capture.dart';
import 'package:flutter_test/flutter_test.dart';

/// MainActivity bisa dipanggil aplikasi lain dengan aksi "buka rute": hanya
/// detail catatan yang boleh dibuka dari luar.
void main() {
  const id = '9385a7d1-ee9b-4d7d-b470-2965774d6424';

  test('detail catatan dari tombol "Ubah" boleh', () {
    expect(
      launchLocation(const RouteLaunch('/transaksi/$id')),
      '/transaksi/$id',
    );
    expect(
      launchLocation(const RouteLaunch('/pemasukan-masuk/$id')),
      '/pemasukan-masuk/$id',
    );
  });

  test('rute lain dari luar ditolak', () {
    for (final route in [
      '/atur-gaji',
      '/pilih-template',
      '/sesuaikan-saldo',
      '/privasi',
      '/transaksi/$id/../../atur-gaji',
      '/transaksi/$id?x=1',
      'https://contoh.id/transaksi/1',
      '',
    ]) {
      expect(launchLocation(RouteLaunch(route)), isNull, reason: route);
    }
  });
}
