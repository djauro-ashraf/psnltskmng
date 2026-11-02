import 'package:personaltskmng/quran_data/controller/screen_wake.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on with the platform's wake lock. A platform without one
/// just does nothing.
class WakelockScreenWake implements ScreenWake {
  const WakelockScreenWake();

  @override
  Future<void> set({required bool on}) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (_) {
      // No wake lock on this platform: reading goes on, the screen may dim.
    }
  }
}
