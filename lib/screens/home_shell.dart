import 'package:flutter/material.dart';

import '../app.dart';
import '../theme/app_colors.dart';
import 'budget_screen.dart';
import 'dashboard_screen.dart';
import 'savings_screen.dart';
import 'transactions_screen.dart';

/// Tab indices for the bottom navigation.
abstract final class HomeTab {
  static const beranda = 0;
  static const riwayat = 1;
  static const anggaran = 2;
  static const tabungan = 3;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = HomeTab.beranda;

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: [
            DashboardScreen(onSelectTab: _select),
            const TransactionsScreen(),
            const BudgetScreen(),
            const SavingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(index: _index, onSelect: _select),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget item(int i, IconData icon, IconData activeIcon, String label) {
      final on = index == i;
      final color = on ? AppColors.primary : AppColors.muted;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkResponse(
            onTap: () => onSelect(i),
            radius: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(on ? activeIcon : icon, size: 22, color: color),
                  const SizedBox(height: 4),
                  Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              item(HomeTab.beranda, Icons.home_outlined, Icons.home_rounded, 'Beranda'),
              item(HomeTab.riwayat, Icons.format_list_bulleted_rounded, Icons.format_list_bulleted_rounded, 'Riwayat'),
              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -14),
                  child: Center(
                    child: Tooltip(
                      message: 'Tambah transaksi',
                      child: Material(
                        color: AppColors.primary,
                        elevation: 6,
                        shadowColor: AppColors.primary.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).pushNamed(Routes.addTransaction),
                          child: const SizedBox(
                            width: 52,
                            height: 52,
                            child: Icon(Icons.add_rounded, size: 28, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              item(HomeTab.anggaran, Icons.pie_chart_outline_rounded, Icons.pie_chart_rounded, 'Anggaran'),
              item(HomeTab.tabungan, Icons.savings_outlined, Icons.savings_rounded, 'Tabungan'),
            ],
          ),
        ),
      ),
    );
  }
}
