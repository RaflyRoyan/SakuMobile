import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:saku_mobile/app.dart';
import 'package:saku_mobile/screens/transactions_screen.dart';

void main() {
  setUpAll(() {
    // No network in tests: fall back to the default font.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Login leads to dashboard with bottom nav', (tester) async {
    await tester.pumpWidget(const SakuApp());
    await tester.pumpAndSettle();

    expect(find.text('Saku'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'ryn');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Total saldo semua akun'), findsOneWidget);
    expect(find.text('Rp 6.389.500'), findsOneWidget);

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    final footer = find.text('Menampilkan 9 dari 9 transaksi');
    await tester.scrollUntilVisible(footer, 300, scrollable: find.descendant(of: find.byType(TransactionsScreen), matching: find.byType(Scrollable)).first);
    expect(footer, findsOneWidget);
  });

  testWidgets('Empty login shows error', (tester) async {
    await tester.pumpWidget(const SakuApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masuk'));
    await tester.pump();
    expect(find.text('Username atau password salah.'), findsOneWidget);
  });

  testWidgets('Every screen builds without overflow', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SakuApp());
    await tester.pumpAndSettle();
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    for (final r in [Routes.home, Routes.addTransaction, Routes.editTransaction, Routes.subscriptions, Routes.closePeriod, Routes.settings]) {
      nav.pushNamed(r);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: r);
    }
  });
}
