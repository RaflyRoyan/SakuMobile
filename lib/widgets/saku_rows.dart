import 'package:flutter/material.dart';

import '../api/models.dart';
import '../app.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'common.dart';

const _badgePalette = [
  (AppColors.transferBg, AppColors.transfer),
  (Color(0xFFFBF0D9), AppColors.warnStrong),
  (Color(0xFFEFE7F7), Color(0xFF5B2E8C)),
  (AppColors.inBg, AppColors.primary),
  (AppColors.outBg, AppColors.outText),
  (AppColors.track, AppColors.inkSoft),
];

/// Coloured square with the account code ("BCA", "MDR", …). Colour is stable per name.
class AkunBadge extends StatelessWidget {
  const AkunBadge(this.nama, {super.key, this.size = 28});

  final String nama;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _badgePalette[nama.toLowerCase().codeUnits.fold(0, (a, b) => a + b) % _badgePalette.length];
    return IconTile(text: kodeAkun(nama), bg: bg, fg: fg, size: size, radius: size * 0.29);
  }
}

String jenisAkunLabel(String jenis) => switch (jenis) { 'bank' => 'Bank', 'ewallet' => 'E-wallet', 'cash' => 'Tunai', _ => jenis };

/// One transaction line, used by the dashboard and history.
class TransaksiRow extends StatelessWidget {
  const TransaksiRow({super.key, required this.tx, this.showDate = false, this.horizontalPadding = 0});

  final Transaksi tx;

  /// Inner horizontal padding (used when the card itself has none, e.g. swipeable rows).
  final double horizontalPadding;

  /// Append a relative date to the subtitle (dashboard).
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final amount = switch (tx.tipe) {
      TipeTransaksi.keluar => signed(-tx.nominal),
      TipeTransaksi.masuk => signed(tx.nominal),
      TipeTransaksi.transfer => thousands(tx.nominal),
    };
    final parts = tx.tipe == TipeTransaksi.transfer
        ? ['${tx.akunNama} → ${tx.akunTujuanNama ?? '?'}']
        : [if (tx.kategoriNama != null) tx.kategoriNama!, tx.akunNama, if (tx.berulangId != null && !showDate) 'berulang'];
    if (showDate) parts.add(tglRelatif(tx.tanggal));
    final ini = tx.tipe == TipeTransaksi.transfer ? 'TF' : inisial(tx.judul);

    return InkWell(
      onTap: () => Navigator.of(context).pushNamed(Routes.editTransaction, arguments: tx.id),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: horizontalPadding),
        child: Row(
          children: [
            IconTile.forTx(tx.tipe, ini),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.judul, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(parts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(amount, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: txColor(tx.tipe))),
                if (tx.biayaAdmin > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('admin ${thousands(tx.biayaAdmin)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
