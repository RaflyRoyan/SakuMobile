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

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  Future<void> _hapus(BuildContext context, RiwayatTabungan r) async {
    final ok = await showSakuSheet<bool>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Batalkan tarik tabungan?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text('${rupiah(r.nominal)} dari ${r.akunNama}. Transaksi pemasukan Tarik Tabungan ikut dihapus.',
              style: const TextStyle(fontSize: 14, color: AppColors.inkSoft, height: 1.5)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: OutlineBtn('Batal', height: 50, radius: 14, fontSize: 15, onPressed: () => Navigator.pop(ctx, false))),
            const SizedBox(width: 10),
            Expanded(child: PrimaryButton('Hapus', height: 50, color: AppColors.out, onPressed: () => Navigator.pop(ctx, true))),
          ]),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await runAction(context, () => context.api.hapusTabungan(r.id), success: 'Tarik tabungan dibatalkan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<Tabungan>(
      load: () => context.api.tabungan(),
      builder: (context, t, _) {
        final riwayat = t.riwayat.where((r) => r.nominal != 0).toList();
        return DefaultTextStyle.merge(
          style: const TextStyle(fontFeatures: AppTheme.tabular),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              const Text('Tabungan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.deep, borderRadius: BorderRadius.circular(22)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Total tabungan', style: TextStyle(fontSize: 13, color: AppColors.mintText)),
                    const SizedBox(height: 4),
                    Text(rupiah(t.total), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: Colors.white)),
                    const SizedBox(height: 6),
                    const Text('Terisi otomatis dari sisa saldo tiap akun saat tutup buku.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.mintText)),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: t.perAkun.any((a) => a.saldo > 0)
                            ? () => showSakuSheet<void>(context, builder: (_) => _TarikSheet(perAkun: t.perAkun.where((a) => a.saldo > 0).toList()))
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.mint,
                          foregroundColor: AppColors.deep,
                          disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
                          disabledForegroundColor: AppColors.mintText,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        child: const Text('Tarik tabungan'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader('Per akun'),
              if (t.perAkun.isEmpty)
                const SakuCard(child: Text('Belum ada tabungan. Tabungan terisi saat periode ditutup.', style: TextStyle(color: AppColors.muted)))
              else
                SakuCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DividedColumn(children: [
                    for (final a in t.perAkun)
                      _Line(
                        title: a.nama,
                        subtitle: 'Setor ${thousands(a.setor)} · Tarik ${thousands(a.tarik)}',
                        trailing: Text(rupiah(a.saldo), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: a.saldo < 0 ? AppColors.out : AppColors.ink)),
                      ),
                  ]),
                ),
              if (riwayat.isNotEmpty) ...[
                const SizedBox(height: 20),
                const SectionHeader('Riwayat'),
                SakuCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DividedColumn(children: [
                    for (final r in riwayat)
                      _Line(
                        leading: r.jenis == 'setor'
                            ? const IconTile(text: 'IN', bg: AppColors.inBg, fg: AppColors.primary, size: 36, radius: 10)
                            : const IconTile(text: 'OUT', bg: AppColors.outBg, fg: AppColors.out, size: 36, radius: 10),
                        title: r.keterangan.isNotEmpty ? r.keterangan : (r.jenis == 'setor' ? 'Sisa ${r.periodeNama}' : 'Tarik tabungan'),
                        subtitle: '${r.akunNama} · ${r.jenis == 'setor' ? 'Setor' : 'Tarik'} · ${tglPendek(r.tanggal)}',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              r.jenis == 'setor' ? signed(r.nominal) : signed(-r.nominal),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: r.jenis == 'setor' && r.nominal >= 0 ? AppColors.primary : AppColors.out),
                            ),
                            if (r.bisaHapus)
                              IconButton(
                                tooltip: 'Batalkan tarik',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _hapus(context, r),
                                icon: const Icon(Icons.undo_rounded, size: 20, color: AppColors.muted),
                              ),
                          ],
                        ),
                      ),
                  ]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TarikSheet extends StatefulWidget {
  const _TarikSheet({required this.perAkun});

  final List<TabunganAkun> perAkun;

  @override
  State<_TarikSheet> createState() => _TarikSheetState();
}

class _TarikSheetState extends State<_TarikSheet> {
  late TabunganAkun _akun = widget.perAkun.first;
  final _nominal = TextEditingController();
  final _ket = TextEditingController();
  bool _busy = false;
  Map<String, List<String>> _errors = {};
  String? _error;

  @override
  void dispose() {
    _nominal.dispose();
    _ket.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final n = parseNominal(_nominal.text);
    if (n == null || n <= 0) {
      setState(() => _errors = {'nominal': ['Nominal harus lebih dari 0.']});
      return;
    }
    setState(() {
      _busy = true;
      _errors = {};
      _error = null;
    });
    try {
      await context.api.tarikTabungan(akunId: _akun.akunId, nominal: n, keterangan: _ket.text.trim());
      if (!mounted) return;
      context.session.dataChanged();
      showToast(context, 'Tabungan ditarik ke ${_akun.nama}.');
      Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() {
        _errors = e.errors;
        _error = e.errors.isEmpty ? e.title : null;
      });
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = parseNominal(_nominal.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Expanded(child: Text('Tarik tabungan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          IconButton(tooltip: 'Tutup', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppColors.ink)),
        ]),
        const SizedBox(height: 8),
        LabeledField(
          label: 'Dari tabungan akun',
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final id = await pickOne<String>(
                context,
                title: 'Dari tabungan akun',
                selected: _akun.akunId,
                options: [for (final a in widget.perAkun) PickOption(a.akunId, a.nama, subtitle: 'Tersedia ${rupiah(a.saldo)}')],
              );
              if (id != null) setState(() => _akun = widget.perAkun.firstWhere((a) => a.akunId == id));
            },
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderStrong)),
              child: Row(children: [
                Text(_akun.nama, style: const TextStyle(fontSize: 15)),
                const Spacer(),
                Text('tersedia ${rupiah(_akun.saldo)}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                const Icon(Icons.expand_more_rounded, color: AppColors.muted),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        LabeledField(label: 'Nominal', child: NominalField(controller: _nominal, errorText: _errors['nominal']?.first, onChanged: (_) => setState(() {}))),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Keterangan',
          child: TextField(
            controller: _ket,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: 'Mis. Servis motor', errorText: _errors['keterangan']?.first),
          ),
        ),
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: 'Uang akan masuk ke saldo ${_akun.nama} periode aktif sebagai pemasukan '),
            const TextSpan(text: 'Tarik Tabungan', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
            const TextSpan(text: '.'),
          ]),
          style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          InfoNote(icon: Icons.error_outline_rounded, bg: AppColors.outBg, fg: AppColors.outText, child: Text(_error!)),
        ],
        const SizedBox(height: 16),
        BusyButton(label: n == null ? 'Tarik' : 'Tarik ${rupiah(n)}', busy: _busy, height: 52, onPressed: _submit),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.title, required this.subtitle, required this.trailing, this.leading});

  final String title;
  final String subtitle;
  final Widget trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}
