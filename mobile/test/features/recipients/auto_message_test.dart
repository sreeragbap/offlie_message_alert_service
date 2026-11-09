import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:offline_alert/core/bloc/resource.dart';
import 'package:offline_alert/core/network/api_exception.dart';
import 'package:offline_alert/features/recipients/domain/models/auto_message.dart';
import 'package:offline_alert/features/recipients/domain/repository/recipient_repository.dart';
import 'package:offline_alert/features/recipients/logic/recipient_form_cubit/recipient_form_cubit.dart';

import '../../fixtures.dart';

class _Recipients extends Mock implements RecipientRepository {}

Map<String, dynamic> _json({
  String? sendTime,
  List<String> days = weekdays,
  bool enabled = true,
}) => {
  'enabled': enabled,
  'text': null,
  'defaultText': 'Hi {name}, this is an automatic message from {sender}.',
  'preview': 'Hi Anu, this is an automatic message from Someone.',
  'sendTime': sendTime,
  'days': days,
  'timeZone': 'Asia/Kolkata',
  'smsAfterMinutes': 1,
  'nextRunAt': '2026-11-09T03:30:00Z',
  'lastRunAt': null,
  'lastMessageId': null,
  'lastError': null,
};

void main() {
  setUpAll(() => registerFallbackValue(const AutoMessage()));

  group('AutoMessage', () {
    test('reads a repeating message from the backend', () {
      final m = AutoMessage.fromJson(
        _json(sendTime: '09:05', days: ['MONDAY', 'FRIDAY']),
      );
      expect(m.repeating, isTrue);
      expect(m.sendTime, const TimeOfDay(hour: 9, minute: 5));
      expect(m.days, ['MONDAY', 'FRIDAY']);
      expect(m.nextRunAt, DateTime.parse('2026-11-09T03:30:00Z').toLocal());
    });

    test(
      'a one-off sends no time or days, so the backend sends it a minute after saving',
      () {
        expect(const AutoMessage(enabled: true).toJson(), {
          'enabled': true,
          'smsAfterMinutes': 1,
        });
      },
    );

    test('a repeating message sends HH:mm, days and its text', () {
      const m = AutoMessage(
        enabled: true,
        text: 'Hi {name}',
        sendTime: TimeOfDay(hour: 7, minute: 0),
        days: ['SUNDAY'],
        smsAfterMinutes: 5,
      );
      expect(m.toJson(), {
        'enabled': true,
        'text': 'Hi {name}',
        'sendTime': '07:00',
        'days': ['SUNDAY'],
        'smsAfterMinutes': 5,
      });
    });

    test('status fields do not count as a change', () {
      final saved = AutoMessage.fromJson(_json());
      expect(const AutoMessage(enabled: true).sameSettingsAs(saved), isTrue);
      expect(
        const AutoMessage(
          enabled: true,
          smsAfterMinutes: 5,
        ).sameSettingsAs(saved),
        isFalse,
      );
    });
  });

  group('RecipientFormCubit with an automatic message', () {
    late _Recipients recipients;

    setUp(() {
      recipients = _Recipients();
      when(
        () => recipients.create(
          displayName: any(named: 'displayName'),
          phone: any(named: 'phone'),
        ),
      ).thenAnswer((_) async => anu);
      when(
        () => recipients.update(
          any(),
          displayName: any(named: 'displayName'),
          phone: any(named: 'phone'),
          optedOut: any(named: 'optedOut'),
        ),
      ).thenAnswer((_) async => anu);
    });

    test(
      'a new recipient is created, then its automatic message is saved',
      () async {
        when(
          () => recipients.saveAutoMessage(any(), any()),
        ).thenAnswer((_) async => AutoMessage.fromJson(_json()));
        final cubit = RecipientFormCubit(recipients);

        await cubit.save(
          displayName: 'Anu',
          phone: '9876543210',
          optedOut: false,
          autoMessage: const AutoMessage(enabled: true),
        );

        expect(cubit.state.status, ActionStatus.done);
        verify(
          () => recipients.saveAutoMessage(
            'r1',
            const AutoMessage(enabled: true),
          ),
        ).called(1);
      },
    );

    test('an unchanged automatic message is not saved again', () async {
      when(
        () => recipients.getAutoMessage('r1'),
      ).thenAnswer((_) async => AutoMessage.fromJson(_json()));
      final cubit = RecipientFormCubit(recipients, existing: anu);
      await cubit.loadAutoMessage();

      await cubit.save(
        displayName: 'Anu',
        phone: '+919876543210',
        optedOut: false,
        autoMessage: const AutoMessage(enabled: true),
      );

      expect(cubit.state.status, ActionStatus.done);
      verifyNever(() => recipients.saveAutoMessage(any(), any()));
    });

    test(
      'saving again sends a one-off that already went, as the screen says',
      () async {
        final sent = AutoMessage.fromJson({
          ..._json(),
          'nextRunAt': null,
          'lastRunAt': '2026-11-05T10:29:10Z',
        });
        when(
          () => recipients.getAutoMessage('r1'),
        ).thenAnswer((_) async => sent);
        when(
          () => recipients.saveAutoMessage(any(), any()),
        ).thenAnswer((_) async => AutoMessage.fromJson(_json()));
        final cubit = RecipientFormCubit(recipients, existing: anu);
        await cubit.loadAutoMessage();

        await cubit.save(
          displayName: 'Anu',
          phone: '+919876543210',
          optedOut: false,
          autoMessage: const AutoMessage(enabled: true),
        );

        verify(
          () => recipients.saveAutoMessage(
            'r1',
            const AutoMessage(enabled: true),
          ),
        ).called(1);
      },
    );

    test(
      'retrying after the automatic message failed does not create the recipient twice',
      () async {
        var calls = 0;
        when(() => recipients.saveAutoMessage(any(), any())).thenAnswer((
          _,
        ) async {
          if (calls++ == 0) {
            throw const ApiException(
              'INVALID_TEXT',
              'Unknown placeholder {phone}.',
            );
          }
          return AutoMessage.fromJson(_json());
        });
        final cubit = RecipientFormCubit(recipients);
        const auto = AutoMessage(enabled: true, text: 'Hi {phone}');

        await cubit.save(
          displayName: 'Anu',
          phone: '9876543210',
          optedOut: false,
          autoMessage: auto,
        );
        expect(cubit.state.status, ActionStatus.failed);
        expect(cubit.state.error, 'Unknown placeholder {phone}.');

        await cubit.save(
          displayName: 'Anu',
          phone: '9876543210',
          optedOut: false,
          autoMessage: auto,
        );
        expect(cubit.state.status, ActionStatus.done);
        verify(
          () => recipients.create(displayName: 'Anu', phone: '9876543210'),
        ).called(1);
      },
    );
  });
}
