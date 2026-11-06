/// Formats an integer with Indonesian thousand separators: 1234567 -> "1.234.567".
String thousands(int value) {
  final s = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return value < 0 ? '−${buf.toString()}' : buf.toString();
}

/// "Rp 1.234.567" / "−Rp 25.000"
String rupiah(int value) => value < 0 ? '−Rp ${thousands(-value)}' : 'Rp ${thousands(value)}';

/// Signed amount using a real minus sign, e.g. "−28.000" / "+750.000".
String signed(int value) => value < 0 ? '−${thousands(-value)}' : '+${thousands(value)}';

/// Parses user input like "1.500.000" or "Rp 25000" to int; null if empty.
int? parseNominal(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : int.tryParse(digits);
}

const _hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _hariPanjang = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const _bulanPanjang = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

/// Today in WIB (UTC+7), date only. The API computes dates in WIB too.
DateTime todayWib() {
  final n = DateTime.now().toUtc().add(const Duration(hours: 7));
  return DateTime(n.year, n.month, n.day);
}

DateTime? parseYmd(String? s) {
  if (s == null || s.length < 10) return null;
  final p = s.substring(0, 10).split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String _two(int n) => n.toString().padLeft(2, '0');
String ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
String ym(DateTime d) => '${d.year}-${_two(d.month)}';

/// "5 Nov"
String tglPendek(String s) {
  final d = parseYmd(s);
  return d == null ? s : '${d.day} ${_bulan[d.month - 1]}';
}

/// "5 Nov 2026"
String tglSedang(String s) {
  final d = parseYmd(s);
  return d == null ? s : '${d.day} ${_bulan[d.month - 1]} ${d.year}';
}

/// "Kamis, 5 Nov 2026"
String tglPanjang(DateTime d) => '${_hariPanjang[d.weekday - 1]}, ${d.day} ${_bulan[d.month - 1]} ${d.year}';

/// "Hari ini · Kam 5 Nov" / "Kemarin · …" / "Rab 4 Nov"
String labelHari(String s) {
  final d = parseYmd(s);
  if (d == null) return s;
  final base = '${_hari[d.weekday - 1]} ${d.day} ${_bulan[d.month - 1]}';
  final diff = todayWib().difference(d).inDays;
  if (diff == 0) return 'Hari ini · $base';
  if (diff == 1) return 'Kemarin · $base';
  return d.year == todayWib().year ? base : '$base ${d.year}';
}

/// "Hari ini" / "Kemarin" / "4 Nov"
String tglRelatif(String s) {
  final d = parseYmd(s);
  if (d == null) return s;
  final diff = todayWib().difference(d).inDays;
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Kemarin';
  return tglPendek(s);
}

/// "2026-11" -> "November 2026"
String namaBulan(String yyyyMm) {
  final p = yyyyMm.split('-');
  final m = p.length == 2 ? int.tryParse(p[1]) : null;
  return m == null || m < 1 || m > 12 ? yyyyMm : '${_bulanPanjang[m - 1]} ${p[0]}';
}

/// "2026-11" -> "NOV"
String bulanSingkat(String yyyyMmDd) {
  final p = yyyyMmDd.split('-');
  final m = p.length >= 2 ? int.tryParse(p[1]) : null;
  return m == null || m < 1 || m > 12 ? '' : _bulan[m - 1].toUpperCase();
}

/// Short badge text for an account name: "BCA", "Mandiri" -> "MDR", "GoPay" -> "GP".
String kodeAkun(String nama) {
  final n = nama.trim();
  if (n.length <= 3) return n.toUpperCase();
  final caps = RegExp(r'[A-Z]').allMatches(n).map((m) => m[0]).join();
  if (caps.length >= 2) return caps.substring(0, caps.length.clamp(2, 3));
  final cons = n[0] + n.substring(1).replaceAll(RegExp(r'[aiueoAIUEO\s]'), '');
  return cons.substring(0, cons.length.clamp(1, 3)).toUpperCase();
}

/// Two-letter initials for a transaction description.
String inisial(String text) {
  final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, words.first.length.clamp(1, 2)).toUpperCase();
  return (words[0][0] + words[1][0]).toUpperCase();
}

/// Time-of-day greeting in WIB.
String salam() {
  final h = DateTime.now().toUtc().add(const Duration(hours: 7)).hour;
  if (h < 11) return 'Selamat pagi,';
  if (h < 15) return 'Selamat siang,';
  if (h < 19) return 'Selamat sore,';
  return 'Selamat malam,';
}
