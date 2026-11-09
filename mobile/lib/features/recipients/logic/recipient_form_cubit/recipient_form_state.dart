part of 'recipient_form_cubit.dart';

class RecipientFormState extends Equatable {
  const RecipientFormState({
    this.status = ActionStatus.idle,
    this.error,
    this.saved,
    this.autoMessage = const AutoMessage(),
    this.autoLoading = false,
    this.autoLoadError,
  });

  final ActionStatus status;
  final String? error;
  final Recipient? saved;

  /// The automatic message as saved on the backend (the form edits a copy).
  final AutoMessage autoMessage;
  final bool autoLoading;
  final String? autoLoadError;

  RecipientFormState copyWith({
    ActionStatus? status,
    String? Function()? error,
    Recipient? saved,
    AutoMessage? autoMessage,
    bool? autoLoading,
    String? Function()? autoLoadError,
  }) =>
      RecipientFormState(
        status: status ?? this.status,
        error: error != null ? error() : this.error,
        saved: saved ?? this.saved,
        autoMessage: autoMessage ?? this.autoMessage,
        autoLoading: autoLoading ?? this.autoLoading,
        autoLoadError: autoLoadError != null ? autoLoadError() : this.autoLoadError,
      );

  @override
  List<Object?> get props => [status, error, saved, autoMessage, autoLoading, autoLoadError];
}
