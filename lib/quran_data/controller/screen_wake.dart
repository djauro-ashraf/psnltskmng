import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps the screen on while the reader reads ("Keep screen on while reading").
/// The platform side (`wakelock_plus`) is in `quran_data/data`, given in
/// `app/dependencies.dart`; tests and the default do nothing.
abstract interface class ScreenWake {
  Future<void> set({required bool on});
}

class NoScreenWake implements ScreenWake {
  const NoScreenWake();

  @override
  Future<void> set({required bool on}) async {}
}

final screenWakeProvider = Provider<ScreenWake>((ref) => const NoScreenWake());
