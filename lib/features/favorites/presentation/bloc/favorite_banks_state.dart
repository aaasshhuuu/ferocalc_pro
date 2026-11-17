import 'package:equatable/equatable.dart';
import '../../domain/models/favorite_bank.dart';

abstract class FavoriteBanksState extends Equatable {
  const FavoriteBanksState();

  @override
  List<Object?> get props => [];
}

class FavoriteBanksInitial extends FavoriteBanksState {
  const FavoriteBanksInitial();
}

class FavoriteBanksLoading extends FavoriteBanksState {
  const FavoriteBanksLoading();
}

class FavoriteBanksLoaded extends FavoriteBanksState {
  const FavoriteBanksLoaded({
    required this.favorites,
    required this.favoriteIds,
  });

  final List<FavoriteBank> favorites;
  final Set<String> favoriteIds;

  bool isFavorite(String bankId) => favoriteIds.contains(bankId);

  @override
  List<Object?> get props => [favorites, favoriteIds];
}

class FavoriteBanksError extends FavoriteBanksState {
  const FavoriteBanksError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
