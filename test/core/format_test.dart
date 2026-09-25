import 'package:catat/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rupiah penuh pakai titik ribuan', () {
    expect(rupiah(2180000), 'Rp 2.180.000');
    expect(rupiah(0), 'Rp 0');
  });

  test('rupiah singkat', () {
    expect(rupiahShort(450000), 'Rp 450rb');
    expect(rupiahShort(1300000), 'Rp 1,3jt');
    expect(rupiahShort(1950000), 'Rp 1,95jt');
    expect(rupiahShort(3000000), 'Rp 3jt');
    expect(rupiahShort(800), 'Rp 800');
  });
}
