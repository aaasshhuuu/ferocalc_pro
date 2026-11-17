import 'bank.dart';

/// Consumer-facing rate freshness states as required by FeroCalc Data Trust Center.
enum ConsumerFreshnessState {
  recentlyChecked,
  verificationUpdatePending,
  olderData,
  sourceUnavailable,
  freshnessInfoUnavailable;

  String get label {
    switch (this) {
      case ConsumerFreshnessState.recentlyChecked:
        return 'Recently checked';
      case ConsumerFreshnessState.verificationUpdatePending:
        return 'Verification update pending';
      case ConsumerFreshnessState.olderData:
        return 'Older data — verify with bank';
      case ConsumerFreshnessState.sourceUnavailable:
        return 'Source temporarily unavailable';
      case ConsumerFreshnessState.freshnessInfoUnavailable:
        return 'Freshness info unavailable';
    }
  }

  String get shortLabel {
    switch (this) {
      case ConsumerFreshnessState.recentlyChecked:
        return 'Recently Checked';
      case ConsumerFreshnessState.verificationUpdatePending:
        return 'Update Pending';
      case ConsumerFreshnessState.olderData:
        return 'Older Data';
      case ConsumerFreshnessState.sourceUnavailable:
        return 'Unavailable';
      case ConsumerFreshnessState.freshnessInfoUnavailable:
        return 'Unknown';
    }
  }
}

/// Metadata representing freshness of an individual bank's official rate source.
class RateFreshnessInfo {
  const RateFreshnessInfo({
    required this.sourceId,
    required this.bankCode,
    required this.bankName,
    required this.sourceUrl,
    this.lastCheckedAt,
    this.lastSuccessAt,
    required this.lastStatus,
    required this.isStale,
    required this.pendingReviewCount,
    required this.hasPendingReview,
    required this.updateDetected,
  });

  factory RateFreshnessInfo.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    return RateFreshnessInfo(
      sourceId: json['sourceId']?.toString() ?? '',
      bankCode: json['bankCode']?.toString() ?? '',
      bankName: json['bankName']?.toString() ?? '',
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      lastCheckedAt: parseDate(json['lastCheckedAt']),
      lastSuccessAt: parseDate(json['lastSuccessAt']),
      lastStatus: json['lastStatus']?.toString() ?? 'UNKNOWN',
      isStale: json['isStale'] == true,
      pendingReviewCount: (json['pendingReviewCount'] as num?)?.toInt() ?? 0,
      hasPendingReview: json['hasPendingReview'] == true,
      updateDetected: json['updateDetected'] == true,
    );
  }

  final String sourceId;
  final String bankCode;
  final String bankName;
  final String sourceUrl;
  final DateTime? lastCheckedAt;
  final DateTime? lastSuccessAt;
  final String lastStatus; // e.g. 'OK', 'UNCHANGED', 'CHANGED', 'FETCH_FAILED', 'UNKNOWN'
  final bool isStale;
  final int pendingReviewCount;
  final bool hasPendingReview;
  final bool updateDetected;

  /// Evaluates user-facing freshness status with honest boundaries.
  ConsumerFreshnessState get consumerState {
    if (lastCheckedAt == null && lastSuccessAt == null && lastStatus == 'UNKNOWN') {
      return ConsumerFreshnessState.freshnessInfoUnavailable;
    }
    if (lastStatus == 'FETCH_FAILED') {
      return ConsumerFreshnessState.sourceUnavailable;
    }
    if (hasPendingReview || updateDetected) {
      return ConsumerFreshnessState.verificationUpdatePending;
    }
    if (isStale) {
      return ConsumerFreshnessState.olderData;
    }
    return ConsumerFreshnessState.recentlyChecked;
  }

  /// Safe user-facing description for collection failure without exposing internal stack traces.
  String get publicStatusDescription {
    switch (consumerState) {
      case ConsumerFreshnessState.recentlyChecked:
        return 'Source checked against official bank rate card within the last 24 hours.';
      case ConsumerFreshnessState.verificationUpdatePending:
        return 'An update was collected from the bank website and is awaiting verification review. Published rate remains active.';
      case ConsumerFreshnessState.olderData:
        return 'Last verified check was over 24 hours ago. Scheduled re-verification pending.';
      case ConsumerFreshnessState.sourceUnavailable:
        return 'Official source check is temporarily retrying. Published verified rates remain valid until updated.';
      case ConsumerFreshnessState.freshnessInfoUnavailable:
        return 'Freshness telemetry is not currently reported for this source.';
    }
  }
}

/// Envelope response for GET /api/verified-rates/freshness
class RateFreshnessResponse {
  const RateFreshnessResponse({
    required this.sources,
    required this.count,
    required this.anyUpdatePending,
    required this.allFresh,
    this.note,
    required this.fetchedAt,
    this.hasError = false,
    this.errorMessage,
    this.statusCode,
  });

  factory RateFreshnessResponse.success({
    required List<RateFreshnessInfo> sources,
    bool anyUpdatePending = false,
    bool allFresh = true,
    String? note,
  }) {
    return RateFreshnessResponse(
      sources: sources,
      count: sources.length,
      anyUpdatePending: anyUpdatePending,
      allFresh: allFresh,
      note: note,
      fetchedAt: DateTime.now(),
      hasError: false,
    );
  }

  factory RateFreshnessResponse.error({
    required String message,
    int? statusCode,
  }) {
    return RateFreshnessResponse(
      sources: const [],
      count: 0,
      anyUpdatePending: false,
      allFresh: false,
      errorMessage: message,
      statusCode: statusCode,
      fetchedAt: DateTime.now(),
      hasError: true,
    );
  }

  factory RateFreshnessResponse.unavailable({required String message}) {
    return RateFreshnessResponse(
      sources: const [],
      count: 0,
      anyUpdatePending: false,
      allFresh: false,
      errorMessage: message,
      statusCode: 503,
      fetchedAt: DateTime.now(),
      hasError: true,
    );
  }

  final List<RateFreshnessInfo> sources;
  final int count;
  final bool anyUpdatePending;
  final bool allFresh;
  final String? note;
  final DateTime fetchedAt;
  final bool hasError;
  final String? errorMessage;
  final int? statusCode;
}

/// A published verified rate transition event from GET /api/verified-rates/history/:bankId
class VerifiedRateHistoryEntry {
  const VerifiedRateHistoryEntry({
    required this.id,
    required this.rateId,
    required this.bankId,
    required this.bankName,
    required this.customerType,
    required this.interestRate,
    this.previousRate,
    required this.tenureDescription,
    required this.tenureDomain,
    this.minTenureDays,
    this.maxTenureDays,
    this.sourceTenureText,
    this.minYears,
    this.minMonths,
    this.minDaysCal,
    this.maxYears,
    this.maxMonths,
    this.maxDaysCal,
    this.effectiveFrom,
    this.effectiveUntil,
    this.verifiedAt,
    required this.status,
    required this.isCallable,
    this.sourceUrl,
    required this.rateCategory,
    this.schemeName,
  });

  factory VerifiedRateHistoryEntry.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    return VerifiedRateHistoryEntry(
      id: json['id']?.toString() ?? '',
      rateId: json['rateId']?.toString() ?? json['id']?.toString() ?? '',
      bankId: json['bankId']?.toString() ?? '',
      bankName: json['bankName']?.toString() ?? '',
      customerType: json['customerType']?.toString() ?? 'REGULAR',
      interestRate: (json['interestRate'] as num?)?.toDouble() ?? 0.0,
      previousRate: (json['previousRate'] as num?)?.toDouble(),
      tenureDescription: json['tenureDescription']?.toString() ?? 'Standard tenure',
      tenureDomain: json['tenureDomain']?.toString() ?? 'DAYS',
      minTenureDays: (json['minTenureDays'] as num?)?.toInt(),
      maxTenureDays: (json['maxTenureDays'] as num?)?.toInt(),
      sourceTenureText: json['sourceTenureText']?.toString(),
      minYears: (json['minYears'] as num?)?.toInt(),
      minMonths: (json['minMonths'] as num?)?.toInt(),
      minDaysCal: (json['minDaysCal'] as num?)?.toInt(),
      maxYears: (json['maxYears'] as num?)?.toInt(),
      maxMonths: (json['maxMonths'] as num?)?.toInt(),
      maxDaysCal: (json['maxDaysCal'] as num?)?.toInt(),
      effectiveFrom: parseDate(json['effectiveFrom']),
      effectiveUntil: parseDate(json['effectiveUntil']),
      verifiedAt: parseDate(json['verifiedAt']),
      status: json['status']?.toString() ?? 'VERIFIED',
      isCallable: json['isCallable'] != false,
      sourceUrl: json['sourceUrl']?.toString(),
      rateCategory: json['rateCategory']?.toString() ?? 'STANDARD',
      schemeName: json['schemeName']?.toString(),
    );
  }

  final String id;
  final String rateId;
  final String bankId;
  final String bankName;
  final String customerType;
  final double interestRate;
  final double? previousRate;
  final String tenureDescription;
  final String tenureDomain;
  final int? minTenureDays;
  final int? maxTenureDays;
  final String? sourceTenureText;
  final int? minYears;
  final int? minMonths;
  final int? minDaysCal;
  final int? maxYears;
  final int? maxMonths;
  final int? maxDaysCal;
  final DateTime? effectiveFrom;
  final DateTime? effectiveUntil;
  final DateTime? verifiedAt;
  final String status; // 'VERIFIED' or 'ARCHIVED'
  final bool isCallable;
  final String? sourceUrl;
  final String rateCategory;
  final String? schemeName;

  double? get rateDifference => previousRate != null ? interestRate - previousRate! : null;
  bool get hasRateIncreased => previousRate != null && interestRate > previousRate!;
  bool get hasRateDecreased => previousRate != null && interestRate < previousRate!;
  bool get isCurrent => status == 'VERIFIED' && effectiveUntil == null;
}

/// Envelope response for GET /api/verified-rates/history/:bankId
class VerifiedRateHistoryResponse {
  const VerifiedRateHistoryResponse({
    required this.history,
    required this.count,
    this.bankId,
    this.bankName,
    required this.hasHistoricalChanges,
    this.note,
    required this.fetchedAt,
    this.hasError = false,
    this.errorMessage,
    this.statusCode,
  });

  factory VerifiedRateHistoryResponse.success({
    required List<VerifiedRateHistoryEntry> history,
    String? bankId,
    String? bankName,
    bool hasHistoricalChanges = false,
    String? note,
  }) {
    return VerifiedRateHistoryResponse(
      history: history,
      count: history.length,
      bankId: bankId,
      bankName: bankName,
      hasHistoricalChanges: hasHistoricalChanges,
      note: note,
      fetchedAt: DateTime.now(),
      hasError: false,
    );
  }

  factory VerifiedRateHistoryResponse.error({
    required String message,
    int? statusCode,
  }) {
    return VerifiedRateHistoryResponse(
      history: const [],
      count: 0,
      hasHistoricalChanges: false,
      errorMessage: message,
      statusCode: statusCode,
      fetchedAt: DateTime.now(),
      hasError: true,
    );
  }

  final List<VerifiedRateHistoryEntry> history;
  final int count;
  final String? bankId;
  final String? bankName;
  final bool hasHistoricalChanges;
  final String? note;
  final DateTime fetchedAt;
  final bool hasError;
  final String? errorMessage;
  final int? statusCode;
}

/// Summary metrics of data coverage across verified banks and total rate records.
class DataCoverageMetrics {
  const DataCoverageMetrics({
    required this.activeVerifiedBanksCount,
    required this.totalVerifiedRatesCount,
    required this.verifiedBanks,
    required this.unsupportedBanks,
    this.supportedSourcesAwaitingVerification = const [],
    this.temporarilyUnavailableBanks = const [],
    this.catalogOnlyBanks = const [],
    this.verifiedSlabsCountByBank = const {},
  });

  final int activeVerifiedBanksCount;
  final int totalVerifiedRatesCount;
  final List<Bank> verifiedBanks;
  final List<Bank> unsupportedBanks;
  final List<Bank> supportedSourcesAwaitingVerification;
  final List<Bank> temporarilyUnavailableBanks;
  final List<Bank> catalogOnlyBanks;
  final Map<String, int> verifiedSlabsCountByBank;
}
