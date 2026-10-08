import 'package:catat/domain/bills.dart';
import 'package:catat/domain/chat_reply.dart';
import 'package:catat/domain/installment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hp = InstallmentSim(
    item: 'HP',
    price: 3000000,
    dp: 500000,
    months: 12,
    ratePercent: 2,
  );

  test('HP 3jt, DP 500rb, 12 bulan, flat 2%/bulan (layar 72)', () {
    expect(hp.principal, 2500000);
    expect(hp.interest, 600000);
    expect(hp.monthly, 258334); // dibulatkan ke atas
    expect(hp.total, 3600000);
    expect(hp.rateLabel, '2% per bulan');
  });

  test('ganti tenor & bunga per tahun & tanpa bunga', () {
    final six = hp.withMonths(6);
    expect(six.interest, 300000);
    expect(six.monthly, 466667);
    expect(hp.altMonths, 6);
    expect(six.altMonths, 12);

    const tahunan = InstallmentSim(
      item: 'Motor',
      price: 20000000,
      dp: 2000000,
      months: 24,
      ratePercent: 12,
      perYear: true,
    );
    expect(tahunan.interest, 4320000); // 18jt × 1% × 24
    expect(tahunan.rateLabel, '12% per tahun');

    const nol = InstallmentSim(
      item: 'Laptop',
      price: 6000000,
      dp: 0,
      months: 6,
      ratePercent: 0,
    );
    expect(nol.monthly, 1000000);
    expect(nol.rateLabel, 'tanpa bunga');
  });

  test('dampak ke gaji: persen & batas aman 30%', () {
    final cicilanHp = Bill(
      id: 'hp',
      name: 'Cicilan HP',
      iconKey: 'phone',
      amount: 500000,
      dueDay: 10,
      kind: BillKind.cicilan,
      remaining: 8,
      startMonth: 0,
      paidThrough: -1,
    );
    final i = BillImpact.of(258334, [cicilanHp], 6500000)!;
    expect(BillImpact.pct(i.share), '4%');
    expect(BillImpact.pct(i.totalShare), '12%');
    expect(i.safe, isTrue);
    expect(BillImpact.of(2000000, [cicilanHp], 6500000)!.safe, isFalse);
    expect(BillImpact.of(1, const [], 0), isNull);
  });

  test(
    'jawaban server v2: cicilan & tagihan dibaca, yang rusak jadi tanya',
    () {
      final sim = AssistantReply.fromJson({
        'action': 'cicilan',
        'reply': 'Ini hitungannya.',
        'notes': [],
        'sim': {
          'item': 'HP',
          'price': 3000000,
          'dp': 500000,
          'months': 12,
          'rate': 2,
          'rate_per': 'bulan',
        },
        'bills': [],
      });
      expect(sim.action, ChatAction.cicilan);
      expect(sim.sim!.monthly, 258334);

      final bills = AssistantReply.fromJson({
        'action': 'tagihan',
        'reply': '',
        'notes': [],
        'sim': null,
        'bills': [
          {
            'name': 'Cicilan motor',
            'amount': 850000,
            'due_day': 5,
            'remaining': 20,
            'pocket': null,
          },
          {'name': 'Kos', 'amount': 1500000, 'due_day': 1, 'remaining': null},
          {'name': 'Rusak', 'amount': 0, 'due_day': 1},
        ],
      });
      expect(bills.action, ChatAction.tagihan);
      expect(bills.bills.map((b) => (b.name, b.remaining)), [
        ('Cicilan motor', 20),
        ('Kos', null),
      ]);

      final broken = AssistantReply.fromJson({
        'action': 'cicilan',
        'reply': '',
        'sim': {'price': 0, 'months': 0},
      });
      expect(broken.action, ChatAction.tanya);
    },
  );
}
