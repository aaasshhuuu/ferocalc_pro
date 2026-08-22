/// Production-grade FD rate model
/// Supports: customer types, tenure ranges, deposit ranges, product types,
/// verification status, source tracking, and freshness

enum CustomerType { regular, seniorCitizen, superSeniorCitizen, staff, nre, nro }
enum FdProductType { callable, nonCallable, cumulative, nonCumulative, taxSaver, flexi }
enum VerificationStatus { verified, pendingReview, stale, suspicious, rejected, archived }

class FdRate {
  final String rateId;
  final String bankId;
  final CustomerType customerType;
  final int minTenureDays;
  final int maxTenureDays;
  final double? minDeposit;
  final double? maxDeposit;
  final double interestRate; // annual percentage
  final FdProductType? productType;
  final DateTime? effectiveFrom;
  final DateTime? effectiveUntil;
  final VerificationStatus verificationStatus;
  final DateTime? verifiedAt;
  final String? sourceUrl;
  final String? sourceName;
  final String? sourceDocument;
  final bool prematureWithdrawalAllowed;
  final double? prematureWithdrawalPenalty; // percentage points

  const FdRate({
    required this.rateId,
    required this.bankId,
    required this.customerType,
    required this.minTenureDays,
    required this.maxTenureDays,
    this.minDeposit,
    this.maxDeposit,
    required this.interestRate,
    this.productType,
    this.effectiveFrom,
    this.effectiveUntil,
    this.verificationStatus = VerificationStatus.pendingReview,
    this.verifiedAt,
    this.sourceUrl,
    this.sourceName,
    this.sourceDocument,
    this.prematureWithdrawalAllowed = true,
    this.prematureWithdrawalPenalty,
  });

  /// Human-readable tenure description
  String get tenureDescription {
    if (minTenureDays == maxTenureDays) {
      return _formatDays(minTenureDays);
    }
    return '${_formatDays(minTenureDays)} to ${_formatDays(maxTenureDays)}';
  }

  static String _formatDays(int days) {
    if (days < 30) return '$days days';
    if (days < 365) {
      final months = days ~/ 30;
      final remainDays = days % 30;
      if (remainDays == 0) return '$months month${months > 1 ? 's' : ''}';
      return '$months month${months > 1 ? 's' : ''} $remainDays days';
    }
    final years = days ~/ 365;
    final remainDays = days % 365;
    if (remainDays == 0) return '$years year${years > 1 ? 's' : ''}';
    final remainMonths = remainDays ~/ 30;
    if (remainMonths > 0) return '$years year${years > 1 ? 's' : ''} $remainMonths month${remainMonths > 1 ? 's' : ''}';
    return '$years year${years > 1 ? 's' : ''} $remainDays days';
  }

  /// Whether this rate applies to a given tenure in days
  bool appliesToTenure(int tenureDays) {
    return tenureDays >= minTenureDays && tenureDays <= maxTenureDays;
  }

  /// Whether this rate applies to a given deposit amount
  bool appliesToAmount(double amount) {
    if (minDeposit != null && amount < minDeposit!) return false;
    if (maxDeposit != null && amount > maxDeposit!) return false;
    return true;
  }

  /// Whether this rate is currently effective
  bool get isCurrentlyEffective {
    final now = DateTime.now();
    if (effectiveFrom != null && now.isBefore(effectiveFrom!)) return false;
    if (effectiveUntil != null && now.isAfter(effectiveUntil!)) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
    'rateId': rateId,
    'bankId': bankId,
    'customerType': customerType.name,
    'minTenureDays': minTenureDays,
    'maxTenureDays': maxTenureDays,
    'minDeposit': minDeposit,
    'maxDeposit': maxDeposit,
    'interestRate': interestRate,
    'productType': productType?.name,
    'effectiveFrom': effectiveFrom?.toIso8601String(),
    'effectiveUntil': effectiveUntil?.toIso8601String(),
    'verificationStatus': verificationStatus.name,
    'verifiedAt': verifiedAt?.toIso8601String(),
    'sourceUrl': sourceUrl,
    'sourceName': sourceName,
    'sourceDocument': sourceDocument,
    'prematureWithdrawalAllowed': prematureWithdrawalAllowed,
    'prematureWithdrawalPenalty': prematureWithdrawalPenalty,
  };

  factory FdRate.fromJson(Map<String, dynamic> json) => FdRate(
    rateId: json['rateId'] ?? '',
    bankId: json['bankId'] ?? '',
    customerType: CustomerType.values.firstWhere(
      (e) => e.name == json['customerType'],
      orElse: () => CustomerType.regular,
    ),
    minTenureDays: json['minTenureDays'] ?? 0,
    maxTenureDays: json['maxTenureDays'] ?? 0,
    minDeposit: json['minDeposit']?.toDouble(),
    maxDeposit: json['maxDeposit']?.toDouble(),
    interestRate: (json['interestRate'] ?? 0).toDouble(),
    productType: json['productType'] != null
      ? FdProductType.values.firstWhere(
          (e) => e.name == json['productType'],
          orElse: () => FdProductType.callable,
        )
      : null,
    effectiveFrom: json['effectiveFrom'] != null ? DateTime.tryParse(json['effectiveFrom']) : null,
    effectiveUntil: json['effectiveUntil'] != null ? DateTime.tryParse(json['effectiveUntil']) : null,
    verificationStatus: VerificationStatus.values.firstWhere(
      (e) => e.name == json['verificationStatus'],
      orElse: () => VerificationStatus.pendingReview,
    ),
    verifiedAt: json['verifiedAt'] != null ? DateTime.tryParse(json['verifiedAt']) : null,
    sourceUrl: json['sourceUrl'],
    sourceName: json['sourceName'],
    sourceDocument: json['sourceDocument'],
    prematureWithdrawalAllowed: json['prematureWithdrawalAllowed'] ?? true,
    prematureWithdrawalPenalty: json['prematureWithdrawalPenalty']?.toDouble(),
  );
}
