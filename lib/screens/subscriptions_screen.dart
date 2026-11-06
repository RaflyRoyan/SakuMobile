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

class _SubsData {
  _SubsData(this.list, this.pengingat);

  final List<Berulang> list;
  final Map<String, Pengingat> pengingat;
}

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  Future<_SubsData> _load(BuildContext context) async {
    final api = context.api;
    final r = await Future.wait([api.berulang(), api.pengingat()]);
    final list = r[0] as List<Berulang>;
    final p = r[1] as List<Pengingat>;
    return _SubsData(list, {for (final x in p) x.berulangId: x});
  }

  void _openForm(BuildContext context, [Berulang? b]) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => SubscriptionFormScreen(existing: b)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SubPageHeader(
              title: 'Langganan',
              trailing: IconButton(
                tooltip: 'Tambah langganan',
                onPressed: () => _openForm(context),
                icon: const Icon(Icons.add_rounded, color: AppColors.primary, size: 26),
              ),
            ),
            Expanded(
              child: AsyncView<_SubsData>(
                load: () => _load(context),
                builder: (context, d, _) {
                  final aktif = d.list.where((b) => b.aktif && b.berlaku).toList()..sort((a, b) => a.jatuhTempo.compareTo(b.jatuhTempo));
                  final lain = d.list.where((b) => !(b.aktif && b.berlaku)).toList();
                  final total = aktif.fold(0, (s, b) => s + b.nominal);
                  final paid = aktif.where((b) => b.status == 'dibayar').length;
                  final pending = aktif.where((b) => b.status == 'belum').length;
                  final bulanIni = ym(todayWib());

                  return DefaultTextStyle.merge(
                    style: const TextStyle(fontFeatures: AppTheme.tabular),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        if (d.list.isEmpty)
                          EmptyState(
                            icon: Icons.repeat_rounded,
                            title: 'Belum ada langganan',
                            message: 'Catat tagihan rutin (internet, streaming, cicilan) supaya diingatkan sebelum jatuh tempo.',
                            action: 'Tambah langganan',
                            onAction: () => _openForm(context),
                          )
                        else ...[
                          SakuCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Tagihan ${namaBulan(bulanIni).split(' ').first}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
                                  const SizedBox(height: 2),
                                  Text(rupiah(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                ]),
                              ),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('$paid dibayar', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                const SizedBox(height: 2),
                                Text('$pending menunggu', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                              ]),
                            ]),
                          ),
                          const SizedBox(height: 18),
                          const OverlineLabel('Bulan ini'),
                          for (final b in aktif) ...[
                            _SubscriptionCard(b: b, pengingat: d.pengingat[b.id], onEdit: () => _openForm(context, b)),
                            const SizedBox(height: 12),
                          ],
                          if (lain.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            const OverlineLabel('Tidak berlaku / nonaktif'),
                            for (final b in lain) ...[
                              _SubscriptionCard(b: b, pengingat: null, onEdit: () => _openForm(context, b), inactive: true),
                              const SizedBox(height: 12),
                            ],
                          ],
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

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.b, required this.pengingat, required this.onEdit, this.inactive = false});

  final Berulang b;
  final Pengingat? pengingat;
  final VoidCallback onEdit;
  final bool inactive;

  @override
  Widget build(BuildContext context) {
    final p = pengingat;
    final (label, bg, fg) = inactive
        ? (b.aktif ? 'Tidak berlaku' : 'Nonaktif', AppColors.background, AppColors.inkSoft)
        : p != null
            ? switch (p.status) {
                'terlambat' => ('Terlambat ${-p.sisaHari} hari', AppColors.outBg, AppColors.outText),
                'hari_ini' => ('Hari ini', AppColors.warnBg, AppColors.warnText),
                _ => ('${p.sisaHari} hari lagi', AppColors.transferBg, AppColors.transfer),
              }
            : switch (b.status) {
                'dibayar' => ('Dibayar', AppColors.inBg, AppColors.primaryDark),
                'dilewati' => ('Dilewati', AppColors.background, AppColors.inkSoft),
                _ => ('Belum', AppColors.background, AppColors.inkSoft),
              };
    final bulan = p?.bulan ?? b.bulan;
    final jatuhTempo = p?.jatuhTempo ?? b.jatuhTempo;
    final actionable = !inactive && (p != null || b.status == 'belum');
    final api = context.api;

    return SakuCard(
      onTap: onEdit,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Opacity(
        opacity: inactive ? 0.65 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 44,
                height: 48,
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${parseYmd(jatuhTempo)?.day ?? b.tglJatuhTempo}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1)),
                  const SizedBox(height: 3),
                  Text(bulanSingkat(jatuhTempo), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.muted)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${b.akunNama} · ${b.kategoriNama} · H-${b.ingatkanHMin}${b.selesai != null ? ' · s.d. ${namaBulan(b.selesai!)}' : ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(rupiah(b.nominal), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Pill(label, bg: bg, fg: fg),
              ]),
            ]),
            if (actionable) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlineBtn('Lewati bulan ini', onPressed: () => runAction(context, () => api.lewatiBerulang(b.id, bulan), success: '${b.nama} dilewati ${namaBulan(bulan)}.')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton('Konfirmasi bayar', height: 40, onPressed: () async {
                    try {
                      final tx = await api.konfirmasiBerulang(b.id, bulan);
                      if (!context.mounted) return;
                      context.session.dataChanged();
                      await showPeringatan(context, tx.peringatan);
                      if (context.mounted) showToast(context, '${b.nama} dicatat sebagai pengeluaran.');
                    } on ApiException catch (e) {
                      if (context.mounted) showToast(context, e.message, error: true);
                    }
                  }),
                ),
              ]),
            ],
            if (!inactive && p == null && b.status == 'dibayar' && b.transaksiId != null) ...[
              const SizedBox(height: 8),
              TextLink('Lihat transaksi', onTap: () => Navigator.of(context).pushNamed(Routes.editTransaction, arguments: b.transaksiId)),
            ],
            if (!inactive && p == null && b.status == 'dilewati') ...[
              const SizedBox(height: 8),
              TextLink('Batal lewati', onTap: () => runAction(context, () => api.batalLewati(b.id, b.bulan), success: 'Lewati dibatalkan.')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Create or edit a subscription.
class SubscriptionFormScreen extends StatefulWidget {
  const SubscriptionFormScreen({super.key, this.existing});

  final Berulang? existing;

  @override
  State<SubscriptionFormScreen> createState() => _SubscriptionFormScreenState();
}

class _SubscriptionFormScreenState extends State<SubscriptionFormScreen> {
  late final Future<(List<Akun>, List<Kategori>, List<KelompokKategori>)> _future;
  final _nama = TextEditingController();
  final _nominal = TextEditingController();
  int _tgl = 1;
  int _hMin = 3;
  late String _mulai;
  String? _selesai;
  String? _akunId;
  String? _kategoriId;
  bool _aktif = true;
  bool _busy = false;
  Map<String, List<String>> _errors = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _mulai = ym(todayWib());
    if (b != null) {
      _nama.text = b.nama;
      _nominal.text = thousands(b.nominal);
      _tgl = b.tglJatuhTempo;
      _hMin = b.ingatkanHMin;
      _mulai = b.mulai;
      _selesai = b.selesai;
      _akunId = b.akunId;
      _kategoriId = b.kategoriId;
      _aktif = b.aktif;
    }
    final api = context.api;
    _future = Future.wait([api.akun(), api.kategori(tipe: 'keluar', untukInput: true), api.kelompokKategori()])
        .then((r) => (r[0] as List<Akun>, r[1] as List<Kategori>, r[2] as List<KelompokKategori>));
  }

  @override
  void dispose() {
    _nama.dispose();
    _nominal.dispose();
    super.dispose();
  }

  List<String> _months({int back = 6, int forward = 24}) {
    final t = todayWib();
    return [for (var i = -back; i <= forward; i++) ym(DateTime(t.year, t.month + i))];
  }

  Future<void> _save() async {
    final nominal = parseNominal(_nominal.text);
    final local = <String, List<String>>{
      if (_nama.text.trim().isEmpty) 'nama': ['Nama wajib diisi.'],
      if (nominal == null || nominal <= 0) 'nominal': ['Nominal harus lebih dari 0.'],
      if (_akunId == null) 'akunId': ['Pilih akun.'],
      if (_kategoriId == null) 'kategoriId': ['Pilih kategori.'],
    };
    if (local.isNotEmpty) {
      setState(() => _errors = local);
      return;
    }
    final input = BerulangInput(
      nama: _nama.text.trim(),
      akunId: _akunId!,
      kategoriId: _kategoriId!,
      nominal: nominal!,
      tglJatuhTempo: _tgl,
      ingatkanHMin: _hMin,
      mulai: _mulai,
      selesai: _selesai,
      aktif: _aktif,
    );
    setState(() {
      _busy = true;
      _errors = {};
      _error = null;
    });
    try {
      final api = context.api;
      if (widget.existing == null) {
        await api.buatBerulang(input);
      } else {
        await api.ubahBerulang(widget.existing!.id, input);
      }
      if (!mounted) return;
      context.session.dataChanged();
      showToast(context, 'Langganan tersimpan.');
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

  String? _err(String f) => _errors[f]?.firstOrNull;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SubPageHeader(title: widget.existing == null ? 'Langganan baru' : 'Ubah langganan'),
            Expanded(
              child: FutureBuilder(
                future: _future,
                builder: (context, s) {
                  if (s.hasError) return ErrorState(message: errorMessage(s.error!), onRetry: () => Navigator.pop(context));
                  if (!s.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  final (akun, kategori, kelompok) = s.data!;
                  final namaAkun = akun.where((a) => a.id == _akunId).firstOrNull?.nama ?? (_akunId == widget.existing?.akunId ? widget.existing?.akunNama : null);
                  final namaKat = kategori.where((k) => k.id == _kategoriId).firstOrNull?.nama ?? (_kategoriId == widget.existing?.kategoriId ? widget.existing?.kategoriNama : null);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      LabeledField(
                        label: 'Nama',
                        child: TextField(
                          controller: _nama,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(hintText: 'Mis. Netflix', errorText: _err('nama')),
                        ),
                      ),
                      const SizedBox(height: 16),
                      LabeledField(label: 'Nominal', child: NominalField(controller: _nominal, errorText: _err('nominal'))),
                      const SizedBox(height: 16),
                      SakuCard(
                        padding: EdgeInsets.zero,
                        child: DividedColumn(children: [
                          SelectRow(
                            label: 'Akun',
                            value: namaAkun,
                            error: _err('akunId'),
                            onTap: () async {
                              final id = await pickOne<String>(context, title: 'Akun', selected: _akunId, options: [for (final a in akun) PickOption(a.id, a.nama)]);
                              if (id != null) setState(() => _akunId = id);
                            },
                          ),
                          SelectRow(
                            label: 'Kategori',
                            value: namaKat,
                            error: _err('kategoriId'),
                            onTap: () async {
                              final id = await pickOne<String>(
                                context,
                                title: 'Kategori',
                                selected: _kategoriId,
                                options: kategoriPickOptions(kategori, kelompok),
                              );
                              if (id != null) setState(() => _kategoriId = id);
                            },
                          ),
                          SelectRow(
                            label: 'Jatuh tempo',
                            value: 'Tanggal $_tgl',
                            error: _err('tglJatuhTempo'),
                            onTap: () async {
                              final v = await pickOne<int>(context, title: 'Tanggal jatuh tempo', selected: _tgl, options: [for (var i = 1; i <= 31; i++) PickOption(i, 'Tanggal $i')]);
                              if (v != null) setState(() => _tgl = v);
                            },
                          ),
                          SelectRow(
                            label: 'Ingatkan',
                            value: _hMin == 0 ? 'Di hari jatuh tempo' : '$_hMin hari sebelumnya',
                            error: _err('ingatkanHMin'),
                            onTap: () async {
                              final v = await pickOne<int>(
                                context,
                                title: 'Ingatkan',
                                selected: _hMin,
                                options: [for (var i = 0; i <= 15; i++) PickOption(i, i == 0 ? 'Di hari jatuh tempo' : 'H-$i')],
                              );
                              if (v != null) setState(() => _hMin = v);
                            },
                          ),
                          SelectRow(
                            label: 'Mulai',
                            value: namaBulan(_mulai),
                            error: _err('mulai'),
                            onTap: () async {
                              final v = await pickOne<String>(context, title: 'Mulai bulan', selected: _mulai, options: [for (final m in _months()) PickOption(m, namaBulan(m))]);
                              if (v != null) setState(() => _mulai = v);
                            },
                          ),
                          SelectRow(
                            label: 'Selesai',
                            value: _selesai == null ? 'Tanpa batas' : namaBulan(_selesai!),
                            error: _err('selesai'),
                            onTap: () async {
                              const tanpa = '-';
                              final v = await pickOne<String>(
                                context,
                                title: 'Selesai bulan',
                                selected: _selesai ?? tanpa,
                                options: [
                                  const PickOption(tanpa, 'Tanpa batas'),
                                  for (final m in _months(back: 0, forward: 36))
                                    if (m.compareTo(_mulai) >= 0) PickOption(m, namaBulan(m)),
                                ],
                              );
                              if (v != null) setState(() => _selesai = v == tanpa ? null : v);
                            },
                          ),
                        ]),
                      ),
                      if (widget.existing != null) ...[
                        const SizedBox(height: 16),
                        SakuCard(
                          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Aktif', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            subtitle: const Text('Nonaktifkan untuk berhenti diingatkan', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                            value: _aktif,
                            activeTrackColor: AppColors.primary,
                            onChanged: (v) => setState(() => _aktif = v),
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        InfoNote(icon: Icons.error_outline_rounded, bg: AppColors.outBg, fg: AppColors.outText, child: Text(_error!)),
                      ],
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: BusyButton(label: 'Simpan langganan', busy: _busy, onPressed: _save),
            ),
          ],
        ),
      ),
    );
  }
}
