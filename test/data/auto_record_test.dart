import 'package:catat/data/auto_record.dart';
import 'package:catat/data/local/database.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/bank_notification_parser.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/domain/types.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// F6.5: catat otomatis di belakang layar dari notifikasi bank.
void main() {
  late AppDatabase db;
  late DateTime now;
  late BudgetRepository repo;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    now = DateTime(2026, 9, 26, 12);
    repo = BudgetRepository(db, () => now);
  });
  tearDown(() => db.close());

  Future<void> setupSalary() => repo.setupBudget(
    netSalary: 6500000,
    payday: 25,
    template: PocketTemplates.klasik,
  );

  DetectedTransaction tx(
    MoneyDirection direction,
    int amount, {
    String? counterparty,
    DateTime? at,
  }) => DetectedTransaction(
    direction: direction,
    amount: amount,
    appName: 'BCA',
    counterparty: counterparty,
    occurredAt: at ?? DateTime(2026, 9, 26, 11, 30),
  );

  test('uang keluar: pengeluaran di kantong tebakan, sumber notif', () async {
    await setupSalary();
    final r = (await recordDetected(
      repo,
      tx(MoneyDirection.out, 32500, counterparty: 'Kopi Kenangan'),
    ))!;
    expect(r.income, isFalse);
    expect(r.pocketName, 'Keinginan');

    final detail = (await repo.loadExpense(r.id))!;
    expect(detail.entry.amount, 32500);
    expect(detail.entry.title, 'Kopi Kenangan');
    expect(detail.entry.source, ExpenseSource.notif);
    expect(detail.entry.occurredAt, DateTime(2026, 9, 26, 11, 30));
    final home = await repo.loadHome();
    expect(home.remaining, 6500000 - 32500);
  });

  test('tanpa nama toko: judul pakai nama bank, kantong Wajib', () async {
    await setupSalary();
    final r = (await recordDetected(repo, tx(MoneyDirection.out, 18000)))!;
    expect(r.title, 'BCA');
    expect(r.pocketName, 'Wajib');
  });

  test('uang masuk: pemasukan & menambah saldo', () async {
    await setupSalary();
    final before = (await repo.loadHome()).remaining;
    final r = (await recordDetected(
      repo,
      tx(MoneyDirection.into, 250000, counterparty: 'Andi Pratama'),
    ))!;
    expect(r.income, isTrue);
    expect((await repo.loadHome()).remaining, before + 250000);
  });

  test('Batalkan menghapus lagi', () async {
    await setupSalary();
    final out = (await recordDetected(repo, tx(MoneyDirection.out, 50000)))!;
    final into = (await recordDetected(repo, tx(MoneyDirection.into, 100000)))!;
    await undoRecord(repo, out.id, income: false);
    await undoRecord(repo, into.id, income: true);
    expect((await repo.loadHome()).remaining, 6500000);
  });

  test('sudah dicatat manual, notif telat 15 menit: tidak dobel', () async {
    await setupSalary();
    final wajib = (await repo.loadHome()).pockets.first;
    await repo.addExpense(
      pocketId: wajib.id,
      amount: 32500,
      title: 'Kopi',
      occurredAt: DateTime(2026, 9, 26, 11, 15),
    );
    final r = (await recordDetected(
      repo,
      tx(MoneyDirection.out, 32500), // notif jam 11:30
    ))!;
    expect(r.duplicate, isTrue);
    expect((await repo.loadHome()).remaining, 6500000 - 32500);
  });

  test('SMS/email telat sampai 48 jam: tetap tidak dobel', () async {
    await setupSalary();
    final wajib = (await repo.loadHome()).pockets.first;
    await repo.addExpense(
      pocketId: wajib.id,
      amount: 32500,
      title: 'Kopi',
      occurredAt: DateTime(2026, 9, 25, 12),
    );
    // SMS baru masuk 47,5 jam kemudian.
    final r = (await recordDetected(
      repo,
      tx(MoneyDirection.out, 32500, at: DateTime(2026, 9, 27, 11, 30)),
    ))!;
    expect(r.duplicate, isTrue);
  });

  test('nominal beda atau lewat 48 jam: tetap dicatat', () async {
    await setupSalary();
    final wajib = (await repo.loadHome()).pockets.first;
    await repo.addExpense(
      pocketId: wajib.id,
      amount: 32500,
      title: 'Kopi',
      occurredAt: DateTime(2026, 9, 25, 11),
    );
    // SMS masuk 48,5 jam kemudian → dianggap transaksi lain.
    final sameAmountOld = (await recordDetected(
      repo,
      tx(MoneyDirection.out, 32500, at: DateTime(2026, 9, 27, 11, 30)),
    ))!;
    final otherAmount = (await recordDetected(
      repo,
      tx(MoneyDirection.out, 32000),
    ))!;
    expect(sameAmountOld.duplicate, isFalse);
    expect(otherAmount.duplicate, isFalse);
  });

  test(
    'jajan rutin berharga sama dari notif tetap tercatat tiap kali',
    () async {
      await setupSalary();
      final first = (await recordDetected(
        repo,
        tx(MoneyDirection.out, 25000),
      ))!;
      final second = (await recordDetected(
        repo,
        tx(MoneyDirection.out, 25000),
      ))!;
      expect(first.duplicate, isFalse);
      expect(second.duplicate, isFalse);
    },
  );

  test('satu catatan manual cuma menyerap satu notif', () async {
    await setupSalary();
    final wajib = (await repo.loadHome()).pockets.first;
    final manual = await repo.addExpense(
      pocketId: wajib.id,
      amount: 25000,
      title: 'Kopi',
      occurredAt: DateTime(2026, 9, 26, 11),
    );
    final a = (await recordDetected(repo, tx(MoneyDirection.out, 25000)))!;
    expect(a.duplicate, isTrue);
    expect(a.id, manual);
    // Notif kedua (transaksi lain) → catatan manual tadi sudah terpakai.
    final b = (await recordDetected(
      repo,
      tx(MoneyDirection.out, 25000),
      matched: {a.id},
    ))!;
    expect(b.duplicate, isFalse);
  });

  test('SMS gaji masuk tidak dobel dengan gajian otomatis', () async {
    await setupSalary();
    await repo.ensureCurrentPeriod(); // gajian 25 Sep otomatis
    final r = (await recordDetected(repo, tx(MoneyDirection.into, 6500000)))!;
    expect(r.duplicate, isTrue);
  });

  test('pemasukan manual yang sama juga tidak dobel', () async {
    await setupSalary();
    await repo.addIncome(
      amount: 250000,
      title: 'Ngojek',
      occurredAt: DateTime(2026, 9, 26, 11, 20),
    );
    final r = (await recordDetected(repo, tx(MoneyDirection.into, 250000)))!;
    expect(r.duplicate, isTrue);
  });

  test('belum setup: tidak dicatat', () async {
    expect(await recordDetected(repo, tx(MoneyDirection.out, 10000)), isNull);
  });
}
