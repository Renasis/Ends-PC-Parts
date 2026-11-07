import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The chosen light / dark / system theme, remembered between launches.
class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_mode';

  final SharedPreferences? _prefs;
  ThemeMode _mode;

  ThemeProvider._(this._prefs, this._mode);

  /// Reads the saved choice. If it cannot be read the app simply follows the
  /// system theme.
  static Future<ThemeProvider> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return ThemeProvider._(prefs, _decode(prefs.getString(_key)));
    } catch (_) {
      return ThemeProvider._(null, ThemeMode.system);
    }
  }

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _prefs?.setString(_key, mode.name);
  }

  static ThemeMode _decode(String? value) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }
}
