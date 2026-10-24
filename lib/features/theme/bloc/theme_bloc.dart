import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_event.dart';
import 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  static const String themePreferenceKey = 'app_theme_mode';
  final SharedPreferences? _preferences;

  ThemeBloc({SharedPreferences? preferences})
      : _preferences = preferences,
        super(_resolveInitialState(preferences)) {
    on<ToggleTheme>((event, emit) async {
      if (state is ThemeDark) {
        emit(ThemeLight());
        await _saveTheme('light');
      } else {
        emit(ThemeDark());
        await _saveTheme('dark');
      }
    });

    on<SetTheme>((event, emit) async {
      if (event.isDark) {
        emit(ThemeDark());
        await _saveTheme('dark');
      } else {
        emit(ThemeLight());
        await _saveTheme('light');
      }
    });
  }

  static ThemeState _resolveInitialState(SharedPreferences? preferences) {
    final savedTheme = preferences?.getString(themePreferenceKey);
    if (savedTheme == 'light') {
      return ThemeLight();
    }
    // Default to Dark theme on fresh install or when no preference / 'dark'
    return ThemeDark();
  }

  Future<void> _saveTheme(String theme) async {
    try {
      await _preferences?.setString(themePreferenceKey, theme);
    } catch (e) {
      debugPrint('Failed to save theme preference: $e');
    }
  }
}
