import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lila/widgets/armed_swipe_to_delete.dart';

void main() {
  Widget _buildTestWidget({required Future<void> Function() onDelete}) {
    return MaterialApp(
      home: _TestHost(onDelete: onDelete),
    );
  }

  testWidgets('does not delete on swipe alone', (tester) async {
    var deleted = false;
    await tester.pumpWidget(_buildTestWidget(onDelete: () async {
      deleted = true;
    }));

    await tester.drag(find.text('Row'), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(deleted, isFalse);
  });

  testWidgets('reveal shows delete button and tap deletes', (tester) async {
    var deleted = false;
    await tester.pumpWidget(_buildTestWidget(onDelete: () async {
      deleted = true;
    }));

    await tester.drag(find.text('Row'), const Offset(-120, 0));
    await tester.pump();

    final deletePill = find.byKey(const ValueKey('armed_delete_pill'));
    expect(deletePill, findsOneWidget);

    await tester.tap(deletePill);
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });

  testWidgets('tap outside hides delete button', (tester) async {
    await tester.pumpWidget(_buildTestWidget(onDelete: () async {}));

    await tester.drag(find.text('Row'), const Offset(-120, 0));
    await tester.pump();

    final deletePill = find.byKey(const ValueKey('armed_delete_pill'));
    expect(deletePill, findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('armed_swipe_container')));
    await tester.pumpAndSettle();

    final opacity = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('armed_delete_opacity')),
    );
    expect(opacity.opacity, equals(0));
  });
}

class _TestHost extends StatefulWidget {
  final Future<void> Function() onDelete;

  const _TestHost({required this.onDelete});

  @override
  State<_TestHost> createState() => _TestHostState();
}

class _TestHostState extends State<_TestHost> {
  bool _show = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _show
            ? ArmedSwipeToDelete(
                dismissKey: const ValueKey('dismiss'),
                onDelete: () async {
                  await widget.onDelete();
                  if (mounted) {
                    setState(() => _show = false);
                  }
                },
                child: Container(
                  width: 300,
                  height: 60,
                  alignment: Alignment.centerLeft,
                  color: Colors.grey.shade800,
                  child: const Text(
                    'Row',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
