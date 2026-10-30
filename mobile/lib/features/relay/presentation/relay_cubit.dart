import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/sms/sms_relay_channel.dart';
import '../data/relay_repository.dart';

class RelayLogEntry extends Equatable {
  const RelayLogEntry({required this.at, required this.to, required this.outcome, this.error});

  final DateTime at;
  final String to;
  final RelaySendOutcome outcome;
  final String? error;

  @override
  List<Object?> get props => [at, to, outcome, error];
}

class RelayState extends Equatable {
  const RelayState({
    this.running = false,
    this.permissionDenied = false,
    this.lastCheckAt,
    this.connectionError,
    this.log = const [],
  });

  final bool running;
  final bool permissionDenied;
  final DateTime? lastCheckAt;
  final String? connectionError;
  final List<RelayLogEntry> log;

  RelayState copyWith({
    bool? running,
    bool? permissionDenied,
    DateTime? lastCheckAt,
    String? connectionError,
    bool clearConnectionError = false,
    List<RelayLogEntry>? log,
  }) => RelayState(
    running: running ?? this.running,
    permissionDenied: permissionDenied ?? this.permissionDenied,
    lastCheckAt: lastCheckAt ?? this.lastCheckAt,
    connectionError: clearConnectionError ? null : (connectionError ?? this.connectionError),
    log: log ?? this.log,
  );

  @override
  List<Object?> get props => [running, permissionDenied, lastCheckAt, connectionError, log];
}

/// Relay mode: while running, asks the backend for due SMS every [interval], sends each from this
/// phone's SIM and reports the outcome. A report that fails to reach the backend is retried on the
/// next check, so an SMS is never sent twice for one alert.
class RelayCubit extends Cubit<RelayState> {
  RelayCubit(
    this._repository,
    this._sms, {
    required this.requestPermission,
    required this.keepScreenOn,
    this.interval = const Duration(seconds: 15),
  }) : super(const RelayState());

  final RelayRepository _repository;
  final SmsRelayChannel _sms;
  final Future<bool> Function() requestPermission;
  final Future<void> Function(bool on) keepScreenOn;
  final Duration interval;

  static const _maxLog = 50;

  Timer? _timer;
  bool _busy = false;
  final _unreported = <String, RelaySendResult>{};

  Future<void> start() async {
    if (state.running) return;
    if (!await requestPermission()) {
      emit(state.copyWith(permissionDenied: true));
      return;
    }
    await keepScreenOn(true);
    emit(state.copyWith(running: true, permissionDenied: false));
    _timer = Timer.periodic(interval, (_) => checkNow());
    await checkNow();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await keepScreenOn(false);
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
