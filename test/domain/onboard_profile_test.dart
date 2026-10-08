import 'package:catat/domain/onboard_profile.dart';
import 'package:catat/domain/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('jawaban pertama jadi nama panggilan', () {
    expect(nameFromAnswer('Fatimah'), 'Fatimah');
    expect(nameFromAnswer('aku fatimah'), 'Fatimah');
    expect(nameFromAnswer('panggil aja Frans ya'), 'Frans');
    expect(nameFromAnswer('nama saya frans juansyah.'), 'Frans Juansyah');
    expect(nameFromAnswer('Hai, aku Dimas!'), 'Dimas');
  });

  test('isian lama tetap ada kalau AI lupa membawanya', () {
    const old = OnboardProfile(
      name: 'Fatimah',
      mode: IncomeMode.salary,
      amount: 5000000,
      payday: 25,
    );
    final next = OnboardProfile.fromJson({
      'name': '',
      'mode': '',
      'amount': 0,
      'payday': 0,
      'balance': 1000000,
    }).over(old);
    expect(next.name, 'Fatimah');
    expect(next.mode, IncomeMode.salary);
    expect(next.amount, 5000000);
    expect(next.payday, 25);
    expect(next.balance, 1000000);
    expect(next.complete, isTrue);
  });
}
