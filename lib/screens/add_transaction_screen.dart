import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

class _Draft {
  const _Draft({
    required this.amount,
    required this.accountLabel,
    required this.account,
    required this.accountBalance,
    this.category = '',
    this.group = '',
    required this.description,
    this.warn = false,
  });

  final String amount;
  final String accountLabel;
  final String account;
  final String accountBalance;
  final String category;
  final String group;
  final String description;
  final bool warn;
}

/// Sample values per type, as shown in the mockup.
const _drafts = {
  TxType.keluar: _Draft(amount: '25.000', accountLabel: 'Dari akun', account: 'GoPay', accountBalance: 'Rp 247.000', category: 'Kopi', group: 'Kebutuhan Harian', description: 'Kopi sore', warn: true),
  TxType.masuk: _Draft(amount: '750.000', accountLabel: 'Ke akun', account: 'Jago', accountBalance: 'Rp 1.399.000', category: 'Pemasukan lain', group: 'Masuk', description: 'Proyek freelance'),
  TxType.transfer: _Draft(amount: '2.000.000', accountLabel: 'Dari akun', account: 'BCA', accountBalance: 'Rp 2.943.500', description: 'Bagi gaji'),
};

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  TxType _type = TxType.keluar;

  @override
  Widget build(BuildContext context) {
    final d = _drafts[_type]!;
    const sub = TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SubPageHeader(title: 'Transaksi baru', leadingIcon: Icons.close_rounded, leadingLabel: 'Tutup'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  SegmentedTabs<TxType>(
                    values: TxType.values,
                    selected: _type,
                    labelOf: (t) => t.label,
                    onChanged: (t) => setState(() => _type = t),
                  ),
                  const SizedBox(height: 30),
                  const Text('Nominal', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  AmountDisplay(amount: d.amount, color: txColor(_type)),
                  const SizedBox(height: 22),
                  SakuCard(
                    padding: EdgeInsets.zero,
                    child: DividedColumn(children: [
                      const FieldRow(
                        label: 'Tanggal',
                        value: 'Kamis, 5 Nov 2026',
                        trailing: Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.muted),
                      ),
                      FieldRow(label: d.accountLabel, value: d.account, trailing: Text(d.accountBalance, style: sub)),
                      if (_type == TxType.transfer) ...[
                        const FieldRow(label: 'Ke akun', value: 'Mandiri', trailing: Text('Rp 1.800.000', style: sub)),
                        const FieldRow(label: 'Biaya admin', value: 'Rp 2.500', trailing: Pill('dicatat ke Biaya Admin', fontSize: 12)),
                      ] else
                        FieldRow(label: 'Kategori', value: d.category, trailing: Pill(d.group, fontSize: 12)),
                      FieldRow(label: 'Deskripsi', value: d.description, valueWeight: FontWeight.w500),
                    ]),
                  ),
                  if (d.warn) ...[
                    const SizedBox(height: 18),
                    const InfoNote(
                      icon: Icons.warning_amber_rounded,
                      bg: AppColors.warnBg,
                      fg: AppColors.warnText,
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: 'Peringatan', style: TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: ' · Anggaran Kopi terlewati Rp 23.000 (terpakai Rp 53.000 dari Rp 30.000). Transaksi tetap bisa disimpan.'),
                      ])),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: PrimaryButton('Simpan transaksi', onPressed: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }
}
