import 'package:injectable/injectable.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on, so Android does not throttle a foreground loop.
@lazySingleton
class ScreenWakeLock {
  Future<void> set({required bool on}) => on ? WakelockPlus.enable() : WakelockPlus.disable();
}
