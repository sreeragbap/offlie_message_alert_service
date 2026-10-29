import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/notifications/alert_reminders.dart';
import '../../../core/state/resource.dart';
import '../../alerts/data/alert_repository.dart';
import '../data/dashboard.dart';

class DashboardCubit extends Cubit<Resource<Dashboard>> {
  DashboardCubit(this._dashboard, this._alerts, this._reminders) : super(const Loading());

  final DashboardRepository _dashboard;
  final AlertRepository _alerts;
  final AlertReminders _reminders;

  Future<void> load() async {
    if (state is! Loaded) emit(const Loading());
    try {
      final dashboard = await _dashboard.load();
      emit(Loaded(dashboard));
      await _syncReminders();
    } on ApiException catch (e) {
      emit(Failed(e));
    }
  }

  /// Keeps device reminders in line with the server (e.g. after reinstalling the app).
  Future<void> _syncReminders() async {
    try {
      final open = await _alerts.list(openOnly: true, size: 100);
      await _reminders.sync(open.items);
    } on ApiException {
      // Not critical: reminders are re-synced on the next load.
    }
  }
}
