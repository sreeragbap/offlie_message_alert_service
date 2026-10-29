import 'package:offline_alert/features/alerts/data/alert.dart';
import 'package:offline_alert/features/recipients/data/recipient.dart';

Map<String, dynamic> alertJson({
  String id = 'a1',
  String state = 'SCHEDULED',
  String channel = 'DEVICE_SMS',
  bool withRecipient = true,
}) =>
    {
      'id': id,
      'recipient': withRecipient ? {'id': 'r1', 'displayName': 'Anu', 'phoneE164': '+919876543210'} : null,
      'platform': 'WHATSAPP',
      'channel': channel,
      'state': state,
      'triggerSource': 'USER_TRIGGERED',
      'messageText': "Hi Anu, I've sent you a message on WhatsApp.",
      'dueAt': '2026-10-29T10:30:00Z',
      'createdAt': '2026-10-29T10:00:00Z',
      'completedAt': null,
      'deliveryConfirmed': false,
      'note': null,
    };

Alert alert({String id = 'a1', String state = 'SCHEDULED', bool withRecipient = true}) =>
    Alert.fromJson(alertJson(id: id, state: state, withRecipient: withRecipient));

const anu = Recipient(id: 'r1', displayName: 'Anu', phoneE164: '+919876543210', alertsEnabled: true, optedOut: false);
const disabledRavi =
    Recipient(id: 'r2', displayName: 'Ravi', phoneE164: '+919812345678', alertsEnabled: false, optedOut: false);
