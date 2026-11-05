import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class ClosePeriodScreen extends StatefulWidget {
  const ClosePeriodScreen({super.key});

  @override
  State<ClosePeriodScreen> createState() => _ClosePeriodScreenState();
}

class _ClosePeriodScreenState extends State<ClosePeriodScreen> {
  bool _copyBudget = true;

  @override
  Widget build(BuildContext context) {
    const accounts = MockData.periodAccounts;
    final toSavings = accounts.fold(0, (s, a) => s + a.toSavings);
    const opening = {'BCA': 6000000, 'Mandiri': 0};
    final openingRows = [
      for (final a in accounts) (a.name, opening[a.name] ?? a.carryOver, a.carryOver > 0),
    ];
    final openingTotal = openingRows.fold(0, (s, r) => s + r.$2);

    return Scaffold(
      body: SafeArea(
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontFeatures: AppTheme.tabular),
          child: Column(
            children: [
              const SubPageHeader(title: 'Mulai periode baru'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    const Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'Periode '),
                        TextSpan(text: MockData.periodName, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                        TextSpan(text: ' akan ditutup. Sisa saldo tiap akun masuk ke tabungan, kecuali yang kamu teruskan.'),
                      ]),
                      style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.55),
                    ),
                    const SizedBox(height: 22),
                    const _Step(1, 'Periode baru'),
                    const SakuCard(
                      padding: EdgeInsets.zero,
                      child: DividedColumn(children: [
                        _KV('Nama', Text('Gajian Nov 2026', style: TextStyle(fontWeight: FontWeight.w600))),
                        _KV('Tanggal mulai', Text('Rabu, 25 Nov 2026', style: TextStyle(fontWeight: FontWeight.w600))),
                        _KV('Periode lama selesai', Text('24 Nov 2026', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.muted))),
                      ]),
                    ),
                    const SizedBox(height: 22),
                    const _Step(2, 'Sisa periode lama'),
                    SakuCard(
                      padding: EdgeInsets.zero,
                      child: DividedColumn(children: [
                        for (final a in accounts)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(
                              children: [
                                Row(children: [
                                  Expanded(child: Text(a.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                                  Text('Sisa ${rupiah(a.remaining)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                ]),
                                const SizedBox(height: 8),
                                Row(children: [
                                  const Expanded(child: Text('Teruskan ke periode baru', style: TextStyle(fontSize: 13, color: AppColors.muted))),
                                  _AmountBox(thousands(a.carryOver)),
                                ]),
                                const SizedBox(height: 8),
                                Row(children: [
                                  const Expanded(child: Text('Masuk tabungan', style: TextStyle(fontSize: 12, color: AppColors.muted))),
                                  Text(rupiah(a.toSavings), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                ]),
                              ],
                            ),
                          ),
                      ]),
                    ),
                    _Total('Total masuk tabungan', rupiah(toSavings)),
                    const SizedBox(height: 22),
                    const _Step(3, 'Saldo awal (gaji masuk di sini)'),
                    SakuCard(
                      padding: EdgeInsets.zero,
                      child: DividedColumn(children: [
                        for (final r in openingRows)
                          _KV.widget(
                            Text.rich(TextSpan(children: [
                              TextSpan(text: r.$1),
                              if (r.$3) const TextSpan(text: ' · diteruskan', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                            ])),
                            _AmountBox(thousands(r.$2), muted: r.$2 == 0),
                          ),
                      ]),
                    ),
                    _Total('Total saldo awal', rupiah(openingTotal)),
                    const SizedBox(height: 22),
                    SakuCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Salin anggaran', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                SizedBox(height: 2),
                                Text('Pakai batas anggaran periode ini lagi', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _copyBudget,
                            onChanged: (v) => setState(() => _copyBudget = v),
                            activeThumbColor: Colors.white,
                            activeTrackColor: AppColors.primary,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: AppColors.dashed,
                            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const InfoNote(
                      icon: Icons.info_outline_rounded,
                      bg: AppColors.transferBg,
                      fg: AppColors.infoText,
                      child: Text('Transaksi yang sudah tercatat bertanggal 25 Nov atau sesudahnya tetap di periode lama.'),
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton('Tutup buku & mulai periode', onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.title);

  final int n;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.deep, shape: BoxShape.circle),
            child: Text('$n', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(String this.label, this.value) : labelWidget = null;
  const _KV.widget(Widget this.labelWidget, this.value) : label = null;

  final String? label;
  final Widget? labelWidget;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: labelWidget ?? Text(label!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ),
            const SizedBox(width: 12),
            DefaultTextStyle.merge(style: const TextStyle(fontSize: 14), child: value),
          ],
        ),
      ),
    );
  }
}

class _AmountBox extends StatelessWidget {
  const _AmountBox(this.value, {this.muted = false});

  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted ? AppColors.muted : AppColors.ink)),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.muted))),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
