// Ubah teks hasil OCR struk jadi draf item + pajak/servis/diskon/total.
// Port dari src/lib/parseStruk.ts; heuristik, pengguna tetap wajib mengecek.

class ItemStruk {
  const ItemStruk(this.nama, this.qty, this.harga);

  final String nama;
  final int qty;

  /// Harga total baris.
  final int harga;

  @override
  bool operator ==(Object other) => other is ItemStruk && other.nama == nama && other.qty == qty && other.harga == harga;

  @override
  int get hashCode => Object.hash(nama, qty, harga);

  @override
  String toString() => 'ItemStruk($nama, $qty, $harga)';
}

class HasilStruk {
  final items = <ItemStruk>[];
  int pajak = 0;
  int servis = 0;
  int diskon = 0;
  int? total;
}

final _angka = RegExp(r'(-?)\s*(?:rp\.?\s*)?(\d[\d.,]*\d|\d)(?!\s*%)', caseSensitive: false);

enum _Label { abaikan, subtotal, total, pajak, servis, diskon }

final _label = <(RegExp, _Label)>[
  (RegExp(r'\b(tunai|cash|kembali(an)?|change|bayar|debit|kredit|qris|kartu|card|ovo|gopay|dana|shopeepay)\b'), _Label.abaikan),
  (RegExp(r'\bsub\s*-?\s*total\b'), _Label.subtotal),
  (RegExp(r'\b(pajak|tax|pb\s*1|pbi|ppn)\b'), _Label.pajak),
  (RegExp(r'\b(service|servis|svc|layanan)\b'), _Label.servis),
  (RegExp(r'\b(disc|diskon|discount|potongan|promo|hemat)\b'), _Label.diskon),
  (RegExp(r'\b(grand\s*total|total|jumlah|harga\s*jual)\b'), _Label.total),
];

/// `12.000`, `12,000`, `12000`, `12.000,00` → 12000.
int _keAngka(String s) => int.tryParse(s.replaceFirst(RegExp(r'[.,]\d{2}$'), '').replaceAll(RegExp(r'[.,]'), '')) ?? 0;

final _qtyTengah = RegExp(r'\s(\d{1,3})\s*[xX@]\s*[\d.,]+\s*$');
final _qtyAkhir = RegExp(r'\s[xX](\d{1,3})\s*$');
final _qtyAwal = RegExp(r'^(\d{1,3})\s*[xX]?\s+(?=\D)');
final _rpAkhir = RegExp(r'\s*(rp\.?)?\s*$', caseSensitive: false);
final _huruf = RegExp(r'[a-zA-Z]');

HasilStruk parseStruk(String teks) {
  final hasil = HasilStruk();
  for (final baris in teks.split(RegExp(r'\r?\n'))) {
    final line = baris.trim();
    final cocok = _angka.allMatches(line).toList();
    if (cocok.isEmpty) continue;
    final akhir = cocok.last;
    final nilai = _keAngka(akhir.group(2)!);
    if (nilai < 100) continue;

    var nama = line.substring(0, akhir.start).trim();
    final lower = nama.toLowerCase();
    _Label? label;
    for (final (re, l) in _label) {
      if (re.hasMatch(lower)) {
        label = l;
        break;
      }
    }
    switch (label) {
      case _Label.abaikan || _Label.subtotal:
        continue;
      case _Label.total:
        hasil.total ??= nilai;
        continue;
      case _Label.pajak:
        hasil.pajak += nilai;
        continue;
      case _Label.servis:
        hasil.servis += nilai;
        continue;
      case _Label.diskon:
        hasil.diskon += nilai;
        continue;
      case null:
        break;
    }

    // Qty: "2 x 3.500" di tengah, "x3" di akhir nama, atau "2 " di awal nama.
    var qty = 1;
    nama = nama.replaceFirstMapped(_qtyTengah, (m) {
      qty = int.parse(m.group(1)!);
      return '';
    }).replaceFirstMapped(_qtyAkhir, (m) {
      qty = int.parse(m.group(1)!);
      return '';
    }).replaceFirstMapped(_qtyAwal, (m) {
      qty = int.parse(m.group(1)!);
      return '';
    }).replaceFirst(_rpAkhir, '').trim();
    if (!_huruf.hasMatch(nama)) continue;
    hasil.items.add(ItemStruk(nama, qty < 1 ? 1 : qty, nilai));
  }
  return hasil;
}
