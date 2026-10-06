import 'package:catat/data/account.dart';
import 'package:catat/data/local/database.dart';
import 'package:catat/data/providers.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/templates.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Akun yang sedang masuk, tanpa Supabase.
class _SignedIn extends AccountController {
  _SignedIn(this.email);
  final String? email;

  @override
  AccountState build() => AccountState(email: email);
}

/// Akun pemilik (OWNER_EMAILS) dapat catat. Pro tanpa beli; akun lain tidak.
void main() {
  late AppDatabase db;
  final now = DateTime(2026, 10, 20, 10); // trial (mulai 1 Okt) sudah habis

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await BudgetRepository(db, () => DateTime(2026, 10, 1)).setupBudget(
      netSalary: 5000000,
      payday: 5,
      template: PocketTemplates.klasik,
    );
  });
  tearDown(() => db.close());

  test('email pemilik dicocokkan tanpa beda huruf besar/spasi', () {
    const list = 'difajuansyah@gmail.com, uji@contoh.id';
    expect(isOwnerEmail(' DifaJuansyah@Gmail.com ', list), isTrue);
    expect(isOwnerEmail('uji@contoh.id', list), isTrue);
    expect(isOwnerEmail('orang@lain.com', list), isFalse);
    expect(isOwnerEmail(null, list), isFalse);
    expect(isOwnerEmail('difajuansyah@gmail.com', ''), isFalse);
  });

  Future<bool> unlocked(String? email) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
        ownerEmailsProvider.overrideWithValue('difajuansyah@gmail.com'),
        accountProvider.overrideWith(() => _SignedIn(email)),
      ],
    );
    addTearDown(container.dispose);
    // Riverpod 3: provider tanpa pendengar langsung dibuang.
    final sub = container.listen(proStatusProvider, (_, _) {});
    addTearDown(sub.close);
    final status = await container.read(proStatusProvider.future);
    return status.unlocked && status.purchased;
  }

  test('akun pemilik: Pro selamanya walau trial habis', () async {
    expect(await unlocked('difajuansyah@gmail.com'), isTrue);
  });

  test('akun lain & belum masuk: tetap terkunci setelah trial', () async {
    expect(await unlocked('orang@lain.com'), isFalse);
    expect(await unlocked(null), isFalse);
  });

  test('nama profil bisa diganti', () async {
    final repo = BudgetRepository(db, () => now);
    await repo.setUserName('  Frans Juansyah ');
    expect((await repo.loadHome()).userName, 'Frans Juansyah');
  });
}
