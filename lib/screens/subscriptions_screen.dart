import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  /// Status before the user acted, so "Batal lewati" can restore it.
  static final _original = {
    for (final s in MockData.subscriptions)
      s.id: s.status == SubStatus.dibayar || s.status == SubStatus.dilewati ? SubStatus.belum : s.status,
  };

  final _status = {for (final s in MockData.subscriptions) s.id: s.status};

  void _set(String id, SubStatus s) => setState(() => _status[id] = s);

  @override
  Widget build(BuildContext context) {
    final paid = _status.values.where((s) => s == SubStatus.dibayar).length;
    final pending = _status.values.where((s) => s != SubStatus.dibayar && s != SubStatus.dilewati).length;

    return Scaffold(
      body: SafeArea(
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontFeatures: AppTheme.tabular),
          child: Column(
            children: [
              SubPageHeader(
                title: 'Langganan',
                trailing: IconButton(
                  tooltip: 'Tambah langganan',
                  onPressed: () {},
                  icon: const Icon(Icons.add_rounded, color: AppColors.primary, size: 26),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    SakuCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tagihan November', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
                                const SizedBox(height: 2),
                                Text(rupiah(MockData.subscriptionTotal), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$paid dibayar', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                              const SizedBox(height: 2),
                              Text('$pending menunggu', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const OverlineLabel('Bulan ini'),
                    for (final s in MockData.subscriptions) ...[
                      _SubscriptionCard(
                        sub: s,
                        status: _status[s.id]!,
                        onPay: () => _set(s.id, SubStatus.dibayar),
                        onSkip: () => _set(s.id, SubStatus.dilewati),
                        onUndo: () => _set(s.id, _original[s.id]!),
                      ),
                      const SizedBox(height: 12),
                    ],
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

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.sub, required this.status, required this.onPay, required this.onSkip, required this.onUndo});

  final Subscription sub;
  final SubStatus status;
  final VoidCallback onPay;
  final VoidCallback onSkip;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      SubStatus.terlambat => ('Terlambat 4 hari', AppColors.outBg, AppColors.outText),
      SubStatus.hariIni => ('Hari ini', AppColors.warnBg, AppColors.warnText),
      SubStatus.akanDatang => ('3 hari lagi', AppColors.transferBg, AppColors.transfer),
      SubStatus.belum => ('Belum', AppColors.background, AppColors.inkSoft),
      SubStatus.dibayar => ('Dibayar', AppColors.inBg, AppColors.primaryDark),
      SubStatus.dilewati => ('Dilewati', AppColors.background, AppColors.inkSoft),
    };
    final actionable = status == SubStatus.terlambat || status == SubStatus.hariIni || status == SubStatus.akanDatang;

    return SakuCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 48,
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${sub.day}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1)),
                    const SizedBox(height: 3),
                    const Text('NOV', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(sub.meta, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(rupiah(sub.amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Pill(label, bg: bg, fg: fg),
                ],
              ),
            ],
          ),
          if (actionable) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlineBtn('Lewati bulan ini', onPressed: onSkip)),
                const SizedBox(width: 8),
                Expanded(child: PrimaryButton('Konfirmasi bayar', height: 40, onPressed: onPay)),
              ],
            ),
          ],
          if (status == SubStatus.dibayar || status == SubStatus.dilewati) ...[
            const SizedBox(height: 8),
            TextLink(status == SubStatus.dibayar ? 'Lihat transaksi' : 'Batal lewati', onTap: status == SubStatus.dilewati ? onUndo : () {}),
          ],
        ],
      ),
    );
  }
}
