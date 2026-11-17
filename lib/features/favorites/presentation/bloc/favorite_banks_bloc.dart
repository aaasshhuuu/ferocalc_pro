import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/favorite_banks_repository.dart';
import 'favorite_banks_event.dart';
import 'favorite_banks_state.dart';

class FavoriteBanksBloc extends Bloc<FavoriteBanksEvent, FavoriteBanksState> {
  FavoriteBanksBloc({required FavoriteBanksRepository repository})
      : _repository = repository,
        super(const FavoriteBanksInitial()) {
    on<LoadFavoriteBanks>(_onLoad);
    on<ToggleFavoriteBank>(_onToggle);
    on<RemoveFavoriteBank>(_onRemove);
    on<ClearAllFavoriteBanks>(_onClearAll);
  }

  final FavoriteBanksRepository _repository;

  Future<void> _onLoad(
    LoadFavoriteBanks event,
    Emitter<FavoriteBanksState> emit,
  ) async {
    emit(const FavoriteBanksLoading());
    try {
      final list = await _repository.getFavorites();
      final ids = list.map((e) => e.bankId).toSet();
      emit(FavoriteBanksLoaded(favorites: list, favoriteIds: ids));
    } catch (e) {
      emit(FavoriteBanksError(e.toString()));
    }
  }

  Future<void> _onToggle(
    ToggleFavoriteBank event,
    Emitter<FavoriteBanksState> emit,
  ) async {
    try {
      await _repository.toggleFavorite(event.bank);
      final list = await _repository.getFavorites();
      final ids = list.map((e) => e.bankId).toSet();
      emit(FavoriteBanksLoaded(favorites: list, favoriteIds: ids));
    } catch (e) {
      emit(FavoriteBanksError(e.toString()));
    }
  }

  Future<void> _onRemove(
    RemoveFavoriteBank event,
    Emitter<FavoriteBanksState> emit,
  ) async {
    try {
      await _repository.removeFavorite(event.bankId);
      final list = await _repository.getFavorites();
      final ids = list.map((e) => e.bankId).toSet();
      emit(FavoriteBanksLoaded(favorites: list, favoriteIds: ids));
    } catch (e) {
      emit(FavoriteBanksError(e.toString()));
    }
  }

  Future<void> _onClearAll(
    ClearAllFavoriteBanks event,
    Emitter<FavoriteBanksState> emit,
  ) async {
    try {
      await _repository.clearAllFavorites();
      emit(const FavoriteBanksLoaded(favorites: [], favoriteIds: {}));
    } catch (e) {
      emit(FavoriteBanksError(e.toString()));
    }
  }
}
