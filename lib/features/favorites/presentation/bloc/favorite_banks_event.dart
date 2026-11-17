import 'package:equatable/equatable.dart';
import '../../domain/models/favorite_bank.dart';

abstract class FavoriteBanksEvent extends Equatable {
  const FavoriteBanksEvent();

  @override
  List<Object?> get props => [];
}

class LoadFavoriteBanks extends FavoriteBanksEvent {
  const LoadFavoriteBanks();
}

class ToggleFavoriteBank extends FavoriteBanksEvent {
  const ToggleFavoriteBank(this.bank);
  final FavoriteBank bank;

  @override
  List<Object?> get props => [bank];
}

class RemoveFavoriteBank extends FavoriteBanksEvent {
  const RemoveFavoriteBank(this.bankId);
  final String bankId;

  @override
  List<Object?> get props => [bankId];
}

class ClearAllFavoriteBanks extends FavoriteBanksEvent {
  const ClearAllFavoriteBanks();
}
