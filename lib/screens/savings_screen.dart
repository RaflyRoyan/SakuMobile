import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  void _openWithdraw(BuildContext context) {
    final from = MockData.savings.first;
    showSakuSheet<void>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Tarik tabungan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              IconButton(
                tooltip: 'Tutup',
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SheetField(
            label: 'Dari tabungan akun',
            child: Row(
              children: [
                Text(from.name, style: const TextStyle(fontSize: 15)),
                const Spacer(),
                Text('tersedia ${rupiah(from.balance)}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SheetField(label: 'Nominal', child: Text('Rp 500.000', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
          const SizedBox(height: 16),
          const _SheetField(label: 'Keterangan', child: Text('Servis motor', style: TextStyle(fontSize: 15))),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Uang akan masuk ke saldo ${from.name} periode aktif sebagai pemasukan '),
              const TextSpan(text: 'Tarik Tabungan', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
              const TextSpan(text: '.'),
            ]),
            style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          PrimaryButton('Tarik Rp 500.000', height: 52, onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFeatures: AppTheme.tabular),
      child: ListView(
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
                Text(
                  rupiah(MockData.savingsTotal),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: Colors.white),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Terisi otomatis dari sisa saldo tiap akun saat tutup buku.',
                  style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.mintText),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: () => _openWithdraw(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.mint,
                      foregroundColor: AppColors.deep,
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
          SakuCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DividedColumn(children: [
              for (final a in MockData.savings)
                _Line(
                  title: a.name,
                  subtitle: 'Setor ${thousands(a.deposit)} · Tarik ${thousands(a.withdraw)}',
                  trailing: Text(rupiah(a.balance), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
          const SizedBox(height: 20),
          const SectionHeader('Riwayat'),
          SakuCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DividedColumn(children: [
              for (final a in MockData.savings)
                _Line(
                  leading: const IconTile(text: 'IN', bg: AppColors.inBg, fg: AppColors.primary, size: 36, radius: 10),
                  title: 'Sisa ${MockData.savingsSourcePeriod}',
                  subtitle: '${a.name} · Setor · ${MockData.savingsDate}',
                  trailing: Text(signed(a.deposit), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
            ]),
          ),
        ],
      ),
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
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: child,
        ),
      ],
    );
  }
}
