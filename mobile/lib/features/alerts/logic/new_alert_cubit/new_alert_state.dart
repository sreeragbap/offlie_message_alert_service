part of 'new_alert_cubit.dart';

class NewAlertState extends Equatable {
  const NewAlertState({
    this.recipients = const Loading(),
    this.recipientId,
    this.platform = MessagingPlatform.whatsapp,
    this.delayMinutes = 30,
    this.status = ActionStatus.idle,
    this.error,
    this.created,
  });

  final Resource<List<Recipient>> recipients;
  final String? recipientId;
  final MessagingPlatform platform;
  final int delayMinutes;
  final ActionStatus status;
  final String? error;
  final Alert? created;

  bool get canSubmit => recipientId != null && status != ActionStatus.working;

  NewAlertState copyWith({
    Resource<List<Recipient>>? recipients,
    String? recipientId,
    MessagingPlatform? platform,
    int? delayMinutes,
    ActionStatus? status,
    String? error,
    Alert? created,
  }) =>
      NewAlertState(
        recipients: recipients ?? this.recipients,
        recipientId: recipientId ?? this.recipientId,
        platform: platform ?? this.platform,
        delayMinutes: delayMinutes ?? this.delayMinutes,
        status: status ?? this.status,
        error: error,
        created: created ?? this.created,
      );

  @override
  List<Object?> get props => [recipients, recipientId, platform, delayMinutes, status, error, created];
}
