import 'package:flutter_test/flutter_test.dart';
import 'package:vietspots/screens/main/notification_screen.dart';

import 'test_app.dart';

void main() {
  testWidgets('Tapping a notification opens detail screen', (tester) async {
    await tester.pumpWidget(buildTestApp(const NotificationScreen()));

    // Tap first notification tile.
    await tester.tap(find.text('System Update'));
    await tester.pumpAndSettle();

    expect(find.text('Notification Details'), findsOneWidget);
    expect(find.text('System Update'), findsOneWidget);
  });
}
