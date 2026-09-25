import 'package:catat/core/format.dart';
import 'package:catat/data/demo_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('format rupiah penuh', () {
    expect(rupiah(2180000), 'Rp 2.180.000');
    expect(rupiah(6500000), 'Rp 6.500.000');
  });

  test('format rupiah singkat', () {
    expect(rupiahShort(450000), 'Rp 450rb');
    expect(rupiahShort(1300000), 'Rp 1,3jt');
    expect(rupiahShort(1950000), 'Rp 1,95jt');
    expect(rupiahShort(3000000), 'Rp 3jt');
  });

  test('sisa duit = total sisa 3 kantong (sesuai desain)', () {
    expect(DemoData.remaining, 2180000);
  });
}
