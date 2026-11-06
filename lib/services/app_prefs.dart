import 'package:shared_preferences/shared_preferences.dart';

/// Device-local settings (not synced to the server).
abstract class PrefStore {
  bool? getBool(String key);
  Future<void> setBool(String key, bool value);
  String? getString(String key);

  /// null removes the key.
  Future<void> setString(String key, String? value);
}

class SharedPrefStore implements PrefStore {
  SharedPrefStore(this._p);

  final SharedPreferences _p;

  @override
  bool? getBool(String key) => _p.getBool(key);

  @override
  Future<void> setBool(String key, bool value) => _p.setBool(key, value);

  @override
  String? getString(String key) => _p.getString(key);

  @override
  Future<void> setString(String key, String? value) async {
    if (value == null) {
      await _p.remove(key);
    } else {
      await _p.setString(key, value);
    }
  }
}

class MemoryPrefStore implements PrefStore {
  MemoryPrefStore([Map<String, Object>? initial]) : _m = {...?initial};

  final Map<String, Object> _m;

  @override
  bool? getBool(String key) => _m[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => _m[key] = value;

  @override
  String? getString(String key) => _m[key] as String?;

  @override
  Future<void> setString(String key, String? value) async => value == null ? _m.remove(key) : _m[key] = value;
}

class AppPrefs {
  AppPrefs(this._store);

  final PrefStore _store;

  /// Require biometrics / device PIN when opening the app.
  bool get kunciAktif => _store.getBool('kunci_aktif') ?? false;
  Future<void> setKunciAktif(bool v) => _store.setBool('kunci_aktif', v);

  /// Local notifications for subscriptions that are due.
  bool get notifAktif => _store.getBool('notif_aktif') ?? true;
  Future<void> setNotifAktif(bool v) => _store.setBool('notif_aktif', v);

  /// Whether the OS notification permission was already requested once.
  bool get notifSudahDiminta => _store.getBool('notif_diminta') ?? false;
  Future<void> setNotifSudahDiminta(bool v) => _store.setBool('notif_diminta', v);

  /// Cached merchant QRIS payload so "Terima QRIS" works offline.
  String? get qrisPayload => _store.getString('qris_payload');
  Future<void> setQrisPayload(String? v) => _store.setString('qris_payload', v);

  /// Last income kategori used for "Terima QRIS → Sudah dibayar".
  String? get kategoriQrisTerakhir => _store.getString('qris_kategori');
  Future<void> setKategoriQrisTerakhir(String? v) => _store.setString('qris_kategori', v);
}
