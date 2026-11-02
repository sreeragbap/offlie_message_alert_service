import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/device/screen_wake_lock.dart';
import 'package:offline_alert/core/network/api_exception.dart';
import 'package:offline_alert/core/sms/sms_relay_channel.dart';
import 'package:offline_alert/features/relay/domain/repository/relay_repository.dart';

part 'relay_state.dart';

/// Relay mode: while running, asks the backend for due SMS every [interval], sends each from this
/// phone's SIM and reports the outcome. A report that fails to reach the backend is retried on the
/// next check, so an SMS is never sent twice for one alert.
@injectable
class RelayCubit extends Cubit<RelayState> {
  RelayCubit(
    this._repository,
    this._sms,
    this._wakeLock, {
    @ignoreParam this.interval = const Duration(seconds: 15),
  }) : super(const RelayState());

  final RelayRepository _repository;
  final SmsRelayChannel _sms;
  final ScreenWakeLock _wakeLock;
  final Duration interval;

  static const _maxLog = 50;

  Timer? _timer;
  bool _busy = false;
  final _unreported = <String, RelaySendResult>{};

  Future<void> start() async {
    if (state.running) return;
    if (!await _sms.requestPermission()) {
      emit(state.copyWith(permissionDenied: true));
      return;
    }
    await _wakeLock.set(on: true);
    emit(state.copyWith(running: true, permissionDenied: false));
    _timer = Timer.periodic(interval, (_) => checkNow());
    await checkNow();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _wakeLock.set(on: false);
    if (!isClosed) emit(state.copyWith(running: false));
  }

  Future<void> checkNow() async {
    if (_busy || !state.running) return;
    _busy = true;
    try {
      await _flushReports();
      final jobs = await _repository.claim();
      for (final job in jobs) {
        final result = await _sms.send(to: job.toE164, text: job.text, reference: job.alertId);
        _unreported[job.alertId] = result;
        _addLog(RelayLogEntry(at: DateTime.now(), to: job.toE164, outcome: result.outcome, error: result.error));
      }
      await _flushReports();
      if (!isClosed) emit(state.copyWith(lastCheckAt: DateTime.now(), clearConnectionError: true));
    } on ApiException catch (e) {
      if (!isClosed) emit(state.copyWith(lastCheckAt: DateTime.now(), connectionError: e.message));
    } finally {
      _busy = false;
    }
  }

  Future<void> _flushReports() async {
    for (final entry in _unreported.entries.toList()) {
      await _repository.report(entry.key, entry.value.outcome, entry.value.error);
      _unreported.remove(entry.key);
    }
  }

  void _addLog(RelayLogEntry entry) {
    if (isClosed) return;
    emit(state.copyWith(log: [entry, ...state.log].take(_maxLog).toList()));
  }

  @override
  Future<void> close() async {
    await stop();
    return super.close();
  }
}
