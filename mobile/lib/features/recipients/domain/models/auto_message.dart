import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show TimeOfDay;

/// Weekdays as the backend names them, Monday first.
const weekdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];

/// The WhatsApp message the backend sends to one recipient by itself, with an SMS alert when it is
/// not delivered in time. With no [sendTime] it goes once, a minute after saving; otherwise every
/// selected day at [sendTime] (India time).
class AutoMessage extends Equatable {
  const AutoMessage({
    this.enabled = false,
    this.text,
    this.defaultText = 'Hi {name}, this is an automatic message from {sender}.',
    this.preview,
    this.sendTime,
    this.days = weekdays,
    this.smsAfterMinutes = 1,
    this.nextRunAt,
    this.lastRunAt,
    this.lastError,
  });

  final bool enabled;

  /// Null: [defaultText] is used.
  final String? text;
  final String defaultText;

  /// The text with the recipient's and the user's names filled in.
  final String? preview;
  final TimeOfDay? sendTime;
  final List<String> days;
  final int smsAfterMinutes;
  final DateTime? nextRunAt;
  final DateTime? lastRunAt;
  final String? lastError;

  bool get repeating => sendTime != null;

  /// Nullable fields take a function, so they can be set back to null.
  AutoMessage copyWith({
    bool? enabled,
    String? Function()? text,
    TimeOfDay? Function()? sendTime,
    List<String>? days,
    int? smsAfterMinutes,
  }) =>
      AutoMessage(
        enabled: enabled ?? this.enabled,
        text: text != null ? text() : this.text,
        defaultText: defaultText,
        preview: preview,
        sendTime: sendTime != null ? sendTime() : this.sendTime,
        days: days ?? this.days,
        smsAfterMinutes: smsAfterMinutes ?? this.smsAfterMinutes,
        nextRunAt: nextRunAt,
        lastRunAt: lastRunAt,
        lastError: lastError,
      );

  factory AutoMessage.fromJson(Map<String, dynamic> json) => AutoMessage(
        enabled: json['enabled'] as bool,
        text: json['text'] as String?,
        defaultText: json['defaultText'] as String,
        preview: json['preview'] as String?,
        sendTime: _time(json['sendTime'] as String?),
        days: (json['days'] as List).cast<String>(),
        smsAfterMinutes: json['smsAfterMinutes'] as int,
        nextRunAt: _date(json['nextRunAt']),
        lastRunAt: _date(json['lastRunAt']),
        lastError: json['lastError'] as String?,
      );

  /// The settings the user can change, as the backend expects them.
  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'text': ?text,
        if (sendTime case final t?) 'sendTime': '${_two(t.hour)}:${_two(t.minute)}',
        if (sendTime != null) 'days': days,
        'smsAfterMinutes': smsAfterMinutes,
      };

  /// Whether the user-editable settings differ (ignores status fields like [nextRunAt]).
  bool sameSettingsAs(AutoMessage other) =>
      enabled == other.enabled &&
      text == other.text &&
      sendTime == other.sendTime &&
      (sendTime == null || _sameDays(days, other.days)) &&
      smsAfterMinutes == other.smsAfterMinutes;

  static bool _sameDays(List<String> a, List<String> b) => a.toSet().length == b.toSet().length && a.toSet().containsAll(b);

  static TimeOfDay? _time(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static DateTime? _date(Object? value) => value == null ? null : DateTime.parse(value as String).toLocal();

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  List<Object?> get props =>
      [enabled, text, defaultText, preview, sendTime, days, smsAfterMinutes, nextRunAt, lastRunAt, lastError];
}
