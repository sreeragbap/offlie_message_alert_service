import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the phone's own messaging app with the number and text filled in.
/// The user reviews and taps Send; this app never sends SMS by itself.
class SmsComposer {
  const SmsComposer();

  Future<bool> open({required String phoneE164, required String body}) {
    return launchUrl(buildUri(phoneE164: phoneE164, body: body, platform: defaultTargetPlatform));
  }

  /// iOS expects `&body=`, Android `?body=`.
  @visibleForTesting
  static Uri buildUri({
    required String phoneE164,
    required String body,
    required TargetPlatform platform,
  }) {
    final separator = platform == TargetPlatform.iOS ? '&' : '?';
    return Uri.parse('sms:$phoneE164${separator}body=${Uri.encodeComponent(body)}');
  }
}
