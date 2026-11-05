import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

/// The three states shown in the mockup.
enum EditMode { periodeAktif, periodeTertutup, tarikTabungan }

class _EditData {
  const _EditData({
    required this.title,
    required this.type,
    required this.amount,
    this.previousAmount,
    required this.date,
    required this.period,
    required this.account,
    required this.category,
    required this.group,
    required this.description,
  });

  final String title;
  final TxType type;
  final String amount;
  final String? previousAmount;
  final String date;
  final String period;
  final String account;
  final String category;
  final String group;
  final String description;
}

const _data = {
  EditMode.periodeAktif: _EditData(title: 'Edit transaksi', type: TxType.keluar, amount: '50.000', previousAmount: '25.000', date: 'Rabu, 28 Okt 2026', period: 'Gajian Okt 2026', account: 'GoPay', category: 'Makan', group: 'Kebutuhan Harian', description: 'Makan siang'),
  EditMode.periodeTertutup: _EditData(title: 'Edit transaksi', type: TxType.keluar, amount: '50.000', previousAmount: '25.000', date: 'Sabtu, 12 Sep 2026', period: 'Gajian Sep 2026 · ditutup', account: 'GoPay', category: 'Makan', group: 'Kebutuhan Harian', description: 'Makan siang'),
  EditMode.tarikTabungan: _EditData(title: 'Detail transaksi', type: TxType.masuk, amount: '500.000', date: 'Kamis, 5 Nov 2026', period: 'Gajian Okt 2026', account: 'BCA', category: 'Tarik Tabungan', group: 'Sistem', description: 'Servis motor'),
};

class EditTransactionScreen extends StatelessWidget {
  const EditTransactionScreen({super.key, this.mode = EditMode.periodeAktif});

  final EditMode mode;

  bool get _locked => mode == EditMode.tarikTabungan;

  void _confirmDelete(BuildContext context, _EditData d) {
    showSakuSheet<void>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Hapus transaksi ini?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text(
            '${d.description} · Rp ${d.amount} dari ${d.account}. Saldo akun dihitung ulang dan transaksi tidak bisa dikembalikan.',
            style: const TextStyle(fontSize: 14, color: AppColors.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: OutlineBtn('Batal', height: 50, radius: 14, fontSize: 15, onPressed: () => Navigator.pop(ctx))),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton('Hapus', height: 50, color: AppColors.out, onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data[mode]!;
    final body = <Widget>[
      if (_locked) ...[
        InfoNote(
          icon: Icons.lock_outline_rounded,
          bg: AppColors.background,
          fg: AppColors.ink,
          borderColor: AppColors.borderStrong,
          child: Text.rich(TextSpan(children: [
            const TextSpan(text: 'Transaksi ini dibuat otomatis dari '),
            const TextSpan(text: 'Tarik Tabungan', style: TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(text: '. Ubah atau hapus lewat '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('menu Tabungan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ),
            const TextSpan(text: '.'),
          ])),
        ),
        const SizedBox(height: 18),
      ],
      Opacity(
        opacity: _locked ? 0.6 : 1,
        child: SegmentedTabs<TxType>(values: TxType.values, selected: d.type, labelOf: (t) => t.label),
      ),
      const SizedBox(height: 24),
      const Text('Nominal', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted)),
      const SizedBox(height: 6),
      AmountDisplay(amount: d.amount, color: d.type == TxType.masuk ? AppColors.primary : AppColors.out),
      if (d.previousAmount != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'sebelumnya '),
              TextSpan(text: 'Rp ${d.previousAmount}', style: const TextStyle(decoration: TextDecoration.lineThrough)),
            ]),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
      const SizedBox(height: 18),
      Opacity(
        opacity: _locked ? 0.6 : 1,
        child: SakuCard(
          padding: EdgeInsets.zero,
          child: DividedColumn(children: [
            FieldRow(label: 'Tanggal', value: d.date, trailing: Pill(d.period, fontSize: 12)),
            FieldRow(label: 'Kategori', value: d.category, trailing: Pill(d.group, fontSize: 12)),
            FieldRow(label: 'Deskripsi', value: d.description, valueWeight: FontWeight.w500),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      if (mode == EditMode.periodeTertutup)
        const InfoNote(
          icon: Icons.info_outline_rounded,
          bg: AppColors.transferBg,
          fg: AppColors.infoText,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: 'Periode '),
            TextSpan(text: 'Gajian Sep 2026', style: TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: ' sudah ditutup. Setelah disimpan, setor tabungan GoPay dihitung ulang: '),
            TextSpan(text: 'Rp 275.000 → Rp 250.000', style: TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: '.'),
          ])),
        ),
      if (mode == EditMode.periodeAktif)
        const InfoNote(
          icon: Icons.swap_horiz_rounded,
          bg: AppColors.warnBg,
          fg: AppColors.warnText,
          child: Text('Kalau tanggal diganti ke periode lain, transaksi otomatis pindah periode.'),
        ),
      if (!_locked) const SizedBox(height: 18),
      const Text(
        'Dibuat 28 Okt 2026, 12.40 oleh ryn\nTerakhir diubah 30 Okt 2026, 08.15',
        style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.6),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SubPageHeader(
              title: d.title,
              trailing: _locked
                  ? null
                  : IconButton(
                      tooltip: 'Hapus transaksi',
                      onPressed: () => _confirmDelete(context, d),
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.out),
                    ),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), children: body),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: _locked
                  ? OutlineBtn(
                      'Buka menu Tabungan',
                      height: 54,
                      radius: 16,
                      fontSize: 16,
                      color: AppColors.primary,
                      borderColor: AppColors.primary,
                      onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    )
                  : PrimaryButton('Simpan perubahan', onPressed: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }
}
