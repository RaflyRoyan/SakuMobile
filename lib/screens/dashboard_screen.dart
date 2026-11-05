import 'package:flutter/material.dart';

import '../app.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final nav = Navigator.of(context);
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFeatures: AppTheme.tabular),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          _Header(onBell: () => nav.pushNamed(Routes.subscriptions), onAvatar: () => nav.pushNamed(Routes.settings)),
          const SizedBox(height: 20),
          _BalanceHero(onCloseBook: () => nav.pushNamed(Routes.closePeriod)),
          const SizedBox(height: 20),
          SectionHeader('Akun', action: 'Atur', onAction: () => nav.pushNamed(Routes.settings)),
          const _AccountGrid(),
          const SizedBox(height: 20),
          SectionHeader('Pengingat langganan', action: 'Semua', onAction: () => nav.pushNamed(Routes.subscriptions)),
          _Reminders(onPay: () => nav.pushNamed(Routes.subscriptions)),
          const SizedBox(height: 20),
          SectionHeader('Anggaran', action: 'Detail', onAction: () => onSelectTab(HomeTab.anggaran)),
          const _BudgetSummary(),
          const SizedBox(height: 20),
          SakuCard(
            onTap: () => onSelectTab(HomeTab.tabungan),
            child: Row(
              children: [
                const IconTile(icon: Icons.savings_outlined, bg: AppColors.inBg, fg: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total tabungan', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      const SizedBox(height: 2),
                      Text(rupiah(MockData.savingsTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader('Transaksi terakhir', action: 'Lihat semua', onAction: () => onSelectTab(HomeTab.riwayat)),
          const _RecentTransactions(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBell, required this.onAvatar});

  final VoidCallback onBell;
  final VoidCallback onAvatar;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi,';
    if (h < 15) return 'Selamat siang,';
    if (h < 19) return 'Selamat sore,';
    return 'Selamat malam,';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting(), style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 2),
              const Text(MockData.userName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        Tooltip(
          message: 'Pengingat langganan, 3 baru',
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
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
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Text(MockData.userInitials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.onCloseBook});

  final VoidCallback onCloseBook;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.mintText)),
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
                  child: const Text(
                    '${MockData.periodName} · sejak ${MockData.periodSince}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              const Spacer(),
              TextLink('Tutup buku', onTap: onCloseBook, fontSize: 12, color: AppColors.mint),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Total saldo semua akun', style: TextStyle(fontSize: 13, color: AppColors.mintText)),
          const SizedBox(height: 4),
          Text(
            rupiah(MockData.totalBalance),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              stat('Saldo awal', thousands(MockData.openingBalance), Colors.white),
              const SizedBox(width: 8),
              stat('Masuk', signed(MockData.income), AppColors.mintBright),
              const SizedBox(width: 8),
              stat('Pengeluaran', signed(-MockData.expense), AppColors.peachBright),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountGrid extends StatelessWidget {
  const _AccountGrid();

  @override
  Widget build(BuildContext context) {
    const accounts = MockData.accounts;
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final a in accounts)
            SizedBox(
              width: w,
              child: SakuCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconTile(text: a.code, bg: a.badgeBg, fg: a.badgeFg, size: 28, radius: 8),
                        const SizedBox(width: 8),
                        Text(a.kind, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(a.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(rupiah(a.balance), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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

class _Reminders extends StatelessWidget {
  const _Reminders({required this.onPay});

  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    Widget row({
      required IconData icon,
      required Color bg,
      required Color fg,
      required String name,
      required String note,
      required Color noteColor,
      required int amount,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            IconTile(icon: icon, bg: bg, fg: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(note, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: noteColor)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(rupiah(amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                TextLink('Bayar', onTap: onPay, fontSize: 12),
              ],
            ),
          ],
        ),
      );
    }

    return SakuCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DividedColumn(children: [
        row(icon: Icons.warning_amber_rounded, bg: AppColors.outBg, fg: AppColors.out, name: 'Gym Fit+', note: 'Terlambat 4 hari · 1 Nov', noteColor: AppColors.out, amount: 250000),
        row(icon: Icons.calendar_today_outlined, bg: AppColors.warnBg, fg: AppColors.warnStrong, name: 'Internet IndiHome', note: 'Jatuh tempo hari ini', noteColor: AppColors.warnStrong, amount: 450000),
        row(icon: Icons.repeat_rounded, bg: AppColors.track, fg: AppColors.inkSoft, name: 'Spotify Premium', note: '3 hari lagi · 8 Nov', noteColor: AppColors.muted, amount: 54990),
      ]),
    );
  }
}

class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary();

  @override
  Widget build(BuildContext context) {
    final groups = MockData.budgets.where((g) => g.limit != null).take(3);
    return SakuCard(
      child: Column(
        children: [
          for (final (i, g) in groups.indexed) ...[
            if (i > 0) const SizedBox(height: 14),
            _BudgetLine(group: g),
          ],
        ],
      ),
    );
  }
}

class _BudgetLine extends StatelessWidget {
  const _BudgetLine({required this.group});

  final BudgetGroup group;

  @override
  Widget build(BuildContext context) {
    final over = group.status == BudgetStatus.lewat;
    final limit = group.limit!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(group.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
            Text(
              over ? 'Lewat ${rupiah(group.used - limit)}' : '${group.percent}%',
              style: TextStyle(fontSize: 13, fontWeight: over ? FontWeight.w700 : FontWeight.w600, color: over ? AppColors.out : AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ProgressBar(value: group.percent / 100, color: over ? AppColors.out : AppColors.primary),
        const SizedBox(height: 4),
        Text('${rupiah(group.used)} dari ${rupiah(limit)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions();

  @override
  Widget build(BuildContext context) {
    final txs = MockData.transactions.take(5).toList();
    return SakuCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DividedColumn(children: [
        for (final (i, t) in txs.indexed)
          TransactionRow(tx: t, subtitle: '${t.subtitle.split(' · ').take(2).join(' · ')} · ${MockData.recentDates[i]}'),
      ]),
    );
  }
}

/// Shared transaction list row (dashboard + history).
class TransactionRow extends StatelessWidget {
  const TransactionRow({super.key, required this.tx, this.subtitle, this.onTap});

  final Transaction tx;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final amount = switch (tx.type) {
      TxType.keluar => signed(-tx.amount),
      TxType.masuk => signed(tx.amount),
      TxType.transfer => thousands(tx.amount),
    };
    return InkWell(
      onTap: onTap ?? () => Navigator.of(context).pushNamed(Routes.editTransaction),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            IconTile.forTx(tx.type, tx.initials),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle ?? tx.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(amount, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: txColor(tx.type))),
                if (tx.fee != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('admin ${thousands(tx.fee!)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
