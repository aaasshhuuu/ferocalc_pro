import 'package:equatable/equatable.dart';

abstract class HomeState extends Equatable {
  const HomeState();
  @override
  List<Object> get props => [];
}

class HomeInitial extends HomeState {}
class HomeLoading extends HomeState {}
class HomeLoaded extends HomeState {
  const HomeLoaded(this.data);
  final Map<String, dynamic> data;
  @override
  List<Object> get props => [data];
}
class HomeError extends HomeState {
  const HomeError(this.message);
  final String message;
  @override
  List<Object> get props => [message];
}
