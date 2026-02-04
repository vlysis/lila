import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lila/models/focus_state.dart';
import 'package:lila/screens/intention_flow_screen.dart';

void main() {
  testWidgets('shows season choices', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: IntentionFlowScreen()),
    );

    expect(find.text('Builder'), findsOneWidget);
    expect(find.text('Sanctuary'), findsOneWidget);
  });

  testWidgets('long press confirm saves intention', (tester) async {
    FocusState? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => IntentionFlowScreen(
                      initialState: FocusState.defaultState(),
                      onSave: (state) async => saved = state,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Builder'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('intention_input')),
      'Focus on one thing',
    );
    await tester.pump();

    final confirm = find.byKey(const ValueKey('intention_confirm'));
    final center = tester.getCenter(confirm);
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 2600));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.season, FocusSeason.builder);
    expect(saved!.intention, 'Focus on one thing');
  });
}
