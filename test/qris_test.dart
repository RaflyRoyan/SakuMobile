import 'package:flutter_test/flutter_test.dart';
import 'package:saku_mobile/split/qris.dart';

String tlv(String id, String v) => '$id${v.length.toString().padLeft(2, '0')}$v';

/// QRIS statis contoh (bukan milik siapa pun). Sama dengan tests/qris.test.ts di web.
String statis([String? merchantInfo]) {
  final info = merchantInfo ?? tlv('00', 'ID.CO.QRIS.WWW') + tlv('01', 'ID1023000000001');
  final body = '${tlv('00', '01')}${tlv('01', '11')}${tlv('26', info)}${tlv('52', '5812')}${tlv('53', '360')}${tlv('58', 'ID')}${tlv('59', 'TOKO SAKU')}${tlv('60', 'SURABAYA')}6304';
  return body + crc16(body);
}

void main() {
  test('crc16 CCITT-FALSE', () {
    expect(crc16('123456789'), '29B1');
  });

  test('payload statis valid → merchant & kota', () {
    final h = parseQris(statis());
    expect(h.ok, isTrue);
    expect(h.payload, statis());
    expect(h.merchant, 'TOKO SAKU');
    expect(h.kota, 'SURABAYA');
  });

  test('spasi/newline di ujung & CRC huruf kecil tetap valid', () {
    final p = statis();
    final h = parseQris('$p\n ');
    expect(h.ok, isTrue);
    expect(h.payload, p);
    expect(parseQris(p.substring(0, p.length - 4) + p.substring(p.length - 4).toLowerCase()).ok, isTrue);
  });

  test('CRC salah, bukan QRIS, atau TLV terpotong → ditolak', () {
    final p = statis();
    final akhir = p.substring(p.length - 4);
    final crcSalah = p.substring(0, p.length - 4) + (akhir == '0000' ? '0001' : '0000');
    for (final s in [crcSalah, statis(tlv('00', 'COM.GOJEK.PERSONAL')), 'halo dunia', p.substring(0, 30), '']) {
      final h = parseQris(s);
      expect(h.ok, isFalse, reason: s);
      expect(h.pesan, pesanBukanQris);
    }
  });

  test('qrisDinamis: tag 01 = 12, tag 54 = nominal, CRC baru valid', () {
    final d = qrisDinamis(statis(), 25000);
    expect(d, contains('010212'));
    expect(d, contains('540525000'));
    expect(d.indexOf('5405'), lessThan(d.indexOf('5802ID')));
    final h = parseQris(d);
    expect(h.ok, isTrue);
    expect(h.merchant, 'TOKO SAKU');
  });

  test('qrisDinamis dua kali: tag 54 diganti, bukan dobel', () {
    final d = qrisDinamis(qrisDinamis(statis(), 1000), 2000);
    expect(RegExp(r'54\d{2}\d+?5802ID').allMatches(d).length, 1);
    expect(d, contains('54042000'));
    expect(d, isNot(contains('54041000')));
    expect(parseQris(d).ok, isTrue);
  });
}
