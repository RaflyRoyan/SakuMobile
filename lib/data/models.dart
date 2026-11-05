import 'package:flutter/material.dart';

enum TxType { keluar, masuk, transfer }

extension TxTypeLabel on TxType {
  String get label => switch (this) {
        TxType.keluar => 'Keluar',
        TxType.masuk => 'Masuk',
        TxType.transfer => 'Transfer',
      };
}

class Account {
  const Account({
    required this.name,
    required this.code,
    required this.kind,
    required this.balance,
    required this.badgeBg,
    required this.badgeFg,
  });

  final String name;
  final String code;
  final String kind;
  final int balance;
  final Color badgeBg;
  final Color badgeFg;
}

class Transaction {
  const Transaction({
    required this.day,
    required this.type,
    required this.initials,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.fee,
  });

  final String day;
  final TxType type;
  final String initials;
  final String title;
  final String subtitle;

  /// Always positive; sign comes from [type].
  final int amount;
  final int? fee;
}

enum BudgetStatus { aman, hampir, lewat }

class SubBudget {
  const SubBudget(this.name, this.used, {this.limit, this.status, this.percent});

  final String name;
  final int used;
  final int? limit;
  final BudgetStatus? status;
  final String? percent;
}

class BudgetGroup {
  const BudgetGroup({
    required this.name,
    required this.used,
    this.limit,
    this.status,
    this.percent = 0,
    this.subs = const [],
  });

  final String name;
  final int used;
  final int? limit;
  final BudgetStatus? status;
  final int percent;
  final List<SubBudget> subs;
}

enum SubStatus { terlambat, hariIni, akanDatang, belum, dibayar, dilewati }

class Subscription {
  const Subscription({
    required this.id,
    required this.day,
    required this.name,
    required this.meta,
    required this.amount,
    required this.status,
  });

  final String id;
  final int day;
  final String name;
  final String meta;
  final int amount;
  final SubStatus status;
}

class SavingsAccount {
  const SavingsAccount(this.name, this.deposit, this.withdraw);

  final String name;
  final int deposit;
  final int withdraw;
  int get balance => deposit - withdraw;
}

class PeriodAccount {
  const PeriodAccount(this.name, this.remaining, this.carryOver);

  final String name;
  final int remaining;
  final int carryOver;
  int get toSavings => remaining - carryOver;
}
