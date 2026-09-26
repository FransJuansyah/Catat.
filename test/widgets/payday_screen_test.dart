import 'package:catat/core/theme/app_theme.dart';
import 'package:catat/data/providers.dart';
import 'package:catat/domain/types.dart';
import 'package:catat/domain/views.dart';
import 'package:catat/features/payday/payday_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Layar 18 · Gajian masuk dengan banyak kantong (bug nyata di HP:
/// 9 kantong → "BOTTOM OVERFLOWED BY 116 PIXELS").
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('9 kantong: tidak overflow, bisa di-scroll', (tester) async {
    tester.view.physicalSize = const Size(1080, 2436);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final info = PaydayInfo(
      periodId: 'p',
      start: DateTime(2026, 9, 1),
      salary: 233333,
      celebrated: false,
      allocations: [
        for (var i = 0; i < 9; i++)
          (
            PocketRef(
              id: 'k$i',
              type: PocketType.keinginan,
              name: 'Kantong $i',
              iconKey: 'home',
              color: 0xFF6D5DFC,
            ),
            i == 0 ? 233333 : 0,
          ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [paydayProvider.overrideWithValue(AsyncData(info))],
        child: MaterialApp(theme: buildAppTheme(), home: const PaydayScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Mantap, lanjut'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Kantong 8'), 200);
    expect(find.text('Kantong 8'), findsOneWidget);
  });
}
