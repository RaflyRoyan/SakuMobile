// QRIS: validasi payload EMV + ubah QRIS statis jadi dinamis bernominal (tag 54).
// Port dari src/lib/qris.ts di repo web; kasus uji sama (test/qris_test.dart).

const pesanBukanQris = 'Kode ini bukan QRIS. Pastikan QR dari GoPay Merchant/QRIS atas namamu.';
const pesanQrTidakTerbaca = 'QR tidak terbaca, coba gambar lebih jelas.';

/// Hasil [parseQris]: `ok` dengan merchant & kota, atau gagal dengan [pesan].
class HasilQris {
  const HasilQris._(this.ok, this.payload, this.merchant, this.kota, this.pesan);
  const HasilQris.valid(String payload, String merchant, String kota) : this._(true, payload, merchant, kota, null);
  const HasilQris.gagal([String pesan = pesanBukanQris]) : this._(false, '', '', '', pesan);

  final bool ok;
  final String payload;
  final String merchant;
  final String kota;
  final String? pesan;
}

/// CRC16-CCITT-FALSE (poly 0x1021, init 0xFFFF), 4 digit hex huruf besar.
String crc16(String s) {
  var crc = 0xffff;
  for (final c in s.codeUnits) {
    crc ^= (c << 8) & 0xffff;
    for (var b = 0; b < 8; b++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff;
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}

final _duaDigit = RegExp(r'^\d{2}$');

/// TLV EMV → daftar (tag, nilai); null kalau rusak/terpotong.
List<(String, String)>? _tlv(String s) {
  final out = <(String, String)>[];
  var i = 0;
  while (i < s.length) {
    if (i + 4 > s.length) return null;
    final id = s.substring(i, i + 2);
    final lenStr = s.substring(i + 2, i + 4);
    if (!_duaDigit.hasMatch(id) || !_duaDigit.hasMatch(lenStr)) return null;
    final len = int.parse(lenStr);
    if (i + 4 + len > s.length) return null;
    out.add((id, s.substring(i + 4, i + 4 + len)));
    i += 4 + len;
  }
  return out;
}

String _gabung(List<(String, String)> tags) => tags.map((t) => '${t.$1}${t.$2.length.toString().padLeft(2, '0')}${t.$2}').join();

HasilQris parseQris(String input) {
  const gagal = HasilQris.gagal();
  final payload = input.trim();
  final tags = _tlv(payload);
  if (tags == null || tags.length < 3) return gagal;
  String? get(String id) {
    for (final (t, v) in tags) {
      if (t == id) return v;
    }
    return null;
  }

  final last = tags.last;
  if (get('00') != '01' || (get('01') ?? '').isEmpty || get('58') != 'ID' || last.$1 != '63' || last.$2.length != 4) return gagal;
  if (crc16(payload.substring(0, payload.length - 4)) != last.$2.toUpperCase()) return gagal;
  // Merchant account information (tag 26–51) harus memuat penanda QRIS nasional.
  final qris = tags.any((t) {
    final n = int.parse(t.$1);
    return n >= 26 && n <= 51 && t.$2.toUpperCase().contains('ID.CO.QRIS');
  });
  if (!qris) return gagal;
  return HasilQris.valid(payload, get('59') ?? '', get('60') ?? '');
}

/// QRIS dinamis: tag 01 = "12", tag 54 = nominal (rupiah bulat) disisipkan
/// sebelum tag 58, CRC dihitung ulang. Payload harus sudah lolos [parseQris].
String qrisDinamis(String payload, int nominal) {
  final tags = _tlv(payload.trim());
  if (tags == null) throw const FormatException('Payload QRIS rusak.');
  final isi = [
    for (final (t, v) in tags)
      if (t != '54' && t != '63') (t, t == '01' ? '12' : v),
  ];
  final i58 = isi.indexWhere((t) => t.$1 == '58');
  isi.insert(i58 < 0 ? isi.length : i58, ('54', '$nominal'));
  final body = '${_gabung(isi)}6304';
  return body + crc16(body);
}
