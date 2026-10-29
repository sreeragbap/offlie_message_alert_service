import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_alert/features/onboarding/presentation/welcome_page.dart';

void main() {
  testWidgets('welcome screen explains what the app cannot do', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
    await tester.scrollUntilVisible(find.text('Create account'), 200);

    expect(find.text('What this app cannot do'), findsOneWidget);
    expect(find.textContaining('No app can read your personal WhatsApp'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}
