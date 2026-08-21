import 'package:flutter_bloc/flutter_bloc.dart';
import 'theme_event.dart';
import 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(ThemeSystem()) {
    on<ToggleTheme>((event, emit) {
      if (state is ThemeDark) {
        emit(ThemeLight());
      } else {
        emit(ThemeDark());
      }
    });
    
    on<SetTheme>((event, emit) {
      if (event.isDark) {
        emit(ThemeDark());
      } else {
        emit(ThemeLight());
      }
    });
  }
}
