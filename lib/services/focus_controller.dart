import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/focus_state.dart';
import 'intention_service.dart';

class FocusController extends ChangeNotifier {
  static const _darkModeKey = 'lila_dark_mode';

  FocusState _state = FocusState.defaultState();
  bool _loading = true;
  Brightness _brightness = Brightness.dark;

  FocusState get state => _state;
  bool get isLoading => _loading;
  Brightness get brightness => _brightness;

  Future<void> load() async {
    try {
      final service = await IntentionService.getInstance();
      _state = await service.readCurrent();
    } catch (_) {
      // Fall back to default.
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_darkModeKey) ?? true;
      _brightness = isDark ? Brightness.dark : Brightness.light;
    } catch (_) {
      // Fall back to dark.
    }
    _loading = false;
    notifyListeners();
  }

  void update(FocusState state) {
    _state = state;
    _loading = false;
    notifyListeners();
  }

  Future<void> setBrightness(Brightness brightness) async {
    if (_brightness == brightness) return;
    _brightness = brightness;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, brightness == Brightness.dark);
  }
}
