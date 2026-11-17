import 'package:equatable/equatable.dart';

abstract class CompareState extends Equatable {
  const CompareState();
  @override
  List<Object> get props => [];
}

class CompareInitial extends CompareState {}

class CompareLoading extends CompareState {}

class CompareResults extends CompareState {
  const CompareResults(this.data);
  final Map<String, dynamic> data;
  @override
  List<Object> get props => [data];
}

class CompareError extends CompareState {
  const CompareError(this.message);
  final String message;
  @override
  List<Object> get props => [message];
}
