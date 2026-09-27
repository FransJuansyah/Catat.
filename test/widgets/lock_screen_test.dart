import 'package:catat/data/app_lock.dart';
import 'package:catat/data/providers.dart';
import 'package:catat/features/security/lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/app_lock_test.dart' show FakeBio;

void main() {
  testWidgets('layar 58: PIN salah goyang, PIN benar membuka app', (
    tester,
  ) async {
    final store = MemoryLockStore();
    await AppLock(store, FakeBio(), DateTime.now).setPin('482913');
    final bio = FakeBio()..pass = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lockStoreProvider.overrideWithValue(store),
          biometricProvider.overrideWithValue(bio),
        ],
        child: MaterialApp(
          home: LockGate(
            onPinReset: () {},
            child: const Scaffold(body: Text('BERANDA')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Masukin PIN'), findsOneWidget);

    Future<void> type(String pin) async {
      for (final d in pin.split('')) {
        await tester.tap(find.text(d).last);
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    await type('000000');
    expect(find.text('Masukin PIN'), findsOneWidget);

    await type('482913');
    expect(find.text('Masukin PIN'), findsNothing);
    expect(find.text('BERANDA'), findsOneWidget);
  });
}
