part of 'alert_history_cubit.dart';

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
