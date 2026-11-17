import 'package:equatable/equatable.dart';

/// Base use case class.
/// Returns a Future that resolves to either a Failure or the expected Type.
abstract class UseCase<T, Params> {
  Future<T> call(Params params);
}

class NoParams extends Equatable {
  @override
  List<Object> get props => [];
}
