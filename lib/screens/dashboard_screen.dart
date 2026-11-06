import 'package:flutter/material.dart';

import '../api/models.dart';
import '../app.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import '../widgets/saku_rows.dart';
import 'home_shell.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return AsyncView<(Dashboard, List<SplitRingkas>)>(
      load: () async {
        final api = context.api;
        // Split list is optional on Beranda: never fail the dashboard for it.
        final split = api.split().catchError((_) => <SplitRingkas>[]);
        return (await api.dashboard(), await split);
      },
      builder: (context, data, _) {
        final (d, splits) = data;
        final belum = splits.where((s) => s.belumLunas.jumlah > 0).toList();
        final nav = Navigator.of(context);
        final r = d.ringkasan;
        final anggaran = (d.anggaran?.kelompok ?? []).where((k) => k.anggaran != null).take(3).toList();
        return DefaultTextStyle.merge(
          style: const TextStyle(fontFeatures: AppTheme.tabular),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              _Header(adaPengingat: d.pengingat.isNotEmpty, onBell: () => nav.pushNamed(Routes.subscriptions), onAvatar: () => nav.pushNamed(Routes.settings)),
              const SizedBox(height: 20),
              if (r == null)
                EmptyState(
                  icon: Icons.event_available_rounded,
                  title: 'Belum ada periode',
                  message: 'Mulai periode pertama dan isi saldo awal tiap akun (gaji masuk di sini).',
                  action: 'Mulai periode pertama',
                  onAction: () => nav.pushNamed(Routes.closePeriod),
                )
              else ...[
                _BalanceHero(r: r, onCloseBook: () => nav.pushNamed(Routes.closePeriod)),
                const SizedBox(height: 16),
                _Shortcuts(actions: [
                  (Icons.call_split_rounded, 'Split Bill', () => nav.pushNamed(Routes.split)),
                  (Icons.qr_code_2_rounded, 'Terima QRIS', () => nav.pushNamed(Routes.terimaQris)),
                  (Icons.donut_large_rounded, 'Statistik', () => nav.pushNamed(Routes.statistics)),
                  (Icons.event_repeat_rounded, 'Langganan', () => nav.pushNamed(Routes.subscriptions)),
                ]),
              ],
              if (belum.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SplitBelumCard(
                  orang: belum.fold<int>(0, (n, s) => n + s.belumLunas.jumlah),
                  nominal: belum.fold<int>(0, (n, s) => n + s.belumLunas.nominal),
                  onTap: () => nav.pushNamed(Routes.split),
                ),
              ],
              if (d.pengingat.isNotEmpty) ...[
                const SizedBox(height: 24),
                SectionHeader('Pengingat langganan', action: 'Semua', onAction: () => nav.pushNamed(Routes.subscriptions)),
                SakuCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DividedColumn(children: [
                    for (final p in d.pengingat.take(3)) _ReminderRow(p: p, onPay: () => nav.pushNamed(Routes.subscriptions)),
                  ]),
                ),
              ],
              if (r != null) ...[
                const SizedBox(height: 24),
                SectionHeader('Akun', action: 'Atur', onAction: () => nav.pushNamed(Routes.settings)),
                _AccountGrid(akun: r.perAkun),
              ],
              const SizedBox(height: 10),
              _TabunganCard(total: d.totalTabungan, onTap: () => onSelectTab(HomeTab.tabungan)),
              if (anggaran.isNotEmpty) ...[
                const SizedBox(height: 24),
                SectionHeader('Anggaran', action: 'Detail', onAction: () => onSelectTab(HomeTab.anggaran)),
                SakuCard(
                  child: Column(children: [
                    for (final (i, k) in anggaran.indexed) ...[
                      if (i > 0) const SizedBox(height: 14),
                      _BudgetLine(k: k),
                    ],
                  ]),
                ),
              ],
              if (r != null) ...[
                const SizedBox(height: 24),
                SectionHeader('Pengeluaran terbesar', action: 'Statistik', onAction: () => nav.pushNamed(Routes.statistics)),
                _TopSpending(r: r, onTap: () => nav.pushNamed(Routes.statistics)),
              ],
              const SizedBox(height: 24),
              SectionHeader('Transaksi terakhir', action: 'Lihat semua', onAction: () => onSelectTab(HomeTab.riwayat)),
              if (d.transaksiTerakhir.isEmpty)
                const SakuCard(child: Text('Belum ada transaksi.', style: TextStyle(color: AppColors.muted)))
              else
                SakuCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DividedColumn(children: [for (final t in d.transaksiTerakhir) TransaksiRow(tx: t, showDate: true)]),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.adaPengingat, required this.onBell, required this.onAvatar});

  final bool adaPengingat;
  final VoidCallback onBell;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(salam(), style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 2),
              Text(user?.nama ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        Tooltip(
          message: adaPengingat ? 'Pengingat langganan, ada yang baru' : 'Langganan',
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
            child: InkWell(
              onTap: onBell,
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.notifications_none_rounded, size: 22, color: AppColors.ink),
                    if (adaPengingat)
                      Positioned(
                        top: 9,
                        right: 10,
                        child: Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.out, borderRadius: BorderRadius.circular(4))),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Pengaturan',
          child: Material(
            color: AppColors.deep,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onAvatar,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(child: Text(user?.inisial ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.r, required this.onCloseBook});

  final Ringkasan r;
  final VoidCallback onCloseBook;

  @override
  Widget build(BuildContext context) {
    // Money available this period = opening balances + income.
    final dana = r.totalSaldoAwal + r.totalMasuk;
    final persen = dana > 0 ? (r.totalPengeluaran * 100 / dana).round() : 0;
    Widget stat(String label, String value, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Single line, shrinks instead of wrapping so all three cards stay aligned.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(label, maxLines: 1, softWrap: false, style: const TextStyle(fontSize: 11, color: AppColors.mintText)),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                ),
              ],
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.deep, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    '${r.periode.nama} · sejak ${tglPendek(r.periode.tanggalMulai)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextLink('Tutup buku', onTap: onCloseBook, fontSize: 12, color: AppColors.mint),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Total saldo semua akun', style: TextStyle(fontSize: 13, color: AppColors.mintText)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(rupiah(r.totalSaldoAkhir), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: Colors.white)),
          ),
          if (dana > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (r.totalPengeluaran / dana).clamp(0, 1),
                minHeight: 6,
                color: persen >= 90 ? AppColors.peachBright : AppColors.mintBright,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 6),
            Text('Terpakai $persen% dari dana periode ini', style: const TextStyle(fontSize: 12, color: AppColors.mintText)),
          ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stat('Saldo awal', thousands(r.totalSaldoAwal), Colors.white),
              const SizedBox(width: 8),
              stat('Masuk', signed(r.totalMasuk), AppColors.mintBright),
              const SizedBox(width: 8),
              stat('Pengeluaran', signed(-r.totalPengeluaran), AppColors.peachBright),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountGrid extends StatelessWidget {
  const _AccountGrid({required this.akun});

  final List<RingkasanAkun> akun;

  @override
  Widget build(BuildContext context) {
    if (akun.isEmpty) {
      return const SakuCard(child: Text('Belum ada akun. Pilih akun di Pengaturan.', style: TextStyle(color: AppColors.muted)));
    }
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final a in akun)
            SizedBox(
              width: w,
              child: SakuCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      AkunBadge(a.nama),
                      const SizedBox(width: 8),
                      Text(jenisAkunLabel(a.jenis), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ]),
                    const SizedBox(height: 12),
                    Text(a.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        rupiah(a.saldoAkhir),
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: a.saldoAkhir < 0 ? AppColors.out : AppColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// Status label/colours for a reminder.
(String, Color, Color, IconData) pengingatGaya(Pengingat p) => switch (p.status) {
      'terlambat' => ('Terlambat ${-p.sisaHari} hari · ${tglPendek(p.jatuhTempo)}', AppColors.out, AppColors.outBg, Icons.warning_amber_rounded),
      'hari_ini' => ('Jatuh tempo hari ini', AppColors.warnStrong, AppColors.warnBg, Icons.calendar_today_outlined),
      _ => ('${p.sisaHari} hari lagi · ${tglPendek(p.jatuhTempo)}', AppColors.muted, AppColors.track, Icons.repeat_rounded),
    };

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.p, required this.onPay});

  final Pengingat p;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final (note, fg, bg, icon) = pengingatGaya(p);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          IconTile(icon: icon, bg: bg, fg: p.status == 'akan_datang' ? AppColors.inkSoft : fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.berulang.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(note, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(rupiah(p.berulang.nominal), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              TextLink('Bayar', onTap: onPay, fontSize: 12),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetLine extends StatelessWidget {
  const _BudgetLine({required this.k});

  final PosAnggaran k;

  @override
  Widget build(BuildContext context) {
    final over = k.status == StatusAnggaran.lewat;
    final limit = k.anggaran ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(k.nama, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
            Text(
              over ? 'Lewat ${rupiah(k.terpakai - limit)}' : '${k.persen ?? 0}%',
              style: TextStyle(fontSize: 13, fontWeight: over ? FontWeight.w700 : FontWeight.w600, color: over ? AppColors.out : AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ProgressBar(value: limit == 0 ? 0 : k.terpakai / limit, color: k.status == null ? AppColors.primary : budgetColor(k.status!)),
        const SizedBox(height: 4),
        Text('${rupiah(k.terpakai)} dari ${rupiah(limit)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}

/// Top 3 kelompok by spending, as a share of the period's spending.
class _TopSpending extends StatelessWidget {
  const _TopSpending({required this.r, required this.onTap});

  final Ringkasan r;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final top = r.pengeluaranPerKelompok.where((k) => k.total > 0).take(3).toList();
    final total = r.totalPengeluaran;
    if (top.isEmpty || total <= 0) {
      return SakuCard(
        onTap: onTap,
        child: const Row(children: [
          IconTile(icon: Icons.insights_rounded, bg: AppColors.background, fg: AppColors.primary),
          SizedBox(width: 12),
          Expanded(child: Text('Belum ada pengeluaran di periode ini.', style: TextStyle(color: AppColors.muted))),
        ]),
      );
    }
    return SakuCard(
      onTap: onTap,
      child: Column(children: [
        for (final (i, k) in top.indexed) ...[
          if (i > 0) const SizedBox(height: 14),
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.chart[i], borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Expanded(child: Text(k.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            Text('${(k.total * 100 / total).round()}%', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(width: 10),
            Text(rupiah(k.total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          ProgressBar(value: k.total / total, color: AppColors.chart[i]),
        ],
      ]),
    );
  }
}

/// Quick actions: icon tiles in one row, label under each.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.actions});

  final List<(IconData, String, VoidCallback)> actions;

  @override
  Widget build(BuildContext context) {
    return SakuCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      child: Row(children: [
        for (final (icon, label, onTap) in actions)
          Expanded(
            child: Semantics(
              button: true,
              label: label,
              excludeSemantics: true,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(children: [
                    IconTile(icon: icon, bg: AppColors.inBg, fg: AppColors.primary, size: 46, radius: 14),
                    const SizedBox(height: 8),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Warning banner: friends who still owe from split bills.
class _SplitBelumCard extends StatelessWidget {
  const _SplitBelumCard({required this.orang, required this.nominal, required this.onTap});

  final int orang;
  final int nominal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warnBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.warn.withValues(alpha: 0.3))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(children: [
            const IconTile(icon: Icons.receipt_long_rounded, bg: AppColors.surface, fg: AppColors.warnStrong),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Split bill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warnStrong)),
                const SizedBox(height: 1),
                Text('$orang orang belum bayar · ${rupiah(nominal)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.warnText)),
              ]),
            ),
            const Text('Tagih', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.warnStrong)),
            const Icon(Icons.chevron_right_rounded, color: AppColors.warnStrong),
          ]),
        ),
      ),
    );
  }
}

class _TabunganCard extends StatelessWidget {
  const _TabunganCard({required this.total, required this.onTap});

  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SakuCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(children: [
        const IconTile(icon: Icons.savings_outlined, bg: AppColors.inBg, fg: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Total tabungan', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(rupiah(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.dashed),
      ]),
    );
  }
}
