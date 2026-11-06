import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'api/saku_api.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/close_period_screen.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/qris_settings_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/split_detail_screen.dart';
import 'screens/split_form_screen.dart';
import 'screens/split_list_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'screens/terima_qris_screen.dart';
import 'screens/users_screen.dart';
import 'services/app_services.dart';
import 'services/platform_services.dart';
import 'state/app_scope.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/app_lock.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const home = '/';
  static const addTransaction = '/transaksi/tambah';
  static const editTransaction = '/transaksi/edit';
  static const subscriptions = '/langganan';
  static const closePeriod = '/periode/baru';
  static const settings = '/pengaturan';
  static const users = '/pengguna';
  static const statistics = '/statistik';
  static const split = '/split';
  static const splitBaru = '/split/baru';
  static const splitDetail = '/split/detail';
  static const splitUbah = '/split/ubah';
  static const terimaQris = '/qris';
  static const qrisSettings = '/pengaturan/qris';
}

class SakuApp extends StatefulWidget {
  const SakuApp({super.key, this.api, this.services});

  /// Injected in tests; defaults to the real API.
  final SakuApi? api;

  /// Device services (prefs, notifications, app lock). Defaults to in-memory
  /// no-op services, which is what tests want; `main()` passes the real ones.
  final AppServices? services;

  @override
  State<SakuApp> createState() => _SakuAppState();
}

class _SakuAppState extends State<SakuApp> {
  final _navKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final SessionController _session;

  @override
  void initState() {
    super.initState();
    final api = widget.api ?? SakuApi(ApiClient());
    _session = SessionController(api, widget.services ?? AppServices.memori());
    api.client.onUnauthorized = _onExpired;
    _session.services.pengingat.init(onTap: _onNotifTap);
  }

  void _onExpired() {
    if (_session.user == null) return;
    _session.expire();
    _navKey.currentState?.pushNamedAndRemoveUntil(Routes.login, (_) => false);
    _messengerKey.currentState?.showSnackBar(const SnackBar(
      content: Text('Sesi berakhir, silakan login ulang.'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.outText,
    ));
  }

  void _onNotifTap(String? payload) {
    if (payload != payloadLangganan) return;
    // Cold start: the session is restored by the splash first; open after it.
    void open() => _navKey.currentState?.pushNamed(Routes.subscriptions);
    if (_session.user != null) {
      open();
    } else {
      void wait() {
        if (_session.user == null) return;
        _session.removeListener(wait);
        WidgetsBinding.instance.addPostFrameCallback((_) => open());
      }
      _session.addListener(wait);
    }
  }

  Future<void> _logoutFromLock() async {
    await _session.logout();
    _navKey.currentState?.pushNamedAndRemoveUntil(Routes.login, (_) => false);
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      session: _session,
      child: MaterialApp(
        title: 'Saku',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        navigatorKey: _navKey,
        scaffoldMessengerKey: _messengerKey,
        builder: (context, child) => AppLock(session: _session, onLogout: _logoutFromLock, child: child!),
        initialRoute: Routes.splash,
        routes: {
          Routes.splash: (_) => const SplashScreen(),
          Routes.login: (_) => const LoginScreen(),
          Routes.home: (_) => const HomeShell(),
          Routes.addTransaction: (_) => const AddTransactionScreen(),
          Routes.subscriptions: (_) => const SubscriptionsScreen(),
          Routes.closePeriod: (_) => const ClosePeriodScreen(),
          Routes.settings: (_) => const SettingsScreen(),
          Routes.users: (_) => const UsersScreen(),
          Routes.statistics: (_) => const StatisticsScreen(),
          Routes.split: (_) => const SplitListScreen(),
          Routes.splitBaru: (_) => const SplitFormScreen(),
          Routes.terimaQris: (_) => const TerimaQrisScreen(),
          Routes.qrisSettings: (_) => const QrisSettingsScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == Routes.editTransaction) {
            final id = settings.arguments as String;
            return MaterialPageRoute(builder: (_) => AddTransactionScreen(editId: id), settings: settings);
          }
          if (settings.name == Routes.splitDetail) {
            return MaterialPageRoute(builder: (_) => SplitDetailScreen(id: settings.arguments as String), settings: settings);
          }
          if (settings.name == Routes.splitUbah) {
            return MaterialPageRoute(builder: (_) => SplitFormScreen(editId: settings.arguments as String), settings: settings);
          }
          return null;
        },
      ),
    );
  }
}
