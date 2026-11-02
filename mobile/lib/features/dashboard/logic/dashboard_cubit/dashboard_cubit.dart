import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/bloc/resource.dart';
import 'package:offline_alert/core/network/api_exception.dart';
import 'package:offline_alert/core/notifications/alert_reminders.dart';
import 'package:offline_alert/features/alerts/domain/repository/alert_repository.dart';
import 'package:offline_alert/features/dashboard/domain/models/dashboard.dart';
import 'package:offline_alert/features/dashboard/domain/repository/dashboard_repository.dart';

@injectable
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
