import 'dart:math' as math;

import 'types.dart';

/// Aturan jatah satu kantong.
class PocketRule {
  const PocketRule({
    required this.pocketId,
    this.mode = AllocationMode.percent,
    this.percent = 0,
    this.nominal = 0,
    this.rangeMin,
    this.rangeMax,
  });

  final String pocketId;
  final AllocationMode mode;
  final int percent;
  final int nominal;
  final int? rangeMin;
  final int? rangeMax;

  int _raw(int salary) => mode == AllocationMode.percent
      ? (salary * percent / 100).round()
      : nominal;

  int _clamp(int value) {
    var v = value;
    if (rangeMin != null) v = math.max(v, rangeMin!);
    if (rangeMax != null) v = math.min(v, rangeMax!);
    return v;
  }
}

/// Jatah tiap kantong (rupiah) dari [salary].
///
/// Jika semua kantong mode persen, totalnya 100%, dan tidak ada yang kena
/// rentang, sisa pembulatan diberikan ke kantong berpersen terbesar agar
/// total jatah = gaji persis.
Map<String, int> allocateAll(int salary, List<PocketRule> rules) {
  final result = {for (final r in rules) r.pocketId: r._clamp(r._raw(salary))};
  final allPercent = rules.every((r) => r.mode == AllocationMode.percent);
  final percentSum = rules.fold<int>(0, (s, r) => s + r.percent);
  final noneClamped = rules.every(
    (r) => r._clamp(r._raw(salary)) == r._raw(salary),
  );
  if (rules.isNotEmpty && allPercent && percentSum == 100 && noneClamped) {
    final diff = salary - result.values.fold<int>(0, (s, v) => s + v);
    if (diff != 0) {
      final biggest = rules.reduce((a, b) => b.percent > a.percent ? b : a);
      result[biggest.pocketId] = result[biggest.pocketId]! + diff;
    }
  }
  return result;
}

/// Hasil validasi alokasi (layar 20 & 23).
class AllocationCheck {
  const AllocationCheck({
    required this.salary,
    required this.totalAllocated,
    required this.percentSum,
    required this.allPercent,
  });

  factory AllocationCheck.of(int salary, List<PocketRule> rules) {
    final amounts = allocateAll(salary, rules);
    return AllocationCheck(
      salary: salary,
      totalAllocated: amounts.values.fold<int>(0, (s, v) => s + v),
      percentSum: rules.fold<int>(0, (s, r) => s + r.percent),
      allPercent: rules.every((r) => r.mode == AllocationMode.percent),
    );
  }

  final int salary;
  final int totalAllocated;
  final int percentSum;
  final bool allPercent;

  /// Persen teralokasi yang ditampilkan ("100% teralokasi").
  int get displayPercent => allPercent
      ? percentSum
      : salary == 0
      ? 0
      : (totalAllocated * 100 / salary).round();

  bool get isValid => allPercent ? percentSum == 100 : totalAllocated == salary;

  /// Positif = kelebihan, negatif = masih ada yang belum dialokasikan (rupiah).
  int get difference => totalAllocated - salary;
}
