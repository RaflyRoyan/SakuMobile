import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../app.dart';
import '../split/kartu_tagihan.dart';
import '../split/qris.dart';
import '../split/qris_store.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import '../widgets/kategori_picker.dart';

/// Terima QRIS: nominal → QRIS bernominal tampil besar untuk di-scan.
class TerimaQrisScreen extends StatefulWidget {
  const TerimaQrisScreen({super.key});

  @override
  State<TerimaQrisScreen> createState() => _TerimaQrisScreenState();
}

class _TerimaQrisScreenState extends State<TerimaQrisScreen> {
  final _nominal = TextEditingController();
  final _ket = TextEditingController();
  QrisTersimpan? _qris;
  bool _loading = true;

  /// Shown QR (null = form).
  ({int nominal, String ket, String payload})? _aktif;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _nominal.dispose();
    _ket.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = context.services.prefs;
    // Cached copy first so the screen works offline; refresh in background.
    setState(() {
      _qris = qrisDariCache(prefs);
      _loading = _qris == null;
    });
    final q = await muatQris(context.api, prefs);
    if (mounted) {
      setState(() {
        _qris = q ?? _qris;
        _loading = false;
      });
    }
  }

  void _buat() {
    final n = parseNominal(_nominal.text) ?? 0;
    final q = _qris;
    if (n <= 0 || q == null) {
      showToast(context, 'Isi nominal dulu.', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _aktif = (nominal: n, ket: _ket.text.trim(), payload: qrisDinamis(q.payload, n)));
  }

  void _baru() => setState(() {
        _aktif = null;
        _nominal.clear();
        _ket.clear();
      });

  Future<void> _bagikan() async {
    final a = _aktif!;
    await bagikanKartu(
      context,
      kartu: KartuQris(nominal: a.nominal, keterangan: a.ket, qris: _qris!),
      namaFile: 'qris-${a.nominal}.png',
      teks: 'Pembayaran ${a.ket.isEmpty ? 'QRIS' : a.ket}: ${rupiah(a.nominal)}. Bayar lewat QRIS di gambar ya.',
    );
  }

  Future<void> _sudahDibayar() async {
    final a = _aktif!;
    final ok = await showSakuSheet<bool>(context, builder: (_) => _CatatSheet(nominal: a.nominal, keterangan: a.ket));
    if (ok == true && mounted) _baru();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const SubPageHeader(title: 'Terima QRIS'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _qris == null
                    ? _BelumAda(onAtur: _aturQris)
                    : DefaultTextStyle.merge(
                        style: const TextStyle(fontFeatures: AppTheme.tabular),
                        child: _aktif == null ? _form() : _tampilQr(_aktif!),
                      ),
          ),
        ]),
      ),
    );
  }

  Future<void> _aturQris() async {
    await Navigator.of(context).pushNamed(Routes.qrisSettings);
    if (mounted) _load();
  }

  Widget _form() {
    final q = _qris!;
    final nominal = parseNominal(_nominal.text) ?? 0;
    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _MerchantStrip(qris: q, onGanti: _aturQris),
            const SizedBox(height: 16),
            SakuCard(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Nominal yang diterima', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted)),
                const SizedBox(height: 4),
                TextField(
                  controller: _nominal,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsFormatter()],
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.ink),
                  cursorColor: AppColors.primary,
                  decoration: const InputDecoration(
                    prefixText: 'Rp ',
                    prefixStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.muted),
                    hintText: '0',
                    hintStyle: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.borderStrong),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: UnderlineInputBorder(),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border, width: 1.5)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
                    filled: false,
                  ),
                  onSubmitted: (_) => _buat(),
                ),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final v in const [10000, 20000, 50000, 100000])
                    _Cepat(
                      label: '${v ~/ 1000}rb',
                      on: nominal == v,
                      onTap: () => setState(() {
                        _nominal.text = thousands(v);
                        _nominal.selection = TextSelection.collapsed(offset: _nominal.text.length);
                      }),
                    ),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Keterangan (opsional)',
              child: TextField(
                controller: _ket,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Mis. Kue pesanan Bu Rina', counterText: ''),
              ),
            ),
            const SizedBox(height: 16),
            const InfoNote(
              icon: Icons.qr_code_scanner_rounded,
              bg: AppColors.inBg,
              fg: AppColors.primaryDark,
              child: Text('Pembeli tinggal scan, nominal sudah terisi. Bisa dibayar pakai e-wallet atau m-banking apa saja.'),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
        child: PrimaryButton('Buat QRIS', onPressed: _buat),
      ),
    ]);
  }

  Widget _tampilQr(({int nominal, String ket, String payload}) a) {
    final q = _qris!;
    return LayoutBuilder(builder: (context, c) {
      // Screen padding 20×2, card padding 16×2, QrisBox quiet zone 14×2.
      final size = (c.maxWidth - 40 - 32 - 28).clamp(200.0, 320.0);
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
            decoration: BoxDecoration(color: AppColors.deep, borderRadius: BorderRadius.circular(24)),
            child: Column(children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                  child: const Text('QRIS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.deep)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(q.merchant.isEmpty ? 'Merchant' : q.merchant,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    if (q.kota.isNotEmpty)
                      Text(q.kota, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.mintText)),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: QrisBox(data: a.payload, size: size),
              ),
              const SizedBox(height: 16),
              const Text('Bayar sebesar', style: TextStyle(fontSize: 12, color: AppColors.mintText)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(rupiah(a.nominal), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: Colors.white)),
              ),
              if (a.ket.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(a.ket, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.mintText)),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bolt_rounded, size: 14, color: AppColors.mintBright),
                  SizedBox(width: 4),
                  Flexible(child: Text('Nominal terisi otomatis saat di-scan', style: TextStyle(fontSize: 12, color: Colors.white))),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          PrimaryButton('Sudah dibayar', onPressed: _sudahDibayar),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _AksiBtn(icon: Icons.ios_share_rounded, label: 'Bagikan', onPressed: _bagikan)),
            const SizedBox(width: 10),
            Expanded(child: _AksiBtn(icon: Icons.refresh_rounded, label: 'Buat baru', onPressed: _baru)),
          ]),
          const SizedBox(height: 14),
          const Text(
            'Cek dulu notifikasi pembayaran di aplikasi merchant sebelum menekan "Sudah dibayar".',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      );
    });
  }
}

/// Merchant QRIS yang dipakai, dengan pintasan ke pengaturan.
class _MerchantStrip extends StatelessWidget {
  const _MerchantStrip({required this.qris, required this.onGanti});

  final QrisTersimpan qris;
  final VoidCallback onGanti;

  @override
  Widget build(BuildContext context) {
    return SakuCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(children: [
        const IconTile(icon: Icons.storefront_rounded, bg: AppColors.inBg, fg: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Diterima ke QRIS', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            Text(
              [qris.merchant.isEmpty ? 'Merchant' : qris.merchant, if (qris.kota.isNotEmpty) qris.kota].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ]),
        ),
        TextButton(
          onPressed: onGanti,
          style: TextButton.styleFrom(foregroundColor: AppColors.primary, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
          child: const Text('Ganti'),
        ),
      ]),
    );
  }
}

/// Quick-amount chip.
class _Cepat extends StatelessWidget {
  const _Cepat({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: on ? AppColors.primary : AppColors.background,
      shape: StadiumBorder(side: BorderSide(color: on ? AppColors.primary : AppColors.border)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? Colors.white : AppColors.inkSoft)),
        ),
      ),
    );
  }
}

class _AksiBtn extends StatelessWidget {
  const _AksiBtn({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _BelumAda extends StatelessWidget {
  const _BelumAda({required this.onAtur});

  final VoidCallback onAtur;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      EmptyState(
        icon: Icons.qr_code_2_rounded,
        title: 'QRIS belum diatur',
        message: 'Upload gambar QRIS merchant-mu dulu, lalu buat QRIS bernominal di sini.',
        action: 'Atur QRIS',
        onAction: onAtur,
      ),
    ]);
  }
}

/// "Sudah dibayar": catat transaksi masuk (akun, kategori, tanggal).
class _CatatSheet extends StatefulWidget {
  const _CatatSheet({required this.nominal, required this.keterangan});

  final int nominal;
  final String keterangan;

  @override
  State<_CatatSheet> createState() => _CatatSheetState();
}

class _CatatSheetState extends State<_CatatSheet> {
  List<Akun>? _akun;
  List<Kategori> _kategori = [];
  List<KelompokKategori> _kelompok = [];
  Object? _loadError;
  String? _akunId;
  String? _kategoriId;
  DateTime _tanggal = todayWib();
  bool _busy = false;
  Map<String, List<String>> _errors = {};
  String? _pesan;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = context.api;
    final prefs = context.services.prefs;
    setState(() => _loadError = null);
    try {
      final r = await Future.wait([api.akun(), api.kategori(), api.kelompokKategori()]);
      if (!mounted) return;
      final akun = (r[0] as List<Akun>).where((a) => a.aktif).toList();
      final kategori = (r[1] as List<Kategori>).where((k) => k.tipe == 'masuk' && k.aktif && k.kodeSistem == null).toList();
      final terakhir = prefs.kategoriQrisTerakhir;
      setState(() {
        _akun = akun;
        _kategori = kategori;
        _kelompok = r[2] as List<KelompokKategori>;
        _akunId = (akun.where((a) => RegExp('gopay', caseSensitive: false).hasMatch(a.nama)).firstOrNull ?? akun.firstOrNull)?.id;
        _kategoriId = kategori.any((k) => k.id == terakhir) ? terakhir : null;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<void> _simpan() async {
    if (_akunId == null || _kategoriId == null) {
      setState(() => _pesan = 'Pilih akun dan kategori.');
      return;
    }
    setState(() {
      _busy = true;
      _errors = {};
      _pesan = null;
    });
    final nav = Navigator.of(context);
    final prefs = context.services.prefs;
    try {
      final t = await context.api.buatTransaksi(TransaksiInput(
        tipe: TipeTransaksi.masuk,
        tanggal: ymd(_tanggal),
        akunId: _akunId!,
        kategoriId: _kategoriId,
        nominal: widget.nominal,
        deskripsi: widget.keterangan.isEmpty ? 'Pembayaran QRIS' : widget.keterangan,
      ));
      await prefs.setKategoriQrisTerakhir(_kategoriId);
      if (!mounted) return;
      context.session.dataChanged();
      final messenger = ScaffoldMessenger.of(context);
      await showPeringatan(context, t.peringatan);
      nav.pop(true);
      messenger.showSnackBar(const SnackBar(content: Text('Pemasukan tercatat.'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.deep));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errors = e.errors;
          _pesan = e.errors.isEmpty ? e.title : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _pesan = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final akun = _akun;
    if (_loadError != null) {
      return SizedBox(height: 260, child: ErrorState(message: errorMessage(_loadError!), onRetry: _load));
    }
    if (akun == null) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Catat ${rupiah(widget.nominal)} masuk', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      SakuCard(
        padding: EdgeInsets.zero,
        child: DividedColumn(children: [
          SelectRow(
            label: 'Masuk ke',
            value: akun.where((a) => a.id == _akunId).firstOrNull?.nama,
            error: _errors['akunId']?.first,
            onTap: () async {
              final v = await pickOne<String>(context, title: 'Akun', selected: _akunId, options: [for (final a in akun) PickOption(a.id, a.nama)]);
              if (v != null) setState(() => _akunId = v);
            },
          ),
          SelectRow(
            label: 'Tanggal',
            value: tglPanjang(_tanggal),
            error: _errors['tanggal']?.first,
            onTap: () async {
              final d = await pickDate(context, _tanggal, last: todayWib());
              if (d != null) setState(() => _tanggal = d);
            },
          ),
        ]),
      ),
      const SizedBox(height: 14),
      KategoriBertingkat(
        kategori: _kategori,
        kelompok: _kelompok,
        value: _kategoriId,
        bertingkat: false,
        error: _errors['kategoriId']?.first,
        onChanged: (v) => setState(() => _kategoriId = v),
      ),
      if (_pesan != null) ...[
        const SizedBox(height: 12),
        InfoNote(icon: Icons.error_outline_rounded, bg: AppColors.outBg, fg: AppColors.outText, child: Text(_pesan!)),
      ],
      const SizedBox(height: 18),
      BusyButton(label: 'Simpan', busy: _busy, onPressed: _simpan),
    ]);
  }
}
