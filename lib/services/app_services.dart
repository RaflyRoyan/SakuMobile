import 'package:shared_preferences/shared_preferences.dart';

import 'app_prefs.dart';
import 'media_services.dart';
import 'platform_services.dart';

/// Device-side services, injected so tests can run without platform plugins.
class AppServices {
  AppServices({required this.prefs, required this.pengingat, required this.auth, required this.media});

  /// Real plugins. Call from `main()` before `runApp`.
  static Future<AppServices> nyata() async => AppServices(
        prefs: AppPrefs(SharedPrefStore(await SharedPreferences.getInstance())),
        pengingat: LocalNotificationScheduler(),
        auth: LocalDeviceAuth(),
        media: PluginMediaServices(),
      );

  /// In-memory prefs, no notifications, no device lock, no camera. Default in tests.
  factory AppServices.memori({PrefStore? prefs, ReminderScheduler? pengingat, DeviceAuth? auth, MediaServices? media}) => AppServices(
        prefs: AppPrefs(prefs ?? MemoryPrefStore()),
        pengingat: pengingat ?? NoopReminderScheduler(),
        auth: auth ?? NoopDeviceAuth(),
        media: media ?? NoopMediaServices(),
      );

  final AppPrefs prefs;
  final ReminderScheduler pengingat;
  final DeviceAuth auth;
  final MediaServices media;
}
