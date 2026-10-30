import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/state/resource.dart';
import '../data/whatsapp_message.dart';

class WhatsAppOverview extends Equatable {
  const WhatsAppOverview({required this.status, required this.messages});

  final WhatsAppStatus status;
  final List<WaMessage> messages;

  @override
  List<Object?> get props => [status, messages];
}

/// Recent WhatsApp messages. While the tab is visible it refreshes every [interval] so ticks and
/// alert states update as webhooks arrive.
class WhatsAppCubit extends Cubit<Resource<WhatsAppOverview>> {
  WhatsAppCubit(this._repository, {this.interval = const Duration(seconds: 10)}) : super(const Loading());

  final WhatsAppRepository _repository;
  final Duration interval;
  Timer? _timer;

  Future<void> load() async {
    try {
      final results = await Future.wait([_repository.status(), _repository.recent()]);
      if (!isClosed) {
        emit(Loaded(WhatsAppOverview(status: results[0] as WhatsAppStatus, messages: results[1] as List<WaMessage>)));
      }
    } on ApiException catch (e) {
      // Keep showing the last data during a background refresh.
      if (!isClosed && state is! Loaded) emit(Failed(e));
    }
  }

  void setVisible(bool visible) {
    _timer?.cancel();
    _timer = visible ? Timer.periodic(interval, (_) => load()) : null;
    if (visible) load();
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
