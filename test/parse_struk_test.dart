import 'package:flutter_test/flutter_test.dart';
import 'package:saku_mobile/split/parse_struk.dart';

void main() {
  test('struk restoran: PB1 + service, subtotal/total/bayar dibuang dari item', () {
    final h = parseStruk('''BAKMI GM
Jl. Pemuda 12 Surabaya
Meja 7   Kasir: Rina
2 Bakmi Ayam         70.000
1 Pangsit Goreng     28,000
Es Teh Manis x3      Rp24.000
Kerupuk                5000
Sub Total           127.000
Service 5%            6.350
PB1 10%              13.335
Total               146.685
Tunai               150.000
Kembali               3.315
Terima kasih''');
    expect(h.items, const [
      ItemStruk('Bakmi Ayam', 2, 70000),
      ItemStruk('Pangsit Goreng', 1, 28000),
      ItemStruk('Es Teh Manis', 3, 24000),
      ItemStruk('Kerupuk', 1, 5000),
    ]);
    expect((h.pajak, h.servis, h.diskon, h.total), (13335, 6350, 0, 146685));
  });

  test('struk minimarket: qty "2 x", diskon negatif, desimal ,00, angka kecil dibuang', () {
    final h = parseStruk('''INDOMARET
AQUA 600ML  2 x 3.500     7.000,00
ROTI TAWAR                15.500,00
DISC ROTI                 -2.000,00
PPN                        1.500
HARGA JUAL                22.000
QRIS                      22.000
NO 12''');
    expect(h.items, const [ItemStruk('AQUA 600ML', 2, 7000), ItemStruk('ROTI TAWAR', 1, 15500)]);
    expect((h.pajak, h.servis, h.diskon, h.total), (1500, 0, 2000, 22000));
  });

  test('baris tunggal dari spesifikasi', () {
    expect(parseStruk('2 Bakmi Ayam 70.000').items, const [ItemStruk('Bakmi Ayam', 2, 70000)]);
    expect(parseStruk('Es Teh Manis x3 Rp24.000').items, const [ItemStruk('Es Teh Manis', 3, 24000)]);
    expect(parseStruk('AQUA 600ML  2 x 3.500  7.000,00').items, const [ItemStruk('AQUA 600ML', 2, 7000)]);
    expect(parseStruk('DISC ROTI -2.000,00').diskon, 2000);
    expect(parseStruk('PB1 10% 13.335').pajak, 13335);
    expect(parseStruk('Service 5% 6.350').servis, 6350);
    expect(parseStruk('Total 146.685').total, 146685);
    final tunai = parseStruk('Tunai 150.000');
    expect(tunai.items, isEmpty);
    expect(tunai.total, isNull);
  });

  test('teks kosong / tanpa angka → item kosong', () {
    final h = parseStruk('');
    expect(h.items, isEmpty);
    expect((h.pajak, h.servis, h.diskon, h.total), (0, 0, 0, null));
    expect(parseStruk('Terima kasih\natas kunjungan').items, isEmpty);
  });
}
