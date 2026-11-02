part of 'relay_cubit.dart';

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
