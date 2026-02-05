import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lila/widgets/log_bottom_sheet.dart';
import 'package:lila/services/file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String fakeDocs;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lila_log_sheet_test_');
    fakeDocs = '${tempDir.path}/Documents';
    Directory(fakeDocs).createSync();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return fakeDocs;
        }
        return null;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider_macos'),
      (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return fakeDocs;
        }
        return null;
      },
    );

    FileService.resetInstance();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    FileService.resetInstance();
    tempDir.deleteSync(recursive: true);
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) async {
    await tester.runAsync(() async {
      await FileService.getInstance();
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final data = MediaQuery.of(context).copyWith(viewInsets: viewInsets);
          return MediaQuery(
            data: data,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: LogBottomSheet(onLogged: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('log flow', () {
    testWidgets('shows mode selection initially', (tester) async {
      await pumpSheet(tester);

      expect(find.text('What kind of moment?'), findsOneWidget);
      expect(find.text('Nourishment'), findsOneWidget);
      expect(find.text('Growth'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Drift'), findsOneWidget);
    });

    testWidgets('selecting mode shows orientation selection', (tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text('Growth'));
      await tester.pumpAndSettle();

      expect(find.text('Directed toward?'), findsOneWidget);
      expect(find.text('Self'), findsOneWidget);
      expect(find.text('Mutual'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('selecting orientation shows duration selection',
        (tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text('Growth'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Self'));
      await tester.pumpAndSettle();

      expect(find.text('How long?'), findsOneWidget);
      // Growth presets
      expect(find.text('Focused'), findsOneWidget);
      expect(find.text('Deep'), findsOneWidget);
      expect(find.text('Extended'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('selecting duration shows label input with duration badge',
        (tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text('Growth'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Self'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deep'));
      await tester.pumpAndSettle();

      expect(find.text('What was it?'), findsOneWidget);
      expect(find.text('Deep'), findsOneWidget); // Duration badge
      expect(find.text('Log without label'), findsOneWidget);
    });

    testWidgets('skipping duration shows label input without duration badge',
        (tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text('Growth'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Self'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('What was it?'), findsOneWidget);
      // Should not show any duration preset as a badge
      expect(find.text('Focused'), findsNothing);
      expect(find.text('Deep'), findsNothing);
      expect(find.text('Extended'), findsNothing);
    });

    testWidgets('button changes from "Log without label" to "Log" when typing',
        (tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text('Growth'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Self'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Log without label'), findsOneWidget);
      expect(find.text('Log'), findsNothing);

      await tester.enterText(find.byType(TextField), 'R');
      await tester.pumpAndSettle();

      expect(find.text('Log'), findsOneWidget);
      expect(find.text('Log without label'), findsNothing);
    });

    testWidgets('moves input above keyboard', (tester) async {
      await pumpSheet(
        tester,
        viewInsets: const EdgeInsets.only(bottom: 280),
      );

      await tester.tap(find.text('Growth'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Self'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      final insetPadding = tester.widget<AnimatedPadding>(
        find.byKey(const ValueKey('log_sheet_inset_padding')),
      );
      expect(insetPadding.padding, const EdgeInsets.only(bottom: 280));
    });
  });

  group('duration presets per mode', () {
    testWidgets('nourishment shows moment/stretch/immersive', (tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text('Nourishment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Self'));
      await tester.pumpAndSettle();

      expect(find.text('Moment'), findsOneWidget);
      expect(find.text('Stretch'), findsOneWidget);
      expect(find.text('Immersive'), findsOneWidget);
    });

    testWidgets('growth shows focused/deep/extended', (tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text('Growth'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Self'));
      await tester.pumpAndSettle();

      expect(find.text('Focused'), findsOneWidget);
      expect(find.text('Deep'), findsOneWidget);
      expect(find.text('Extended'), findsOneWidget);
    });

    testWidgets('maintenance shows quick/routine/heavy', (tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text('Maintenance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Self'));
      await tester.pumpAndSettle();

      expect(find.text('Quick'), findsOneWidget);
      expect(find.text('Routine'), findsOneWidget);
      expect(find.text('Heavy'), findsOneWidget);
    });

    testWidgets('drift shows energizing/short/spiral', (tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text('Drift'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Self'));
      await tester.pumpAndSettle();

      expect(find.text('Energizing'), findsOneWidget);
      expect(find.text('Short'), findsOneWidget);
      expect(find.text('Spiral'), findsOneWidget);
    });
  });
}
