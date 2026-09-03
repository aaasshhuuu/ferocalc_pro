/// FeroCalc Verified FD Rate Engine — Flutter models
/// Server-side verified FD rate data structure.
/// Distinct from the legacy BankInfo / FdRate models.
/// Do NOT mix with unverified data.

// ============================================================
// Enums (mirror backend PostgreSQL enums exactly)
// ============================================================

enum RateStatus {
  draft,
  inReview,
  verified,
  rejected,
  archived;

  factory RateStatus.fromString(String s) {
    switch (s.toUpperCase()) {
      case 'DRAFT':     return RateStatus.draft;
      case 'IN_REVIEW': return RateStatus.inReview;
      case 'VERIFIED':  return RateStatus.verified;
      case 'REJECTED':  return RateStatus.rejected;
      case 'ARCHIVED':  return RateStatus.archived;
      default:          return RateStatus.draft;
    }
  }

  String get displayLabel {
    switch (this) {
      case RateStatus.draft:     return 'Draft';
      case RateStatus.inReview:  return 'In Review';
      case RateStatus.verified:  return 'Verified';
      case RateStatus.rejected:  return 'Rejected';
      case RateStatus.archived:  return 'Archived';
    }
  }

  bool get isPublic => this == RateStatus.verified;
}

enum VerifiedCustomerType {
  regular,
  seniorCitizen,
  superSeniorCitizen,
  staff,
  nre,
  nro;

  factory VerifiedCustomerType.fromString(String s) {
    switch (s.toUpperCase()) {
      case 'REGULAR':              return VerifiedCustomerType.regular;
      case 'SENIOR_CITIZEN':       return VerifiedCustomerType.seniorCitizen;
      case 'SUPER_SENIOR_CITIZEN': return VerifiedCustomerType.superSeniorCitizen;
      case 'STAFF':                return VerifiedCustomerType.staff;
      case 'NRE':                  return VerifiedCustomerType.nre;
      case 'NRO':                  return VerifiedCustomerType.nro;
      default:                     return VerifiedCustomerType.regular;
    }
  }

  String get displayLabel {
    switch (this) {
      case VerifiedCustomerType.regular:              return 'Regular';
      case VerifiedCustomerType.seniorCitizen:        return 'Senior Citizen';
      case VerifiedCustomerType.superSeniorCitizen:   return 'Super Senior Citizen';
      case VerifiedCustomerType.staff:                return 'Staff';
      case VerifiedCustomerType.nre:                  return 'NRE';
      case VerifiedCustomerType.nro:                  return 'NRO';
    }
  }
}

enum CompoundingFrequency {
  monthly,
  quarterly,
  halfYearly,
  annually,
  atMaturity;

  factory CompoundingFrequency.fromString(String s) {
    switch (s.toUpperCase()) {
      case 'MONTHLY':     return CompoundingFrequency.monthly;
      case 'QUARTERLY':   return CompoundingFrequency.quarterly;
      case 'HALF_YEARLY': return CompoundingFrequency.halfYearly;
      case 'ANNUALLY':    return CompoundingFrequency.annually;
      case 'AT_MATURITY': return CompoundingFrequency.atMaturity;
      default:            return CompoundingFrequency.quarterly;
    }
  }

  String get displayLabel {
    switch (this) {
      case CompoundingFrequency.monthly:    return 'Monthly';
      case CompoundingFrequency.quarterly:  return 'Quarterly';
      case CompoundingFrequency.halfYearly: return 'Half-Yearly';
      case CompoundingFrequency.annually:   return 'Annually';
      case CompoundingFrequency.atMaturity: return 'At Maturity';
    }
  }

  /// Number of compounding periods per year (for maturity calculation).
  int get periodsPerYear {
    switch (this) {
      case CompoundingFrequency.monthly:    return 12;
      case CompoundingFrequency.quarterly:  return 4;
      case CompoundingFrequency.halfYearly: return 2;
      case CompoundingFrequency.annually:   return 1;
      case CompoundingFrequency.atMaturity: return 1; // simple interest at maturity
    }
  }
}

// ============================================================
// VerifiedFdRate model
// Represents one row from the verified_fd_rates Supabase view.
// Every field is guaranteed VERIFIED by the DB constraints + workflow.
// ============================================================

class VerifiedFdRate {
  final String id;
  final String bankId;
  final String bankName;
  final String bankShortName;
  final String? bankSourceDomain;
  final VerifiedCustomerType customerType;
  final int minTenureDays;
  final int maxTenureDays;
  final double minDeposit;
  final double? maxDeposit;
  final double interestRate;
  final bool isCallable;
  final CompoundingFrequency compoundingFrequency;
  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;
  final String? sourceUrl;
  final DateTime? verifiedAt;
  final String? reviewNotes;

  const VerifiedFdRate({
    required this.id,
    required this.bankId,
    required this.bankName,
    required this.bankShortName,
    this.bankSourceDomain,
    required this.customerType,
    required this.minTenureDays,
    required this.maxTenureDays,
    required this.minDeposit,
    this.maxDeposit,
    required this.interestRate,
    required this.isCallable,
    required this.compoundingFrequency,
    required this.effectiveFrom,
    this.effectiveUntil,
    this.sourceUrl,
    this.verifiedAt,
    this.reviewNotes,
  });

  factory VerifiedFdRate.fromJson(Map<String, dynamic> json) {
    return VerifiedFdRate(
      id:                   json['id']?.toString() ?? '',
      bankId:               json['bank_id']?.toString() ?? '',
      bankName:             json['bank_name']?.toString() ?? '',
      bankShortName:        json['bank_short_name']?.toString() ?? '',
      bankSourceDomain:     json['bank_source_domain']?.toString(),
      customerType:         VerifiedCustomerType.fromString(json['customer_type']?.toString() ?? 'REGULAR'),
      minTenureDays:        (json['min_tenure_days'] as int?) ?? 0,
      maxTenureDays:        (json['max_tenure_days'] as int?) ?? 0,
      minDeposit:           ((json['min_deposit'] as num?) ?? 0).toDouble(),
      maxDeposit:           (json['max_deposit'] as num?)?.toDouble(),
      interestRate:         ((json['interest_rate'] as num?) ?? 0).toDouble(),
      isCallable:           (json['is_callable'] as bool?) ?? true,
      compoundingFrequency: CompoundingFrequency.fromString(json['compounding_frequency']?.toString() ?? 'QUARTERLY'),
      effectiveFrom:        DateTime.parse(json['effective_from'].toString()),
      effectiveUntil:       json['effective_until'] != null
                              ? DateTime.tryParse(json['effective_until'].toString())
                              : null,
      sourceUrl:            json['source_url']?.toString(),
      verifiedAt:           json['verified_at'] != null
                              ? DateTime.tryParse(json['verified_at'].toString())
                              : null,
      reviewNotes:          json['review_notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id':                   id,
    'bank_id':              bankId,
    'bank_name':            bankName,
    'bank_short_name':      bankShortName,
    'bank_source_domain':   bankSourceDomain,
    'customer_type':        customerType.name.toUpperCase(),
    'min_tenure_days':      minTenureDays,
    'max_tenure_days':      maxTenureDays,
    'min_deposit':          minDeposit,
    'max_deposit':          maxDeposit,
    'interest_rate':        interestRate,
    'is_callable':          isCallable,
    'compounding_frequency': compoundingFrequency.name.toUpperCase(),
    'effective_from':       effectiveFrom.toIso8601String(),
    'effective_until':      effectiveUntil?.toIso8601String(),
    'source_url':           sourceUrl,
    'verified_at':          verifiedAt?.toIso8601String(),
    'review_notes':         reviewNotes,
  };

  /// Human-readable tenure string
  String get tenureDescription {
    if (minTenureDays == maxTenureDays) return _formatDays(minTenureDays);
    return '${_formatDays(minTenureDays)} – ${_formatDays(maxTenureDays)}';
  }

  static String _formatDays(int days) {
    if (days < 30) return '$days days';
    if (days < 365) {
      final m = days ~/ 30;
      final d = days % 30;
      return d == 0 ? '$m month${m > 1 ? 's' : ''}' : '$m month${m > 1 ? 's' : ''} $d days';
    }
    final y = days ~/ 365;
    final rem = days % 365;
    if (rem == 0) return '$y year${y > 1 ? 's' : ''}';
    final m = rem ~/ 30;
    return m > 0
        ? '$y year${y > 1 ? 's' : ''} $m month${m > 1 ? 's' : ''}'
        : '$y year${y > 1 ? 's' : ''} $rem days';
  }

  /// Whether this rate applies to a given tenure
  bool coverstenure(int days) => days >= minTenureDays && days <= maxTenureDays;

  /// Whether this rate applies to a given deposit amount
  bool coversAmount(double amount) {
    if (amount < minDeposit) return false;
    if (maxDeposit != null && amount > maxDeposit!) return false;
    return true;
  }
}

// ============================================================
// VerifiedRatesResponse — envelope from the API
// ============================================================

class VerifiedRatesResponse {
  final List<VerifiedFdRate> rates;
  final String source;       // always 'verified'
  final String? note;
  final DateTime fetchedAt;

  const VerifiedRatesResponse({
    required this.rates,
    required this.source,
    this.note,
    required this.fetchedAt,
  });

  bool get isEmpty => rates.isEmpty;
  bool get isVerifiedSource => source == 'verified';
}
