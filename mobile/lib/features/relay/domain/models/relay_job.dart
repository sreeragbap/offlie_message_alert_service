/// An SMS the backend wants this relay phone to send now.
class RelayJob {
  const RelayJob({required this.alertId, required this.toE164, required this.text});

  final String alertId;
  final String toE164;
  final String text;

  factory RelayJob.fromJson(Map<String, dynamic> json) =>
      RelayJob(alertId: json['alertId'] as String, toE164: json['toE164'] as String, text: json['text'] as String);
}
