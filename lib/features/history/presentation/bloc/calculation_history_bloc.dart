import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/calculation_history_repository.dart';

// Events
abstract class CalculationHistoryEvent extends Equatable {
  const CalculationHistoryEvent();

  @override
  List<Object?> get props => [];
}

class LoadCalculationHistory extends CalculationHistoryEvent {
  const LoadCalculationHistory();
}

class SaveCalculationEntry extends CalculationHistoryEvent {
  final CalculationHistoryEntry entry;

  const SaveCalculationEntry(this.entry);

  @override
  List<Object?> get props => [entry];
}

class DeleteCalculationEntry extends CalculationHistoryEvent {
  final String id;

  const DeleteCalculationEntry(this.id);

  @override
  List<Object?> get props => [id];
}

class ClearAllCalculationHistory extends CalculationHistoryEvent {
  const ClearAllCalculationHistory();
}

// States
abstract class CalculationHistoryState extends Equatable {
  const CalculationHistoryState();

  @override
  List<Object?> get props => [];
}

class CalculationHistoryInitial extends CalculationHistoryState {
  const CalculationHistoryInitial();
}

class CalculationHistoryLoading extends CalculationHistoryState {
  const CalculationHistoryLoading();
}

class CalculationHistoryLoaded extends CalculationHistoryState {
  final List<CalculationHistoryEntry> entries;

  const CalculationHistoryLoaded(this.entries);

  @override
  List<Object?> get props => [entries];
}

class CalculationHistoryError extends CalculationHistoryState {
  final String message;

  const CalculationHistoryError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class CalculationHistoryBloc
    extends Bloc<CalculationHistoryEvent, CalculationHistoryState> {
  final CalculationHistoryRepository repository;

  CalculationHistoryBloc({required this.repository})
      : super(const CalculationHistoryInitial()) {
    on<LoadCalculationHistory>(_onLoadHistory);
    on<SaveCalculationEntry>(_onSaveEntry);
    on<DeleteCalculationEntry>(_onDeleteEntry);
    on<ClearAllCalculationHistory>(_onClearHistory);
  }

  Future<void> _onLoadHistory(
    LoadCalculationHistory event,
    Emitter<CalculationHistoryState> emit,
  ) async {
    emit(const CalculationHistoryLoading());
    try {
      final entries = await repository.getHistory();
      emit(CalculationHistoryLoaded(entries));
    } catch (e) {
      emit(CalculationHistoryError(e.toString()));
    }
  }

  Future<void> _onSaveEntry(
    SaveCalculationEntry event,
    Emitter<CalculationHistoryState> emit,
  ) async {
    try {
      await repository.saveEntry(event.entry);
      final entries = await repository.getHistory();
      emit(CalculationHistoryLoaded(entries));
    } catch (e) {
      emit(CalculationHistoryError(e.toString()));
    }
  }

  Future<void> _onDeleteEntry(
    DeleteCalculationEntry event,
    Emitter<CalculationHistoryState> emit,
  ) async {
    try {
      await repository.deleteEntry(event.id);
      final entries = await repository.getHistory();
      emit(CalculationHistoryLoaded(entries));
    } catch (e) {
      emit(CalculationHistoryError(e.toString()));
    }
  }

  Future<void> _onClearHistory(
    ClearAllCalculationHistory event,
    Emitter<CalculationHistoryState> emit,
  ) async {
    try {
      await repository.clearHistory();
      emit(const CalculationHistoryLoaded([]));
    } catch (e) {
      emit(CalculationHistoryError(e.toString()));
    }
  }
}
