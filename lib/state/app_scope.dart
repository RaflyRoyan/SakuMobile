import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../api/saku_api.dart';
import '../services/app_services.dart';
import '../services/jadwal_pengingat.dart';

/// Holds the logged-in user and a "data version" counter that screens
/// listen to so they reload after any mutation.
class SessionController extends ChangeNotifier {
  SessionController(this.api, this.services);

  final SakuApi api;
  final AppServices services;

  Pengguna? _user;
  Pengguna? get user => _user;

  /// True when the current session started from typing the password (login /
  /// setup) rather than resuming a stored cookie. The app lock skips its
  /// first prompt in that case.
  bool _viaPassword = false;
  bool get viaPassword => _viaPassword;

  int _dataVersion = 0;
  int get dataVersion => _dataVersion;

  /// Tries to resume a stored session. Returns true when logged in.
  Future<bool> restore() async {
    if (!await api.client.hasToken()) return false;
    try {
      _user = await api.me();
      _viaPassword = false;
      notifyListeners();
      syncPengingat();
      return true;
    } on ApiException catch (e) {
      if (e.status == 401) return false;
      rethrow;
    }
  }

  Future<void> login(String username, String password) async {
    _user = await api.login(username, password);
    _viaPassword = true;
    notifyListeners();
    syncPengingat();
  }

  Future<void> setup(String username, String password, String nama) async {
    _user = await api.setup(username, password, nama);
    _viaPassword = true;
    notifyListeners();
    syncPengingat();
  }

  Future<void> logout() async {
    try {
      await api.logout();
    } on ApiException {
      // Cookie is cleared locally regardless.
    }
    _user = null;
    notifyListeners();
    await services.pengingat.batalSemua();
  }

  void setUser(Pengguna u) {
    _user = u;
    notifyListeners();
  }

  /// Session expired on the server.
  void expire() {
    _user = null;
    notifyListeners();
    services.pengingat.batalSemua();
  }

  /// Call after any write so every visible screen refetches.
  void dataChanged() {
    _dataVersion++;
    notifyListeners();
    syncPengingat();
  }

  bool _syncJalan = false;
  bool _syncLagi = false;

  /// Reschedules subscription reminders from `/berulang`. Never throws;
  /// overlapping calls collapse into one extra run.
  Future<void> syncPengingat() async {
    final s = services.pengingat;
    if (!s.didukung || _user == null) return;
    if (_syncJalan) {
      _syncLagi = true;
      return;
    }
    _syncJalan = true;
    try {
      do {
        _syncLagi = false;
        if (!services.prefs.notifAktif) {
          await s.batalSemua();
          break;
        }
        if (!services.prefs.notifSudahDiminta) {
          await services.prefs.setNotifSudahDiminta(true);
          await s.mintaIzin();
        }
        final list = await api.berulang();
        final now = DateTime.now().toUtc().add(const Duration(hours: 7));
        await s.jadwalkan(buatJadwalPengingat(list, DateTime(now.year, now.month, now.day, now.hour, now.minute)));
      } while (_syncLagi && _user != null);
    } catch (e) {
      debugPrint('syncPengingat: ${e.runtimeType}');
    } finally {
      _syncJalan = false;
    }
  }
}

class AppScope extends InheritedNotifier<SessionController> {
  const AppScope({super.key, required SessionController session, required super.child}) : super(notifier: session);

  static SessionController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Access without subscribing to changes (for callbacks).
  static SessionController read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

extension AppScopeX on BuildContext {
  SakuApi get api => AppScope.read(this).api;
  SessionController get session => AppScope.read(this);
  AppServices get services => AppScope.read(this).services;
}
