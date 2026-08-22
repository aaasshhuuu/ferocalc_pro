/// Tracks historical rate changes for audit and transparency
class RateChange {
  final String changeId;
  final String rateId;
  final String bankId;
  final double previousRate;
  final double newRate;
  final DateTime changedAt;
  final String? changedBy; // admin userId or 'system'
  final String? reason;
  final String? sourceUrl;

  const RateChange({
    required this.changeId,
    required this.rateId,
    required this.bankId,
    required this.previousRate,
    required this.newRate,
    required this.changedAt,
    this.changedBy,
    this.reason,
    this.sourceUrl,
  });

  /// Absolute percentage-point change
  double get absoluteChange => (newRate - previousRate).abs();

  /// Relative percentage change
  double get relativeChange => previousRate > 0 ? ((newRate - previousRate) / previousRate * 100).abs() : 0;

  /// Whether this change should be flagged for review
  /// Uses both absolute and relative thresholds per the user's specification
  bool get isSuspicious {
    // Flag if absolute change exceeds 1.5 percentage points
    if (absoluteChange > 1.5) return true;
    // Flag if relative change exceeds 25%
    if (relativeChange > 25) return true;
    return false;
  }

  Map<String, dynamic> toJson() => {
    'changeId': changeId,
    'rateId': rateId,
    'bankId': bankId,
    'previousRate': previousRate,
    'newRate': newRate,
    'changedAt': changedAt.toIso8601String(),
    'changedBy': changedBy,
    'reason': reason,
    'sourceUrl': sourceUrl,
  };

  factory RateChange.fromJson(Map<String, dynamic> json) => RateChange(
    changeId: json['changeId'] ?? '',
    rateId: json['rateId'] ?? '',
    bankId: json['bankId'] ?? '',
    previousRate: (json['previousRate'] ?? 0).toDouble(),
    newRate: (json['newRate'] ?? 0).toDouble(),
    changedAt: DateTime.parse(json['changedAt']),
    changedBy: json['changedBy'],
    reason: json['reason'],
    sourceUrl: json['sourceUrl'],
  );
}
