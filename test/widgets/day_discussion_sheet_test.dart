import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lila/widgets/day_discussion_sheet.dart';
import 'package:lila/services/file_service.dart';
import 'package:lila/models/log_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String fakeDocs;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lila_discussion_sheet_test_');
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

  /// Pump the DayDiscussionSheet directly without bottom sheet wrapper
  Future<void> pumpDirectSheet(
    WidgetTester tester, {
    DateTime? date,
    List<LogEntry>? entries,
    String reflectionText = '',
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) async {
    final testDate = date ?? DateTime(2026, 2, 3);
    final testEntries = entries ??
        [
          LogEntry(
            label: 'Reading',
            mode: Mode.growth,
            orientation: LogOrientation.self_,
            timestamp: testDate.add(const Duration(hours: 10)),
          ),
        ];

    await tester.runAsync(() async {
      await FileService.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) {
            final data =
                MediaQuery.of(context).copyWith(viewInsets: viewInsets);
            return MediaQuery(
              data: data,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: DayDiscussionSheet(
                date: testDate,
                entries: testEntries,
                reflectionText: reflectionText,
              ),
            ),
          ),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 800));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  Future<void> pumpUntilLoaded(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
  }

  group('DayDiscussionSheet UI', () {
    testWidgets('shows header and close button', (tester) async {
      await pumpDirectSheet(tester);

      expect(find.text('Discuss your day'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows input field with placeholder', (tester) async {
      await pumpDirectSheet(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text("What's on your mind?"), findsOneWidget);
    });

    testWidgets('shows send button', (tester) async {
      await pumpDirectSheet(tester);

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('shows empty state when no discussion exists', (tester) async {
      await pumpDirectSheet(tester);

      expect(find.text('Start a conversation about your day'), findsOneWidget);
    });

    testWidgets('moves input above keyboard', (tester) async {
      await pumpDirectSheet(
        tester,
        viewInsets: const EdgeInsets.only(bottom: 300),
      );

      expect(find.byType(AnimatedPadding), findsOneWidget);
    });
  });

  group('DayDiscussionSheet with existing discussion', () {
    testWidgets('loads and displays existing discussion', (tester) async {
      final date = DateTime(2026, 2, 3);

      // Create a file with existing discussion
      await tester.runAsync(() async {
        final fs = await FileService.getInstance();
        final entry = LogEntry(
          label: 'Test',
          mode: Mode.growth,
          orientation: LogOrientation.self_,
          timestamp: date.add(const Duration(hours: 10)),
        );
        await fs.appendEntry(entry);
        await fs.saveDiscussion(date, '''**User:** How was my morning?

**Claude:** You had a productive growth-focused morning.''');
        final stored = await fs.readDiscussion(date);
        expect(stored, isNotNull);
      });

      await pumpDirectSheet(
        tester,
        date: date,
        entries: [
          LogEntry(
            label: 'Test',
            mode: Mode.growth,
            orientation: LogOrientation.self_,
            timestamp: date.add(const Duration(hours: 10)),
          ),
        ],
      );
      await pumpUntilLoaded(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Should show the existing messages
      expect(find.text('How was my morning?'), findsOneWidget);
      expect(find.text('You had a productive growth-focused morning.'), findsOneWidget);
    });

    testWidgets('parses Assistant label in saved discussion', (tester) async {
      final date = DateTime(2026, 2, 3);

      await tester.runAsync(() async {
        final fs = await FileService.getInstance();
        final entry = LogEntry(
          label: 'Test',
          mode: Mode.growth,
          orientation: LogOrientation.self_,
          timestamp: date.add(const Duration(hours: 10)),
        );
        await fs.appendEntry(entry);
        await fs.saveDiscussion(date, '''**User:** Noticing patterns

**Assistant:** That sounds like a reflective moment.''');
        final stored = await fs.readDiscussion(date);
        expect(stored, isNotNull);
      });

      await pumpDirectSheet(
        tester,
        date: date,
        entries: [
          LogEntry(
            label: 'Test',
            mode: Mode.growth,
            orientation: LogOrientation.self_,
            timestamp: date.add(const Duration(hours: 10)),
          ),
        ],
      );
      await pumpUntilLoaded(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      expect(find.text('Noticing patterns'), findsOneWidget);
      expect(find.text('That sounds like a reflective moment.'), findsOneWidget);
    });
  });

  group('DayDiscussionSheet message input', () {
    testWidgets('user can type in input field', (tester) async {
      await pumpDirectSheet(tester);

      await tester.enterText(find.byType(TextField), 'Hello Claude');
      await tester.pump();

      expect(find.text('Hello Claude'), findsOneWidget);
    });

    testWidgets('empty input field shows placeholder', (tester) async {
      await pumpDirectSheet(tester);

      expect(find.text("What's on your mind?"), findsOneWidget);
    });
  });
}
