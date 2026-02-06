import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lila/models/log_entry.dart';
import 'package:lila/widgets/log_bottom_sheet.dart';
import 'package:lila/services/file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String fakeDocs;
  late String defaultVault;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lila_sheet_date_test_');
    fakeDocs = '${tempDir.path}/Documents';
    defaultVault = '$fakeDocs/Lila';
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

  testWidgets('accepts date parameter and renders normally', (tester) async {
    final pastDate = DateTime(2026, 1, 20);

    await tester.runAsync(() async {
      await FileService.getInstance();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: LogBottomSheet(
            onLogged: () {},
            date: pastDate,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Sheet still shows mode selection
    expect(find.text('What kind of moment?'), findsOneWidget);
    expect(find.text('Growth'), findsOneWidget);
  });

  testWidgets('date parameter creates entry file for that date', (tester) async {
    final pastDate = DateTime(2026, 1, 20);
    final dateStr = DateFormat('yyyy-MM-dd').format(pastDate);

    await tester.runAsync(() async {
      final fs = await FileService.getInstance();
      // Ensure the Daily directory exists
      await Directory('$defaultVault/Daily').create(recursive: true);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: LogBottomSheet(
            onLogged: () {},
            date: pastDate,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate through the flow
    await tester.tap(find.text('Growth'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Self'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Trigger save by finding and tapping the button, wrapping in runAsync
    // for the file I/O to complete
    await tester.runAsync(() async {
      final state = tester.state<State>(find.byType(LogBottomSheet));
      // Call _saveEntry via the widget's internal state
      // Since it's private, we trigger it through the button's onPressed
      final buttonFinder = find.text('Log without label');
      final textButton = tester.widget<TextButton>(
        find.ancestor(
          of: buttonFinder,
          matching: find.byType(TextButton),
        ),
      );
      textButton.onPressed!();
      await Future.delayed(const Duration(milliseconds: 500));
    });

    // Verify the file was created for the past date
    await tester.runAsync(() async {
      final file = File('$defaultVault/Daily/$dateStr.md');
      expect(await file.exists(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('mode:: growth'));
      expect(content, contains('orientation:: self'));
    });
  });

  testWidgets('null date creates entry file for today', (tester) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);

    await tester.runAsync(() async {
      final fs = await FileService.getInstance();
      await Directory('$defaultVault/Daily').create(recursive: true);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: LogBottomSheet(
            onLogged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Growth'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Self'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final textButton = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Log without label'),
          matching: find.byType(TextButton),
        ),
      );
      textButton.onPressed!();
      await Future.delayed(const Duration(milliseconds: 500));
    });

    await tester.runAsync(() async {
      final file = File('$defaultVault/Daily/$dateStr.md');
      expect(await file.exists(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('mode:: growth'));
    });
  });
}
