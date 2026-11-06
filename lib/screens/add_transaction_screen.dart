import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import '../widgets/kategori_picker.dart';

class _FormData {
  _FormData({required this.akun, required this.kategori, required this.kelompok, this.aktif, this.tx});

  final List<Akun> akun;
  final List<Kategori> kategori;
  final List<KelompokKategori> kelompok;
  final Periode? aktif;
  final Transaksi? tx;
}

/// Create a transaction, or edit/delete one when [editId] is given.
class AddTransactionScreen extends StatelessWidget {
  const AddTransactionScreen({super.key, this.editId});

  final String? editId;

  Future<_FormData> _load(BuildContext context) async {
    final api = context.api;
    final results = await Future.wait([
      api.akun(),
      // Inactive/system categories are filtered in the form (kept only when the edited transaction uses them).
      api.kategori(termasukNonaktif: true),
      api.kelompokKategori(),
      api.periodeAktif(),
      if (editId != null) api.detailTransaksi(editId!),
    ]);
    return _FormData(
      akun: results[0] as List<Akun>,
      kategori: results[1] as List<Kategori>,
      kelompok: results[2] as List<KelompokKategori>,
      aktif: results[3] as Periode?,
      tx: editId != null ? results[4] as Transaksi : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = editId == null ? 'Transaksi baru' : 'Edit transaksi';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SubPageHeader(
              title: title,
              leadingIcon: editId == null ? Icons.close_rounded : Icons.chevron_left_rounded,
              leadingLabel: editId == null ? 'Tutup' : 'Kembali',
            ),
            Expanded(
              child: _OnceLoader<_FormData>(
                load: () => _load(context),
                builder: (data) => _TransaksiForm(data: data),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loads once (forms must not reset while the user types).
class _OnceLoader<T> extends StatefulWidget {
  const _OnceLoader({required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(T data) builder;

  @override
  State<_OnceLoader<T>> createState() => _OnceLoaderState<T>();
}

class _OnceLoaderState<T> extends State<_OnceLoader<T>> {
  late Future<T> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, s) {
        if (s.hasError) return ErrorState(message: errorMessage(s.error!), onRetry: () => setState(() => _future = widget.load()));
        if (!s.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        return widget.builder(s.data as T);
      },
    );
  }
}

class _TransaksiForm extends StatefulWidget {
  const _TransaksiForm({required this.data});

  final _FormData data;

  @override
  State<_TransaksiForm> createState() => _TransaksiFormState();
}

class _TransaksiFormState extends State<_TransaksiForm> {
  final _nominal = TextEditingController();
  final _admin = TextEditingController();
  final _desk = TextEditingController();

  late TipeTransaksi _tipe;
  late DateTime _tanggal;
  String? _akunId;
  String? _tujuanId;
  String? _kategoriId;
  bool _busy = false;
  Map<String, List<String>> _errors = {};
  String? _formError;

  Transaksi? get _tx => widget.data.tx;
  bool get _locked => _tx?.isTarikTabungan ?? false;
  bool get _tertutup => _tx != null && _tx!.periodeId != widget.data.aktif?.id;

  @override
  void initState() {
    super.initState();
    final tx = _tx;
    if (tx != null) {
      _tipe = tx.tipe;
      _tanggal = parseYmd(tx.tanggal) ?? todayWib();
      _akunId = tx.akunId;
      _tujuanId = tx.akunTujuanId;
      _kategoriId = tx.kategoriId;
      _nominal.text = thousands(tx.nominal);
      if (tx.biayaAdmin > 0) _admin.text = thousands(tx.biayaAdmin);
      _desk.text = tx.deskripsi;
    } else {
      _tipe = TipeTransaksi.keluar;
      _tanggal = todayWib();
      _akunId = widget.data.akun.firstOrNull?.id;
    }
  }

  @override
  void dispose() {
    _nominal.dispose();
    _admin.dispose();
    _desk.dispose();
    super.dispose();
  }

  /// Account options; keeps the transaction's current account even if no longer selectable.
  List<({String id, String nama, int? saldo})> get _akunOptions {
    final list = [for (final a in widget.data.akun) (id: a.id, nama: a.nama, saldo: a.saldo)];
    final tx = _tx;
    if (tx != null) {
      if (!list.any((a) => a.id == tx.akunId)) list.add((id: tx.akunId, nama: tx.akunNama, saldo: null));
      if (tx.akunTujuanId != null && !list.any((a) => a.id == tx.akunTujuanId)) list.add((id: tx.akunTujuanId!, nama: tx.akunTujuanNama ?? '?', saldo: null));
    }
    return list;
  }

  /// Same rule as the web form: active, non-system categories of this type,
  /// plus the edited transaction's own category even if inactive/system.
  List<Kategori> get _kategoriOptions {
    final editKat = _tx?.kategoriId;
    return widget.data.kategori
        .where((k) => k.tipe == _tipe.name && (k.aktif || k.id == editKat) && (k.kodeSistem == null || k.id == editKat))
        .toList();
  }

  String? _namaAkun(String? id) => _akunOptions.where((a) => a.id == id).firstOrNull?.nama;

  Future<void> _pickAkun({required bool tujuan}) async {
    final picked = await pickOne<String>(
      context,
      title: tujuan ? 'Ke akun' : (_tipe == TipeTransaksi.masuk ? 'Ke akun' : 'Dari akun'),
      selected: tujuan ? _tujuanId : _akunId,
      options: [
        for (final a in _akunOptions)
          if (!tujuan || a.id != _akunId) PickOption(a.id, a.nama, subtitle: a.saldo == null ? null : 'Saldo ${rupiah(a.saldo!)}'),
      ],
    );
    if (picked == null) return;
    setState(() {
      if (tujuan) {
        _tujuanId = picked;
      } else {
        _akunId = picked;
        if (_tujuanId == picked) _tujuanId = null;
      }
    });
  }

  Future<void> _pickTanggal() async {
    final d = await pickDate(context, _tanggal);
    if (d != null) setState(() => _tanggal = d);
  }

  Future<void> _save() async {
    final nominal = parseNominal(_nominal.text);
    final local = <String, List<String>>{};
    if (nominal == null || nominal <= 0) local['nominal'] = ['Nominal harus lebih dari 0.'];
    if (_akunId == null) local['akunId'] = ['Pilih akun.'];
    if (_tipe == TipeTransaksi.transfer && _tujuanId == null) local['akunTujuanId'] = ['Pilih akun tujuan.'];
    if (_tipe != TipeTransaksi.transfer && _kategoriId == null) local['kategoriId'] = ['Pilih kategori.'];
    if (local.isNotEmpty) {
      setState(() => _errors = local);
      return;
    }

    final input = TransaksiInput(
      tipe: _tipe,
      tanggal: ymd(_tanggal),
      akunId: _akunId!,
      akunTujuanId: _tujuanId,
      kategoriId: _kategoriId,
      nominal: nominal!,
      biayaAdmin: parseNominal(_admin.text) ?? 0,
      deskripsi: _desk.text.trim(),
    );
    setState(() {
      _busy = true;
      _errors = {};
      _formError = null;
    });
    try {
      final api = context.api;
      final saved = _tx == null ? await api.buatTransaksi(input) : await api.ubahTransaksi(_tx!.id, input);
      if (!mounted) return;
      context.session.dataChanged();
      await showPeringatan(context, saved.peringatan);
      if (!mounted) return;
      showToast(context, _tx == null ? 'Transaksi tersimpan.' : 'Perubahan tersimpan.');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() {
        _errors = e.errors;
        _formError = e.errors.isEmpty ? e.title : null;
      });
    } catch (e) {
      setState(() => _formError = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final tx = _tx!;
    final ok = await showSakuSheet<bool>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Hapus transaksi ini?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text(
            '${tx.judul} · ${rupiah(tx.nominal)} dari ${tx.akunNama}. Saldo akun dihitung ulang dan transaksi tidak bisa dikembalikan.',
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
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final done = await runAction(context, () => context.api.hapusTransaksi(tx.id), success: 'Transaksi dihapus.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) Navigator.of(context).pop();
  }

  String? _err(String f) => _errors[f]?.firstOrNull;

  @override
  Widget build(BuildContext context) {
    final tx = _tx;
    final akunSaldo = widget.data.akun.where((a) => a.id == _akunId).firstOrNull?.saldo;

    final fields = SakuCard(
      padding: EdgeInsets.zero,
      child: DividedColumn(children: [
        SelectRow(
          label: 'Tanggal',
          value: tglPanjang(_tanggal),
          trailing: const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.muted),
          onTap: _locked ? null : _pickTanggal,
          error: _err('tanggal'),
        ),
        SelectRow(
          label: _tipe == TipeTransaksi.masuk ? 'Ke akun' : 'Dari akun',
          value: _namaAkun(_akunId),
          hint: 'Pilih akun',
          onTap: _locked ? null : () => _pickAkun(tujuan: false),
          error: _err('akunId'),
        ),
        if (_tipe == TipeTransaksi.transfer) ...[
          SelectRow(label: 'Ke akun', value: _namaAkun(_tujuanId), hint: 'Pilih akun', onTap: () => _pickAkun(tujuan: true), error: _err('akunTujuanId')),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(children: [
              const SizedBox(width: 96, child: Text('Biaya admin', style: TextStyle(fontSize: 13, color: AppColors.muted))),
              const SizedBox(width: 12),
              Expanded(child: NominalField(controller: _admin, dense: true, errorText: _err('biayaAdmin'))),
            ]),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: KategoriBertingkat(
              key: ValueKey(_tipe),
              kategori: _kategoriOptions,
              kelompok: widget.data.kelompok,
              value: _kategoriId,
              bertingkat: _tipe == TipeTransaksi.keluar,
              enabled: !_locked,
              error: _err('kategoriId'),
              onChanged: (id) => setState(() => _kategoriId = id),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(children: [
            const SizedBox(width: 96, child: Text('Deskripsi', style: TextStyle(fontSize: 13, color: AppColors.muted))),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _desk,
                enabled: !_locked,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Opsional',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  counterText: '',
                  errorText: _err('deskripsi'),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              if (_locked) ...[
                InfoNote(
                  icon: Icons.lock_outline_rounded,
                  bg: AppColors.background,
                  fg: AppColors.ink,
                  borderColor: AppColors.borderStrong,
                  child: const Text.rich(TextSpan(children: [
                    TextSpan(text: 'Transaksi ini dibuat otomatis dari '),
                    TextSpan(text: 'Tarik Tabungan', style: TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: '. Ubah atau hapus lewat menu Tabungan.'),
                  ])),
                ),
                const SizedBox(height: 18),
              ],
              Opacity(
                opacity: _locked ? 0.6 : 1,
                child: _TipePicker(
                  selected: _tipe,
                  onChanged: _locked
                      ? null
                      : (t) => setState(() {
                            _tipe = t;
                            _kategoriId = null;
                            _errors = {};
                          }),
                ),
              ),
              const SizedBox(height: 14),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                decoration: BoxDecoration(color: _tipeBg(_tipe), borderRadius: BorderRadius.circular(20)),
                child: Column(children: [
                  Text(
                    switch (_tipe) {
                      TipeTransaksi.keluar => 'Uang keluar',
                      TipeTransaksi.masuk => 'Uang masuk',
                      TipeTransaksi.transfer => 'Dipindahkan',
                    },
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: txColor(_tipe)),
                  ),
                  const SizedBox(height: 2),
                  _AmountInput(controller: _nominal, color: txColor(_tipe), enabled: !_locked, autofocus: tx == null),
                  if (_err('nominal') != null)
                    Text(_err('nominal')!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.out)),
                  if (!_locked && akunSaldo != null && _tipe != TipeTransaksi.masuk) ...[
                    const SizedBox(height: 6),
                    Text('Saldo ${_namaAkun(_akunId) ?? ''}: ${rupiah(akunSaldo)}',
                        textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ]),
              ),
              const SizedBox(height: 22),
              const OverlineLabel('Rincian'),
              Opacity(opacity: _locked ? 0.6 : 1, child: fields),
              if (_tertutup && !_locked) ...[
                const SizedBox(height: 18),
                const InfoNote(
                  icon: Icons.info_outline_rounded,
                  bg: AppColors.transferBg,
                  fg: AppColors.infoText,
                  child: Text('Periode transaksi ini sudah ditutup. Setelah disimpan, setor tabungan periode itu dihitung ulang.'),
                ),
              ] else if (tx != null && !_locked) ...[
                const SizedBox(height: 18),
                const InfoNote(
                  icon: Icons.swap_horiz_rounded,
                  bg: AppColors.warnBg,
                  fg: AppColors.warnText,
                  child: Text('Kalau tanggal diganti ke periode lain, transaksi otomatis pindah periode.'),
                ),
              ],
              if (_formError != null) ...[
                const SizedBox(height: 18),
                InfoNote(icon: Icons.error_outline_rounded, bg: AppColors.outBg, fg: AppColors.outText, child: Text(_formError!)),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
          child: _locked
              ? OutlineBtn('Kembali', height: 54, radius: 16, fontSize: 16, color: AppColors.primary, borderColor: AppColors.primary, onPressed: () => Navigator.pop(context))
              : Row(
                  children: [
                    if (tx != null) ...[
                      SizedBox(
                        width: 54,
                        height: 54,
                        child: OutlinedButton(
                          onPressed: _busy ? null : _confirmDelete,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            side: const BorderSide(color: AppColors.out),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: AppColors.out, semanticLabel: 'Hapus transaksi'),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(child: BusyButton(label: tx == null ? 'Simpan transaksi' : 'Simpan perubahan', busy: _busy, onPressed: _save)),
                  ],
                ),
        ),
      ],
    );
  }
}

Color _tipeBg(TipeTransaksi t) => switch (t) {
      TipeTransaksi.keluar => AppColors.outBg,
      TipeTransaksi.masuk => AppColors.inBg,
      TipeTransaksi.transfer => AppColors.transferBg,
    };

/// Keluar / Masuk / Transfer, the selected one tinted with its own colour.
class _TipePicker extends StatelessWidget {
  const _TipePicker({required this.selected, this.onChanged});

  final TipeTransaksi selected;
  final ValueChanged<TipeTransaksi>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (final t in TipeTransaksi.values)
          Expanded(
            child: Semantics(
              button: true,
              selected: t == selected,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onChanged == null ? null : () => onChanged!(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 44,
                  decoration: BoxDecoration(
                    color: t == selected ? AppColors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: t == selected ? const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 1))] : null,
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(
                      switch (t) {
                        TipeTransaksi.keluar => Icons.north_east_rounded,
                        TipeTransaksi.masuk => Icons.south_west_rounded,
                        TipeTransaksi.transfer => Icons.swap_horiz_rounded,
                      },
                      size: 16,
                      color: t == selected ? txColor(t) : AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        t.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: t == selected ? FontWeight.w700 : FontWeight.w600,
                          color: t == selected ? txColor(t) : AppColors.muted,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _AmountInput extends StatelessWidget {
  const _AmountInput({required this.controller, required this.color, required this.enabled, required this.autofocus});

  final TextEditingController controller;
  final Color color;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('Rp', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.muted)),
        const SizedBox(width: 8),
        IntrinsicWidth(
          child: TextField(
            controller: controller,
            enabled: enabled,
            autofocus: autofocus,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: color),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: color.withValues(alpha: 0.35)),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ),
      ],
    );
  }
}

