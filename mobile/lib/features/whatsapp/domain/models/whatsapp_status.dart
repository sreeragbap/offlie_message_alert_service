import 'package:equatable/equatable.dart';

class WhatsAppStatus extends Equatable {
  const WhatsAppStatus({required this.connected, this.templateName});

  final bool connected;
  final String? templateName;

  @override
  List<Object?> get props => [connected, templateName];
}
