import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../app.dart';
import '../split/parse_struk.dart';
import '../split/split_hitung.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import '../widgets/kategori_picker.dart';

class _FormData {
  _FormData(this.akun, this.kategori, this.kelompok, this.namaDipakai, this.edit);

  final List<Akun> akun;
  final List<Kategori> kategori;
  final List<KelompokKategori> kelompok;
  final List<String> namaDipakai;
  final SplitBill? edit;
}

/// Split baru (4 langkah: Struk → Item → Peserta → Ringkasan) atau ubah
/// split ([editId], mulai dari langkah Item). Ubah mengembalikan [SplitBill].
class SplitFormScreen extends StatefulWidget {
  const SplitFormScreen({super.key, this.editId});

  final String? editId;

  @override
  State<SplitFormScreen> createState() => _SplitFormScreenState();
}

class _SplitFormScreenState extends State<SplitFormScreen> {
  _FormData? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final api = context.api;
    try {
      final r = await Future.wait([
        api.akun(),
        api.kategori(termasukNonaktif: true),
        api.kelompokKategori(),
        api.namaPesertaSplit().catchError((_) => <String>[]),
        if (widget.editId != null) api.detailSplit(widget.editId!),
      ]);
      if (!mounted) return;
      setState(() => _data = _FormData(
            r[0] as List<Akun>,
            r[1] as List<Kategori>,
            r[2] as List<KelompokKategori>,
            r[3] as List<String>,
            widget.editId != null ? r[4] as SplitBill : null,
          ));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d != null) return _SplitWizard(data: d);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          SubPageHeader(title: widget.editId == null ? 'Split baru' : 'Ubah split'),
          Expanded(
            child: _error != null ? ErrorState(message: errorMessage(_error!), onRetry: _load) : const Center(child: CircularProgressIndicator()),
          ),
        ]),
      ),
    );
  }
}

class _ItemDraft {
  _ItemDraft({String nama = '', int harga = 0, this.qty = 1, Set<int>? peserta})
      : nama = TextEditingController(text: nama),
        harga = TextEditingController(text: harga > 0 ? thousands(harga) : ''),
        peserta = peserta ?? {};

  static int _seq = 0;
  final key = _seq++;
  final TextEditingController nama;
  final TextEditingController harga;
  int qty;
  final Set<int> peserta;

  int get nilai => parseNominal(harga.text) ?? 0;

  void dispose() {
    nama.dispose();
    harga.dispose();
  }
}

class _PesertaDraft {
  _PesertaDraft({this.id, required this.nama, this.saya = false, this.lunas = false});

  final String? id;
  final String nama;
  final bool saya;
  final bool lunas;
}

const _langkah = ['Struk', 'Item', 'Peserta', 'Ringkasan'];

class _SplitWizard extends StatefulWidget {
  const _SplitWizard({required this.data});

  final _FormData data;

  @override
  State<_SplitWizard> createState() => _SplitWizardState();
}

class _SplitWizardState extends State<_SplitWizard> {
  late final bool _edit = widget.data.edit != null;
  late int _step = _edit ? 1 : 0;
  late final int _stepAwal = _step;

  final _items = <_ItemDraft>[];
  final _pajak = TextEditingController();
  final _servis = TextEditingController();
  final _diskon = TextEditingController();
  final _peserta = <_PesertaDraft>[];
  final _nama = TextEditingController();
  late DateTime _tanggal = todayWib();
  String? _akunId;
  String? _kategoriId;
  String? _akunTerimaId;

  int? _ocrTotal;
  bool _ocrBusy = false;
  String? _ocrPesan;
  bool _saving = false;

  /// Client-side message for the current step.
  String? _pesan;
  Map<String, List<String>> _errors = {};

  List<Akun> get _akun => widget.data.akun;

  @override
  void initState() {
    super.initState();
    final s = widget.data.edit;
    if (s != null) {
      final idx = {for (final (i, p) in s.peserta.indexed) p.id: i};
      _peserta.addAll([for (final p in s.peserta) _PesertaDraft(id: p.id, nama: p.nama, saya: p.saya, lunas: p.lunas)]);
      for (final it in s.items) {
        _items.add(_ItemDraft(nama: it.nama, harga: it.harga, qty: it.qty < 1 ? 1 : it.qty, peserta: {for (final id in it.peserta) ?idx[id]}));
      }
      _pajak.text = s.pajak > 0 ? thousands(s.pajak) : '';
      _servis.text = s.servis > 0 ? thousands(s.servis) : '';
      _diskon.text = s.diskon > 0 ? thousands(s.diskon) : '';
      _nama.text = s.nama;
      _tanggal = parseYmd(s.tanggal) ?? todayWib();
      _akunId = s.akunId;
      _kategoriId = s.kategoriId;
      _akunTerimaId = s.akunTerimaId;
    } else {
      _peserta.add(_PesertaDraft(nama: 'Saya', saya: true));
      final aktif = _akun.where((a) => a.aktif).toList();
      _akunId = aktif.firstOrNull?.id;
      _akunTerimaId = (aktif.where((a) => RegExp('gopay', caseSensitive: false).hasMatch(a.nama)).firstOrNull ?? aktif.firstOrNull)?.id;
    }
  }

  @override
  void dispose() {
    for (final it in _items) {
      it.dispose();
    }
    _pajak.dispose();
    _servis.dispose();
    _diskon.dispose();
    _nama.dispose();
    super.dispose();
  }

  int get _indeksSaya => _peserta.indexWhere((p) => p.saya);

  ({int subtotal, int total, List<int> nominal}) get _hitung => hitungBagian(
        [for (final it in _items) (harga: it.nilai, peserta: it.peserta.toList())],
        pajak: parseNominal(_pajak.text) ?? 0,
        servis: parseNominal(_servis.text) ?? 0,
        diskon: parseNominal(_diskon.text) ?? 0,
        jumlahPeserta: _peserta.length,
        indeksSaya: _indeksSaya,
      );

  String? _err(String key) => _errors[key]?.first;

  void _ubah(VoidCallback f) => setState(() {
        f();
        _pesan = null;
      });

  // ── Langkah 1: struk

  Future<void> _scan(bool kamera) async {
    final media = context.services.media;
    final String? path;
    try {
      path = await media.ambilGambar(kamera: kamera);
    } catch (_) {
      if (mounted) showToast(context, kamera ? 'Kamera tidak bisa dibuka.' : 'Galeri tidak bisa dibuka.', error: true);
      return;
    }
    if (path == null || !mounted) return;
    setState(() {
      _ocrBusy = true;
      _ocrPesan = null;
    });
    try {
      final h = parseStruk(await media.bacaTeks(path));
      if (!mounted) return;
      if (h.items.isEmpty) {
        setState(() => _ocrPesan = 'Struk tidak terbaca, isi manual atau foto ulang.');
        return;
      }
      setState(() {
        for (final it in _items) {
          it.dispose();
        }
        _items
          ..clear()
          ..addAll([for (final it in h.items) _ItemDraft(nama: it.nama, harga: it.harga, qty: it.qty)]);
        _pajak.text = h.pajak > 0 ? thousands(h.pajak) : '';
        _servis.text = h.servis > 0 ? thousands(h.servis) : '';
        _diskon.text = h.diskon > 0 ? thousands(h.diskon) : '';
        _ocrTotal = h.total;
        _step = 1;
      });
    } catch (_) {
      if (mounted) setState(() => _ocrPesan = 'Struk tidak terbaca, isi manual atau foto ulang.');
    } finally {
      if (mounted) setState(() => _ocrBusy = false);
    }
  }

  void _isiManual() => setState(() {
        if (_items.isEmpty) _items.add(_ItemDraft());
        _step = 1;
      });

  // ── Navigasi

  String? _validasi(int step) {
    switch (step) {
      case 1:
        if (_items.isEmpty) return 'Tambahkan minimal 1 item.';
        if (_items.any((it) => it.nama.text.trim().isEmpty || it.nilai <= 0)) return 'Lengkapi nama dan harga tiap item.';
      case 2:
        if (_peserta.length < 2) return 'Tambahkan minimal 1 teman.';
        if (_items.any((it) => it.peserta.isEmpty)) return 'Tandai pemilik tiap item.';
      case 3:
        if (_nama.text.trim().isEmpty) return 'Isi nama tagihan.';
        if (_akunId == null || _kategoriId == null || _akunTerimaId == null) return 'Lengkapi akun dan kategori.';
    }
    return null;
  }

  void _lanjut() {
    final pesan = _validasi(_step);
    if (pesan != null) {
      setState(() => _pesan = pesan);
      return;
    }
    if (_step < 3) {
      setState(() {
        _step++;
        _pesan = null;
      });
    } else {
      _simpan();
    }
  }

  void _kembali() => setState(() {
        _step--;
        _pesan = null;
      });

  /// Step that owns a server error key.
  static int _stepUntuk(String key) {
    if (key.startsWith('items') || key == 'pajak' || key == 'servis' || key == 'diskon') return 1;
    if (key.startsWith('peserta')) return 2;
    return 3;
  }

  Future<void> _simpan() async {
    final input = SplitInput(
      nama: _nama.text.trim(),
      tanggal: ymd(_tanggal),
      akunId: _akunId!,
      kategoriId: _kategoriId!,
      akunTerimaId: _akunTerimaId!,
      pajak: parseNominal(_pajak.text) ?? 0,
      servis: parseNominal(_servis.text) ?? 0,
      diskon: parseNominal(_diskon.text) ?? 0,
      peserta: [for (final p in _peserta) (id: p.id, nama: p.nama, saya: p.saya)],
      items: [
        for (final it in _items) (nama: it.nama.text.trim(), qty: it.qty, harga: it.nilai, peserta: (it.peserta.toList()..sort())),
      ],
    );
    setState(() {
      _saving = true;
      _errors = {};
      _pesan = null;
    });
    final nav = Navigator.of(context);
    final api = context.api;
    try {
      final s = _edit ? await api.ubahSplit(widget.data.edit!.id, input) : await api.buatSplit(input);
      if (!mounted) return;
      context.session.dataChanged();
      await showPeringatan(context, s.peringatan);
      if (!mounted) return;
      showToast(context, _edit ? 'Split bill diperbarui.' : 'Split bill tersimpan.');
      if (_edit) {
        nav.pop(s);
      } else {
        nav.pushReplacementNamed(Routes.splitDetail, arguments: s.id);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errors = e.errors;
        final steps = e.errors.keys.map(_stepUntuk);
        _step = steps.isEmpty ? 3 : steps.reduce((a, b) => a < b ? a : b);
        _pesan = e.errors.isEmpty ? e.title : (e.errors['items']?.first ?? e.errors['peserta']?.first ?? 'Periksa isian yang ditandai.');
      });
    } catch (e) {
      if (mounted) setState(() => _pesan = errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Peserta

  void _tambahPeserta(String nama) {
    final n = nama.trim();
    if (n.isEmpty) return;
    if (_peserta.any((p) => p.nama.toLowerCase() == n.toLowerCase())) {
      setState(() => _pesan = 'Nama "$n" sudah ada.');
      return;
    }
    _ubah(() => _peserta.add(_PesertaDraft(nama: n)));
  }

  void _hapusPeserta(int i) => _ubah(() {
        _peserta.removeAt(i);
        for (final it in _items) {
          final baru = {for (final p in it.peserta) if (p != i) p > i ? p - 1 : p};
          it.peserta
            ..clear()
            ..addAll(baru);
        }
      });

  void _bagiRata() => _ubah(() {
        for (final it in _items) {
          it.peserta
            ..clear()
            ..addAll(List.generate(_peserta.length, (i) => i));
        }
      });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _stepAwal,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _kembali();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            SubPageHeader(title: _edit ? 'Ubah split' : 'Split baru'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Langkah ${_step + 1} dari 4 · ${_langkah[_step]}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
                const SizedBox(height: 6),
                ProgressBar(value: (_step + 1) / 4, color: AppColors.primary),
              ]),
            ),
            Expanded(
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontFeatures: AppTheme.tabular),
                child: ListView(
                  key: PageStorageKey(_step),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    ...switch (_step) {
                      0 => _langkahStruk(),
                      1 => _langkahItem(),
                      2 => _langkahPeserta(),
                      _ => _langkahRingkasan(),
                    },
                  ],
                ),
              ),
            ),
            if (_step > 0) _bottomBar(),
          ]),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_pesan != null) ...[
          InfoNote(icon: Icons.error_outline_rounded, bg: AppColors.outBg, fg: AppColors.outText, child: Text(_pesan!)),
          const SizedBox(height: 10),
        ],
        Row(children: [
          if (_step > _stepAwal) ...[
            Expanded(child: OutlineBtn('Kembali', height: 54, radius: 16, fontSize: 15, onPressed: _saving ? null : _kembali)),
            const SizedBox(width: 10),
          ],
          Expanded(flex: 2, child: BusyButton(label: _step == 3 ? 'Simpan' : 'Lanjut', busy: _saving, onPressed: _lanjut)),
        ]),
      ]),
    );
  }

  // ── UI langkah

  List<Widget> _langkahStruk() => [
        const Text('Foto struknya, nanti item terisi otomatis. Foto diproses di HP, tidak dikirim ke mana pun.', style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.inkSoft)),
        const SizedBox(height: 16),
        if (_ocrBusy)
          const SakuCard(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Column(children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Membaca struk…', style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
          )
        else ...[
          _PilihanStruk(icon: Icons.photo_camera_outlined, label: 'Foto struk', hint: 'Buka kamera', onTap: () => _scan(true)),
          const SizedBox(height: 10),
          _PilihanStruk(icon: Icons.photo_library_outlined, label: 'Pilih dari galeri', hint: 'Foto struk yang sudah ada', onTap: () => _scan(false)),
          const SizedBox(height: 10),
          _PilihanStruk(icon: Icons.edit_note_rounded, label: 'Isi manual', hint: 'Ketik item sendiri', onTap: _isiManual),
        ],
        if (_ocrPesan != null) ...[
          const SizedBox(height: 14),
          InfoNote(icon: Icons.info_outline_rounded, bg: AppColors.warnBg, fg: AppColors.warnText, child: Text(_ocrPesan!)),
        ],
      ];

  List<Widget> _langkahItem() {
    final h = _hitung;
    return [
      for (final (i, it) in _items.indexed) ...[
        _ItemCard(
          key: ValueKey(it.key),
          item: it,
          nomor: i + 1,
          errNama: _err('items.$i.nama'),
          errHarga: _err('items.$i.harga') ?? _err('items.$i.qty'),
          onChanged: () => _ubah(() {}),
          onHapus: () => _ubah(() => _items.removeAt(i).dispose()),
        ),
        const SizedBox(height: 10),
      ],
      OutlineBtn('+ Tambah item', height: 46, onPressed: () => _ubah(() => _items.add(_ItemDraft()))),
      const SizedBox(height: 16),
      SakuCard(
        child: Column(children: [
          _NominalRow(label: 'Pajak', controller: _pajak, error: _err('pajak'), onChanged: () => _ubah(() {})),
          const SizedBox(height: 10),
          _NominalRow(label: 'Servis', controller: _servis, error: _err('servis'), onChanged: () => _ubah(() {})),
          const SizedBox(height: 10),
          _NominalRow(label: 'Diskon', controller: _diskon, error: _err('diskon'), onChanged: () => _ubah(() {})),
          const Divider(height: 24, color: AppColors.divider),
          _TotalRow('Subtotal', h.subtotal),
          const SizedBox(height: 4),
          _TotalRow('Total', h.total, besar: true),
        ]),
      ),
      if (_ocrTotal != null && _ocrTotal != h.total) ...[
        const SizedBox(height: 12),
        InfoNote(
          icon: Icons.warning_amber_rounded,
          bg: AppColors.warnBg,
          fg: AppColors.warnText,
          child: Text('Total struk ${rupiah(_ocrTotal!)}, hasil hitung ${rupiah(h.total)}. Cek lagi item.'),
        ),
      ],
    ];
  }

  List<Widget> _langkahPeserta() {
    final h = _hitung;
    final saran = widget.data.namaDipakai;
    return [
      const OverlineLabel('Peserta'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (i, p) in _peserta.indexed)
          InputChip(
            label: Text(p.lunas ? '${p.nama} (lunas)' : p.nama),
            avatar: p.saya ? const Icon(Icons.person_rounded, size: 18) : null,
            backgroundColor: p.saya ? AppColors.inBg : AppColors.surface,
            side: const BorderSide(color: AppColors.borderStrong),
            onDeleted: p.saya || p.lunas ? null : () => _hapusPeserta(i),
            deleteButtonTooltipMessage: 'Hapus ${p.nama}',
          ),
      ]),
      for (final (i, _) in _peserta.indexed)
        if (_err('peserta.$i.nama') != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_err('peserta.$i.nama')!, style: const TextStyle(fontSize: 12, color: AppColors.out))),
      if (_err('peserta') != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_err('peserta')!, style: const TextStyle(fontSize: 12, color: AppColors.out))),
      const SizedBox(height: 12),
      _TambahPeserta(
        saran: [for (final n in saran) if (!_peserta.any((p) => p.nama.toLowerCase() == n.toLowerCase())) n],
        onTambah: _tambahPeserta,
      ),
      const SizedBox(height: 20),
      Row(children: [
        const Expanded(child: OverlineLabel('Siapa pesan apa')),
        TextLink('Bagi rata', onTap: _peserta.length < 2 ? null : _bagiRata),
      ]),
      for (final (i, it) in _items.indexed) ...[
        SakuCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Text('${it.qty > 1 ? '${it.qty}× ' : ''}${it.nama.text.trim().isEmpty ? 'Item ${i + 1}' : it.nama.text.trim()}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              Text(rupiah(it.nilai), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (pi, p) in _peserta.indexed)
                FilterChip(
                  label: Text(p.nama),
                  selected: it.peserta.contains(pi),
                  showCheckmark: false,
                  selectedColor: AppColors.mint,
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: it.peserta.contains(pi) ? AppColors.primary : AppColors.borderStrong),
                  labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: it.peserta.contains(pi) ? AppColors.deep : AppColors.inkSoft),
                  onSelected: (on) => _ubah(() => on ? it.peserta.add(pi) : it.peserta.remove(pi)),
                ),
            ]),
            if (_err('items.$i.peserta') != null)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(_err('items.$i.peserta')!, style: const TextStyle(fontSize: 12, color: AppColors.out))),
          ]),
        ),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 10),
      const OverlineLabel('Pratinjau bagian'),
      _BagianCard(peserta: _peserta, nominal: h.nominal, total: h.total),
    ];
  }

  List<Widget> _langkahRingkasan() {
    final h = _hitung;
    final editKat = widget.data.edit?.kategoriId;
    final kategori = widget.data.kategori.where((k) => k.tipe == 'keluar' && ((k.aktif && k.kodeSistem == null) || k.id == editKat)).toList();
    final aktif = _akun.where((a) => a.aktif || a.id == _akunId || a.id == _akunTerimaId).toList();
    String? namaAkun(String? id) => _akun.where((a) => a.id == id).firstOrNull?.nama;
    Future<void> pilihAkun(String judul, String? sekarang, ValueChanged<String> set) async {
      final v = await pickOne<String>(context, title: judul, selected: sekarang, options: [for (final a in aktif) PickOption(a.id, a.nama)]);
      if (v != null) _ubah(() => set(v));
    }

    return [
      LabeledField(
        label: 'Nama tagihan',
        child: TextField(
          controller: _nama,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _ubah(() {}),
          decoration: InputDecoration(hintText: 'Mis. Makan malam Bakmi GM', errorText: _err('nama'), counterText: ''),
        ),
      ),
      const SizedBox(height: 14),
      SakuCard(
        padding: EdgeInsets.zero,
        child: DividedColumn(children: [
          SelectRow(
            label: 'Tanggal',
            value: tglPanjang(_tanggal),
            error: _err('tanggal'),
            onTap: () async {
              final d = await pickDate(context, _tanggal, last: todayWib());
              if (d != null) _ubah(() => _tanggal = d);
            },
          ),
          SelectRow(label: 'Dibayar dari', value: namaAkun(_akunId), error: _err('akunId'), onTap: () => pilihAkun('Akun pembayar', _akunId, (v) => _akunId = v)),
          SelectRow(label: 'Terima di', value: namaAkun(_akunTerimaId), error: _err('akunTerimaId'), onTap: () => pilihAkun('Akun penerima', _akunTerimaId, (v) => _akunTerimaId = v)),
        ]),
      ),
      const SizedBox(height: 16),
      KategoriBertingkat(
        kategori: kategori,
        kelompok: widget.data.kelompok,
        value: _kategoriId,
        bertingkat: true,
        error: _err('kategoriId'),
        onChanged: (v) => _ubah(() => _kategoriId = v),
      ),
      const SizedBox(height: 20),
      const OverlineLabel('Bagian tiap orang'),
      _BagianCard(peserta: _peserta, nominal: h.nominal, total: h.total),
      const SizedBox(height: 8),
      const Text('Pajak, servis & diskon dibagi sebanding dengan pesanan tiap orang.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
    ];
  }
}

class _PilihanStruk extends StatelessWidget {
  const _PilihanStruk({required this.icon, required this.label, required this.hint, required this.onTap});

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SakuCard(
      onTap: onTap,
      child: Row(children: [
        IconTile(icon: icon, bg: AppColors.inBg, fg: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text(hint, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      ]),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({super.key, required this.item, required this.nomor, required this.onChanged, required this.onHapus, this.errNama, this.errHarga});

  final _ItemDraft item;
  final int nomor;
  final VoidCallback onChanged;
  final VoidCallback onHapus;
  final String? errNama;
  final String? errHarga;

  @override
  Widget build(BuildContext context) {
    return SakuCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              controller: item.nama,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => onChanged(),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              decoration: InputDecoration(hintText: 'Nama item $nomor', errorText: errNama, isDense: true),
            ),
          ),
          IconButton(tooltip: 'Hapus item', icon: const Icon(Icons.delete_outline_rounded, color: AppColors.muted), onPressed: onHapus),
        ]),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _QtyStepper(
              qty: item.qty,
              onChanged: (q) {
                item.qty = q;
                onChanged();
              },
            ),
            const Spacer(),
            SizedBox(width: 150, child: NominalField(controller: item.harga, dense: true, hint: 'Harga', errorText: errHarga, onChanged: (_) => onChanged())),
          ]),
        ),
      ]),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.qty, required this.onChanged});

  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String tip, VoidCallback? f) => SizedBox(
          width: 36,
          height: 36,
          child: IconButton(tooltip: tip, padding: EdgeInsets.zero, iconSize: 18, onPressed: f, icon: Icon(icon)),
        );
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.borderStrong), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(Icons.remove_rounded, 'Kurangi jumlah', qty > 1 ? () => onChanged(qty - 1) : null),
        SizedBox(width: 28, child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
        btn(Icons.add_rounded, 'Tambah jumlah', () => onChanged(qty + 1)),
      ]),
    );
  }
}

class _NominalRow extends StatelessWidget {
  const _NominalRow({required this.label, required this.controller, required this.onChanged, this.error});

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Padding(padding: const EdgeInsets.only(top: 10), child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))),
      SizedBox(width: 150, child: NominalField(controller: controller, dense: true, errorText: error, onChanged: (_) => onChanged())),
    ]);
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.nominal, {this.besar = false});

  final String label;
  final int nominal;
  final bool besar;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: besar ? 17 : 13, fontWeight: besar ? FontWeight.w800 : FontWeight.w500, color: besar ? AppColors.ink : AppColors.muted);
    return Row(children: [Expanded(child: Text(label, style: style)), Text(rupiah(nominal), style: style)]);
  }
}

class _BagianCard extends StatelessWidget {
  const _BagianCard({required this.peserta, required this.nominal, required this.total});

  final List<_PesertaDraft> peserta;
  final List<int> nominal;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SakuCard(
      child: Column(children: [
        for (final (i, p) in peserta.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(child: Text(p.saya ? '${p.nama} (bagianmu)' : p.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
              Text(rupiah(i < nominal.length ? nominal[i] : 0), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          ),
        const Divider(height: 18, color: AppColors.divider),
        _TotalRow('Total', total, besar: true),
      ]),
    );
  }
}

/// Text field + autocomplete from `/split/nama` + "Tambah".
class _TambahPeserta extends StatefulWidget {
  const _TambahPeserta({required this.saran, required this.onTambah});

  final List<String> saran;
  final ValueChanged<String> onTambah;

  @override
  State<_TambahPeserta> createState() => _TambahPesertaState();
}

class _TambahPesertaState extends State<_TambahPeserta> {
  TextEditingController? _ctrl;
  FocusNode? _focus;

  void _submit() {
    final c = _ctrl;
    if (c == null || c.text.trim().isEmpty) return;
    widget.onTambah(c.text);
    c.clear();
    _focus?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Autocomplete<String>(
          optionsBuilder: (v) {
            final q = v.text.trim().toLowerCase();
            if (q.isEmpty) return const [];
            return widget.saran.where((n) => n.toLowerCase().contains(q)).take(6);
          },
          onSelected: (n) {
            widget.onTambah(n);
            _ctrl?.clear();
          },
          fieldViewBuilder: (context, controller, focus, onSubmit) {
            _ctrl = controller;
            _focus = focus;
            return TextField(
              controller: controller,
              focusNode: focus,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(hintText: 'Nama teman'),
            );
          },
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(height: 48, child: OutlineBtn('Tambah', height: 48, onPressed: _submit)),
    ]);
  }
}
