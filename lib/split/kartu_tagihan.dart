import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/models.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import 'qris.dart';
import 'split_hitung.dart';

/// Logical width of the shareable card; rendered at 3× (≈1080 px).
const lebarKartu = 360.0;

/// Rincian tagihan satu peserta: porsi item + selisih pajak/servis/diskon.
({SplitPeserta peserta, List<({String nama, int porsi})> items, int selisih}) rincianPeserta(SplitBill split, String pesertaId) {
  final p = split.peserta.firstWhere((x) => x.id == pesertaId);
  final items = [
    for (final it in split.items)
      if (it.peserta.contains(pesertaId))
        (
          nama: '${it.qty > 1 ? '${it.qty}× ' : ''}${it.nama}${it.peserta.length > 1 ? ' (${labelPecahan(it.peserta.length)})' : ''}',
          porsi: (it.harga / it.peserta.length + 0.5).floor(),
        ),
  ];
  final selisih = p.nominal - items.fold<int>(0, (a, it) => a + it.porsi);
  return (peserta: p, items: items, selisih: selisih);
}

/// QR with a white quiet zone, square.
class QrisBox extends StatelessWidget {
  const QrisBox({super.key, required this.data, this.size = 240});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        size: size,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        semanticsLabel: 'Kode QRIS',
      ),
    );
  }
}

class _KartuFrame extends StatelessWidget {
  const _KartuFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: lebarKartu,
      decoration: const BoxDecoration(color: AppColors.surface),
      child: DefaultTextStyle(
        style: const TextStyle(color: AppColors.ink, fontSize: 13, height: 1.35, fontFeatures: AppTheme.tabular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 6, color: AppColors.primary),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _garis() => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, thickness: 1, color: AppColors.border));

List<Widget> _bagianQr(QrisTersimpan? qris, int nominal) => qris == null
    ? [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(color: AppColors.inBg, borderRadius: BorderRadius.circular(12)),
          child: const Text('Transfer sesuai total di atas', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 14),
        const Text('Terima kasih!', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.muted)),
      ]
    : [
        Center(child: QrisBox(data: qrisDinamis(qris.payload, nominal))),
        const SizedBox(height: 10),
        Text('QRIS · ${qris.merchant}', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        const Text('Nominal sudah terisi otomatis.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 14),
        const Text(
          'Simpan gambar ini, lalu bayar lewat Scan QR → Galeri di aplikasi e-wallet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ];

/// Tagihan satu peserta split bill.
class KartuSplit extends StatelessWidget {
  const KartuSplit({super.key, required this.split, required this.pesertaId, required this.qris});

  final SplitBill split;
  final String pesertaId;
  final QrisTersimpan? qris;

  @override
  Widget build(BuildContext context) {
    final r = rincianPeserta(split, pesertaId);
    final tgl = parseYmd(split.tanggal);
    return _KartuFrame(children: [
      Text(split.nama, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(tgl == null ? split.tanggal : tglPanjang(tgl), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      const SizedBox(height: 16),
      Text('Tagihan untuk ${r.peserta.nama}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
      _garis(),
      for (final it in r.items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(it.nama, maxLines: 2, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 12),
            Text(rupiah(it.porsi)),
          ]),
        ),
      if (r.selisih != 0)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            const Expanded(child: Text('Pajak, servis & diskon', style: TextStyle(color: AppColors.muted))),
            Text(rupiah(r.selisih), style: const TextStyle(color: AppColors.muted)),
          ]),
        ),
      _garis(),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        const Expanded(child: Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        Text(rupiah(r.peserta.nominal), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
      ]),
      const SizedBox(height: 18),
      ..._bagianQr(qris, r.peserta.nominal),
    ]);
  }
}

/// "Bayar dengan QRIS" untuk Terima QRIS.
class KartuQris extends StatelessWidget {
  const KartuQris({super.key, required this.nominal, required this.keterangan, required this.qris});

  final int nominal;
  final String keterangan;
  final QrisTersimpan qris;

  @override
  Widget build(BuildContext context) {
    return _KartuFrame(children: [
      const Text('Bayar dengan QRIS', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
      const SizedBox(height: 6),
      Text(rupiah(nominal), textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
      if (keterangan.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(keterangan, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      ],
      const SizedBox(height: 16),
      ..._bagianQr(qris, nominal),
    ]);
  }
}

/// Bottom sheet with a preview of [kartu] and a "Bagikan" button that renders
/// it to PNG (3×) and opens the share sheet.
Future<void> bagikanKartu(BuildContext context, {required Widget kartu, required String namaFile, required String teks}) {
  return showSakuSheet<void>(context, builder: (_) => _KartuSheet(kartu: kartu, namaFile: namaFile, teks: teks));
}

class _KartuSheet extends StatefulWidget {
  const _KartuSheet({required this.kartu, required this.namaFile, required this.teks});

  final Widget kartu;
  final String namaFile;
  final String teks;

  @override
  State<_KartuSheet> createState() => _KartuSheetState();
}

class _KartuSheetState extends State<_KartuSheet> {
  final _key = GlobalKey();
  bool _busy = false;

  Future<void> _bagikan() async {
    setState(() => _busy = true);
    try {
      final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null || !mounted) return;
      await context.services.media.bagikanGambar(bytes.buffer.asUint8List(), namaFile: widget.namaFile, teks: widget.teks);
    } catch (e) {
      if (mounted) showToast(context, 'Gagal membuat gambar. Coba lagi.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: DecoratedBox(
                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(4)),
                    child: RepaintBoundary(key: _key, child: widget.kartu),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: BusyButton(label: 'Bagikan', busy: _busy, onPressed: _bagikan),
          ),
        ],
      ),
    );
  }
}
