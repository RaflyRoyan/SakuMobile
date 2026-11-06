import 'package:flutter/material.dart';

import '../api/models.dart';
import '../app.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';

/// Daftar split bill: ringkasan piutang, lalu yang belum lunas dulu.
class SplitListScreen extends StatelessWidget {
  const SplitListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = Navigator.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SubPageHeader(
              title: 'Split Bill',
              trailing: IconButton(
                tooltip: 'Terima QRIS',
                icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
                onPressed: () => nav.pushNamed(Routes.terimaQris),
              ),
            ),
            Expanded(
              child: AsyncView<List<SplitRingkas>>(
                load: () => context.api.split(),
                builder: (context, list, _) {
                  final belum = [for (final s in list) if (s.belumLunas.jumlah > 0) s];
                  final lunas = [for (final s in list) if (s.belumLunas.jumlah == 0) s];
                  void open(SplitRingkas s) => nav.pushNamed(Routes.splitDetail, arguments: s.id);
                  return DefaultTextStyle.merge(
                    style: const TextStyle(fontFeatures: AppTheme.tabular),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      children: [
                        if (list.isEmpty)
                          EmptyState(
                            icon: Icons.call_split_rounded,
                            title: 'Belum ada split bill',
                            message: 'Talangi satu struk, bagi per item, lalu tagih teman pakai QRIS bernominal.',
                            action: 'Split baru',
                            onAction: () => nav.pushNamed(Routes.splitBaru),
                          )
                        else ...[
                          _Ringkasan(list: list),
                          if (belum.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            const OverlineLabel('Menunggu pembayaran'),
                            for (final s in belum) ...[
                              _SplitCard(s: s, onTap: () => open(s)),
                              const SizedBox(height: 10),
                            ],
                          ],
                          if (lunas.isNotEmpty) ...[
                            SizedBox(height: belum.isEmpty ? 22 : 12),
                            const OverlineLabel('Sudah lunas'),
                            for (final s in lunas) ...[
                              _SplitCard(s: s, onTap: () => open(s)),
                              const SizedBox(height: 10),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => nav.pushNamed(Routes.splitBaru),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Split baru', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Dark hero: total yang masih ditunggu dari teman.
class _Ringkasan extends StatelessWidget {
  const _Ringkasan({required this.list});

  final List<SplitRingkas> list;

  @override
  Widget build(BuildContext context) {
    final piutang = list.fold<int>(0, (a, s) => a + s.belumLunas.nominal);
    final orang = list.fold<int>(0, (a, s) => a + s.belumLunas.jumlah);
    final ditalangi = list.fold<int>(0, (a, s) => a + s.total);
    final aktif = list.where((s) => s.belumLunas.jumlah > 0).length;

    Widget stat(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.mintText)),
              const SizedBox(height: 4),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.deep, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Belum kembali ke kamu', style: TextStyle(fontSize: 13, color: AppColors.mintText)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            rupiah(piutang),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: piutang > 0 ? Colors.white : AppColors.mintBright,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          piutang > 0 ? '$orang orang di $aktif split' : 'Semua teman sudah bayar',
          style: const TextStyle(fontSize: 13, color: AppColors.mintText),
        ),
        const SizedBox(height: 16),
        Row(children: [
          stat('Total ditalangi', thousands(ditalangi)),
          const SizedBox(width: 8),
          stat('Split', '${list.length}'),
        ]),
      ]),
    );
  }
}

class _SplitCard extends StatelessWidget {
  const _SplitCard({required this.s, required this.onTap});

  final SplitRingkas s;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = s.belumLunas;
    final teman = (s.jumlahPeserta - 1).clamp(0, 999);
    final sudah = (teman - b.jumlah).clamp(0, teman);
    final lunas = b.jumlah == 0;
    final tgl = tglPendek(s.tanggal).split(' ');

    return SakuCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(children: [
        // Date tile: "12 / Nov".
        Container(
          width: 46,
          height: 50,
          decoration: BoxDecoration(
            color: lunas ? AppColors.inBg : AppColors.warnBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(tgl.first,
                style: TextStyle(fontSize: 17, height: 1.1, fontWeight: FontWeight.w800, color: lunas ? AppColors.primary : AppColors.warnStrong)),
            if (tgl.length > 1)
              Text(tgl[1], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: lunas ? AppColors.primary : AppColors.warnStrong)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(s.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text(rupiah(s.total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
            ]),
            const SizedBox(height: 3),
            Text(
              lunas ? '${s.jumlahPeserta} orang · Lunas semua' : '${b.jumlah} belum · ${rupiah(b.nominal)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: lunas ? FontWeight.w500 : FontWeight.w700,
                color: lunas ? AppColors.primary : AppColors.warnStrong,
              ),
            ),
            if (teman > 0) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: ProgressBar(value: sudah / teman, color: lunas ? AppColors.primary : AppColors.warn, height: 5)),
                const SizedBox(width: 8),
                Text('$sudah/$teman', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ]),
            ],
          ]),
        ),
        const SizedBox(width: 2),
        const Icon(Icons.chevron_right_rounded, color: AppColors.dashed),
      ]),
    );
  }
}
