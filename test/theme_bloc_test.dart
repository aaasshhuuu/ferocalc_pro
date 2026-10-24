import 'package:fincalc_pro/features/theme/bloc/theme_bloc.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_event.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeBloc persistence and defaults', () {
    test('defaults to ThemeDark on fresh install / empty preferences',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final bloc = ThemeBloc(preferences: prefs);

      expect(bloc.state, isA<ThemeDark>());
      await bloc.close();
    });

    test('defaults to ThemeDark when preferences instance is null', () async {
      final bloc = ThemeBloc(preferences: null);

      expect(bloc.state, isA<ThemeDark>());
      await bloc.close();
    });

    test('restores ThemeLight when preference is "light"', () async {
      SharedPreferences.setMockInitialValues({
        ThemeBloc.themePreferenceKey: 'light',
      });
      final prefs = await SharedPreferences.getInstance();
      final bloc = ThemeBloc(preferences: prefs);

      expect(bloc.state, isA<ThemeLight>());
      await bloc.close();
    });

    test('restores ThemeDark when preference is "dark"', () async {
      SharedPreferences.setMockInitialValues({
        ThemeBloc.themePreferenceKey: 'dark',
      });
      final prefs = await SharedPreferences.getInstance();
      final bloc = ThemeBloc(preferences: prefs);

      expect(bloc.state, isA<ThemeDark>());
      await bloc.close();
    });

    test('ToggleTheme from Dark emits Light and persists "light"', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final bloc = ThemeBloc(preferences: prefs);

      expect(bloc.state, isA<ThemeDark>());

      bloc.add(ToggleTheme());
      await expectLater(bloc.stream, emits(isA<ThemeLight>()));

      expect(prefs.getString(ThemeBloc.themePreferenceKey), equals('light'));
      await bloc.close();
    });

    test('ToggleTheme from Light emits Dark and persists "dark"', () async {
      SharedPreferences.setMockInitialValues({
        ThemeBloc.themePreferenceKey: 'light',
      });
      final prefs = await SharedPreferences.getInstance();
      final bloc = ThemeBloc(preferences: prefs);

      expect(bloc.state, isA<ThemeLight>());

      bloc.add(ToggleTheme());
      await expectLater(bloc.stream, emits(isA<ThemeDark>()));

      expect(prefs.getString(ThemeBloc.themePreferenceKey), equals('dark'));
      await bloc.close();
    });

    test('SetTheme(isDark: false) emits Light and persists "light"', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final bloc = ThemeBloc(preferences: prefs);

      bloc.add(const SetTheme(isDark: false));
      await expectLater(bloc.stream, emits(isA<ThemeLight>()));

      expect(prefs.getString(ThemeBloc.themePreferenceKey), equals('light'));
      await bloc.close();
    });

    test('SetTheme(isDark: true) emits Dark and persists "dark"', () async {
      SharedPreferences.setMockInitialValues({
        ThemeBloc.themePreferenceKey: 'light',
      });
      final prefs = await SharedPreferences.getInstance();
      final bloc = ThemeBloc(preferences: prefs);

      bloc.add(const SetTheme(isDark: true));
      await expectLater(bloc.stream, emits(isA<ThemeDark>()));

      expect(prefs.getString(ThemeBloc.themePreferenceKey), equals('dark'));
      await bloc.close();
    });
  });
}
