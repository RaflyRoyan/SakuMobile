import 'package:flutter_test/flutter_test.dart';
import 'package:saku_mobile/split/split_hitung.dart';

void main() {
  test('pajak dibagi sebanding, sisa pembulatan ke saya', () {
    final r = hitungBagian(
      [(harga: 30000, peserta: [0]), (harga: 20000, peserta: [1]), (harga: 10000, peserta: [0, 1, 2])],
      pajak: 6000,
      servis: 0,
      diskon: 0,
      jumlahPeserta: 3,
      indeksSaya: 0,
    );
    expect(r.subtotal, 60000);
    expect(r.total, 66000);
    expect(r.nominal, [36666, 25667, 3667]);
  });

  test('bagi rata 100.000 / 3', () {
    final r = hitungBagian([(harga: 100000, peserta: [0, 1, 2])], pajak: 0, servis: 0, diskon: 0, jumlahPeserta: 3, indeksSaya: 0);
    expect(r.nominal, [33334, 33333, 33333]);
  });

  test('diskon mengurangi tiap bagian', () {
    final r = hitungBagian([(harga: 25000, peserta: [0]), (harga: 25000, peserta: [1])], pajak: 0, servis: 0, diskon: 10000, jumlahPeserta: 2, indeksSaya: 0);
    expect(r.total, 40000);
    expect(r.nominal, [20000, 20000]);
  });

  test('label pecahan', () {
    expect([2, 3, 4, 5, 6].map(labelPecahan), ['½', '⅓', '¼', '⅕', '1/6']);
  });
}
