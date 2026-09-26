import 'package:catat/core/format.dart';
import 'package:catat/data/auto_record.dart';
import 'package:catat/data/local/database.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/bank_notification_parser.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/domain/types.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulasi catat otomatis dari notifikasi nyata (disamarkan): gaji masuk,
/// bayar pakai m-banking, bayar QRIS, dan isi saldo GoPay/DANA dari m-banking.
/// Tiap skenario = urutan notifikasi yang benar-benar muncul di HP (sisi bank
/// DAN sisi e-wallet), lalu dicek apa yang tercatat.
class Notif {
  const Notif(
    this.pkg,
    this.title,
    this.text, {
    this.source = NotificationSource.financeApp,
  });

  final String pkg;
  final String title;
  final String text;
  final NotificationSource source;
}

const bca = 'com.bca';
const brimo = 'id.co.bri.brimo';
const livin = 'id.bmri.livin';
const gopay = 'com.gojek.app';
const dana = 'id.dana';
const sms = 'com.google.android.apps.messaging';

void main() {
  late AppDatabase db;
  late BudgetRepository repo;
  final now = DateTime(2026, 9, 26, 10);

  Future<void> setup(IncomeMode mode) async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    repo = BudgetRepository(db, () => now);
    await repo.setupBudget(
      incomeMode: mode,
      netSalary: mode == IncomeMode.irregular ? 0 : 6500000,
      payday: 25,
      template: mode == IncomeMode.irregular
          ? PocketTemplates.freelancer
          : PocketTemplates.klasik,
    );
    await repo.ensureCurrentPeriod();
  }

  tearDown(() => db.close());

  /// Jalankan notif berurutan seperti di HP; hasil: daftar yang tercatat.
  Future<List<String>> run(List<Notif> notifs) async {
    final log = <String>[];
    final matched = <String>{};
    for (final n in notifs) {
      final t = parseBankNotification(
        packageName: n.pkg,
        title: n.title,
        text: n.text,
        postedAt: now,
        source: n.source,
      );
      if (t == null) {
        log.add('dilewati   ← ${n.title}: ${n.text}');
        continue;
      }
      final r = await recordDetected(repo, t, matched: matched);
      if (r == null) {
        log.add('tidak dicatat ← ${n.text}');
      } else if (r.duplicate) {
        matched.add(r.id);
        log.add('sudah ada (anti-dobel) ← ${n.text}');
      } else {
        log.add(
          '${r.income ? 'PEMASUKAN' : 'PENGELUARAN'} ${rupiah(r.amount)} '
          '"${r.title}"${r.pocketName == null ? '' : ' → ${r.pocketName}'}',
        );
      }
    }
    debugPrint(log.map((l) => '    $l').join('\n'));
    return log;
  }

  Future<int> remaining() async => (await repo.loadHome()).remaining;

  group('1. gaji masuk', () {
    // Gaji masuk ke rekening BNI: notif aplikasi wondr. SMS BNI untuk transaksi
    // yang sama (nominal sama, < 10 menit) sudah disaring di Android
    // (AutoCapture.seenRecently per bank), jadi tidak sampai ke sini.
    const salary = Notif(
      'id.bni.wondr',
      'Dana Masuk',
      'Dana Masuk Rp 6.500.000,00 dari PT MAJU JAYA SENTOSA ke rek 123xxx789 pada 25/09/2026 08:15',
    );

    test(
      'mode gaji bulanan: gaji otomatis sudah masuk → notif tidak dobel',
      () async {
        await setup(IncomeMode.salary);
        final before = await remaining();
        final log = await run([salary]);
        expect(await remaining(), before, reason: log.join('\n'));
      },
    );

    test(
      'mode penghasilan tidak tetap: gaji dicatat sekali jadi pemasukan',
      () async {
        await setup(IncomeMode.irregular);
        final log = await run([salary]);
        expect(await remaining(), 6500000, reason: log.join('\n'));
      },
    );
  });

  group('2. bayar pakai m-banking', () {
    test('PLN & transfer ke orang = pengeluaran', () async {
      await setup(IncomeMode.irregular);
      await repo.addIncome(amount: 1000000, title: 'Modal');
      final log = await run(const [
        Notif(
          brimo,
          'Pembayaran Berhasil',
          'Pembayaran PLN Prabayar Rp 102.500 berhasil. Token 1234-5678-9012-3456-7890',
        ),
        Notif(
          livin,
          'Transaksi Berhasil',
          'Transfer ke BUDI SANTOSO Rp 150.000 berhasil',
        ),
      ]);
      expect(
        await remaining(),
        1000000 - 102500 - 150000,
        reason: log.join('\n'),
      );
    });
  });

  group('3. bayar QRIS', () {
    test('QRIS dari bank & dari e-wallet = pengeluaran', () async {
      await setup(IncomeMode.irregular);
      await repo.addIncome(amount: 1000000, title: 'Modal');
      final log = await run(const [
        Notif(
          bca,
          'BCA mobile',
          'Pembayaran QRIS Rp 25.000 ke KOPI KENANGAN FATMAWATI berhasil pada 26/09/2026 10:05',
        ),
        Notif(
          gopay,
          'Pembayaran berhasil',
          'Kamu bayar Rp18.000 ke Warung Bu Sri pakai GoPay',
        ),
        Notif(
          dana,
          'Pembayaran Berhasil',
          'Pembayaran Rp12.000 di Parkir Blok M berhasil menggunakan saldo DANA.',
        ),
      ]);
      expect(
        await remaining(),
        1000000 - 25000 - 18000 - 12000,
        reason: log.join('\n'),
      );
    });
  });

  group(
    '4. isi saldo e-wallet dari m-banking (uang sendiri pindah dompet)',
    () {
      // Saldo total tidak berubah: tidak boleh jadi pengeluaran / pemasukan.
      final cases = <String, List<Notif>>{
        'BCA → GoPay ("Transfer ke GOPAY")': const [
          Notif(
            bca,
            'Transaksi Berhasil',
            'Transfer ke GOPAY 081234567890 Rp 100.000,00 berhasil',
          ),
          Notif(
            gopay,
            'Saldo masuk',
            'Saldo GoPay kamu nambah Rp100.000 dari BCA',
          ),
        ],
        'BRImo → DANA ("Top Up DANA")': const [
          Notif(brimo, 'Transaksi Berhasil', 'Top Up DANA Rp50.000 Berhasil'),
          Notif(
            dana,
            'Isi Saldo Berhasil',
            'Rp50.000 berhasil masuk ke akun DANA kamu dari BRI',
          ),
        ],
        "Livin' → DANA (\"Top-up\")": const [
          Notif(livin, 'Top-up Berhasil', 'Top-up DANA Rp75.000 berhasil'),
        ],
        'SMS BNI → GoPay ("Trf ke GOPAY")': const [
          Notif(
            sms,
            'BNI',
            'BNI: Rek *4321 Debet Rp100.000 Trf ke GOPAY 0812xxx 26/09 10:00',
            source: NotificationSource.sms,
          ),
        ],
        'DANA menerima dari virtual account bank': const [
          Notif(
            dana,
            'Uang Masuk',
            'Kamu menerima Rp100.000 dari BCA Virtual Account',
          ),
        ],
      };
      for (final MapEntry(key: name, value: notifs) in cases.entries) {
        test(name, () async {
          await setup(IncomeMode.irregular);
          await repo.addIncome(amount: 1000000, title: 'Modal');
          final log = await run(notifs);
          expect(await remaining(), 1000000, reason: log.join('\n'));
        });
      }
    },
  );

  test(
    'pengaman: kiriman teman ke DANA & transfer ke orang tetap dicatat',
    () async {
      await setup(IncomeMode.irregular);
      await repo.addIncome(amount: 1000000, title: 'Modal');
      final log = await run(const [
        Notif(dana, 'Uang Masuk', 'Kamu menerima Rp50.000 dari BUDI SANTOSO'),
        Notif(
          bca,
          'Transaksi Berhasil',
          'Transfer ke SITI AMINAH Rp 40.000,00 berhasil',
        ),
        Notif(
          sms,
          'BNI',
          'BNI: Rek *4321 Debet Rp30.000 Trf ke ANDI WIJAYA 26/09 10:00',
          source: NotificationSource.sms,
        ),
      ]);
      expect(
        await remaining(),
        1000000 + 50000 - 40000 - 30000,
        reason: log.join('\n'),
      );
    },
  );
}
