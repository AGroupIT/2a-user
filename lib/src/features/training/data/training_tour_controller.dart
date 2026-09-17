import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Progress means a viewed explanation, never a completed business operation.
class TrainingTourController extends ChangeNotifier {
  final SharedPreferences preferences;
  final String scopeKey;
  List<String> _steps = const [];
  final Set<String> _viewed = {};
  int _index = 0;
  bool _active = false;
  bool _complete = false;
  bool _disposed = false;
  bool _saveFailed = false;
  String? _resumeId;
  Future<void> _pendingSave = Future.value();

  TrainingTourController(this.preferences, {required this.scopeKey}) {
    try {
      final raw = preferences.getString(storageKey);
      if (raw != null) {
        final data = jsonDecode(raw);
        if (data is Map) {
          if (data['step'] is String) _resumeId = data['step'] as String;
          if (data['viewed'] is List) {
            _viewed.addAll((data['viewed'] as List).whereType<String>());
          }
        }
      }
    } on FormatException {
      // Recover a damaged or old local snapshot without touching account data.
    } on TypeError {
      // Preferences may have a value written by an incompatible prototype.
    }
  }

  String get storageKey => 'training_tour_v1_${Uri.encodeComponent(scopeKey)}';
  bool get active => _active;
  bool get complete => _complete;
  bool get saveFailed => _saveFailed;
  int get index => _index;
  int get length => _steps.length;
  String? get currentId => _steps.isEmpty ? null : _steps[_index];
  String? get resumeId => _resumeId;
  Set<String> get viewed => Set.unmodifiable(_viewed);
  Future<void> get settled => _pendingSave;

  void start(List<String> steps, {String? initialStepId, bool resume = true}) {
    if (steps.isEmpty || steps.toSet().length != steps.length) {
      throw ArgumentError.value(steps, 'steps');
    }
    _steps = List.unmodifiable(steps);
    final wanted = initialStepId ?? (resume ? _resumeId : null);
    final found = wanted == null ? -1 : _steps.indexOf(wanted);
    _index = found < 0 ? 0 : found;
    _active = true;
    _complete = false;
    _save();
    notifyListeners();
  }

  void next({bool skip = false}) {
    if (!_active || _complete) return;
    if (!skip) _viewed.add(currentId!);
    if (_index + 1 < _steps.length) {
      _index++;
    } else {
      _complete = true;
    }
    _save();
    notifyListeners();
  }

  void previous() {
    if (!_active || _index == 0) return;
    _index--;
    _complete = false;
    _save();
    notifyListeners();
  }

  void stop() {
    if (!_active) return;
    _active = false;
    _save();
    notifyListeners();
  }

  void retrySave() => _save();

  void _save() {
    _resumeId = _complete ? null : currentId;
    final snapshot = jsonEncode({
      'step': _resumeId,
      'viewed': _viewed.toList(),
    });
    // Serialize saves so a slower previous step cannot overwrite the newest one.
    _pendingSave = _pendingSave.then((_) async {
      var ok = false;
      try {
        ok = await preferences.setString(storageKey, snapshot);
      } catch (_) {
        ok = false;
      }
      if (_disposed) return;
      if (_saveFailed == !ok) return;
      _saveFailed = !ok;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
