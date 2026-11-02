part of 'alert_detail_cubit.dart';

class AlertDetailState extends Equatable {
  const AlertDetailState({this.alert = const Loading(), this.busy = false, this.error});

  final Resource<Alert> alert;
  final bool busy;
  final String? error;

  @override
  List<Object?> get props => [alert, busy, error];
}
