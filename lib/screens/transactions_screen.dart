import 'dart:async';

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import '../widgets/saku_rows.dart';

const _ukuran = 50;

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  TipeTransaksi? _tipe;
  String _q = '';
  Periode? _periode; // null = aktif
  Akun? _akun;

  final List<Transaksi> _items = [];
  int _total = 0;
  int _halaman = 1;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _version = -1;
  int _req = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final v = AppScope.of(context).dataVersion;
    if (v != _version) {
      _version = v;
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final my = ++_req;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final page = await context.api.transaksi(
        periodeId: _periode?.id,
        akunId: _akun?.id,
        tipe: _tipe?.name,
        q: _q,
        halaman: more ? _halaman + 1 : 1,
        ukuran: _ukuran,
      );
      if (!mounted || my != _req) return;
      setState(() {
        if (!more) _items.clear();
        _items.addAll(page.data);
        _total = page.total;
        _halaman = page.halaman;
      });
    } catch (e) {
      if (mounted && my == _req) {
        if (more) {
          showToast(context, errorMessage(e), error: true);
        } else {
          setState(() => _error = e);
        }
      }
    } finally {
      if (mounted && my == _req) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  /// Swipe-to-delete: confirm, call the API, and only let the row go on success.
  Future<bool> _konfirmasiHapus(Transaksi t) async {
    if (t.isTarikTabungan) {
      showToast(context, 'Transaksi Tarik Tabungan dihapus lewat menu Tabungan.', error: true);
      return false;
    }
    final ok = await showSakuSheet<bool>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Hapus transaksi ini?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text(
            '${t.judul} · ${rupiah(t.nominal)} (${tglSedang(t.tanggal)}). Saldo akun dihitung ulang dan transaksi tidak bisa dikembalikan.',
            style: const TextStyle(fontSize: 14, color: AppColors.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: OutlineBtn('Batal', height: 50, radius: 14, fontSize: 15, onPressed: () => Navigator.pop(ctx, false))),
            const SizedBox(width: 10),
            Expanded(child: PrimaryButton('Hapus', height: 50, color: AppColors.out, onPressed: () => Navigator.pop(ctx, true))),
          ]),
        ],
      ),
    );
    if (ok != true || !mounted) return false;
    try {
      await context.api.hapusTransaksi(t.id);
      if (!mounted) return true;
      showToast(context, 'Transaksi dihapus.');
      // Refresh dashboard/budget/etc. after the row animates out.
      final session = context.session;
      Future.delayed(const Duration(milliseconds: 400), session.dataChanged);
      return true;
    } catch (e) {
      if (mounted) showToast(context, errorMessage(e), error: true);
      return false;
    }
  }

  void _setTipe(TipeTransaksi? t) {
    setState(() => _tipe = t);
    _load();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _q = v.trim();
      _load();
    });
  }

  Future<void> _pilihPeriode() async {
    try {
      final list = await context.api.periode();
      if (!mounted) return;
      final aktifId = list.where((p) => p.aktif).firstOrNull?.id;
      final picked = await pickOne<String>(
        context,
        title: 'Periode',
        selected: _periode?.id ?? aktifId,
        options: [
          for (final p in list)
            PickOption(p.id, p.nama, subtitle: '${tglSedang(p.tanggalMulai)} – ${p.tanggalSelesai == null ? 'sekarang' : tglSedang(p.tanggalSelesai!)}'),
        ],
      );
      if (picked == null || !mounted) return;
      setState(() => _periode = picked == aktifId ? null : list.firstWhere((p) => p.id == picked));
      _load();
    } catch (e) {
      if (mounted) showToast(context, errorMessage(e), error: true);
    }
  }

  Future<void> _pilihAkun() async {
    try {
      final list = await context.api.akun(termasukNonaktif: true);
      if (!mounted) return;
      const semua = '__semua__';
      final picked = await pickOne<String>(
        context,
        title: 'Filter akun',
        selected: _akun?.id ?? semua,
        options: [const PickOption(semua, 'Semua akun'), for (final a in list) PickOption(a.id, a.nama, subtitle: jenisAkunLabel(a.jenis))],
      );
      if (picked == null || !mounted) return;
      setState(() => _akun = picked == semua ? null : list.firstWhere((a) => a.id == picked));
      _load();
    } catch (e) {
      if (mounted) showToast(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = <String, List<Transaksi>>{};
    for (final t in _items) {
      days.putIfAbsent(t.tanggal, () => []).add(t);
    }

    return DefaultTextStyle.merge(
      style: const TextStyle(fontFeatures: AppTheme.tabular),
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Row(
              children: [
                const Expanded(child: Text('Riwayat', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
                const SizedBox(width: 12),
                // Shrink-wraps its label and sits flush right; long names ellipsize.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: _pilihPeriode,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.expand_more_rounded, size: 18),
                      label: Text(_periode?.nama ?? 'Periode aktif', overflow: TextOverflow.ellipsis),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.borderStrong),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              onChanged: _onSearch,
              decoration: const InputDecoration(
                hintText: 'Cari deskripsi…',
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              textInputAction: TextInputAction.search,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _Chip(label: 'Semua', on: _tipe == null, onTap: () => _setTipe(null)),
                  for (final t in TipeTransaksi.values) _Chip(label: t.label, on: _tipe == t, onTap: () => _setTipe(t)),
                  _Chip(label: _akun?.nama ?? 'Akun', on: _akun != null, trailing: Icons.expand_more_rounded, onTap: _pilihAkun),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loading && _items.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_error != null)
              ErrorState(message: errorMessage(_error!), onRetry: _load)
            else if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text('Tidak ada transaksi.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
              ),
            for (final e in days.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(labelHari(e.key).toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5)),
              ),
              SakuCard(
                padding: EdgeInsets.zero,
                child: DividedColumn(children: [
                  for (final t in e.value)
                    Dismissible(
                      key: ValueKey(t.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _konfirmasiHapus(t),
                      onDismissed: (_) => setState(() {
                        _items.removeWhere((x) => x.id == t.id);
                        _total--;
                      }),
                      background: Container(
                        color: AppColors.out,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      child: ColoredBox(color: AppColors.surface, child: TransaksiRow(tx: t, horizontalPadding: 16)),
                    ),
                ]),
              ),
              const SizedBox(height: 16),
            ],
            if (_items.length < _total)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Center(
                  child: _loadingMore
                      ? const CircularProgressIndicator(color: AppColors.primary)
                      : OutlineBtn('Muat lebih banyak', onPressed: () => _load(more: true)),
                ),
              ),
            if (_items.isNotEmpty)
              Text('Menampilkan ${_items.length} dari $_total transaksi', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap, this.trailing});

  final String label;
  final bool on;
  final VoidCallback onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final fg = on ? Colors.white : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: on ? AppColors.deep : AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: on ? AppColors.deep : AppColors.borderStrong)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
                if (trailing != null) ...[const SizedBox(width: 4), Icon(trailing, size: 16, color: fg)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
