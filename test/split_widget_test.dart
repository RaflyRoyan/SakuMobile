import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:saku_mobile/app.dart';
import 'package:saku_mobile/services/app_services.dart';
import 'package:saku_mobile/services/media_services.dart';
import 'package:saku_mobile/split/qris.dart';

import 'fake_server.dart';

class FakeMedia implements MediaServices {
  String? gambar = 'struk.jpg';
  String teks = '';
  String? qr;
  final shared = <({String namaFile, String teks, int bytes})>[];

  @override
  Future<String?> ambilGambar({required bool kamera}) async => gambar;
  @override
  Future<String> bacaTeks(String path) async => teks;
  @override
  Future<String?> bacaQr(String path) async => qr;
  @override
  Future<void> bagikanGambar(Uint8List png, {required String namaFile, required String teks}) async =>
      shared.add((namaFile: namaFile, teks: teks, bytes: png.length));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeServer server;
  late FakeMedia media;

  Future<NavigatorState> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    server = FakeServer();
    media = FakeMedia();
    await tester.pumpWidget(SakuApp(api: server.api(), services: AppServices.memori(media: media)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'ryn');
    await tester.enterText(find.byType(TextField).at(1), 'rahasia123');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    return tester.state<NavigatorState>(find.byType(Navigator).first);
  }

  Map<String, dynamic> lastBody(String method, String path) =>
      jsonDecode(server.requests.lastWhere((r) => r.method == method && r.url.path.endsWith(path)).body) as Map<String, dynamic>;

  testWidgets('Beranda shows unpaid split bills and shortcuts', (tester) async {
    await start(tester);
    expect(find.text('2 orang belum bayar · Rp 29.334'), findsOneWidget);
    expect(find.text('Split Bill'), findsOneWidget);
    expect(find.text('Terima QRIS'), findsOneWidget);
  });

  testWidgets('Detail: mark a friend paid, share a bill card without QRIS', (tester) async {
    final nav = await start(tester);
    nav.pushNamed(Routes.splitDetail, arguments: 'SP-1');
    await tester.pumpAndSettle();
    expect(find.text('bagianmu'), findsOneWidget);
    expect(find.text('Rp 25.667'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Lunas Budi'));
    await tester.pumpAndSettle();
    expect(lastBody('PUT', '/split/SP-1/peserta/PS-2/lunas')['lunas'], isTrue);
    expect(find.text('Lunas'), findsOneWidget);

    expect(find.widgetWithText(TextButton, 'Bagikan'), findsOneWidget, reason: 'only Sari is unpaid now');
    await tester.tap(find.widgetWithText(TextButton, 'Bagikan'));
    await tester.pumpAndSettle();
    expect(find.text('Tagihan untuk Sari'), findsOneWidget);
    expect(find.text('Transfer sesuai total di atas'), findsOneWidget);
    expect(find.text('3× Es Teh (⅓)'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Bagikan'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(media.shared, hasLength(1));
    expect(media.shared.single.teks, 'Halo Sari, tagihan Bakmi GM: Rp 3.667. Bayar lewat QRIS di gambar ya.');
    expect(media.shared.single.bytes, greaterThan(1000));
  });

  testWidgets('New split from a receipt photo: OCR fills items, split evenly, saved with indices', (tester) async {
    final nav = await start(tester);
    media.teks = '2 Bakmi Ayam   70.000\nEs Teh x2   20.000\nPB1 10%   9.000\nTotal   99.000';
    nav.pushNamed(Routes.splitBaru);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foto struk'));
    await tester.pumpAndSettle();

    expect(find.text('Langkah 2 dari 4 · Item'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Bakmi Ayam'), findsOneWidget);
    expect(find.textContaining('Total struk'), findsNothing, reason: 'OCR total matches');
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Nama teman'), 'Budi');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Tambah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Tandai pemilik tiap item.'), findsOneWidget);
    await tester.tap(find.text('Bagi rata'));
    await tester.pumpAndSettle();
    final preview = find.text('Rp 49.500');
    await tester.scrollUntilVisible(preview.first, 300, scrollable: find.byType(Scrollable).first);
    expect(preview, findsNWidgets(2));
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Mis. Makan malam Bakmi GM'), 'Makan siang');
    await tester.tap(find.text('Kebutuhan Harian'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    final body = lastBody('POST', '/split');
    expect(body['nama'], 'Makan siang');
    expect(body['akunTerimaId'], 'AK-gp', reason: 'defaults to GoPay');
    expect(body['kategoriId'], 'KT-kopi');
    expect(body['pajak'], 9000);
    expect(body['peserta'], [
      {'nama': 'Saya', 'saya': true},
      {'nama': 'Budi', 'saya': false},
    ]);
    expect(body['items'], [
      {'nama': 'Bakmi Ayam', 'qty': 2, 'harga': 70000, 'peserta': [0, 1]},
      {'nama': 'Es Teh', 'qty': 2, 'harga': 20000, 'peserta': [0, 1]},
    ]);
    expect(find.text('bagianmu'), findsOneWidget, reason: 'opens the new split');
  });

  testWidgets('Unreadable receipt keeps manual entry available', (tester) async {
    final nav = await start(tester);
    media.teks = 'Terima kasih';
    nav.pushNamed(Routes.splitBaru);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih dari galeri'));
    await tester.pumpAndSettle();
    expect(find.text('Struk tidak terbaca, isi manual atau foto ulang.'), findsOneWidget);
    await tester.tap(find.text('Isi manual'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Lengkapi nama dan harga tiap item.'), findsOneWidget);
  });

  testWidgets('Terima QRIS: dynamic QR then record the income', (tester) async {
    final nav = await start(tester);
    server.qrisPayload = qrisContoh;
    nav.pushNamed(Routes.terimaQris);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '25000');
    await tester.tap(find.text('Buat QRIS'));
    await tester.pumpAndSettle();

    expect(find.text('Rp 25.000'), findsOneWidget);
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.size, greaterThanOrEqualTo(240));
    final payload = parseQris(qrisDinamis(qrisContoh, 25000));
    expect(payload.ok, isTrue);

    await tester.tap(find.text('Sudah dibayar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pemasukan lain'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();
    final body = lastBody('POST', '/transaksi');
    expect(body, containsPair('tipe', 'masuk'));
    expect(body, containsPair('akunId', 'AK-gp'));
    expect(body, containsPair('nominal', 25000));
    expect(body, containsPair('deskripsi', 'Pembayaran QRIS'));
    expect(find.text('Buat QRIS'), findsOneWidget, reason: 'back to the form');
  });

  testWidgets('Terima QRIS without a saved QRIS invites to settings', (tester) async {
    final nav = await start(tester);
    nav.pushNamed(Routes.terimaQris);
    await tester.pumpAndSettle();
    expect(find.text('QRIS belum diatur'), findsOneWidget);
  });

  testWidgets('QRIS settings: reject non-QRIS and unreadable images, then save a valid one', (tester) async {
    final nav = await start(tester);
    nav.pushNamed(Routes.qrisSettings);
    await tester.pumpAndSettle();

    media.qr = 'https://contoh.com';
    await tester.tap(find.text('Upload QRIS'));
    await tester.pumpAndSettle();
    expect(find.text(pesanBukanQris), findsOneWidget);

    media.qr = null;
    await tester.tap(find.text('Upload QRIS'));
    await tester.pumpAndSettle();
    expect(find.text(pesanQrTidakTerbaca), findsOneWidget);

    media.qr = qrisContoh;
    await tester.tap(find.text('Upload QRIS'));
    await tester.pumpAndSettle();
    expect(find.text('Pratinjau QRIS baru'), findsOneWidget);
    expect(find.text('TOKO SAKU'), findsOneWidget);
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(server.qrisPayload, qrisContoh);
    expect(find.text('QRIS tersimpan'), findsOneWidget);
    expect(find.text('Ganti QRIS'), findsOneWidget);
  });
}
