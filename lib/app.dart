import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'config/routes/app_router.dart';
import 'config/themes/app_theme.dart';
import 'features/theme/bloc/theme_bloc.dart';
import 'features/theme/bloc/theme_state.dart';

class FinCalcProApp extends StatelessWidget {
  const FinCalcProApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        ThemeMode themeMode = ThemeMode.system;
        if (themeState is ThemeDark) {
          themeMode = ThemeMode.dark;
        } else if (themeState is ThemeLight) {
          themeMode = ThemeMode.light;
        }

        return MaterialApp.router(
          title: 'FeroCalc',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routerConfig: appRouter,
        );
      },
    );
  }
}
