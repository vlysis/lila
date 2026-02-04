import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'services/file_service.dart';
import 'services/focus_controller.dart';
import 'theme/lila_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FileService.getInstance();
  final focusController = FocusController();
  await focusController.load();
  runApp(LilaApp(focusController: focusController));
}

class LilaApp extends StatelessWidget {
  final FocusController focusController;
  final Widget? homeOverride;

  const LilaApp({
    super.key,
    required this.focusController,
    this.homeOverride,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: focusController,
      builder: (context, _) {
        final theme = LilaTheme.forSeason(focusController.state.season);
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: theme.scaffoldBackgroundColor,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
        );

        return MaterialApp(
          title: 'Lila',
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: homeOverride ?? HomeScreen(focusController: focusController),
        );
      },
    );
  }
}
