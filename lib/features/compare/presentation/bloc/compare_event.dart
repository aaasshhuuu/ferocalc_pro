import 'package:equatable/equatable.dart';

abstract class CompareEvent extends Equatable {
  const CompareEvent();
  @override
  List<Object> get props => [];
}

class SelectBanks extends CompareEvent {
  final List<String> bankIds;
  const SelectBanks(this.bankIds);
}

class SetParameters extends CompareEvent {
  final double amount;
  final double tenureYears;
  final bool isSeniorCitizen;
  const SetParameters(this.amount, this.tenureYears, this.isSeniorCitizen);
}

class RunComparison extends CompareEvent {}
class SaveComparison extends CompareEvent {}
