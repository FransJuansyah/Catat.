import 'dart:async';

import 'package:catat/data/local/database.dart';
import 'package:catat/data/pro_store.dart';
import 'package:catat/data/providers.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/features/pro/pro_screen.dart';
import 'package:catat/domain/pro.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Google Play palsu: bayar langsung berhasil, atau menunggu (e-wallet).
class FakeProStore implements ProStore {
  final _events = StreamController<ProStoreEvent>.broadcast();
  bool pendingFirst = false;
  bool owned = false;

  void emit(ProStoreEvent e) => _events.add(e);

  @override
  Future<String?> price() async => 'Rp 49.000';

  @override
  Future<void> buy() async {
    emit(
      pendingFirst
          ? const ProStoreEvent(ProPurchaseState.pending)
          : const ProStoreEvent(ProPurchaseState.purchased, token: 'tok'),
    );
  }

  @override
  Future<void> restore() async {
    if (owned) {
      emit(const ProStoreEvent(ProPurchaseState.purchased, token: 'lama'));
    }
  }

  @override
  Stream<ProStoreEvent> get events => _events.stream;
}

void main() {
  late AppDatabase db;
  late DateTime now;
  late FakeProStore store;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    now = DateTime(2026, 9, 27, 10);
    store = FakeProStore();
  });
  tearDown(() => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
        proStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> setup(ProviderContainer c) => c
      .read(budgetRepositoryProvider)
      .setupBudget(
        netSalary: 6500000,
        payday: 25,
        template: PocketTemplates.klasik,
      );

  test('selesai daftar → trial 7 hari, hari ke-8 terkunci', () async {
    final c = container();
    await setup(c);
    final repo = c.read(proRepositoryProvider);
    expect((await repo.status()).daysLeft, 7);
    now = now.add(const Duration(days: 8));
    expect((await repo.status()).unlocked, isFalse);
  });

  test('beli → Pro kebuka selamanya, layar 54 muncul', () async {
    final c = container();
    await setup(c);
    now = now.add(const Duration(days: 10));
    final pro = c.read(proProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(proProvider).price, 'Rp 49.000');

    await pro.buy();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final status = await c.read(proRepositoryProvider).status();
    expect(status.purchased, isTrue);
    expect(status.unlocked, isTrue);
    expect(c.read(proProvider).unlockedNow, isTrue);
  });

  test('bayar e-wallet belum lunas → menunggu, lalu kebuka', () async {
    final c = container();
    await setup(c);
    store.pendingFirst = true;
    final pro = c.read(proProvider.notifier);
    await pro.buy();
    await Future<void>.delayed(Duration.zero);
    expect(c.read(proProvider).pending, isTrue);
    expect((await c.read(proRepositoryProvider).status()).purchased, isFalse);

    store.emit(const ProStoreEvent(ProPurchaseState.purchased, token: 't'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect((await c.read(proRepositoryProvider).status()).purchased, isTrue);
    expect(c.read(proProvider).pending, isFalse);
  });

  test('install ulang: pembelian lama dipulihkan otomatis', () async {
    store.owned = true;
    final c = container();
    await setup(c);
    c.read(proProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final status = await c.read(proRepositoryProvider).status();
    expect(status.purchased, isTrue);
    // Pulihkan diam-diam, bukan beli baru → tanpa layar 54.
    expect(c.read(proProvider).unlockedNow, isFalse);
  });

  testWidgets('ProGate: trial habis → layar 53, sudah beli → fitur', (
    tester,
  ) async {
    final c = container();
    await tester.runAsync(() => setup(c));
    now = now.add(const Duration(days: 8));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: ProGate(feature: ProFeature.scan, child: Text('KAMERA')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buka catat. Pro'), findsOneWidget);
    expect(find.text('Trial kamu udah habis'), findsOneWidget);
    expect(find.text('KAMERA'), findsNothing);

    await tester.runAsync(
      () => c.read(proRepositoryProvider).markPurchased('tok'),
    );
    await tester.pumpAndSettle();
    expect(find.text('KAMERA'), findsOneWidget);
  });
}
