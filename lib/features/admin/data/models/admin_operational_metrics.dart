import 'package:equatable/equatable.dart';

/// Represents operational metrics for the admin dashboard overview.
class AdminOperationalMetrics extends Equatable {
  const AdminOperationalMetrics({
    this.totalStaged,
    this.draftCount,
    this.inReviewCount,
    this.promotedCount,
    this.rejectedCount,
    this.anomalyCount,
    this.isUnavailable = false,
    this.unavailableReason,
    this.lastRefreshedAt,
  });

  factory AdminOperationalMetrics.unavailable(String reason) {
    return AdminOperationalMetrics(
      isUnavailable: true,
      unavailableReason: reason,
      lastRefreshedAt: DateTime.now(),
    );
  }

  final int? totalStaged;
  final int? draftCount;
  final int? inReviewCount;
  final int? promotedCount;
  final int? rejectedCount;
  final int? anomalyCount;
  final bool isUnavailable;
  final String? unavailableReason;
  final DateTime? lastRefreshedAt;

  @override
  List<Object?> get props => [
        totalStaged,
        draftCount,
        inReviewCount,
        promotedCount,
        rejectedCount,
        anomalyCount,
        isUnavailable,
        unavailableReason,
        lastRefreshedAt,
      ];
}
