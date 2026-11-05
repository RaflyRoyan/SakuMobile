import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'models.dart';

/// Static sample data matching the design mockup.
/// Replace with a real repository once the backend is decided.
abstract final class MockData {
  static const userName = 'Ryn';
  static const userHandle = 'ryn';
  static const userInitials = 'RR';
  static const periodName = 'Gajian Okt 2026';
  static const periodSince = '25 Okt';

  static const openingBalance = 6000000;
  static const income = 750000;
  static const expense = 360500;
  static int get totalBalance =>
      accounts.fold(0, (sum, a) => sum + a.balance);

  static const accounts = [
    Account(
      name: 'BCA',
      code: 'BCA',
      kind: 'Bank',
      balance: 2943500,
      badgeBg: AppColors.transferBg,
      badgeFg: AppColors.transfer,
    ),
    Account(
      name: 'Mandiri',
      code: 'MDR',
      kind: 'Bank',
      balance: 1800000,
      badgeBg: Color(0xFFFBF0D9),
      badgeFg: AppColors.warnStrong,
    ),
    Account(
      name: 'Jago',
      code: 'JGO',
      kind: 'Bank',
      balance: 1399000,
      badgeBg: Color(0xFFEFE7F7),
      badgeFg: Color(0xFF5B2E8C),
    ),
    Account(
      name: 'GoPay',
      code: 'GP',
      kind: 'E-wallet',
      balance: 247000,
      badgeBg: AppColors.inBg,
      badgeFg: AppColors.primary,
    ),
  ];

  static const transactions = [
    Transaction(day: 'Hari ini · Kam 5 Nov', type: TxType.keluar, initials: 'KP', title: 'Kopi susu', subtitle: 'Kopi · GoPay', amount: 28000),
    Transaction(day: 'Rab 4 Nov', type: TxType.keluar, initials: 'BS', title: 'Bensin motor', subtitle: 'Bensin · Jago', amount: 50000),
    Transaction(day: 'Sel 3 Nov', type: TxType.masuk, initials: 'FL', title: 'Proyek freelance', subtitle: 'Pemasukan lain · Jago', amount: 750000),
    Transaction(day: 'Sen 2 Nov', type: TxType.keluar, initials: 'NF', title: 'Netflix', subtitle: 'Langganan · BCA · berulang', amount: 54000),
    Transaction(day: 'Min 1 Nov', type: TxType.keluar, initials: 'LS', title: 'Token listrik', subtitle: 'Listrik · Mandiri', amount: 200000),
    Transaction(day: 'Rab 28 Okt', type: TxType.keluar, initials: 'MK', title: 'Makan siang', subtitle: 'Makan · GoPay', amount: 25000),
    Transaction(day: 'Sen 26 Okt', type: TxType.transfer, initials: 'TF', title: 'Isi saldo GoPay', subtitle: 'Jago → GoPay', amount: 300000, fee: 1000),
    Transaction(day: 'Min 25 Okt', type: TxType.transfer, initials: 'TF', title: 'Bagi gaji', subtitle: 'BCA → Mandiri', amount: 2000000, fee: 2500),
    Transaction(day: 'Min 25 Okt', type: TxType.transfer, initials: 'TF', title: 'Bagi gaji', subtitle: 'BCA → Jago', amount: 1000000),
  ];

  /// Short-date labels used on the dashboard "recent" list.
  static const recentDates = ['Hari ini', '4 Nov', '3 Nov', '2 Nov', '1 Nov'];

  static const budgetLimit = 2340000;
  static const budgetUsed = 360500;

  static const budgets = [
    BudgetGroup(name: 'Transportasi', used: 50000, limit: 40000, status: BudgetStatus.lewat, percent: 125, subs: [
      SubBudget('Bensin', 50000),
    ]),
    BudgetGroup(name: 'Kebutuhan Harian', used: 53000, limit: 1500000, status: BudgetStatus.aman, percent: 4, subs: [
      SubBudget('Makan', 25000, limit: 1200000, status: BudgetStatus.aman, percent: '2%'),
      SubBudget('Kopi', 28000, limit: 30000, status: BudgetStatus.hampir, percent: '93%'),
    ]),
    BudgetGroup(name: 'Tagihan & Langganan', used: 254000, limit: 500000, status: BudgetStatus.aman, percent: 51, subs: [
      SubBudget('Listrik', 200000, limit: 250000, status: BudgetStatus.hampir, percent: '80%'),
      SubBudget('Langganan', 54000),
    ]),
    BudgetGroup(name: 'Hiburan & Liburan', used: 0, limit: 300000, status: BudgetStatus.aman, percent: 0),
    BudgetGroup(name: 'Keuangan', used: 3500, subs: [
      SubBudget('Biaya Admin Bank', 3500),
    ]),
  ];

  static const subscriptions = [
    Subscription(id: 'gym', day: 1, name: 'Gym Fit+', meta: 'BCA · Olahraga · ingatkan H-3', amount: 250000, status: SubStatus.terlambat),
    Subscription(id: 'net', day: 5, name: 'Internet IndiHome', meta: 'Mandiri · Internet · H-3', amount: 450000, status: SubStatus.hariIni),
    Subscription(id: 'spot', day: 8, name: 'Spotify Premium', meta: 'GoPay · Langganan · H-3', amount: 54990, status: SubStatus.akanDatang),
    Subscription(id: 'nf', day: 2, name: 'Netflix', meta: 'BCA · Langganan · s.d. Des 2026', amount: 54000, status: SubStatus.dibayar),
    Subscription(id: 'asur', day: 15, name: 'Asuransi motor', meta: 'Jago · Asuransi · H-5', amount: 46000, status: SubStatus.dilewati),
    Subscription(id: 'icl', day: 20, name: 'iCloud 50 GB', meta: 'BCA · Langganan · H-3', amount: 15000, status: SubStatus.belum),
  ];

  static const subscriptionTotal = 869990;

  static const savings = [
    SavingsAccount('BCA', 2997500, 0),
    SavingsAccount('Mandiri', 2000000, 0),
    SavingsAccount('Jago', 699000, 0),
    SavingsAccount('GoPay', 275000, 0),
  ];
  static int get savingsTotal => savings.fold(0, (s, a) => s + a.balance);
  static const savingsSourcePeriod = 'Gajian Sep 2026';
  static const savingsDate = '24 Okt';

  static const periodAccounts = [
    PeriodAccount('BCA', 2943500, 0),
    PeriodAccount('Mandiri', 1800000, 0),
    PeriodAccount('Jago', 1399000, 200000),
    PeriodAccount('GoPay', 247000, 247000),
  ];
}
