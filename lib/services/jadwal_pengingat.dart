import '../api/models.dart';
import '../utils/format.dart';

/// One local notification to schedule. [waktu] is a WIB wall-clock time.
class JadwalPengingat {
  const JadwalPengingat({required this.id, required this.waktu, required this.judul, required this.isi});

  final int id;
  final DateTime waktu;
  final String judul;
  final String isi;

  @override
  String toString() => 'JadwalPengingat($id, $waktu, $judul)';
}

/// Hour (WIB) at which reminders fire.
const jamPengingat = 8;

/// Android keeps a limited number of alarms per app; stay well below it.
const maksJadwal = 60;

/// Due date of a subscription in month [bulan] (`yyyy-MM`):
/// min(tglJatuhTempo, last day of the month), same rule as the server.
DateTime jatuhTempoBulan(int tgl, String bulan) {
  final p = bulan.split('-');
  final y = int.parse(p[0]), m = int.parse(p[1]);
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, tgl.clamp(1, last));
}

String _tambahBulan(String bulan, int n) {
  final p = bulan.split('-');
  return ym(DateTime(int.parse(p[0]), int.parse(p[1]) + n, 1));
}

/// Reminders for the current month and the next [bulanKedepan] months.
///
/// For each active subscription that applies in a month (between `mulai` and
/// `selesai`), schedules one notification `ingatkanHMin` days before the due
/// date and one on the due date, both at [jamPengingat] WIB. The current month
/// is skipped when it is already paid or skipped (`status != belum`); future
/// months are rescheduled on every sync, so paying early cancels them then.
List<JadwalPengingat> buatJadwalPengingat(List<Berulang> list, DateTime sekarangWib, {int bulanKedepan = 2}) {
  final hasil = <JadwalPengingat>[];
  final bulanIni = ym(sekarangWib);
  for (final b in list) {
    if (!b.aktif) continue;
    for (var i = 0; i <= bulanKedepan; i++) {
      final bulan = _tambahBulan(bulanIni, i);
      if (b.mulai.isNotEmpty && bulan.compareTo(b.mulai) < 0) continue;
      if (b.selesai != null && b.selesai!.isNotEmpty && bulan.compareTo(b.selesai!) > 0) continue;
      if (bulan == b.bulan && b.status != 'belum') continue;
      final jt = jatuhTempoBulan(b.tglJatuhTempo, bulan);
      final detail = '${rupiah(b.nominal)} dari ${b.akunNama} · ${tglPanjang(jt)}';
      final hMin = b.ingatkanHMin.clamp(0, 28);
      if (hMin > 0) {
        final d = jt.subtract(Duration(days: hMin));
        hasil.add(JadwalPengingat(
          id: 0,
          waktu: DateTime(d.year, d.month, d.day, jamPengingat),
          judul: '${b.nama} jatuh tempo $hMin hari lagi',
          isi: detail,
        ));
      }
      hasil.add(JadwalPengingat(
        id: 0,
        waktu: DateTime(jt.year, jt.month, jt.day, jamPengingat),
        judul: '${b.nama} jatuh tempo hari ini',
        isi: '$detail. Tandai lunas di Saku setelah bayar.',
      ));
    }
  }
  final akanDatang = hasil.where((j) => j.waktu.isAfter(sekarangWib)).toList()..sort((a, b) => a.waktu.compareTo(b.waktu));
  return [
    for (final (i, j) in akanDatang.take(maksJadwal).indexed) JadwalPengingat(id: i + 1, waktu: j.waktu, judul: j.judul, isi: j.isi),
  ];
}
