import 'package:flutter/foundation.dart';
import '../models/focus_state.dart';
import 'intention_service.dart';

class FocusController extends ChangeNotifier {
  FocusState _state = FocusState.defaultState();
  bool _loading = true;

  FocusState get state => _state;
  bool get isLoading => _loading;

  Future<void> load() async {
    try {
      final service = await IntentionService.getInstance();
      _state = await service.readCurrent();
    } catch (_) {
      // Fall back to default.
    }
    _loading = false;
    notifyListeners();
  }

  void update(FocusState state) {
    _state = state;
    _loading = false;
    notifyListeners();
  }
}
