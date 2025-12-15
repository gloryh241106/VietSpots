import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vietspots/screens/auth/registration_screen.dart';

import 'test_app.dart';

void main() {
  testWidgets('Registration requires email/phone/password/confirm', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const RegistrationScreen()));

    await tester.tap(find.text('Register'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Phone number is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('Confirm password is required'), findsOneWidget);
  });

  testWidgets('Registration validates password match', (tester) async {
    await tester.pumpWidget(buildTestApp(const RegistrationScreen()));

    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(1), '0123');
    await tester.enterText(find.byType(TextFormField).at(2), '123456');
    await tester.enterText(find.byType(TextFormField).at(3), 'wrong');

    await tester.tap(find.text('Register'));
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });
}
