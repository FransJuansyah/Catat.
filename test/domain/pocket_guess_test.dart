import 'package:catat/domain/home_summary.dart';
import 'package:catat/domain/pocket_balance.dart';
import 'package:catat/domain/pocket_guess.dart';
import 'package:catat/domain/types.dart';
import 'package:flutter_test/flutter_test.dart';

PocketView pocket(String name, PocketType type, String icon) => PocketView(
  id: name,
  type: type,
  name: name,
  iconKey: icon,
  color: 0xFF6D5DFC,
  balance: const PocketBalance(allocation: 1000000),
);

String? guess(String title, PocketType type, List<PocketView> pockets) =>
    guessPocket(title, type, pockets)?.name;

void main() {
  final bawaan = [
    pocket('Wajib', PocketType.wajib, 'house'),
    pocket('Darurat', PocketType.darurat, 'shield'),
    pocket('Keinginan', PocketType.keinginan, 'sparkles'),
  ];

  test('kantong bawaan: tetap ikut jenisnya', () {
    expect(guess('Kopi susu', PocketType.keinginan, bawaan), 'Keinginan');
    expect(guess('Bensin', PocketType.wajib, bawaan), 'Wajib');
    expect(guess('Obat batuk', PocketType.darurat, bawaan), 'Darurat');
    expect(guess('Bayar kos', PocketType.wajib, bawaan), 'Wajib');
  });

  // Mirip setelan user 6 Okt 2026: "Transport" berjenis Keinginan.
  final user = [
    pocket('Wajib', PocketType.wajib, 'house'),
    pocket('tabungan', PocketType.darurat, 'piggy'),
    pocket('Transport', PocketType.keinginan, 'car'),
    pocket('Jajan', PocketType.keinginan, 'coffee'),
    pocket('Kesehatan', PocketType.darurat, 'heart'),
  ];

  test('kopi tidak masuk Transport; bensin & ojek masuk Transport', () {
    expect(guess('Kopi susu', PocketType.keinginan, user), 'Jajan');
    expect(guess('Bensin', PocketType.wajib, user), 'Transport');
    expect(guess('Gojek ke kampus', PocketType.wajib, user), 'Transport');
    expect(guess('Obat flu', PocketType.darurat, user), 'Kesehatan');
    expect(guess('Bayar kos', PocketType.wajib, user), 'Wajib');
  });

  test('tanpa kantong jajan: kopi ke Wajib, bukan Transport/tabungan', () {
    final tanpaJajan = user.where((p) => p.name != 'Jajan').toList();
    expect(guess('Kopi susu', PocketType.keinginan, tanpaJajan), 'Wajib');
    expect(guess('Nonton', PocketType.keinginan, tanpaJajan), 'Wajib');
  });

  test('ikon kantong juga dipakai', () {
    final ikon = [
      pocket('Pokok', PocketType.wajib, 'house'),
      pocket('Jalan', PocketType.wajib, 'car'),
    ];
    expect(guess('Isi pertalite', PocketType.wajib, ikon), 'Jalan');
  });
}
