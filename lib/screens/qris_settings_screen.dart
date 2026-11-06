import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../split/qris.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';

/// Pengaturan → QRIS untuk tagihan: upload gambar QRIS merchant, simpan ke server.
class QrisSettingsScreen extends StatefulWidget {
  const QrisSettingsScreen({super.key});

  @override
  State<QrisSettingsScreen> createState() => _QrisSettingsScreenState();
}

class _QrisSettingsScreenState extends State<QrisSettingsScreen> {
  QrisTersimpan? _tersimpan;
  bool _loading = true;
  Object? _loadError;

  /// Decoded from a picked image, waiting for "Simpan".
  HasilQris? _baru;
  String? _pesan;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final q = await context.api.qris();
      if (!mounted) return;
      await context.services.prefs.setQrisPayload(q?.payload);
      setState(() => _tersimpan = q);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pilihGambar() async {
    final media = context.services.media;
    setState(() {
      _pesan = null;
      _baru = null;
    });
    final String? path;
    try {
      path = await media.ambilGambar(kamera: false);
    } catch (_) {
      if (mounted) showToast(context, 'Galeri tidak bisa dibuka.', error: true);
      return;
    }
    if (path == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final raw = await media.bacaQr(path);
      if (!mounted) return;
      if (raw == null) {
        setState(() => _pesan = pesanQrTidakTerbaca);
        return;
      }
      final h = parseQris(raw);
      setState(() => h.ok ? _baru = h : _pesan = h.pesan);
    } catch (_) {
      if (mounted) setState(() => _pesan = pesanQrTidakTerbaca);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _simpan(String? payload) async {
    setState(() {
      _busy = true;
      _pesan = null;
    });
    try {
      final q = await context.api.simpanQris(payload);
      if (!mounted) return;
      await context.services.prefs.setQrisPayload(q?.payload);
      setState(() {
        _tersimpan = q;
        _baru = null;
      });
      if (mounted) showToast(context, payload == null ? 'QRIS dihapus.' : 'QRIS tersimpan.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _pesan = e.fieldError('payload') ?? e.title);
    } catch (e) {
      if (mounted) setState(() => _pesan = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _hapus() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Hapus QRIS?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: const Text('Kartu tagihan berikutnya dibuat tanpa QR sampai kamu upload lagi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.out), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) await _simpan(null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const SubPageHeader(title: 'QRIS untuk tagihan'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? ErrorState(message: errorMessage(_loadError!), onRetry: _load)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        children: [
                          const InfoNote(
                            icon: Icons.info_outline_rounded,
                            bg: AppColors.transferBg,
                            fg: AppColors.infoText,
                            child: Text('Pakai QRIS merchant (mis. GoPay Merchant/GoBiz), bukan QR kirim uang pribadi.'),
                          ),
                          const SizedBox(height: 16),
                          if (_tersimpan != null && _baru == null)
                            _MerchantCard(judul: 'QRIS tersimpan', merchant: _tersimpan!.merchant, kota: _tersimpan!.kota)
                          else if (_tersimpan == null && _baru == null)
                            const SakuCard(
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                              child: Column(children: [
                                Icon(Icons.qr_code_2_rounded, size: 40, color: AppColors.dashed),
                                SizedBox(height: 8),
                                Text('Belum ada QRIS', style: TextStyle(fontWeight: FontWeight.w700)),
                                SizedBox(height: 4),
                                Text('Upload gambar QRIS merchant-mu agar kartu tagihan berisi QR bernominal.',
                                    textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.muted)),
                              ]),
                            ),
                          if (_baru != null) _MerchantCard(judul: 'Pratinjau QRIS baru', merchant: _baru!.merchant, kota: _baru!.kota, baru: true),
                          if (_pesan != null) ...[
                            const SizedBox(height: 12),
                            InfoNote(icon: Icons.error_outline_rounded, bg: AppColors.outBg, fg: AppColors.outText, child: Text(_pesan!)),
                          ],
                          const SizedBox(height: 20),
                          if (_baru != null) ...[
                            BusyButton(label: 'Simpan', busy: _busy, onPressed: () => _simpan(_baru!.payload)),
                            const SizedBox(height: 10),
                            OutlineBtn('Batal', height: 48, onPressed: _busy ? null : () => setState(() => _baru = null)),
                          ] else ...[
                            BusyButton(label: _tersimpan == null ? 'Upload QRIS' : 'Ganti QRIS', busy: _busy, onPressed: _pilihGambar),
                            if (_tersimpan != null) ...[
                              const SizedBox(height: 10),
                              OutlineBtn('Hapus QRIS', height: 48, color: AppColors.out, borderColor: AppColors.outBg, onPressed: _busy ? null : _hapus),
                            ],
                          ],
                        ],
                      ),
          ),
        ]),
      ),
    );
  }
}

class _MerchantCard extends StatelessWidget {
  const _MerchantCard({required this.judul, required this.merchant, required this.kota, this.baru = false});

  final String judul;
  final String merchant;
  final String kota;
  final bool baru;

  @override
  Widget build(BuildContext context) {
    return SakuCard(
      child: Row(children: [
        IconTile(icon: Icons.storefront_rounded, bg: baru ? AppColors.warnBg : AppColors.inBg, fg: baru ? AppColors.warnStrong : AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(judul, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            Text(merchant.isEmpty ? '(tanpa nama merchant)' : merchant, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (kota.isNotEmpty) Text(kota, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ]),
        ),
      ]),
    );
  }
}
