import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';

class _CloseData {
  _CloseData(this.pratinjau, this.akun);

  /// Null when there is no active period yet (first period).
  final PratinjauTutup? pratinjau;
  final List<Akun> akun;
}

/// "Mulai periode baru (tutup buku)", also used for the very first period.
class ClosePeriodScreen extends StatefulWidget {
  const ClosePeriodScreen({super.key});

  @override
  State<ClosePeriodScreen> createState() => _ClosePeriodScreenState();
}

class _ClosePeriodScreenState extends State<ClosePeriodScreen> {
  late Future<_CloseData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CloseData> _load() async {
    final api = context.api;
    final r = await Future.wait([api.pratinjauTutup(), api.akun()]);
    return _CloseData(r[0] as PratinjauTutup?, r[1] as List<Akun>);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SubPageHeader(title: 'Mulai periode baru'),
            Expanded(
              child: FutureBuilder<_CloseData>(
                future: _future,
                builder: (context, s) {
                  if (s.hasError) return ErrorState(message: errorMessage(s.error!), onRetry: () => setState(() => _future = _load()));
                  if (!s.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  return _CloseForm(data: s.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseForm extends StatefulWidget {
  const _CloseForm({required this.data});

  final _CloseData data;

  @override
  State<_CloseForm> createState() => _CloseFormState();
}

class _CloseFormState extends State<_CloseForm> {
  final _nama = TextEditingController();
  late DateTime _mulai;
  bool _salin = true;
  bool _busy = false;
  String? _error;

  /// akunId -> controller
  final _teruskan = <String, TextEditingController>{};
  final _saldo = <String, TextEditingController>{};

  /// Opening balances the user typed by hand (not auto-filled from "teruskan").
  final _saldoManual = <String>{};

  PratinjauTutup? get _p => widget.data.pratinjau;

  /// Accounts for the new period's opening balance: selected accounts plus any with leftovers.
  List<({String id, String nama})> get _akunBaru {
    final list = [for (final a in widget.data.akun) (id: a.id, nama: a.nama)];
    for (final s in _p?.sisa ?? <({String akunId, String nama, int nominal})>[]) {
      if (!list.any((a) => a.id == s.akunId)) list.add((id: s.akunId, nama: s.nama));
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    final today = todayWib();
    final minMulai = parseYmd(_p?.periode.tanggalMulai)?.add(const Duration(days: 1));
    _mulai = minMulai != null && today.isBefore(minMulai) ? minMulai : today;
    for (final s in _p?.sisa ?? <({String akunId, String nama, int nominal})>[]) {
      _teruskan[s.akunId] = TextEditingController();
    }
    for (final a in _akunBaru) {
      _saldo[a.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nama.dispose();
    for (final c in [..._teruskan.values, ..._saldo.values]) {
      c.dispose();
    }
    super.dispose();
  }

  int _n(TextEditingController? c) => c == null ? 0 : parseNominal(c.text) ?? 0;

  void _onTeruskan(String akunId) {
    if (!_saldoManual.contains(akunId)) {
      final v = _n(_teruskan[akunId]);
      _saldo[akunId]?.text = v == 0 ? '' : thousands(v);
    }
    setState(() {});
  }

  Future<void> _submit() async {
    final p = _p;
    final saldoAwal = [for (final a in _akunBaru) if (_n(_saldo[a.id]) > 0) (akunId: a.id, saldo: _n(_saldo[a.id]))];
    final teruskan = [for (final e in _teruskan.entries) if (_n(e.value) > 0) (akunId: e.key, nominal: _n(e.value))];

    final ok = await showSakuSheet<bool>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(p == null ? 'Mulai periode pertama?' : 'Tutup ${p.periode.nama}?', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(
            p == null
                ? 'Periode baru dimulai ${tglPanjang(_mulai)} dengan saldo awal ${rupiah(saldoAwal.fold(0, (s, x) => s + x.saldo))}.'
                : 'Periode lama selesai ${tglPanjang(_mulai.subtract(const Duration(days: 1)))}. Sisa yang tidak diteruskan masuk tabungan.',
            style: const TextStyle(fontSize: 14, color: AppColors.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: OutlineBtn('Batal', height: 50, radius: 14, fontSize: 15, onPressed: () => Navigator.pop(ctx, false))),
            const SizedBox(width: 10),
            Expanded(child: PrimaryButton(p == null ? 'Mulai' : 'Tutup buku', height: 50, onPressed: () => Navigator.pop(ctx, true))),
          ]),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final hasil = await context.api.mulaiPeriode(
        nama: _nama.text.trim(),
        tanggalMulai: ymd(_mulai),
        saldoAwal: saldoAwal,
        teruskan: teruskan,
        salinAnggaran: p != null && _salin,
      );
      if (!mounted) return;
      context.session.dataChanged();
      final extra = [
        if (hasil.anggaranDisalin > 0) '${hasil.anggaranDisalin} anggaran disalin',
        if (hasil.transaksiTetapDiPeriodeLama > 0) '${hasil.transaksiTetapDiPeriodeLama} transaksi tetap di periode lama',
      ];
      showToast(context, '${hasil.periode.nama} dimulai.${extra.isEmpty ? '' : ' ${extra.join(', ')}.'}');
      Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final totalTabung = (p?.sisa ?? []).fold(0, (s, x) => s + (x.nominal - _n(_teruskan[x.akunId])));
    final totalAwal = _akunBaru.fold(0, (s, a) => s + _n(_saldo[a.id]));
    final minMulai = parseYmd(p?.periode.tanggalMulai)?.add(const Duration(days: 1));

    return DefaultTextStyle.merge(
      style: const TextStyle(fontFeatures: AppTheme.tabular),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                Text.rich(
                  p == null
                      ? const TextSpan(text: 'Belum ada periode. Isi saldo awal tiap akun (gaji masuk di sini), lalu mulai mencatat.')
                      : TextSpan(children: [
                          const TextSpan(text: 'Periode '),
                          TextSpan(text: p.periode.nama, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                          const TextSpan(text: ' akan ditutup. Sisa saldo tiap akun masuk ke tabungan, kecuali yang kamu teruskan.'),
                        ]),
                  style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.55),
                ),
                const SizedBox(height: 22),
                const _Step(1, 'Periode baru'),
                SakuCard(
                  padding: EdgeInsets.zero,
                  child: DividedColumn(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      child: Row(children: [
                        const SizedBox(width: 96, child: Text('Nama', style: TextStyle(fontSize: 13, color: AppColors.muted))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _nama,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: 'Periode ${tglSedang(ymd(_mulai))}',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    SelectRow(
                      label: 'Tanggal mulai',
                      value: tglPanjang(_mulai),
                      trailing: const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.muted),
                      onTap: () async {
                        final d = await pickDate(context, _mulai, first: minMulai);
                        if (d != null) setState(() => _mulai = d);
                      },
                    ),
                    if (p != null) FieldRow(label: 'Periode lama selesai', value: tglSedang(ymd(_mulai.subtract(const Duration(days: 1))))),
                  ]),
                ),
                if (p != null && p.sisa.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const _Step(2, 'Sisa periode lama'),
                  SakuCard(
                    padding: EdgeInsets.zero,
                    child: DividedColumn(children: [
                      for (final s in p.sisa)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(children: [
                            Row(children: [
                              Expanded(child: Text(s.nama, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                              Text('Sisa ${rupiah(s.nominal)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: s.nominal < 0 ? AppColors.out : AppColors.ink)),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              const Expanded(child: Text('Teruskan ke periode baru', style: TextStyle(fontSize: 13, color: AppColors.muted))),
                              SizedBox(
                                width: 128,
                                child: s.nominal > 0
                                    ? NominalField(controller: _teruskan[s.akunId]!, dense: true, onChanged: (_) => _onTeruskan(s.akunId))
                                    : const Text('—', textAlign: TextAlign.right, style: TextStyle(color: AppColors.muted)),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              const Expanded(child: Text('Masuk tabungan', style: TextStyle(fontSize: 12, color: AppColors.muted))),
                              Text(
                                rupiah(s.nominal - _n(_teruskan[s.akunId])),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s.nominal - _n(_teruskan[s.akunId]) < 0 ? AppColors.out : AppColors.primary),
                              ),
                            ]),
                          ]),
                        ),
                    ]),
                  ),
                  _Total('Total masuk tabungan', rupiah(totalTabung)),
                ],
                const SizedBox(height: 22),
                _Step(p == null ? 2 : 3, 'Saldo awal (gaji masuk di sini)'),
                SakuCard(
                  padding: EdgeInsets.zero,
                  child: DividedColumn(children: [
                    for (final a in _akunBaru)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(children: [
                          Expanded(
                            child: Text.rich(TextSpan(children: [
                              TextSpan(text: a.nama, style: const TextStyle(fontSize: 14)),
                              if (_n(_teruskan[a.id]) > 0) const TextSpan(text: ' · diteruskan', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                            ])),
                          ),
                          SizedBox(
                            width: 128,
                            child: NominalField(
                              controller: _saldo[a.id]!,
                              dense: true,
                              onChanged: (_) => setState(() => _saldoManual.add(a.id)),
                            ),
                          ),
                        ]),
                      ),
                  ]),
                ),
                _Total('Total saldo awal', rupiah(totalAwal)),
                if (p != null) ...[
                  const SizedBox(height: 22),
                  SakuCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(children: [
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Salin anggaran', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          SizedBox(height: 2),
                          Text('Pakai batas anggaran periode ini lagi', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                        ]),
                      ),
                      Switch(
                        value: _salin,
                        onChanged: (v) => setState(() => _salin = v),
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppColors.primary,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: AppColors.dashed,
                        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 22),
                  InfoNote(
                    icon: Icons.info_outline_rounded,
                    bg: AppColors.transferBg,
                    fg: AppColors.infoText,
                    child: Text('Transaksi yang sudah tercatat bertanggal ${tglPendek(ymd(_mulai))} atau sesudahnya tetap di periode lama.'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 18),
                  InfoNote(icon: Icons.error_outline_rounded, bg: AppColors.outBg, fg: AppColors.outText, child: Text(_error!)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: BusyButton(label: p == null ? 'Mulai periode' : 'Tutup buku & mulai periode', busy: _busy, onPressed: _submit),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.title);

  final int n;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.deep, shape: BoxShape.circle),
          child: Text('$n', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.muted))),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
