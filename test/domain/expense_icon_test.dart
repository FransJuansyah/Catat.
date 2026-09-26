import 'package:catat/domain/expense_icon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String g(String title) => guessExpenseIcon(title, fallback: 'house');

  test('menebak ikon dari judul umum', () {
    expect(g('Makan siang'), 'food');
    expect(g('Kopi susu'), 'coffee');
    expect(g('Belanja Indomaret'), 'bag');
    expect(g('Token listrik'), 'bolt');
    expect(g('Bensin'), 'fuel');
    expect(g('Ojek online'), 'car');
    expect(g('Pulsa & internet'), 'phone');
    expect(g('Nonton bioskop'), 'film');
  });

  test('kata spesifik menang atas kata umum', () {
    expect(g('Rumah sakit'), 'heart');
    expect(g('Bayar kos'), 'house');
  });

  test('kata pendek hanya cocok utuh', () {
    // "kosmetik" bukan "kos", "pantas" bukan "tas" → pakai fallback.
    expect(guessExpenseIcon('Kosmetik', fallback: 'x'), 'x');
    expect(guessExpenseIcon('Pantas', fallback: 'x'), 'x');
  });

  test('tidak dikenal → ikon kantong', () {
    expect(guessExpenseIcon('Lain-lain', fallback: 'sparkles'), 'sparkles');
  });
}
