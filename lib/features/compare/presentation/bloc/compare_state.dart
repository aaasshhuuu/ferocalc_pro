import 'package:equatable/equatable.dart';

abstract class CompareState extends Equatable {
  const CompareState();
  @override
  List<Object> get props => [];
}

class CompareInitial extends CompareState {}

class CompareLoading extends CompareState {}

class CompareResults extends CompareState {
  final Map<String, dynamic> data;
  const CompareResults(this.data);
  @override
  List<Object> get props => [data];
}

class CompareError extends CompareState {
  final String message;
  const CompareError(this.message);
  @override
  List<Object> get props => [message];
}
