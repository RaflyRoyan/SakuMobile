import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart' show TransactionRow;

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  TxType? _type; // null = semua
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = MockData.transactions;
    final list = all.where((t) {
      if (_type != null && t.type != _type) return false;
      if (_query.isNotEmpty && !t.title.toLowerCase().contains(_query.toLowerCase())) return false;
      return true;
    }).toList();

    // Group by day, keeping order.
    final days = <String, List<Transaction>>{};
    for (final t in list) {
      days.putIfAbsent(t.day, () => []).add(t);
    }

    return DefaultTextStyle.merge(
      style: const TextStyle(fontFeatures: AppTheme.tabular),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Row(
            children: [
              const Expanded(child: Text('Riwayat', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
              _PeriodButton(),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Cari deskripsi…',
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            textInputAction: TextInputAction.search,
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Chip(label: 'Semua', on: _type == null, onTap: () => setState(() => _type = null)),
                for (final t in TxType.values) _Chip(label: t.label, on: _type == t, onTap: () => setState(() => _type = t)),
                _Chip(label: 'Akun', on: false, trailing: Icons.expand_more_rounded, onTap: () {}),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('Tidak ada transaksi.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            ),
          for (final e in days.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                e.key.toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5),
              ),
            ),
            SakuCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: DividedColumn(children: [for (final t in e.value) TransactionRow(tx: t)]),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Menampilkan ${list.length} dari ${all.length} transaksi',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: () {},
        iconAlignment: IconAlignment.end,
        icon: const Icon(Icons.expand_more_rounded, size: 18),
        label: const Text(MockData.periodName),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap, this.trailing});

  final String label;
  final bool on;
  final VoidCallback onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final fg = on ? Colors.white : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: on ? AppColors.deep : AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: on ? AppColors.deep : AppColors.borderStrong)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
                if (trailing != null) ...[const SizedBox(width: 4), Icon(trailing, size: 16, color: fg)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
