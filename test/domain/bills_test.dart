import 'package:catat/domain/bills.dart';
import 'package:flutter_test/flutter_test.dart';

Bill bill(
  String name, {
  int amount = 100000,
  int dueDay = 10,
  BillKind kind = BillKind.rutin,
  int? remaining,
  required DateTime created,
}) {
  final start = firstDueMonth(dueDay, created);
  return Bill(
    id: name,
    name: name,
    iconKey: 'card',
    amount: amount,
    dueDay: dueDay,
    kind: kind,
    remaining: remaining,
    startMonth: start,
    paidThrough: start - 1,
  );
}

Bill pay(Bill b) => Bill(
  id: b.id,
  name: b.name,
  iconKey: b.iconKey,
  amount: b.amount,
  dueDay: b.dueDay,
  kind: b.kind,
  remaining: b.remaining == null ? null : b.remaining! - 1,
  startMonth: b.startMonth,
  paidThrough: b.nextMonth,
);

void main() {
  final today = DateTime(2026, 10, 9);

  test(
    'jatuh tempo pertama: bulan ini kalau belum lewat, else bulan depan',
    () {
      expect(firstDueMonth(10, today), monthIndex(DateTime(2026, 10)));
      expect(firstDueMonth(9, today), monthIndex(DateTime(2026, 10)));
      expect(firstDueMonth(5, today), monthIndex(DateTime(2026, 11)));
    },
  );

  test('tanggal 31 di bulan pendek jadi hari terakhir', () {
    expect(dueDateIn(monthIndex(DateTime(2027, 2)), 31), DateTime(2027, 2, 28));
    expect(
      dueDateIn(monthIndex(DateTime(2026, 11)), 31),
      DateTime(2026, 11, 30),
    );
  });

  test('cicilan HP 8x mulai 10 Okt: lunas Mei 2027, besok jatuh tempo', () {
    final hp = bill(
      'Cicilan HP',
      kind: BillKind.cicilan,
      remaining: 8,
      created: today,
    );
    expect(monthLabel(hp.lastMonth!), 'Mei 2027');
    expect(hp.daysLeft(today), 1);
    expect(dueLabel(hp.daysLeft(today)), 'Besok');
  });

  test('bayar: bulan berikutnya, sisa berkurang, cicilan terakhir selesai', () {
    var b = bill(
      'Cicilan',
      kind: BillKind.cicilan,
      remaining: 2,
      created: today,
    );
    b = pay(b);
    expect(b.remaining, 1);
    expect(b.nextDue, DateTime(2026, 11, 10));
    expect(b.finished, isFalse);
    b = pay(b);
    expect(b.finished, isTrue);
  });

  test('ringkasan bulan ini: total, lunas, urutan jatuh tempo', () {
    final kos = pay(
      bill('Kos', amount: 1500000, dueDay: 1, created: DateTime(2026, 9, 20)),
    );
    final hp = bill(
      'HP',
      amount: 500000,
      kind: BillKind.cicilan,
      remaining: 8,
      created: today,
    );
    final cc = bill(
      'Kartu kredit',
      amount: 1250000,
      dueDay: 15,
      created: today,
    );
    final s = summarizeBills([cc, kos, hp], today);
    expect(s.unpaid.map((b) => b.name), ['HP', 'Kartu kredit']);
    expect(s.done.map((b) => b.name), ['Kos']);
    expect(s.total, 3250000);
    expect(s.paid, 1500000);
  });

  test('dibuat setelah tanggalnya lewat: belum masuk total bulan ini', () {
    final motor = bill('Motor', amount: 850000, dueDay: 5, created: today);
    final s = summarizeBills([motor], today);
    expect(s.unpaid.single.name, 'Motor');
    expect(s.total, 0);
    expect(motor.nextDue, DateTime(2026, 11, 5));
  });

  test('telat bayar & tagihan dekat untuk Beranda', () {
    final telat = bill('Listrik', dueDay: 7, created: DateTime(2026, 10, 1));
    final jauh = bill('Spotify', dueDay: 25, created: today);
    expect(dueLabel(telat.daysLeft(today)), 'Telat 2 hari');
    expect(dueSoon([jauh, telat], today).map((b) => b.name), ['Listrik']);
  });
}
