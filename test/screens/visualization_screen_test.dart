import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lila/models/log_entry.dart';
import 'package:lila/screens/visualization_screen.dart';
import 'package:lila/services/file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String fakeDocs;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lila_viz_test_');
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

    SharedPreferences.setMockInitialValues({});
    FileService.resetInstance();
  });

  tearDown(() {
    FileService.resetInstance();
    tempDir.deleteSync(recursive: true);
  });

  testWidgets('shows empty state when no data', (tester) async {
    await tester.runAsync(() async {
      await FileService.getInstance();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: VisualizationScreen(),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    for (var i = 0; i < 5; i += 1) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Balance Garden'), findsOneWidget);
    expect(find.text('No moments yet.'), findsOneWidget);
  });
}
