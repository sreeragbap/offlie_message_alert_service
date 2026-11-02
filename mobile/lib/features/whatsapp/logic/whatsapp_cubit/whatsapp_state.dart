part of 'whatsapp_cubit.dart';

class WhatsAppOverview extends Equatable {
  const WhatsAppOverview({required this.status, required this.messages});

  final WhatsAppStatus status;
  final List<WaMessage> messages;

  @override
  List<Object?> get props => [status, messages];
}
