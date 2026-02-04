import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lila/main.dart';
import 'package:lila/models/focus_state.dart';
import 'package:lila/services/focus_controller.dart';
import 'package:lila/theme/lila_theme.dart';

void main() {
  testWidgets('Theme uses sanctuary palette when in sanctuary',
      (WidgetTester tester) async {
    final controller = FocusController();
    controller.update(const FocusState(
      season: FocusSeason.sanctuary,
      intention: '',
      setAt: null,
    ));

    await tester.pumpWidget(
      LilaApp(
        focusController: controller,
        homeOverride: const SizedBox.shrink(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.scaffoldBackgroundColor,
        LilaTheme.sanctuary.scaffoldBackgroundColor);
  });

  testWidgets('Theme switches when focus changes',
      (WidgetTester tester) async {
    final controller = FocusController();
    controller.update(FocusState.defaultState());

    await tester.pumpWidget(
      LilaApp(
        focusController: controller,
        homeOverride: const SizedBox.shrink(),
      ),
    );
    var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.scaffoldBackgroundColor,
        LilaTheme.builder.scaffoldBackgroundColor);

    controller.update(const FocusState(
      season: FocusSeason.sanctuary,
      intention: '',
      setAt: null,
    ));
    await tester.pump();

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.scaffoldBackgroundColor,
        LilaTheme.sanctuary.scaffoldBackgroundColor);
  });
}
