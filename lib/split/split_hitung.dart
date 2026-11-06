// Pratinjau bagian split bill. Port dari src/lib/splitHitung.ts (server tetap
// sumber kebenaran); kasus uji sama di test/split_hitung_test.dart.

/// Satu baris struk untuk dihitung: harga total baris + indeks peserta pemilik.
typedef ItemHitung = ({int harga, List<int> peserta});

/// Bagian tiap peserta. Pajak/servis/diskon dibagi sebanding dengan pesanan;
/// sisa pembulatan masuk ke [indeksSaya].
({int subtotal, int total, List<int> nominal}) hitungBagian(
  List<ItemHitung> items, {
  required int pajak,
  required int servis,
  required int diskon,
  required int jumlahPeserta,
  required int indeksSaya,
}) {
  final porsi = List<double>.filled(jumlahPeserta, 0);
  var subtotal = 0;
  for (final it in items) {
    subtotal += it.harga;
    final pemilik = it.peserta.where((p) => p >= 0 && p < jumlahPeserta).toList();
    for (final p in pemilik) {
      porsi[p] += it.harga / pemilik.length;
    }
  }
  final total = subtotal + pajak + servis - diskon;
  final faktor = subtotal > 0 ? total / subtotal : 0;
  // JS Math.round: half up (toward +∞), unlike Dart's round() (half away from zero).
  final nominal = [for (final x in porsi) (x * faktor + 0.5).floor()];
  final sisa = total - nominal.fold<int>(0, (a, b) => a + b);
  if (jumlahPeserta > 0 && indeksSaya >= 0 && indeksSaya < jumlahPeserta) nominal[indeksSaya] += sisa;
  return (subtotal: subtotal, total: total, nominal: nominal);
}

const _pecahan = {2: '½', 3: '⅓', 4: '¼', 5: '⅕'};

/// "½", "⅓", "¼", "⅕", selain itu "1/n".
String labelPecahan(int n) => _pecahan[n] ?? '1/$n';
