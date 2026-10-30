import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:offline_alert/core/network/api_exception.dart';
import 'package:offline_alert/core/sms/sms_relay_channel.dart';
import 'package:offline_alert/features/relay/data/relay_repository.dart';
import 'package:offline_alert/features/relay/presentation/relay_cubit.dart';

class _Repository extends Mock implements RelayRepository {}

class _Sms extends Mock implements SmsRelayChannel {}

const _job = RelayJob(alertId: 'a1', toE164: '+919876543210', text: 'Hi Anu');

void main() {
  late _Repository repository;
  late _Sms sms;
  late List<bool> screenOn;

  setUpAll(() => registerFallbackValue(RelaySendOutcome.sent));

  setUp(() {
    repository = _Repository();
    sms = _Sms();
    screenOn = [];
    when(() => repository.claim()).thenAnswer((_) async => []);
    when(() => repository.report(any(), any(), any())).thenAnswer((_) async {});
  });

  RelayCubit cubit({bool permission = true}) => RelayCubit(
    repository,
    sms,
    requestPermission: () async => permission,
    keepScreenOn: (on) async => screenOn.add(on),
    interval: const Duration(hours: 1),
  );

  test('sends each claimed SMS from the SIM and reports the outcome', () async {
    when(() => repository.claim()).thenAnswer((_) async => [_job]);
    when(
      () => sms.send(
        to: any(named: 'to'),
        text: any(named: 'text'),
        reference: any(named: 'reference'),
      ),
    ).thenAnswer((_) async => const RelaySendResult(RelaySendOutcome.sent));

    final relay = cubit();
    await relay.start();

    verify(() => sms.send(to: '+919876543210', text: 'Hi Anu', reference: 'a1')).called(1);
    verify(() => repository.report('a1', RelaySendOutcome.sent, null)).called(1);
    expect(relay.state.running, isTrue);
    expect(relay.state.log.single.outcome, RelaySendOutcome.sent);
    expect(screenOn, [true]);

    await relay.close();
    expect(screenOn, [true, false]);
  });

  test('a report that could not reach the server is sent on the next check, without resending the SMS', () async {
    when(() => repository.claim()).thenAnswer((_) async => [_job]);
    when(
      () => sms.send(
        to: any(named: 'to'),
        text: any(named: 'text'),
        reference: any(named: 'reference'),
      ),
    ).thenAnswer((_) async => const RelaySendResult(RelaySendOutcome.sent));
    when(() => repository.report(any(), any(), any())).thenThrow(ApiException.network);

    final relay = cubit();
    await relay.start();
    expect(relay.state.connectionError, isNotNull);

    when(() => repository.claim()).thenAnswer((_) async => []);
    when(() => repository.report(any(), any(), any())).thenAnswer((_) async {});
    await relay.checkNow();

    verify(
      () => sms.send(
        to: any(named: 'to'),
        text: any(named: 'text'),
        reference: any(named: 'reference'),
      ),
    ).called(1);
    verify(() => repository.report('a1', RelaySendOutcome.sent, null)).called(2); // failed once, then delivered
    expect(relay.state.connectionError, isNull);
    await relay.close();
  });

  test('does not start without the SMS permission', () async {
    final relay = cubit(permission: false);
    await relay.start();

    expect(relay.state.running, isFalse);
    expect(relay.state.permissionDenied, isTrue);
    verifyNever(() => repository.claim());
    await relay.close();
  });
}
