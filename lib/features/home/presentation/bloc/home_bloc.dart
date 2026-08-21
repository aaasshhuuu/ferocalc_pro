import 'package:flutter_bloc/flutter_bloc.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(HomeInitial()) {
    on<LoadDashboard>((event, emit) async {
      emit(HomeLoading());
      try {
        // Mock loading data
        await Future.delayed(const Duration(seconds: 1));
        emit(const HomeLoaded({'recent': [], 'topBanks': []}));
      } catch (e) {
        emit(HomeError(e.toString()));
      }
    });

    on<RefreshDashboard>((event, emit) async {
      add(LoadDashboard());
    });
  }
}
