import 'dart:async';

import 'package:catat/data/account.dart';
import 'package:catat/data/local/database.dart';
import 'package:catat/data/providers.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/data/sync/sync_remote.dart';
import 'package:catat/domain/templates.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_engine_test.dart' show FakeRemote;

class FakeAccount implements AccountService {
  FakeAccount(this.remote);

  @override
  final SyncRemote remote;
  final _changes = StreamController<String?>.broadcast();
  String? _email;
  bool offline = false;

  @override
  bool get available => true;
  @override
  String? get email => _email;
  @override
  Stream<String?> get emailChanges => _changes.stream;

  @override
  Future<void> sendCode(String email) async {}

  @override
  Future<void> verifyCode(String email, String code) async {
    if (code != '123456') throw Exception('invalid otp');
    _email = email;
  }

  @override
  Future<void> signOut() async => _email = null;
}

/// Server yang bisa dibuat offline.
class FlakyRemote extends FakeRemote {
  bool offline = false;

  @override
  Future<void> push(List<RemoteRow> batch) {
    if (offline) throw Exception('SocketException');
    return super.push(batch);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FlakyRemote remote;

  ({ProviderContainer c, AppDatabase db}) device() {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => DateTime(2026, 9, 27, 10)),
        accountServiceProvider.overrideWithValue(FakeAccount(remote)),
      ],
    );
    addTearDown(() async {
      c.dispose();
      await db.close();
    });
    return (c: c, db: db);
  }

  Future<void> setup(ProviderContainer c) => c
      .read(budgetRepositoryProvider)
      .setupBudget(
        netSalary: 6500000,
        payday: 25,
        template: PocketTemplates.klasik,
      );

  setUp(() => remote = FlakyRemote());

  test('HP lama login pertama: data ikut ke akun, HP baru dapat', () async {
    final a = device();
    await setup(a.c);
    await a.c.read(budgetRepositoryProvider).loadHome();
    final account = a.c.read(accountProvider.notifier);

    await expectLater(
      account.verifyCode('frans@email.com', '000000'),
      throwsException,
    );
    final start = await account.verifyCode('frans@email.com', '123456');
    expect(start, LoginStart.upload);
    await account.finishLogin(start);
    expect(a.c.read(accountProvider).signedIn, isTrue);
    expect(a.c.read(accountProvider).lastSync, isNotNull);

    final b = device();
    final startB = await b.c
        .read(accountProvider.notifier)
        .verifyCode('frans@email.com', '123456');
    expect(startB, LoginStart.restore);
    await b.c.read(accountProvider.notifier).finishLogin(startB);
    final home = await b.c.read(budgetRepositoryProvider).loadHome();
    expect(home.remaining, 6500000);
  });

  test('HP yang sudah ada isinya login ke akun berisi → konflik', () async {
    final a = device();
    await setup(a.c);
    final account = a.c.read(accountProvider.notifier);
    await account.finishLogin(
      await account.verifyCode('frans@email.com', '123456'),
    );

    final b = device();
    await setup(b.c);
    expect(
      await b.c
          .read(accountProvider.notifier)
          .verifyCode('frans@email.com', '123456'),
      LoginStart.conflict,
    );
  });

  test('keluar saat offline dengan perubahan tertunda → ditanya', () async {
    final a = device();
    await setup(a.c);
    final account = a.c.read(accountProvider.notifier);
    await account.finishLogin(
      await account.verifyCode('frans@email.com', '123456'),
    );
    final k = (await a.c.read(budgetRepositoryProvider).loadPocketSetup())
        .pockets
        .last;
    remote.offline = true;
    await a.c
        .read(budgetRepositoryProvider)
        .addExpense(pocketId: k.id, amount: 10000, title: 'Es teh');

    await expectLater(
      account.signOut(),
      throwsA(isA<PendingChangesException>()),
    );
    expect(a.c.read(accountProvider).signedIn, isTrue);

    await account.signOut(force: true);
    expect(a.c.read(accountProvider).signedIn, isFalse);
    expect(await BudgetRepository(a.db, DateTime.now).isSetUp(), isFalse);
  });

  test('hapus akun: akun & HP kosong', () async {
    final a = device();
    await setup(a.c);
    final account = a.c.read(accountProvider.notifier);
    await account.finishLogin(
      await account.verifyCode('frans@email.com', '123456'),
    );
    await account.deleteAccount();
    expect(remote.rows, isEmpty);
    expect(a.c.read(accountProvider).signedIn, isFalse);
    expect(await a.c.read(budgetRepositoryProvider).isSetUp(), isFalse);
  });
}
