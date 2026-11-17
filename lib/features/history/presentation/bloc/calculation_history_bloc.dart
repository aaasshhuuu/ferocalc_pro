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

  const SaveCalculationEntry(this.entry);
  final CalculationHistoryEntry entry;

  @override
  List<Object?> get props => [entry];
}

class UpdateCalculationEntry extends CalculationHistoryEvent {

  const UpdateCalculationEntry(this.entry);
  final CalculationHistoryEntry entry;

  @override
  List<Object?> get props => [entry];
}

class RenameCalculationEntry extends CalculationHistoryEvent {

  const RenameCalculationEntry(this.id, this.newName);
  final String id;
  final String newName;

  @override
  List<Object?> get props => [id, newName];
}

class DuplicateCalculationEntry extends CalculationHistoryEvent {

  const DuplicateCalculationEntry(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class DeleteCalculationEntry extends CalculationHistoryEvent {

  const DeleteCalculationEntry(this.id);
  final String id;

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

  const CalculationHistoryLoaded(this.entries);
  final List<CalculationHistoryEntry> entries;

  @override
  List<Object?> get props => [entries];
}

class CalculationHistoryError extends CalculationHistoryState {

  const CalculationHistoryError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

// BLoC
class CalculationHistoryBloc
    extends Bloc<CalculationHistoryEvent, CalculationHistoryState> {

  CalculationHistoryBloc({required this.repository})
      : super(const CalculationHistoryInitial()) {
    on<LoadCalculationHistory>(_onLoadHistory);
    on<SaveCalculationEntry>(_onSaveEntry);
    on<UpdateCalculationEntry>(_onUpdateEntry);
    on<RenameCalculationEntry>(_onRenameEntry);
    on<DuplicateCalculationEntry>(_onDuplicateEntry);
    on<DeleteCalculationEntry>(_onDeleteEntry);
    on<ClearAllCalculationHistory>(_onClearHistory);
  }
  final CalculationHistoryRepository repository;

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

  Future<void> _onUpdateEntry(
    UpdateCalculationEntry event,
    Emitter<CalculationHistoryState> emit,
  ) async {
    try {
      await repository.updateEntry(event.entry);
      final entries = await repository.getHistory();
      emit(CalculationHistoryLoaded(entries));
    } catch (e) {
      emit(CalculationHistoryError(e.toString()));
    }
  }

  Future<void> _onRenameEntry(
    RenameCalculationEntry event,
    Emitter<CalculationHistoryState> emit,
  ) async {
    try {
      await repository.renameEntry(event.id, event.newName);
      final entries = await repository.getHistory();
      emit(CalculationHistoryLoaded(entries));
    } catch (e) {
      emit(CalculationHistoryError(e.toString()));
    }
  }

  Future<void> _onDuplicateEntry(
    DuplicateCalculationEntry event,
    Emitter<CalculationHistoryState> emit,
  ) async {
    try {
      await repository.duplicateEntry(event.id);
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
