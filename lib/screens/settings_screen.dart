import 'package:flutter/material.dart';

import '../app.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = Navigator.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SubPageHeader(title: 'Pengaturan'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  SakuCard(
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.deep, shape: BoxShape.circle),
                          child: const Text(MockData.userInitials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(MockData.userName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              SizedBox(height: 2),
                              Text('@${MockData.userHandle} · Admin', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        OutlineBtn('Ubah', height: 36, radius: 10, onPressed: () {}),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const OverlineLabel('Akun saya'),
                  SakuCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Akun yang tampil di transaksi, urut sesuai pilihanmu.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final (i, a) in MockData.accounts.indexed) _AccChip('${i + 1} · ${a.name}'),
                            const _AccChip('Cash (tidak dipilih)', dashed: true),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextLink('Atur akun & urutan', onTap: () {}),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const OverlineLabel('Keuangan'),
                  SakuCard(
                    padding: EdgeInsets.zero,
                    child: DividedColumn(children: [
                      _MenuItem(icon: Icons.category_outlined, label: 'Kategori & sub kategori', value: '24', onTap: () {}),
                      _MenuItem(icon: Icons.repeat_rounded, label: 'Langganan', value: '6 aktif', onTap: () => nav.pushNamed(Routes.subscriptions)),
                      _MenuItem(icon: Icons.history_rounded, label: 'Riwayat periode', value: '3', onTap: () {}),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  const OverlineLabel('Admin'),
                  SakuCard(
                    padding: EdgeInsets.zero,
                    child: DividedColumn(children: [
                      _MenuItem(icon: Icons.group_outlined, label: 'Kelola pengguna', value: '3 pengguna', onTap: () {}),
                      _MenuItem(icon: Icons.account_balance_outlined, label: 'Master akun', value: '5', onTap: () {}),
                      _MenuItem(icon: Icons.folder_outlined, label: 'Kelompok kategori', value: '11', onTap: () {}),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  const OverlineLabel('Keamanan'),
                  SakuCard(
                    padding: EdgeInsets.zero,
                    child: DividedColumn(children: [
                      _MenuItem(icon: Icons.key_outlined, label: 'Ganti password', onTap: () {}),
                      _MenuItem(
                        icon: Icons.logout_rounded,
                        label: 'Keluar',
                        danger: true,
                        onTap: () => nav.pushNamedAndRemoveUntil(Routes.login, (_) => false),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  const Text('Saku · data tersimpan di Google Sheets', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccChip extends StatelessWidget {
  const _AccChip(this.label, {this.dashed = false});

  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dashed ? AppColors.surface : AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: dashed ? Border.all(color: AppColors.dashed) : null,
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dashed ? AppColors.muted : AppColors.ink)),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, this.value, this.danger = false, required this.onTap});

  final IconData icon;
  final String label;
  final String? value;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.out : AppColors.ink;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              IconTile(
                icon: icon,
                bg: danger ? AppColors.outBg : AppColors.background,
                fg: danger ? AppColors.out : AppColors.primary,
                size: 34,
                radius: 10,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg))),
              if (value != null) Text(value!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              if (!danger) ...[const SizedBox(width: 6), const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.muted)],
            ],
          ),
        ),
      ),
    );
  }
}
