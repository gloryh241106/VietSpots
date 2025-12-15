// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vietspots/main.dart';
import 'package:vietspots/screens/main/main_screen.dart';

import 'test_app.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VietSpotsApp());

    // Wait for app to settle
    await tester.pumpAndSettle();

    // Verify that the app has loaded (check for common elements)
    // Since it's a travel app, check for some basic UI elements
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(
      find.byType(Scaffold),
      findsWidgets,
    ); // Should find at least one Scaffold
  });
  testWidgets('MainScreen renders', (tester) async {
    await tester.pumpWidget(buildTestApp(const MainScreen()));
    expect(find.text('VietSpots'), findsWidgets);
  });
}
