import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_auth/local_auth.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'jadwal_pengingat.dart';

/// Schedules subscription reminders as local notifications.
abstract class ReminderScheduler {
  /// False where local notifications aren't available (tests, web, desktop).
  bool get didukung;
  Future<void> init({void Function(String? payload)? onTap});

  /// Asks the OS for permission (Android 13+ / iOS). True when granted.
  Future<bool> mintaIzin();

  /// Replaces every scheduled reminder with [jadwal].
  Future<void> jadwalkan(List<JadwalPengingat> jadwal);
  Future<void> batalSemua();
}

/// Device biometrics / screen-lock PIN.
abstract class DeviceAuth {
  Future<bool> didukung();

  /// Throws [DeviceAuthException] with a readable message on hard failures.
  Future<bool> autentikasi(String alasan);
}

class DeviceAuthException implements Exception {
  DeviceAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class NoopReminderScheduler implements ReminderScheduler {
  @override
  bool get didukung => false;
  @override
  Future<void> init({void Function(String? payload)? onTap}) async {}
  @override
  Future<bool> mintaIzin() async => false;
  @override
  Future<void> jadwalkan(List<JadwalPengingat> jadwal) async {}
  @override
  Future<void> batalSemua() async {}
}

class NoopDeviceAuth implements DeviceAuth {
  @override
  Future<bool> didukung() async => false;
  @override
  Future<bool> autentikasi(String alasan) async => false;
}

const payloadLangganan = 'langganan';

class LocalNotificationScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _siap = false;
  Future<void>? _initF;
  late final tz.Location _wib;

  static const _channel = AndroidNotificationDetails(
    'pengingat_langganan',
    'Pengingat langganan',
    channelDescription: 'Langganan dan tagihan yang mendekati jatuh tempo',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_notif',
    color: Color(0xFF0E6B47),
  );

  @override
  bool get didukung => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> init({void Function(String? payload)? onTap}) => _initF ??= _init(onTap);

  Future<void> _init(void Function(String? payload)? onTap) async {
    if (!didukung) return;
    tzdata.initializeTimeZones();
    _wib = tz.getLocation('Asia/Jakarta');
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notif'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
    );
    _siap = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) onTap?.call(launch!.notificationResponse?.payload);
  }

  @override
  Future<bool> mintaIzin() async {
    await _initF;
    if (!_siap) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  @override
  Future<void> jadwalkan(List<JadwalPengingat> jadwal) async {
    await _initF;
    if (!_siap) return;
    await _plugin.cancelAll();
    for (final j in jadwal) {
      final w = j.waktu;
      await _plugin.zonedSchedule(
        id: j.id,
        scheduledDate: tz.TZDateTime(_wib, w.year, w.month, w.day, w.hour, w.minute),
        notificationDetails: const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: j.judul,
        body: j.isi,
        payload: payloadLangganan,
      );
    }
  }

  @override
  Future<void> batalSemua() async {
    await _initF;
    if (_siap) await _plugin.cancelAll();
  }
}

class LocalDeviceAuth implements DeviceAuth {
  final _auth = LocalAuthentication();

  @override
  Future<bool> didukung() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> autentikasi(String alasan) async {
    try {
      return await _auth.authenticate(localizedReason: alasan, persistAcrossBackgrounding: true);
    } on LocalAuthException catch (e) {
      if (e.code == LocalAuthExceptionCode.userCanceled || e.code == LocalAuthExceptionCode.systemCanceled) return false;
      throw DeviceAuthException(switch (e.code) {
        LocalAuthExceptionCode.noCredentialsSet => 'Kunci layar HP belum diatur. Atur PIN/pola/sidik jari di pengaturan HP dulu.',
        LocalAuthExceptionCode.temporaryLockout || LocalAuthExceptionCode.biometricLockout => 'Terlalu banyak percobaan. Coba lagi sebentar lagi.',
        _ => 'Verifikasi gagal (${e.code.name}).',
      });
    } on PlatformException catch (e) {
      throw DeviceAuthException('Verifikasi gagal (${e.code}).');
    }
  }
}
