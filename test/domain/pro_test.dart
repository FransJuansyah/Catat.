import 'package:catat/domain/pro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 9, 27, 10);

  ProStatus at(DateTime now, {DateTime? purchased}) =>
      ProStatus(trialStart: start, purchasedAt: purchased, now: now);

  test('hari pertama: trial 7 hari', () {
    final s = at(start);
    expect(s.inTrial, isTrue);
    expect(s.unlocked, isTrue);
    expect(s.daysLeft, 7);
  });

  test('sisa hari dibulatkan ke atas', () {
    expect(at(start.add(const Duration(days: 2, hours: 1))).daysLeft, 5);
    expect(at(start.add(const Duration(days: 6, hours: 23))).daysLeft, 1);
  });

  test('hari ke-8: terkunci', () {
    final s = at(start.add(const Duration(days: 7)));
    expect(s.inTrial, isFalse);
    expect(s.trialOver, isTrue);
    expect(s.unlocked, isFalse);
    expect(s.daysLeft, 0);
  });

  test('sudah beli: kebuka selamanya', () {
    final s = at(
      start.add(const Duration(days: 400)),
      purchased: start.add(const Duration(days: 3)),
    );
    expect(s.unlocked, isTrue);
    expect(s.trialOver, isFalse);
    expect(s.daysLeft, 0);
  });

  test('belum daftar: belum dikunci', () {
    final s = ProStatus(now: start);
    expect(s.unlocked, isTrue);
    expect(s.inTrial, isFalse);
  });

  test('jam HP dimundurkan: trial dianggap habis', () {
    final s = at(start.subtract(const Duration(days: 30)));
    expect(s.unlocked, isFalse);
  });
}
