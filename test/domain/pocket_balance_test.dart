import 'package:catat/domain/pocket_balance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sisa = jatah + masuk − keluar − terpakai', () {
    const b = PocketBalance(
      allocation: 1950000,
      spent: 1660000,
      transferIn: 200000,
      transferOut: 0,
    );
    expect(b.available, 2150000);
    expect(b.remaining, 490000);
  });

  test('usedRatio aman untuk jatah 0 dan pengeluaran melebihi jatah', () {
    expect(const PocketBalance(allocation: 0).usedRatio, 0);
    expect(const PocketBalance(allocation: 0, spent: 5).usedRatio, 1);
    expect(const PocketBalance(allocation: 100, spent: 150).usedRatio, 1);
    expect(const PocketBalance(allocation: 100, spent: 150).remaining, -50);
  });

  test('peringatan hampir habis di bawah 20%', () {
    expect(
      const PocketBalance(allocation: 1950000, spent: 1660000).isLow(),
      isTrue,
    ); // sisa 15%
    expect(
      const PocketBalance(allocation: 1950000, spent: 1520000).isLow(),
      isFalse,
    ); // sisa 22%
  });

  test('on track membandingkan uang terpakai vs waktu berjalan', () {
    expect(
      isOnTrack(spent: 4320000, budget: 6500000, elapsedRatio: 0.97),
      isTrue,
    );
    expect(
      isOnTrack(spent: 4320000, budget: 6500000, elapsedRatio: 0.3),
      isFalse,
    );
    expect(isOnTrack(spent: 0, budget: 0, elapsedRatio: 0.5), isTrue);
  });
}
