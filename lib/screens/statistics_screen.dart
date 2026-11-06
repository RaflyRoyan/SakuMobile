import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';

enum _Mode { keluar, masuk }

class _StatData {
  _StatData(this.periode, this.semuaPeriode, this.ringkasan, this.harian);

  final Periode periode;
  final List<Periode> semuaPeriode;
  final Ringkasan ringkasan;

  /// One entry per day of the period (up to today), pengeluaran & pemasukan.
  final List<({DateTime tanggal, int keluar, int masuk})> harian;
}

/// Spending / income per kategori and per day for one period.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String? _periodeId;
  _Mode _mode = _Mode.keluar;

  Future<_StatData?> _load() async {
    final api = context.api;
    final semua = await api.periode();
    if (semua.isEmpty) return null;
    final p = semua.firstWhere((p) => p.id == _periodeId, orElse: () => semua.firstWhere((p) => p.aktif, orElse: () => semua.first));

    final ringkasanF = api.ringkasanPeriode(p.id);
    final tx = <Transaksi>[];
    for (var halaman = 1; halaman <= 10; halaman++) {
      final h = await api.transaksi(periodeId: p.id, halaman: halaman, ukuran: 200);
      tx.addAll(h.data);
      if (tx.length >= h.total || h.data.isEmpty) break;
    }
    return _StatData(p, semua, await ringkasanF, _perHari(p, tx));
  }

  static List<({DateTime tanggal, int keluar, int masuk})> _perHari(Periode p, List<Transaksi> tx) {
    final mulai = parseYmd(p.tanggalMulai) ?? todayWib();
    var akhir = parseYmd(p.tanggalSelesai) ?? todayWib();
    if (akhir.isBefore(mulai)) akhir = mulai;
    final keluar = <String, int>{}, masuk = <String, int>{};
    for (final t in tx) {
      final k = t.tanggal.length >= 10 ? t.tanggal.substring(0, 10) : t.tanggal;
      switch (t.tipe) {
        case TipeTransaksi.keluar:
          keluar[k] = (keluar[k] ?? 0) + t.nominal + t.biayaAdmin;
        case TipeTransaksi.masuk:
          masuk[k] = (masuk[k] ?? 0) + t.nominal;
        case TipeTransaksi.transfer:
          if (t.biayaAdmin > 0) keluar[k] = (keluar[k] ?? 0) + t.biayaAdmin;
      }
    }
    final hari = akhir.difference(mulai).inDays + 1;
    return [
      for (var i = 0; i < hari; i++)
        (() {
          final d = DateTime(mulai.year, mulai.month, mulai.day + i);
          return (tanggal: d, keluar: keluar[ymd(d)] ?? 0, masuk: masuk[ymd(d)] ?? 0);
        })(),
    ];
  }

  Future<void> _pilihPeriode(_StatData d) async {
    final picked = await pickOne<String>(
      context,
      title: 'Periode',
      selected: d.periode.id,
      options: [
        for (final p in d.semuaPeriode)
          PickOption(p.id, p.nama, subtitle: '${tglSedang(p.tanggalMulai)} – ${p.tanggalSelesai == null ? 'sekarang' : tglSedang(p.tanggalSelesai!)}'),
      ],
    );
    if (picked != null && picked != d.periode.id && mounted) setState(() => _periodeId = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SubPageHeader(title: 'Statistik'),
            Expanded(
              child: AsyncView<_StatData?>(
                key: ValueKey(_periodeId),
                load: _load,
                builder: (context, d, _) {
                  if (d == null) {
                    return ListView(padding: const EdgeInsets.all(20), children: const [
                      EmptyState(icon: Icons.insights_rounded, title: 'Belum ada periode', message: 'Statistik muncul setelah periode pertama dimulai.'),
                    ]);
                  }
                  final r = d.ringkasan;
                  final keluar = _mode == _Mode.keluar;
                  final items = keluar ? r.pengeluaranPerKelompok : r.pemasukanPerKategori;
                  final total = keluar ? r.totalPengeluaran : r.totalMasuk;
                  return DefaultTextStyle.merge(
                    style: const TextStyle(fontFeatures: AppTheme.tabular),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      children: [
                        _PeriodeButton(periode: d.periode, onTap: () => _pilihPeriode(d)),
                        const SizedBox(height: 12),
                        SegmentedTabs<_Mode>(
                          values: _Mode.values,
                          selected: _mode,
                          labelOf: (m) => m == _Mode.keluar ? 'Pengeluaran' : 'Pemasukan',
                          onChanged: (m) => setState(() => _mode = m),
                        ),
                        const SizedBox(height: 16),
                        _KategoriCard(key: ValueKey(_mode), items: items, total: total, keluar: keluar),
                        const SizedBox(height: 16),
                        _HarianCard(key: ValueKey('h-$_mode'), harian: d.harian, keluar: keluar),
                        if (keluar && r.perAkun.any((a) => a.keluar + a.biayaAdmin > 0)) ...[
                          const SizedBox(height: 16),
                          _AkunCard(akun: r.perAkun),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodeButton extends StatelessWidget {
  const _PeriodeButton({required this.periode, required this.onTap});

  final Periode periode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rentang = '${tglSedang(periode.tanggalMulai)} – ${periode.tanggalSelesai == null ? 'sekarang' : tglSedang(periode.tanggalSelesai!)}';
    return SakuCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        const Icon(Icons.event_note_rounded, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(periode.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text(rentang, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
        if (periode.aktif) const Pill('Aktif', bg: AppColors.inBg, fg: AppColors.primary),
        const SizedBox(width: 6),
        const Icon(Icons.expand_more_rounded, color: AppColors.muted),
      ]),
    );
  }
}

/// Donut + legend. Kelompok rows expand to their sub kategori.
class _KategoriCard extends StatefulWidget {
  const _KategoriCard({super.key, required this.items, required this.total, required this.keluar});

  final List<PerKategori> items;
  final int total;
  final bool keluar;

  @override
  State<_KategoriCard> createState() => _KategoriCardState();
}

class _KategoriCardState extends State<_KategoriCard> {
  String? _buka;

  @override
  Widget build(BuildContext context) {
    final items = widget.items.where((i) => i.total > 0).toList();
    final jumlah = items.fold<int>(0, (n, i) => n + i.total);
    if (items.isEmpty || jumlah == 0) {
      return SakuCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(children: [
          const Icon(Icons.donut_large_rounded, size: 32, color: AppColors.dashed),
          const SizedBox(height: 10),
          Text(widget.keluar ? 'Belum ada pengeluaran di periode ini.' : 'Belum ada pemasukan di periode ini.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        ]),
      );
    }
    // At most 6 coloured slices; the rest are merged into one grey slice.
    final utama = items.take(items.length > 7 ? 6 : 7).toList();
    final sisa = items.skip(utama.length).fold<int>(0, (n, i) => n + i.total);
    Color warna(int i) => AppColors.chart[i % AppColors.chart.length];
    final slices = [
      for (final (i, it) in utama.indexed) (nilai: it.total, warna: warna(i)),
      if (sisa > 0) (nilai: sisa, warna: AppColors.chartRest),
    ];
    String persen(int v) {
      final p = v * 100 / jumlah;
      return p < 1 && v > 0 ? '<1%' : '${p.round()}%';
    }

    return SakuCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SizedBox(
              width: 176,
              height: 176,
              child: Semantics(
                label: '${widget.keluar ? 'Pengeluaran' : 'Pemasukan'} ${rupiah(widget.total)}',
                child: CustomPaint(
                  painter: _DonutPainter(slices),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(widget.keluar ? 'Pengeluaran' : 'Pemasukan', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        const SizedBox(height: 2),
                        FittedBox(child: Text(rupiah(widget.total), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final (i, it) in items.indexed) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.divider),
            _LegendRow(
              warna: i < utama.length ? warna(i) : AppColors.chartRest,
              nama: it.nama,
              nominal: it.total,
              persen: persen(it.total),
              jumlah: it.jumlah,
              bisaBuka: it.sub.length > 1,
              buka: _buka == it.id,
              onTap: it.sub.length > 1 ? () => setState(() => _buka = _buka == it.id ? null : it.id) : null,
            ),
            if (_buka == it.id)
              Padding(
                padding: const EdgeInsets.only(left: 22, bottom: 10),
                child: Column(children: [
                  for (final s in it.sub)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Expanded(child: Text(s.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft))),
                        const SizedBox(width: 8),
                        Text(persen(s.total), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        const SizedBox(width: 10),
                        Text(thousands(s.total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                ]),
              ),
          ],
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.warna,
    required this.nama,
    required this.nominal,
    required this.persen,
    required this.jumlah,
    required this.bisaBuka,
    required this.buka,
    this.onTap,
  });

  final Color warna;
  final String nama;
  final int nominal;
  final String persen;
  final int jumlah;
  final bool bisaBuka;
  final bool buka;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text('$jumlah transaksi', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(rupiah(nominal), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text(persen, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
          SizedBox(
            width: 24,
            child: bisaBuka ? Icon(buka ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: AppColors.muted) : null,
          ),
        ]),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices);

  final List<({int nilai, Color warna})> slices;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide / 2 - stroke / 2);
    final total = slices.fold<int>(0, (n, s) => n + s.nilai);
    if (total <= 0) return;
    // Small gap between slices, unless there is only one.
    final gap = slices.length > 1 ? 0.025 : 0.0;
    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = s.nilai / total * 2 * math.pi;
      final paint = Paint()
        ..color = s.warna
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke;
      canvas.drawArc(rect, start + gap / 2, math.max(0.004, sweep - gap), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.slices != slices;
}

/// Bar per day. Tap a bar to read its value.
class _HarianCard extends StatefulWidget {
  const _HarianCard({super.key, required this.harian, required this.keluar});

  final List<({DateTime tanggal, int keluar, int masuk})> harian;
  final bool keluar;

  @override
  State<_HarianCard> createState() => _HarianCardState();
}

class _HarianCardState extends State<_HarianCard> {
  int? _pilih;

  int _nilai(int i) => widget.keluar ? widget.harian[i].keluar : widget.harian[i].masuk;

  String _tgl(DateTime d) => tglPendek(ymd(d));

  @override
  Widget build(BuildContext context) {
    final n = widget.harian.length;
    final nilai = [for (var i = 0; i < n; i++) _nilai(i)];
    final total = nilai.fold<int>(0, (a, b) => a + b);
    final maks = nilai.fold<int>(0, math.max);
    final iMaks = maks > 0 ? nilai.indexOf(maks) : null;
    final rata = n == 0 ? 0 : (total / n).round();
    final sel = _pilih ?? iMaks;
    final warna = widget.keluar ? AppColors.out : AppColors.primary;

    return SakuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.keluar ? 'Pengeluaran per hari' : 'Pemasukan per hari', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Rata-rata ${rupiah(rata)} / hari · $n hari', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(
                child: Text(
                  sel == null ? 'Belum ada transaksi' : '${tglPanjang(widget.harian[sel].tanggal)}${_pilih == null ? ' · tertinggi' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
              const SizedBox(width: 8),
              Text(sel == null ? '–' : rupiah(nilai[sel]), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: warna)),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 132,
            child: LayoutBuilder(builder: (context, c) {
              void tap(Offset p) {
                if (n == 0) return;
                final i = (p.dx / c.maxWidth * n).floor().clamp(0, n - 1);
                setState(() => _pilih = _pilih == i ? null : i);
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (e) => tap(e.localPosition),
                onHorizontalDragUpdate: (e) {
                  if (n == 0) return;
                  setState(() => _pilih = (e.localPosition.dx / c.maxWidth * n).floor().clamp(0, n - 1));
                },
                child: CustomPaint(
                  size: Size(c.maxWidth, c.maxHeight),
                  painter: _BarPainter(nilai: nilai, maks: maks, rata: rata, pilih: sel, warna: warna),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          if (n > 0)
            Row(children: [
              Text(_tgl(widget.harian.first.tanggal), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              const Spacer(),
              if (n > 2) Text(_tgl(widget.harian[n ~/ 2].tanggal), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              const Spacer(),
              if (n > 1) Text(_tgl(widget.harian.last.tanggal), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ]),
        ],
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.nilai, required this.maks, required this.rata, required this.pilih, required this.warna});

  final List<int> nilai;
  final int maks;
  final int rata;
  final int? pilih;
  final Color warna;

  @override
  void paint(Canvas canvas, Size size) {
    final n = nilai.length;
    final base = Paint()..color = AppColors.track;
    canvas.drawRect(Rect.fromLTWH(0, size.height - 1, size.width, 1), base);
    if (n == 0 || maks <= 0) return;
    final slot = size.width / n;
    final w = math.max(2.0, math.min(18.0, slot * 0.64));
    for (var i = 0; i < n; i++) {
      if (nilai[i] <= 0) continue;
      final h = math.max(3.0, nilai[i] / maks * (size.height - 4));
      final x = slot * i + (slot - w) / 2;
      final paint = Paint()..color = pilih == null || pilih == i ? warna : warna.withValues(alpha: 0.35);
      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(x, size.height - h, w, h), topLeft: Radius.circular(w / 3), topRight: Radius.circular(w / 3)),
        paint,
      );
    }
    // Dashed average line.
    if (rata > 0) {
      final y = size.height - rata / maks * (size.height - 4);
      final dash = Paint()
        ..color = AppColors.inkSoft.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.nilai != nilai || old.pilih != pilih || old.warna != warna || old.maks != maks;
}

class _AkunCard extends StatelessWidget {
  const _AkunCard({required this.akun});

  final List<RingkasanAkun> akun;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final a in akun)
        if (a.keluar + a.biayaAdmin > 0) (nama: a.nama, nilai: a.keluar + a.biayaAdmin),
    ]..sort((a, b) => b.nilai.compareTo(a.nilai));
    final maks = rows.first.nilai;
    return SakuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Keluar dari akun', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text(r.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              Text(rupiah(r.nilai), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            ProgressBar(value: r.nilai / maks, color: AppColors.out),
          ],
        ],
      ),
    );
  }
}
