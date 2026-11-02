part of 'recipient_form_cubit.dart';

class RecipientFormState extends Equatable {
  const RecipientFormState({this.status = ActionStatus.idle, this.error, this.saved});

  final ActionStatus status;
  final String? error;
  final Recipient? saved;

  @override
  List<Object?> get props => [status, error, saved];
}
