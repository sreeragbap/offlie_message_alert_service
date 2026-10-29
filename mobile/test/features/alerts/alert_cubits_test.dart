import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:offline_alert/core/network/api_exception.dart';
import 'package:offline_alert/core/notifications/alert_reminders.dart';
import 'package:offline_alert/core/sms/sms_composer.dart';
import 'package:offline_alert/core/state/resource.dart';
import 'package:offline_alert/features/alerts/data/alert.dart';
import 'package:offline_alert/features/alerts/data/alert_repository.dart';
import 'package:offline_alert/features/alerts/presentation/alert_detail_cubit.dart';
import 'package:offline_alert/features/alerts/presentation/alert_history_cubit.dart';
import 'package:offline_alert/features/alerts/presentation/new_alert_cubit.dart';
import 'package:offline_alert/features/preferences/data/alert_preferences.dart';
import 'package:offline_alert/features/recipients/data/recipient_repository.dart';

import '../../fixtures.dart';

class _Recipients extends Mock implements RecipientRepository {}

class _Preferences extends Mock implements AlertPreferencesRepository {}

class _Alerts extends Mock implements AlertRepository {}

class _Reminders extends Mock implements AlertReminders {}

class _Composer extends Mock implements SmsComposer {}

const _prefs = AlertPreferences(
    defaultDelayMinutes: 45, maxAlertsPerRecipientPerDay: 3, maxAlertsPerDay: 20, messageTemplate: 'Hi {name}');

void main() {
  late _Recipients recipients;
  late _Preferences preferences;
  late _Alerts alerts;
  late _Reminders reminders;

  setUpAll(() => registerFallbackValue(MessagingPlatform.whatsapp));

  setUp(() {
    recipients = _Recipients();
    preferences = _Preferences();
    alerts = _Alerts();
    reminders = _Reminders();
    when(() => recipients.list()).thenAnswer((_) async => [anu, disabledRavi]);
    when(() => preferences.load()).thenAnswer((_) async => _prefs);
    when(() => reminders.requestPermission()).thenAnswer((_) async {});
    when(() => reminders.schedule(any())).thenAnswer((_) async {});
    when(() => reminders.cancel(any())).thenAnswer((_) async {});
  });

  setUpAll(() => registerFallbackValue(alert()));

  NewAlertCubit newCubit() => NewAlertCubit(recipients, preferences, alerts, reminders);

  group('NewAlertCubit', () {
    test('offers only recipients who can get alerts and uses the default delay', () async {
      final cubit = newCubit();
      await cubit.load();
      expect(cubit.state.recipients, const Loaded([anu]));
      expect(cubit.state.recipientId, 'r1'); // only one choice: preselected
      expect(cubit.state.delayMinutes, 45);
    });

    test('scheduled alert sets a reminder', () async {
      when(() => alerts.create(
            clientRequestId: any(named: 'clientRequestId'),
            recipientId: 'r1',
            platform: MessagingPlatform.whatsapp,
            delayMinutes: 45,
          )).thenAnswer((_) async => alert(state: 'SCHEDULED'));
      final cubit = newCubit();
      await cubit.load();
      await cubit.submit();

      expect(cubit.state.status, ActionStatus.done);
      verify(() => reminders.schedule(any())).called(1);
    });

    test('retrying after a failure reuses the request id; changing the choice does not', () async {
      final ids = <String>[];
      when(() => alerts.create(
            clientRequestId: any(named: 'clientRequestId'),
            recipientId: any(named: 'recipientId'),
            platform: any(named: 'platform'),
            delayMinutes: any(named: 'delayMinutes'),
          )).thenAnswer((invocation) async {
        ids.add(invocation.namedArguments[#clientRequestId] as String);
        throw ApiException.network;
      });
      final cubit = newCubit();
      await cubit.load();
      await cubit.submit();
      expect(cubit.state.error, ApiException.network.message);
      await cubit.submit();
      cubit.selectDelay(0);
      await cubit.submit();

      expect(ids[0], ids[1]);
      expect(ids[2], isNot(ids[1]));
    });
  });

  group('AlertDetailCubit', () {
    late _Composer composer;

    setUp(() {
      composer = _Composer();
      when(() => alerts.get('a1')).thenAnswer((_) async => alert(state: 'DUE'));
    });

    blocTest<AlertDetailCubit, AlertDetailState>(
      'confirming a send records it and removes the reminder',
      build: () => AlertDetailCubit(alerts, reminders, composer, 'a1'),
      setUp: () => when(() => alerts.markSentFromDevice('a1')).thenAnswer((_) async => alert(state: 'SENT_FROM_DEVICE')),
      act: (cubit) async {
        await cubit.load();
        await cubit.confirmSent();
      },
      skip: 2,
      expect: () => [AlertDetailState(alert: Loaded(alert(state: 'SENT_FROM_DEVICE')))],
      verify: (_) => verify(() => reminders.cancel('a1')).called(1),
    );

    blocTest<AlertDetailCubit, AlertDetailState>(
      'reports when no SMS app is available',
      build: () => AlertDetailCubit(alerts, reminders, composer, 'a1'),
      setUp: () => when(() => composer.open(phoneE164: any(named: 'phoneE164'), body: any(named: 'body')))
          .thenAnswer((_) async => false),
      act: (cubit) async {
        await cubit.load();
        expect(await cubit.openSmsApp(), isFalse);
      },
      skip: 1,
      expect: () => [AlertDetailState(alert: Loaded(alert(state: 'DUE')), error: 'No SMS app found on this device.')],
    );

    blocTest<AlertDetailCubit, AlertDetailState>(
      'keeps the alert and shows the error when cancelling fails',
      build: () => AlertDetailCubit(alerts, reminders, composer, 'a1'),
      setUp: () => when(() => alerts.cancel('a1')).thenThrow(
          const ApiException('INVALID_STATE', 'Only alerts that have not been sent can be cancelled.')),
      act: (cubit) async {
        await cubit.load();
        await cubit.cancel();
      },
      skip: 2,
      expect: () => [
        AlertDetailState(
            alert: Loaded(alert(state: 'DUE')), error: 'Only alerts that have not been sent can be cancelled.'),
      ],
    );
  });

  group('AlertHistoryCubit', () {
    test('pages through history', () async {
      when(() => alerts.list(page: 0, size: 2))
          .thenAnswer((_) async => AlertPage(items: [alert(id: '1'), alert(id: '2')], page: 0, totalItems: 3));
      when(() => alerts.list(page: 1, size: 2))
          .thenAnswer((_) async => AlertPage(items: [alert(id: '3')], page: 1, totalItems: 3));
      final cubit = AlertHistoryCubit(alerts, pageSize: 2);

      await cubit.refresh();
      expect(cubit.state.items.map((a) => a.id), ['1', '2']);
      expect(cubit.state.hasMore, isTrue);

      await cubit.loadMore();
      expect(cubit.state.items.map((a) => a.id), ['1', '2', '3']);
      expect(cubit.state.hasMore, isFalse);

      await cubit.loadMore();
      verifyNever(() => alerts.list(page: 2, size: 2));
    });
  });
}
