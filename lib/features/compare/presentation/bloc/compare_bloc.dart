import 'package:flutter_bloc/flutter_bloc.dart';
import 'compare_event.dart';
import 'compare_state.dart';

class CompareBloc extends Bloc<CompareEvent, CompareState> {
  CompareBloc() : super(CompareInitial()) {
    on<SelectBanks>((event, emit) {
      // Logic to select banks
    });

    on<SetParameters>((event, emit) {
      // Logic to set parameters
    });

    on<RunComparison>((event, emit) async {
      emit(CompareLoading());
      try {
        await Future.delayed(const Duration(seconds: 1)); // Mock calculation
        emit(const CompareResults({'winner': 'Bank A', 'extraProfit': 1500}));
      } catch (e) {
        emit(CompareError(e.toString()));
      }
    });
    
    on<SaveComparison>((event, emit) {
      // Logic to save
    });
  }
}
