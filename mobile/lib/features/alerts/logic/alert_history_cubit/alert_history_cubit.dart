import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/network/api_exception.dart';
import 'package:offline_alert/features/alerts/domain/models/alert.dart';
import 'package:offline_alert/features/alerts/domain/repository/alert_repository.dart';

part 'alert_history_state.dart';

@injectable
class AlertHistoryCubit extends Cubit<AlertHistoryState> {
  AlertHistoryCubit(this._alerts, {@ignoreParam this.pageSize = 20}) : super(const AlertHistoryState());

  final AlertRepository _alerts;
  final int pageSize;

  Future<void> refresh() => _load(reset: true);

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    await _load(reset: false);
  }

  Future<void> _load({required bool reset}) async {
    final base = reset ? const AlertHistoryState() : state;
    emit(AlertHistoryState(
      items: base.items,
      nextPage: base.nextPage,
      totalItems: base.totalItems,
      loadedOnce: state.loadedOnce,
      loading: true,
    ));
    try {
      final page = await _alerts.list(page: base.nextPage, size: pageSize);
      emit(AlertHistoryState(
        items: [...base.items, ...page.items],
        nextPage: base.nextPage + 1,
        totalItems: page.totalItems,
        loadedOnce: true,
      ));
    } on ApiException catch (e) {
      emit(AlertHistoryState(
        items: base.items,
        nextPage: base.nextPage,
        totalItems: base.totalItems,
        loadedOnce: state.loadedOnce,
        error: e,
      ));
    }
  }
}
