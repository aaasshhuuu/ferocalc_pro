import 'package:equatable/equatable.dart';

abstract class CompareEvent extends Equatable {
  const CompareEvent();
  @override
  List<Object> get props => [];
}

class SelectBanks extends CompareEvent {
  const SelectBanks(this.bankIds);
  final List<String> bankIds;
}

class SetParameters extends CompareEvent {
  const SetParameters(this.amount, this.tenureYears, this.isSeniorCitizen);
  final double amount;
  final double tenureYears;
  final bool isSeniorCitizen;
}

class RunComparison extends CompareEvent {}
class SaveComparison extends CompareEvent {}
