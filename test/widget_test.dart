import 'package:daily_activity_tracker/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('opens the Daylight timeline', (tester) async {
    SharedPreferences.setMockInitialValues({'daylight-guest-mode': true});

    await tester.pumpWidget(const DaylightApp());
    await tester.pumpAndSettle();

    expect(find.text('DAYLIGHT'), findsOneWidget);
    expect(find.text('Timeline'), findsWidgets);
    expect(find.text('Log time'), findsOneWidget);
  });
}
