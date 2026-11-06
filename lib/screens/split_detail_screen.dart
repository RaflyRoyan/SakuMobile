import 'package:flutter/material.dart';

import '../api/models.dart';
import '../app.dart';
import '../split/kartu_tagihan.dart';
import '../split/qris_store.dart';
import '../split/split_hitung.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';

/// Rincian satu split: item, total, peserta (lunas), bagikan tagihan.
class SplitDetailScreen extends StatefulWidget {
  const SplitDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<SplitDetailScreen> createState() => _SplitDetailScreenState();
}

class _SplitDetailScreenState extends State<SplitDetailScreen> {
  SplitBill? _split;
  Object? _error;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final s = await context.api.detailSplit(widget.id);
      if (mounted) setState(() => _split = s);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _setLunas(SplitPeserta p, bool lunas) async {
    setState(() => _busy.add(p.id));
    try {
      final s = await context.api.setLunas(widget.id, p.id, lunas, tanggal: lunas ? ymd(todayWib()) : null);
      if (!mounted) return;
      setState(() => _split = s);
      context.session.dataChanged();
    } catch (e) {
      if (mounted) showToast(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(p.id));
    }
  }

  Future<void> _bagikan(SplitBill s, SplitPeserta p) async {
    final qris = await muatQris(context.api, context.services.prefs);
    if (!mounted) return;
    if (qris == null) showToast(context, 'QRIS belum diatur di Pengaturan, kartu dibuat tanpa QR');
    await bagikanKartu(
      context,
      kartu: KartuSplit(split: s, pesertaId: p.id, qris: qris),
      namaFile: 'tagihan-${p.nama.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}.png',
      teks: 'Halo ${p.nama}, tagihan ${s.nama}: ${rupiah(p.nominal)}. Bayar lewat QRIS di gambar ya.',
    );
  }

  Future<void> _hapus(SplitBill s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Hapus split bill ini?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text('Transaksi pengeluaran ${rupiah(s.total)} dan semua pemasukan dari teman yang sudah bayar ikut terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.out), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final nav = Navigator.of(context);
    if (await runAction(context, () => context.api.hapusSplit(s.id), success: 'Split bill dihapus.')) nav.pop();
  }

  Future<void> _ubah(SplitBill s) async {
    final hasil = await Navigator.of(context).pushNamed(Routes.splitUbah, arguments: s.id);
    if (hasil is SplitBill && mounted) setState(() => _split = hasil);
  }

  @override
  Widget build(BuildContext context) {
    final s = _split;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SubPageHeader(
              title: 'Split Bill',
              trailing: s == null
                  ? null
                  : PopupMenuButton<String>(
                      tooltip: 'Menu',
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (v) => v == 'ubah' ? _ubah(s) : _hapus(s),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'ubah', child: Text('Ubah')),
                        PopupMenuItem(value: 'hapus', child: Text('Hapus', style: TextStyle(color: AppColors.out))),
                      ],
                    ),
            ),
            Expanded(
              child: _error != null
                  ? ErrorState(message: errorMessage(_error!), onRetry: _load)
                  : s == null
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(onRefresh: _load, child: _body(s)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(SplitBill s) {
    final namaPeserta = {for (final p in s.peserta) p.id: p.nama};
    final warna = {for (final (i, p) in s.peserta.indexed) p.id: _warnaAvatar(i)};
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFeatures: AppTheme.tabular),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _Hero(s: s),
          const SizedBox(height: 12),
          SakuCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: DividedColumn(children: [
              _InfoRow(icon: Icons.account_balance_wallet_outlined, label: 'Dibayar dari', value: s.akunNama),
              _InfoRow(icon: Icons.south_west_rounded, label: 'Terima di', value: s.akunTerimaNama),
              _InfoRow(icon: Icons.sell_outlined, label: 'Kategori', value: s.kategoriNama),
            ]),
          ),
          const SizedBox(height: 22),
          const OverlineLabel('Peserta'),
          SakuCard(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            child: DividedColumn(children: [
              for (final p in s.peserta)
                _PesertaRow(
                  p: p,
                  warna: warna[p.id]!,
                  busy: _busy.contains(p.id),
                  onLunas: (v) => _setLunas(p, v),
                  onBagikan: () => _bagikan(s, p),
                ),
            ]),
          ),
          const SizedBox(height: 22),
          const OverlineLabel('Rincian struk'),
          SakuCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final (i, it) in s.items.indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 28),
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(7)),
                    child: Text('${it.qty}×', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it.nama, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        for (final id in it.peserta)
                          _Avatar(nama: namaPeserta[id] ?? '?', warna: warna[id] ?? _warnaAvatar(0), size: 20),
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Text(
                            it.peserta.length > 1
                                ? '${it.peserta.map((id) => namaPeserta[id] ?? '?').join(', ')} · ${labelPecahan(it.peserta.length)} tiap orang'
                                : it.peserta.map((id) => namaPeserta[id] ?? '?').join(', '),
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Text(rupiah(it.harga), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
              ],
              const SizedBox(height: 14),
              const _Garis(),
              const SizedBox(height: 10),
              _Baris('Subtotal', s.subtotal),
              if (s.pajak > 0) _Baris('Pajak', s.pajak),
              if (s.servis > 0) _Baris('Servis', s.servis),
              if (s.diskon > 0) _Baris('Diskon', -s.diskon, color: AppColors.primary),
              const SizedBox(height: 8),
              Row(children: [
                const Expanded(child: Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                Text(rupiah(s.total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ]),
            ]),
          ),
          const SizedBox(height: 10),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.info_outline_rounded, size: 14, color: AppColors.muted)),
            SizedBox(width: 6),
            Expanded(
              child: Text('Pajak, servis & diskon dibagi sebanding dengan pesanan tiap orang.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Soft avatar colours, cycled per participant.
({Color bg, Color fg}) _warnaAvatar(int i) => const [
      (bg: AppColors.inBg, fg: AppColors.primary),
      (bg: AppColors.transferBg, fg: AppColors.transfer),
      (bg: AppColors.outBg, fg: AppColors.out),
      (bg: AppColors.warnBg, fg: AppColors.warnStrong),
      (bg: Color(0xFFECE6F5), fg: Color(0xFF6B4FA0)),
      (bg: Color(0xFFDDF2EF), fg: Color(0xFF1F7A70)),
    ][i % 6];

/// Dark summary: total struk + how much has come back from friends.
class _Hero extends StatelessWidget {
  const _Hero({required this.s});

  final SplitBill s;

  @override
  Widget build(BuildContext context) {
    final teman = s.peserta.where((p) => !p.saya);
    final tagihan = teman.fold<int>(0, (a, p) => a + p.nominal);
    final masuk = teman.where((p) => p.lunas).fold<int>(0, (a, p) => a + p.nominal);
    final saya = s.peserta.where((p) => p.saya).fold<int>(0, (a, p) => a + p.nominal);
    final tgl = parseYmd(s.tanggal);
    final selesai = tagihan > 0 && masuk >= tagihan;

    Widget stat(String label, String value, {Color color = Colors.white}) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.mintText)),
              const SizedBox(height: 4),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ]),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.deep, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
          child: Text(tgl == null ? s.tanggal : tglPanjang(tgl), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
        const SizedBox(height: 12),
        Text(s.nama, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(rupiah(s.total), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: Colors.white)),
        ),
        if (tagihan > 0) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Text(selesai ? 'Semua teman sudah bayar' : 'Terkumpul ${thousands(masuk)} dari ${thousands(tagihan)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.mintText)),
            ),
            if (selesai) const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.mintBright),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: masuk / tagihan,
              minHeight: 8,
              color: AppColors.mintBright,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(children: [
          stat('Porsimu', thousands(saya)),
          const SizedBox(width: 8),
          stat('Belum masuk', thousands(s.belumLunas.nominal), color: s.belumLunas.nominal > 0 ? AppColors.peachBright : AppColors.mintBright),
          const SizedBox(width: 8),
          stat('Peserta', '${s.peserta.length} orang'),
        ]),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(value, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

/// Dashed receipt-style separator.
class _Garis extends StatelessWidget {
  const _Garis();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final n = (c.maxWidth / 8).floor();
      return Row(children: [
        for (var i = 0; i < n; i++)
          Expanded(child: Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 2), color: AppColors.borderStrong)),
      ]);
    });
  }
}

class _Baris extends StatelessWidget {
  const _Baris(this.label, this.nominal, {this.color = AppColors.muted});

  final String label;
  final int nominal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
        Text(rupiah(nominal), style: TextStyle(fontSize: 13, color: color)),
      ]),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.nama, required this.warna, this.size = 40});

  final String nama;
  final ({Color bg, Color fg}) warna;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = nama.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: warna.bg, shape: BoxShape.circle),
      child: Text(
        t.isEmpty ? '?' : t.characters.first.toUpperCase(),
        style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w800, color: warna.fg, height: 1),
      ),
    );
  }
}

class _PesertaRow extends StatelessWidget {
  const _PesertaRow({required this.p, required this.warna, required this.busy, required this.onLunas, required this.onBagikan});

  final SplitPeserta p;
  final ({Color bg, Color fg}) warna;
  final bool busy;
  final ValueChanged<bool> onLunas;
  final VoidCallback onBagikan;

  @override
  Widget build(BuildContext context) {
    final status = p.saya ? 'bagianmu' : (p.lunas ? 'Lunas' : 'Belum bayar');
    final statusColor = p.saya ? AppColors.muted : (p.lunas ? AppColors.primary : AppColors.warnStrong);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 68),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          _Avatar(nama: p.nama, warna: warna),
          if (!p.saya && p.lunas)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                padding: const EdgeInsets.all(1),
                child: const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary),
              ),
            ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(p.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          Text(
            rupiah(p.nominal),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: !p.saya && p.lunas ? AppColors.muted : AppColors.ink,
              decoration: !p.saya && p.lunas ? TextDecoration.lineThrough : null,
              decorationColor: AppColors.muted,
            ),
          ),
          if (!p.saya && !p.lunas) ...[
            const SizedBox(height: 4),
            Semantics(
              label: 'Bagikan tagihan ${p.nama}',
              button: true,
              excludeSemantics: true,
              child: TextButton.icon(
                onPressed: onBagikan,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.inBg,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                icon: const Icon(Icons.ios_share_rounded, size: 14),
                label: const Text('Bagikan'),
              ),
            ),
          ],
        ]),
        SizedBox(
          width: 48,
          child: p.saya
              ? null
              : busy
                  ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2)))
                  : Checkbox(
                      value: p.lunas,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                      side: const BorderSide(color: AppColors.borderStrong, width: 1.6),
                      onChanged: (v) => onLunas(v ?? false),
                      semanticLabel: 'Lunas ${p.nama}',
                    ),
        ),
      ]),
    );
  }
}
