import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/alert.dart';
import '../data/alert_repository.dart';

class AlertHistoryState extends Equatable {
  const AlertHistoryState({
    this.items = const [],
    this.nextPage = 0,
    this.totalItems = 0,
    this.loading = false,
    this.loadedOnce = false,
    this.error,
  });

  final List<Alert> items;
  final int nextPage;
  final int totalItems;
  final bool loading;
  final bool loadedOnce;
  final ApiException? error;

  bool get hasMore => items.length < totalItems;

  @override
  List<Object?> get props => [items, nextPage, totalItems, loading, loadedOnce, error?.code];
}

class AlertHistoryCubit extends Cubit<AlertHistoryState> {
  AlertHistoryCubit(this._alerts, {this.pageSize = 20}) : super(const AlertHistoryState());

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
