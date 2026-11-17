import 'package:equatable/equatable.dart';

/// Represents the diff between a staged candidate and the active verified rate.
class CandidateRateDiff extends Equatable {
  const CandidateRateDiff({
    required this.diffType,
    this.previousVerifiedRate,
    this.rateDelta,
    this.details,
  });

  factory CandidateRateDiff.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    return CandidateRateDiff(
      diffType: (json['diffType'] ?? json['diff_type'])?.toString() ?? 'NEW_RATE',
      previousVerifiedRate: parseDouble(json['previousVerifiedRate'] ?? json['previous_verified_rate']),
      rateDelta: parseDouble(json['rateDelta'] ?? json['rate_delta']),
      details: json['details']?.toString(),
    );
  }

  final String diffType;
  final double? previousVerifiedRate;
  final double? rateDelta;
  final String? details;

  bool get isNewRate => diffType == 'NEW_RATE';
  bool get isRateIncrease => diffType == 'RATE_INCREASE';
  bool get isRateDecrease => diffType == 'RATE_DECREASE';
  bool get isUnchanged => diffType == 'UNCHANGED';

  Map<String, dynamic> toJson() {
    return {
      'diffType': diffType,
      'previousVerifiedRate': previousVerifiedRate,
      'rateDelta': rateDelta,
      'details': details,
    };
  }

  @override
  List<Object?> get props => [diffType, previousVerifiedRate, rateDelta, details];
}
