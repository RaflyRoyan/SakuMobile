import 'package:flutter_test/flutter_test.dart';
import 'package:saku_mobile/api/models.dart';
import 'package:saku_mobile/services/jadwal_pengingat.dart';

import 'fake_server.dart';

Berulang langganan([Map<String, dynamic> ubah = const {}]) => Berulang.fromJson({...berulangJson, ...ubah});

void main() {
  final sekarang = DateTime(2026, 11, 6, 10);

  test('schedules H-min and due-day reminders for coming months, skipping the past', () {
    final j = buatJadwalPengingat([langganan()], sekarang);
    expect(j.map((e) => e.waktu), [
      DateTime(2026, 11, 28, 8),
      DateTime(2026, 12, 1, 8),
      DateTime(2026, 12, 29, 8),
      DateTime(2027, 1, 1, 8),
    ]);
    expect(j.map((e) => e.id), [1, 2, 3, 4]);
    expect(j.first.judul, 'Gym Fit+ jatuh tempo 3 hari lagi');
    expect(j.first.isi, contains('Rp 250.000 dari BCA'));
    expect(j[1].judul, 'Gym Fit+ jatuh tempo hari ini');
  });

  test('current month is skipped once paid; later months still remind', () {
    final b = langganan({'tglJatuhTempo': 20, 'status': 'dibayar'});
    final j = buatJadwalPengingat([b], sekarang);
    expect(j.first.waktu, DateTime(2026, 12, 17, 8));
  });

  test('unpaid current month still reminds on the due date', () {
    final j = buatJadwalPengingat([langganan({'tglJatuhTempo': 20})], sekarang);
    expect(j.take(2).map((e) => e.waktu), [DateTime(2026, 11, 17, 8), DateTime(2026, 11, 20, 8)]);
  });

  test('respects selesai, inactive, and short months', () {
    expect(buatJadwalPengingat([langganan({'selesai': '2026-12'})], sekarang).length, 2);
    expect(buatJadwalPengingat([langganan({'aktif': false})], sekarang), isEmpty);
    expect(jatuhTempoBulan(31, '2027-02'), DateTime(2027, 2, 28));
    expect(jatuhTempoBulan(31, '2028-02'), DateTime(2028, 2, 29));
  });

  test('caps the number of scheduled alarms', () {
    final banyak = [for (var i = 0; i < 40; i++) langganan({'id': 'RB-$i'})];
    expect(buatJadwalPengingat(banyak, sekarang).length, maksJadwal);
  });
}
