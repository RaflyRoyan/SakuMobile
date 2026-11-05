import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFeatures: AppTheme.tabular),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Anggaran', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('${MockData.periodName} · sisa hangus saat tutup buku', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ),
              OutlineBtn('Ubah', color: AppColors.primary, borderColor: AppColors.primary, onPressed: () {}),
            ],
          ),
          const SizedBox(height: 16),
          const _Overview(),
          for (final g in MockData.budgets) ...[
            const SizedBox(height: 16),
            _GroupCard(group: g),
          ],
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) {
    final counts = {for (final s in BudgetStatus.values) s: 0};
    for (final g in MockData.budgets) {
      if (g.status != null) counts[g.status!] = counts[g.status!]! + 1;
      for (final s in g.subs) {
        if (s.status != null) counts[s.status!] = counts[s.status!]! + 1;
      }
    }
    Widget legend(BudgetStatus s, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: budgetColor(s), borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 6),
            Text('${counts[s]} $label', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        );

    return SakuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Terpakai', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted))),
              Text('dari ${rupiah(MockData.budgetLimit)}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 10),
          Text(rupiah(MockData.budgetUsed), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 10),
          ProgressBar(value: MockData.budgetUsed / MockData.budgetLimit, color: AppColors.primary, height: 8),
          const SizedBox(height: 10),
          Wrap(spacing: 16, runSpacing: 6, children: [
            legend(BudgetStatus.aman, 'aman'),
            legend(BudgetStatus.hampir, 'hampir'),
            legend(BudgetStatus.lewat, 'lewat'),
          ]),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final BudgetGroup group;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final s = g.status;
    final over = s == BudgetStatus.lewat;
    final String sisa;
    if (g.limit == null) {
      sisa = '';
    } else if (over) {
      sisa = 'Lewat ${rupiah(g.used - g.limit!)}';
    } else {
      sisa = 'Sisa ${rupiah(g.limit! - g.used)}';
    }

    return SakuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(g.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              if (s != null)
                Pill.budget(s, switch (s) { BudgetStatus.aman => 'Aman', BudgetStatus.hampir => 'Hampir', BudgetStatus.lewat => 'Lewat' })
              else
                const Pill('Tanpa batas'),
            ],
          ),
          if (s != null) ...[
            const SizedBox(height: 8),
            ProgressBar(value: g.percent / 100, color: budgetColor(s), height: 8),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: rupiah(g.used), style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(
                      text: g.limit != null ? ' dari ${rupiah(g.limit!)}' : ' terpakai',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ]),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(
                sisa,
                style: TextStyle(fontSize: 13, color: over ? AppColors.out : AppColors.muted, fontWeight: over ? FontWeight.w700 : FontWeight.w600),
              ),
            ],
          ),
          if (g.subs.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 4, top: 8),
              padding: const EdgeInsets.only(left: 14, top: 10),
              decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.border, width: 2))),
              child: Column(
                children: [
                  for (final sub in g.subs)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 26),
                      child: Row(
                        children: [
                          Expanded(child: Text(sub.name, style: const TextStyle(fontSize: 13))),
                          Text(
                            sub.limit != null ? '${rupiah(sub.used)} / ${rupiah(sub.limit!)}' : rupiah(sub.used),
                            style: const TextStyle(fontSize: 13, color: AppColors.muted),
                          ),
                          if (sub.status != null) ...[const SizedBox(width: 8), Pill.budget(sub.status!, sub.percent ?? '')],
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
