import 'package:flutter_test/flutter_test.dart';
import 'package:vietspots/screens/main/chat_screen.dart';

import 'test_app.dart';

void main() {
  testWidgets('Chat empty state shows helper text and input hint', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const ChatScreen()));

    expect(find.text('Hi there!'), findsOneWidget);
    expect(find.text('Ask TourMate...'), findsOneWidget);
    expect(
      find.textContaining('Ask TourMate for sightseeing suggestions'),
      findsOneWidget,
    );
  });
}
