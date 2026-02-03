import 'package:flutter_test/flutter_test.dart';
import 'package:lila/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const LilaApp());
    expect(find.text('Today'), findsOneWidget);
  });
}
