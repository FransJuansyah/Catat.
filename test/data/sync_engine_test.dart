import 'package:catat/data/local/database.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/data/sync/sync_engine.dart';
import 'package:catat/data/sync/sync_remote.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/domain/types.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Server palsu: satu akun, "yang terakhir menang", rev naik tiap tulis.
class FakeRemote implements SyncRemote {
  final rows = <String, RemoteRow>{};
  var _rev = 0;
  var deleted = false;

  @override
  Future<void> push(List<RemoteRow> batch) async {
    for (final r in batch) {
      final key = '${r.table}/${r.id}';
      final old = rows[key];
      if (old != null && old.changedAt > r.changedAt) continue;
      rows[key] = RemoteRow(
        table: r.table,
        id: r.id,
        data: r.data,
        changedAt: r.changedAt,
        deleted: r.deleted,
        rev: ++_rev,
      );
    }
  }

  @override
  Future<List<RemoteRow>> pull(int afterRev, {int limit = 500}) async =>
      (rows.values.where((r) => r.rev > afterRev).toList()
            ..sort((a, b) => a.rev.compareTo(b.rev)))
          .take(limit)
          .toList();

  @override
  Future<bool> hasData() async => rows.isNotEmpty;

  @override
  Future<void> deleteAccount() async {
    rows.clear();
    deleted = true;
  }
}

class Device {
  Device(this.remote, DateTime Function() now)
    : db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      ) {
    repo = BudgetRepository(db, now);
    sync = SyncEngine(db, remote);
  }

  final FakeRemote remote;
  final AppDatabase db;
  late final BudgetRepository repo;
  late final SyncEngine sync;
}

void main() {
  late FakeRemote remote;
  late DateTime now;
  late Device a;
  late Device b;

  setUp(() {
    remote = FakeRemote();
    now = DateTime(2026, 9, 27, 10);
    a = Device(remote, () => now);
    b = Device(remote, () => now);
  });
  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });

  Future<void> setupA() => a.repo.setupBudget(
    netSalary: 6500000,
    payday: 25,
    template: PocketTemplates.klasik,
  );

  test('akun sudah berisi, pilih data HP ini: isi akun ditimpa', () async {
    // Akun berisi data lama dari HP lain (a).
    await setupA();
    final [wa, _, _] = (await a.repo.loadPocketSetup()).pockets;
    await a.repo.addExpense(pocketId: wa.id, amount: 999000, title: 'Lama');
    await a.sync.sync();

    // HP ini (b) punya data sendiri: gaji 5 jt, satu pengeluaran.
    await b.repo.setupBudget(
      netSalary: 5000000,
      payday: 5,
      template: PocketTemplates.klasik,
    );
    final [wb, _, _] = (await b.repo.loadPocketSetup()).pockets;
    await b.repo.addExpense(pocketId: wb.id, amount: 25000, title: 'Kopi');
    final before = await b.repo.loadHome();

    await b.sync.replaceRemoteWithLocal();
    await b.sync.sync();

    // Data HP ini tidak berubah.
    final after = await b.repo.loadHome();
    expect(after.remaining, before.remaining);
    expect(after.salary, 5000000);
    expect(after.pockets, hasLength(3));

    // HP ketiga yang masuk akun yang sama melihat data HP ini, bukan data lama.
    final c = Device(remote, () => now);
    addTearDown(c.db.close);
    await c.sync.sync();
    final homeC = await c.repo.loadHome();
    expect(homeC.salary, 5000000);
    expect(homeC.remaining, before.remaining);
    expect(homeC.pockets, hasLength(3));
  });

  test('perubahan lokal otomatis masuk antrian (trigger)', () async {
    expect(await a.sync.pendingCount(), 0);
    await setupA();
    // Profil + pengaturan + 3 kantong.
    expect(await a.sync.pendingCount(), 5);
    await a.sync.push();
    expect(await a.sync.pendingCount(), 0);
    expect(remote.rows, hasLength(5));
  });

  test('ganti HP: data kembali utuh', () async {
    await setupA();
    final [w, _, k] = (await a.repo.loadPocketSetup()).pockets;
    await a.repo.addExpense(pocketId: k.id, amount: 150000, title: 'Kopi');
    await a.repo.addExpense(pocketId: w.id, amount: 50000, title: 'Listrik');
    await a.sync.sync();

    expect(await b.remote.hasData(), isTrue);
    await b.sync.sync();
    final homeA = await a.repo.loadHome();
    final homeB = await b.repo.loadHome();
    expect(homeB.remaining, homeA.remaining);
    expect(
      homeB.pockets.map((p) => (p.name, p.balance.remaining)),
      homeA.pockets.map((p) => (p.name, p.balance.remaining)),
    );
    // Data dari akun tidak dikirim balik.
    expect(await b.sync.pendingCount(), 0);
  });

  test('dua HP bikin periode yang sama offline → tidak dobel', () async {
    await setupA();
    await a.repo.loadHome(); // periode September
    await a.sync.sync();
    await b.sync.sync();
    // Bulan depan: kedua HP membuka app tanpa internet.
    now = DateTime(2026, 10, 26, 9);
    await a.repo.loadHome();
    await b.repo.loadHome();
    await a.sync.sync();
    await b.sync.sync();
    await a.sync.sync();
    for (final d in [a, b]) {
      final periods = await d.db.select(d.db.periods).get();
      expect(periods, hasLength(2));
      final allocs = await d.db.select(d.db.periodAllocations).get();
      expect(allocs, hasLength(6));
    }
    expect((await b.repo.loadHome()).remaining, 6500000);
  });

  test('edit & hapus di HP lain ikut ke sini', () async {
    await setupA();
    final k = (await a.repo.loadPocketSetup()).pockets.last;
    await a.repo.addExpense(pocketId: k.id, amount: 100000, title: 'Nonton');
    await a.sync.sync();
    await b.sync.sync();

    final expense = (await b.db.select(b.db.expenses).get()).single;
    now = now.add(const Duration(minutes: 5));
    await b.repo.deleteExpense(expense.id);
    await b.sync.sync();
    await a.sync.sync();
    expect((await a.repo.loadHome()).remaining, 6500000);
  });

  test('perubahan lokal yang belum terkirim tidak ditimpa akun', () async {
    await setupA();
    await a.sync.sync();
    await b.sync.sync();
    final pocket = (await a.repo.loadPocketSetup()).pockets.first;
    // B ganti nama, belum sinkron. A ganti nama & sinkron duluan.
    await b.db.customStatement(
      "UPDATE pockets SET name = 'Punya B' WHERE id = ?",
      [pocket.id],
    );
    await a.db.customStatement(
      "UPDATE pockets SET name = 'Punya A' WHERE id = ?",
      [pocket.id],
    );
    await a.sync.sync();
    await b.sync.pull();
    final row = await (b.db.select(
      b.db.pockets,
    )..where((t) => t.id.equals(pocket.id))).getSingle();
    expect(row.name, 'Punya B');
  });

  test('periode lama ber-id acak digabung ke periode akun', () async {
    await setupA();
    await a.sync.sync();
    await b.sync.sync();
    // B punya periode dengan id acak (app versi lama) di tanggal yang sama.
    final start = DateTime(2026, 9, 25);
    await b.db
        .into(b.db.periods)
        .insert(
          PeriodsCompanion.insert(
            id: 'periode-lama',
            startDate: start,
            endDate: DateTime(2026, 10, 24),
            salary: 6500000,
          ),
        );
    final k = (await b.repo.loadPocketSetup()).pockets.last;
    await b.db
        .into(b.db.expenses)
        .insert(
          ExpensesCompanion.insert(
            id: 'jajan',
            pocketId: k.id,
            periodId: 'periode-lama',
            amount: 20000,
            title: 'Jajan',
            occurredAt: now,
            source: ExpenseSource.manual,
          ),
        );
    await b.db.delete(b.db.syncOutbox).go(); // anggap sudah terkirim dulu

    await a.repo.loadHome(); // A bikin periode ber-id tetap
    await a.sync.sync();
    await b.sync.pull();
    final periods = await b.db.select(b.db.periods).get();
    expect(periods.map((p) => p.id), isNot(contains('periode-lama')));
    final jajan = await (b.db.select(
      b.db.expenses,
    )..where((t) => t.id.equals('jajan'))).getSingle();
    expect(jajan.periodId, periods.single.id);
  });

  test('keluar: HP kosong, tidak ada yang masuk antrian', () async {
    await setupA();
    await a.sync.sync();
    await a.sync.wipeLocal();
    expect(await a.repo.isSetUp(), isFalse);
    expect(await a.sync.pendingCount(), 0);
    // Masuk lagi → data kembali.
    await a.sync.pull();
    expect(await a.repo.isSetUp(), isTrue);
  });

  test('hapus akun: akun & HP kosong', () async {
    await setupA();
    await a.sync.sync();
    await a.sync.deleteAccount();
    expect(remote.deleted, isTrue);
    expect(remote.rows, isEmpty);
    expect(await a.repo.isSetUp(), isFalse);
  });

  test('login pertama dengan data lama: semua ikut ke akun', () async {
    await setupA();
    await a.db.delete(a.db.syncOutbox).go(); // data dari sebelum ada F8
    await a.sync.enqueueAll();
    await a.sync.sync();
    await b.sync.sync();
    expect((await b.repo.loadHome()).remaining, 6500000);
  });
}
