import 'package:equatable/equatable.dart';
import '../error/failures.dart';

/// Base use case class.
/// Returns a Future that resolves to either a Failure or the expected Type.
abstract class UseCase<Type, Params> {
  Future<Type> call(Params params);
}

class NoParams extends Equatable {
  @override
  List<Object> get props => [];
}
