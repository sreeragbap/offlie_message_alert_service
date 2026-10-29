import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_alert/core/network/api_exception.dart';
import 'package:offline_alert/core/notifications/alert_reminders.dart';
import 'package:offline_alert/core/sms/sms_composer.dart';

void main() {
  group('SmsComposer.buildUri', () {
    test('uses ?body= on Android and encodes the text', () {
      final uri = SmsComposer.buildUri(
          phoneE164: '+919876543210', body: 'Hi Anu, check WhatsApp & reply', platform: TargetPlatform.android);
      expect(uri.toString(), 'sms:+919876543210?body=Hi%20Anu%2C%20check%20WhatsApp%20%26%20reply');
    });

    test('uses &body= on iOS', () {
      final uri = SmsComposer.buildUri(phoneE164: '+919876543210', body: 'Hi', platform: TargetPlatform.iOS);
      expect(uri.toString(), 'sms:+919876543210&body=Hi');
    });
  });

  group('AlertReminders.notificationId', () {
    test('is stable and fits in 31 bits', () {
      const id = '3f2b8c1e-8d4a-4c55-9f1e-0a1b2c3d4e5f';
      expect(AlertReminders.notificationId(id), AlertReminders.notificationId(id));
      expect(AlertReminders.notificationId(id), inInclusiveRange(0, 0x7fffffff));
      expect(AlertReminders.notificationId(id), isNot(AlertReminders.notificationId('other')));
    });
  });

  group('ApiException.fromDio', () {
    final request = RequestOptions(path: '/alerts');

    test('uses the problem detail from the server', () {
      final e = ApiException.fromDio(DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 429,
          data: {'code': 'RECIPIENT_RATE_LIMITED', 'detail': "You've reached the daily alert limit for Anu."},
        ),
      ));
      expect(e.code, 'RECIPIENT_RATE_LIMITED');
      expect(e.message, "You've reached the daily alert limit for Anu.");
      expect(e.statusCode, 429);
    });

    test('maps missing response to a network error', () {
      final e = ApiException.fromDio(DioException(requestOptions: request, type: DioExceptionType.connectionError));
      expect(e.code, 'NETWORK');
    });

    test('never shows raw server errors', () {
      final e = ApiException.fromDio(DioException(
        requestOptions: request,
        response: Response(requestOptions: request, statusCode: 502, data: '<html>Bad gateway</html>'),
      ));
      expect(e.message, 'Something went wrong. Please try again.');
    });
  });
}
