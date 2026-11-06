import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:saku_mobile/app.dart';
import 'package:saku_mobile/services/app_prefs.dart';
import 'package:saku_mobile/services/app_services.dart';
import 'package:saku_mobile/services/platform_services.dart';
import 'package:saku_mobile/screens/settings_screen.dart';
import 'package:saku_mobile/screens/transactions_screen.dart';

import 'fake_server.dart';

class FakeDeviceAuth implements DeviceAuth {
  FakeDeviceAuth({this.hasil = true});
  bool hasil;
  int dipanggil = 0;

  @override
  Future<bool> didukung() async => true;

  @override
  Future<bool> autentikasi(String alasan) async {
    dipanggil++;
    return hasil;
  }
}

void main() {
  setUpAll(() {
    // No network in tests: fall back to the default font.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> login(WidgetTester tester, FakeServer server) async {
    await tester.pumpWidget(SakuApp(api: server.api()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'ryn');
    await tester.enterText(find.byType(TextField).at(1), 'rahasia123');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
  }

  testWidgets('Login leads to dashboard with live data', (tester) async {
    phoneSize(tester);
    final server = FakeServer();
    await login(tester, server);

    expect(find.text('Total saldo semua akun'), findsOneWidget);
    expect(find.text('Rp 6.389.500'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Gym Fit+'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Gym Fit+'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Riwayat').last);
    await tester.pumpAndSettle();
    final footer = find.text('Menampilkan 4 dari 4 transaksi');
    await tester.scrollUntilVisible(footer, 300, scrollable: find.descendant(of: find.byType(TransactionsScreen), matching: find.byType(Scrollable)).first);
    expect(footer, findsOneWidget);
  });

  testWidgets('Dashboard stat cards keep labels on one line', (tester) async {
    phoneSize(tester);
    await login(tester, FakeServer());
    final tops = [for (final l in ['Saldo awal', 'Masuk', 'Pengeluaran']) tester.getTopLeft(find.text(l)).dy];
    expect(tops.toSet().length, 1);
    final heights = [for (final l in ['Saldo awal', 'Masuk', 'Pengeluaran']) tester.getSize(find.text(l)).height];
    expect(heights.toSet().length, 1, reason: 'a wrapped label would be taller');
  });

  testWidgets('Swipe left on a history row deletes it after confirmation', (tester) async {
    phoneSize(tester);
    final server = FakeServer();
    await login(tester, server);
    await tester.tap(find.text('Riwayat').last);
    await tester.pumpAndSettle();

    final row = find.descendant(of: find.byType(TransactionsScreen), matching: find.text('Bensin motor'));
    expect(row, findsOneWidget);
    await tester.drag(row, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Hapus transaksi ini?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(server.requests.any((r) => r.method == 'DELETE' && r.url.path.endsWith('/transaksi/TR-2')), isTrue);
    expect(find.descendant(of: find.byType(TransactionsScreen), matching: find.text('Bensin motor')), findsNothing);
  });

  testWidgets('Wrong password shows the server message', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(SakuApp(api: FakeServer().api()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'ryn');
    await tester.enterText(find.byType(TextField).at(1), 'salah');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Username atau password salah.'), findsOneWidget);
  });

  testWidgets('Every screen builds without overflow', (tester) async {
    phoneSize(tester);
    final server = FakeServer();
    await login(tester, server);

    for (final tab in ['Anggaran', 'Tabungan', 'Riwayat', 'Beranda']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }

    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    for (final (route, args) in [
      (Routes.addTransaction, null),
      (Routes.editTransaction, 'TR-1'),
      (Routes.subscriptions, null),
      (Routes.closePeriod, null),
      (Routes.settings, null),
      (Routes.users, null),
      (Routes.statistics, null),
      (Routes.split, null),
      (Routes.splitBaru, null),
      (Routes.splitDetail, 'SP-1'),
      (Routes.splitUbah, 'SP-1'),
      (Routes.terimaQris, null),
      (Routes.qrisSettings, null),
    ]) {
      nav.pushNamed(route, arguments: args);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
      nav.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Statistik shows spending per kelompok and switches to income', (tester) async {
    phoneSize(tester);
    await login(tester, FakeServer());
    final top = find.text('Pengeluaran terbesar');
    await tester.scrollUntilVisible(top, 300, scrollable: find.byType(Scrollable).first);
    expect(top, findsOneWidget);

    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pushNamed(Routes.statistics);
    await tester.pumpAndSettle();
    expect(find.text('Rp 360.500'), findsOneWidget);
    expect(find.text('Transportasi'), findsOneWidget);
    expect(find.text('64%'), findsOneWidget);
    expect(find.text('Pengeluaran per hari'), findsOneWidget);

    await tester.tap(find.text('Pemasukan'));
    await tester.pumpAndSettle();
    expect(find.text('Pemasukan lain'), findsOneWidget);
    expect(find.text('Pemasukan per hari'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('App lock covers a resumed session until the device unlocks it', (tester) async {
    phoneSize(tester);
    final server = FakeServer()..loggedIn = true;
    final auth = FakeDeviceAuth(hasil: false);
    final services = AppServices.memori(prefs: MemoryPrefStore({'kunci_aktif': true}), auth: auth);
    await tester.pumpWidget(SakuApp(api: server.api(token: 'jwt-abc'), services: services));
    await tester.pumpAndSettle();

    expect(find.text('Saku terkunci'), findsOneWidget);
    expect(auth.dipanggil, 1, reason: 'prompts automatically');

    auth.hasil = true;
    await tester.tap(find.text('Buka kunci'));
    await tester.pumpAndSettle();
    expect(find.text('Saku terkunci'), findsNothing);
    expect(find.text('Total saldo semua akun'), findsOneWidget);
  });

  testWidgets('App lock does not ask again right after typing the password', (tester) async {
    phoneSize(tester);
    final server = FakeServer();
    final auth = FakeDeviceAuth();
    await tester.pumpWidget(SakuApp(api: server.api(), services: AppServices.memori(prefs: MemoryPrefStore({'kunci_aktif': true}), auth: auth)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'ryn');
    await tester.enterText(find.byType(TextField).at(1), 'rahasia123');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Saku terkunci'), findsNothing);
    expect(auth.dipanggil, 0);
  });

  testWidgets('Turning on app lock in settings verifies the device first', (tester) async {
    phoneSize(tester);
    final prefs = MemoryPrefStore();
    final auth = FakeDeviceAuth();
    await tester.pumpWidget(SakuApp(api: FakeServer().api(), services: AppServices.memori(prefs: prefs, auth: auth)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'ryn');
    await tester.enterText(find.byType(TextField).at(1), 'rahasia123');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    tester.state<NavigatorState>(find.byType(Navigator).first).pushNamed(Routes.settings);
    await tester.pumpAndSettle();
    final item = find.text('Kunci aplikasi');
    await tester.scrollUntilVisible(item, 200, scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first);
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
    expect(auth.dipanggil, 1);
    expect(prefs.getBool('kunci_aktif'), isTrue);
  });
}
