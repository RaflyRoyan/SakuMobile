import 'package:flutter/material.dart';

import 'screens/add_transaction_screen.dart';
import 'screens/close_period_screen.dart';
import 'screens/edit_transaction_screen.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'theme/app_theme.dart';

abstract final class Routes {
  static const login = '/login';
  static const home = '/';
  static const addTransaction = '/transaksi/tambah';
  static const editTransaction = '/transaksi/edit';
  static const subscriptions = '/langganan';
  static const closePeriod = '/periode/baru';
  static const settings = '/pengaturan';
}

class SakuApp extends StatelessWidget {
  const SakuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saku',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: Routes.login,
      routes: {
        Routes.login: (_) => const LoginScreen(),
        Routes.home: (_) => const HomeShell(),
        Routes.addTransaction: (_) => const AddTransactionScreen(),
        Routes.subscriptions: (_) => const SubscriptionsScreen(),
        Routes.closePeriod: (_) => const ClosePeriodScreen(),
        Routes.settings: (_) => const SettingsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == Routes.editTransaction) {
          final mode = settings.arguments as EditMode? ?? EditMode.periodeAktif;
          return MaterialPageRoute(builder: (_) => EditTransactionScreen(mode: mode), settings: settings);
        }
        return null;
      },
    );
  }
}
