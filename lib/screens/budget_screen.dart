import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../app.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import '../widgets/kategori_picker.dart';

class _BudgetData {
  _BudgetData(this.periode, this.anggaran);

  final Periode? periode;
  final AnggaranPeriode? anggaran;
}

Color _statusColor(StatusAnggaran? s) => s == null ? AppColors.muted : budgetColor(s);

/// One-line text that shrinks instead of wrapping.
Widget _oneLine(String text, TextStyle style, {Alignment align = Alignment.centerLeft}) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: align,
      child: Text(text, maxLines: 1, softWrap: false, style: style),
    );

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  Future<_BudgetData> _load(BuildContext context) async {
    final api = context.api;
    final p = await api.periodeAktif();
    if (p == null) return _BudgetData(null, null);
    return _BudgetData(p, await api.anggaran(p.id));
  }

  void _edit(BuildContext context, Periode p, AnggaranPeriode? a) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditBudgetScreen(periode: p, anggaran: a)));

  @override
  Widget build(BuildContext context) {
    return AsyncView<_BudgetData>(
      load: () => _load(context),
      builder: (context, d, _) {
        final p = d.periode;
        final a = d.anggaran;
        final berbatas = a?.kelompok.where((k) => k.anggaran != null).toList() ?? [];
        final tanpaBatas = a?.kelompok.where((k) => k.anggaran == null).toList() ?? [];
        return DefaultTextStyle.merge(
          style: const TextStyle(fontFeatures: AppTheme.tabular),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              Row(children: [
                const Expanded(child: Text('Anggaran', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
                if (p != null)
                  OutlineBtn('Ubah batas', color: AppColors.primary, borderColor: AppColors.primary, onPressed: () => _edit(context, p, a)),
              ]),
              const SizedBox(height: 16),
              if (p == null)
                EmptyState(
                  icon: Icons.pie_chart_outline_rounded,
                  title: 'Belum ada periode aktif',
                  message: 'Anggaran berlaku per periode.',
                  action: 'Mulai periode',
                  onAction: () => Navigator.of(context).pushNamed(Routes.closePeriod),
                )
              else ...[
                _Hero(periode: p, a: a),
                if (a == null || a.kelompok.isEmpty) ...[
                  const SizedBox(height: 16),
                  EmptyState(
                    icon: Icons.pie_chart_outline_rounded,
                    title: 'Belum ada anggaran',
                    message: 'Atur batas pengeluaran per kategori untuk periode ini.',
                    action: 'Atur anggaran',
                    onAction: () => _edit(context, p, a),
                  ),
                ],
                if (berbatas.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const OverlineLabel('Dengan batas'),
                  for (final k in berbatas) ...[_GroupCard(k: k), const SizedBox(height: 12)],
                ],
                if (tanpaBatas.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const OverlineLabel('Tanpa batas'),
                  for (final k in tanpaBatas) ...[_GroupCard(k: k), const SizedBox(height: 12)],
                ],
                const SizedBox(height: 4),
                const Text('Sisa anggaran hangus saat tutup buku.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.periode, required this.a});

  final Periode periode;
  final AnggaranPeriode? a;

  @override
  Widget build(BuildContext context) {
    final t = a?.total;
    final batas = t?.anggaran;
    final counts = {for (final s in StatusAnggaran.values) s: 0};
    for (final k in a?.kelompok ?? <PosAnggaran>[]) {
      if (k.status != null) counts[k.status!] = counts[k.status!]! + 1;
    }

    Widget stat(String label, String value, {Color color = Colors.white}) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _oneLine(label, const TextStyle(fontSize: 11, color: AppColors.mintText)),
              const SizedBox(height: 4),
              _oneLine(value, TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ]),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.deep, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
            child: Text(periode.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
          const SizedBox(height: 16),
          const Text('Terpakai', style: TextStyle(fontSize: 13, color: AppColors.mintText)),
          const SizedBox(height: 4),
          _oneLine(rupiah(t?.terpakai ?? 0), const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: Colors.white)),
          if (batas != null && batas > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (t!.terpakai / batas).clamp(0, 1),
                minHeight: 8,
                color: t.status == StatusAnggaran.lewat ? AppColors.peachBright : t.status == StatusAnggaran.hampir ? const Color(0xFFFFD98A) : AppColors.mintBright,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            stat('Batas', batas == null ? '—' : thousands(batas)),
            const SizedBox(width: 8),
            stat(
              (t?.sisa ?? 0) < 0 ? 'Lewat' : 'Sisa',
              t?.sisa == null ? '—' : thousands(t!.sisa!.abs()),
              color: (t?.sisa ?? 0) < 0 ? AppColors.peachBright : AppColors.mintBright,
            ),
            const SizedBox(width: 8),
            stat('Terpakai', t?.persen == null ? '—' : '${t!.persen}%'),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 14, runSpacing: 6, children: [
            for (final (s, label, c) in [
              (StatusAnggaran.aman, 'aman', AppColors.mintBright),
              (StatusAnggaran.hampir, 'hampir', const Color(0xFFFFD98A)),
              (StatusAnggaran.lewat, 'lewat', AppColors.peachBright),
            ])
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('${counts[s]} $label', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              ]),
          ]),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.k});

  final PosAnggaran k;

  @override
  Widget build(BuildContext context) {
    final s = k.status;
    final limit = k.anggaran;
    final over = s == StatusAnggaran.lewat;

    return SakuCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(k.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                if (s != null) Pill.budget(s, s.label) else const Pill('Tanpa batas'),
              ]),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: rupiah(k.terpakai), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        if (limit != null) TextSpan(text: '  / ${rupiah(limit)}', style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w500)),
                      ]),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
                if (k.persen != null) ...[
                  const SizedBox(width: 8),
                  Text('${k.persen}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _statusColor(s))),
                ],
              ]),
              if (limit != null && limit > 0) ...[
                const SizedBox(height: 8),
                ProgressBar(value: k.terpakai / limit, color: _statusColor(s), height: 8),
                const SizedBox(height: 6),
                _oneLine(
                  over ? 'Lewat ${rupiah(-(k.sisa ?? 0))}' : 'Sisa ${rupiah(k.sisa ?? 0)}',
                  TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: over ? AppColors.out : AppColors.muted),
                ),
              ],
            ]),
          ),
          if (k.sub.isNotEmpty) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Column(children: [for (final sub in k.sub) _SubRow(sub: sub)]),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow({required this.sub});

  final PosAnggaran sub;

  @override
  Widget build(BuildContext context) {
    final limit = sub.anggaran;
    final color = _statusColor(sub.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: limit == null ? AppColors.borderStrong : color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(sub.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Text(rupiah(sub.terpakai), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        if (limit != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Row(children: [
              Expanded(child: ProgressBar(value: limit == 0 ? 0 : sub.terpakai / limit, color: color, height: 4)),
              const SizedBox(width: 10),
              Text('${sub.persen ?? 0}% dari ${thousands(limit)}', style: TextStyle(fontSize: 11, color: sub.status == StatusAnggaran.lewat ? AppColors.out : AppColors.muted)),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// Edit every budget line of a period (PUT replaces all).
class EditBudgetScreen extends StatefulWidget {
  const EditBudgetScreen({super.key, required this.periode, this.anggaran});

  final Periode periode;
  final AnggaranPeriode? anggaran;

  @override
  State<EditBudgetScreen> createState() => _EditBudgetScreenState();
}

class _EditBudgetScreenState extends State<EditBudgetScreen> {
  late final Future<(List<KelompokKategori>, List<Kategori>)> _future;
  final _kelompokCtl = <String, TextEditingController>{};
  final _kategoriCtl = <String, TextEditingController>{};
  final _open = <String>{};

  /// Spending so far, for context next to each input.
  final _terpakai = <String, int>{};
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final k in widget.anggaran?.kelompok ?? <PosAnggaran>[]) {
      _terpakai[k.id] = k.terpakai;
      if (k.anggaranSendiri != null) _ctl(_kelompokCtl, k.id).text = thousands(k.anggaranSendiri!);
      for (final s in k.sub) {
        _terpakai[s.id] = s.terpakai;
        if (s.anggaran != null) {
          _ctl(_kategoriCtl, s.id).text = thousands(s.anggaran!);
          _open.add(k.id);
        }
      }
    }
    final api = context.api;
    _future = Future.wait([api.kelompokKategori(), api.kategori(tipe: 'keluar')]).then((r) => (r[0] as List<KelompokKategori>, r[1] as List<Kategori>));
  }

  TextEditingController _ctl(Map<String, TextEditingController> m, String id) => m.putIfAbsent(id, TextEditingController.new);

  @override
  void dispose() {
    for (final c in [..._kelompokCtl.values, ..._kategoriCtl.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final items = <({String? kelompokId, String? kategoriId, int nominal})>[
      for (final e in _kelompokCtl.entries)
        if ((parseNominal(e.value.text) ?? 0) > 0) (kelompokId: e.key, kategoriId: null, nominal: parseNominal(e.value.text)!),
      for (final e in _kategoriCtl.entries)
        if ((parseNominal(e.value.text) ?? 0) > 0) (kelompokId: null, kategoriId: e.key, nominal: parseNominal(e.value.text)!),
    ];
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.api.simpanAnggaran(widget.periode.id, items);
      if (!mounted) return;
      context.session.dataChanged();
      showToast(context, 'Anggaran tersimpan.');
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SubPageHeader(title: 'Ubah anggaran'),
            Expanded(
              child: FutureBuilder(
                future: _future,
                builder: (context, s) {
                  if (s.hasError) return ErrorState(message: errorMessage(s.error!), onRetry: () => Navigator.pop(context));
                  if (!s.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  final (kelompok, kategori) = s.data!;
                  final aktif = kategori.where((c) => c.aktif).toList();
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      Text(widget.periode.nama, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Kosongkan batas kategori induk supaya dihitung dari jumlah sub kategorinya.', style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5)),
                      const SizedBox(height: 16),
                      for (final k in kelompok.where((k) => k.aktif)) ...[
                        _kelompokCard(k, aktif.where((c) => indukId(c) == k.id).toList()),
                        const SizedBox(height: 12),
                      ],
                      if (_error != null) InfoNote(icon: Icons.error_outline_rounded, bg: AppColors.outBg, fg: AppColors.outText, child: Text(_error!)),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: BusyButton(label: 'Simpan anggaran', busy: _busy, onPressed: _save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nameWithSpent(String nama, String id, {bool bold = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
          if ((_terpakai[id] ?? 0) > 0)
            Text('terpakai ${rupiah(_terpakai[id]!)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      );

  Widget _kelompokCard(KelompokKategori k, List<Kategori> subs) {
    final open = _open.contains(k.id);
    return SakuCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: _nameWithSpent(k.nama, k.id, bold: true)),
            const SizedBox(width: 12),
            SizedBox(width: 132, child: NominalField(controller: _ctl(_kelompokCtl, k.id), dense: true, hint: 'Tanpa batas')),
          ]),
          if (subs.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => open ? _open.remove(k.id) : _open.add(k.id)),
                icon: Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
                label: Text(open ? 'Sembunyikan sub kategori' : 'Sub kategori (${subs.length})'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: EdgeInsets.zero, textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          if (open)
            for (final c in subs)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: Row(children: [
                  Expanded(child: _nameWithSpent(c.nama, c.id)),
                  const SizedBox(width: 12),
                  SizedBox(width: 132, child: NominalField(controller: _ctl(_kategoriCtl, c.id), dense: true, hint: '—')),
                ]),
              ),
        ],
      ),
    );
  }
}
