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

// ============================================================
// RateCategory — mirrors PostgreSQL rate_category enum (Migration 007)
// ============================================================

/// Distinguishes a normal card-rate slab from a named promotional scheme.
///
/// STANDARD:      Normal tenure slab published in the bank's rate card.
///                Standard slabs must not overlap in the same conflict domain.
/// SPECIAL_SCHEME: Named promotional / fixed-day product (e.g. "AMRIT KALASH").
///                Different scheme names may coexist with each other and with
///                standard slabs.
enum RateCategory {
  standard,
  specialScheme;

  factory RateCategory.fromString(String? s) {
    switch ((s ?? '').toUpperCase()) {
      case 'SPECIAL_SCHEME': return RateCategory.specialScheme;
      case 'STANDARD':
      default:               return RateCategory.standard;
    }
  }

  /// PostgreSQL / API wire value (matches enum name exactly).
  String get apiValue {
    switch (this) {
      case RateCategory.standard:      return 'STANDARD';
      case RateCategory.specialScheme: return 'SPECIAL_SCHEME';
    }
  }

  String get displayLabel {
    switch (this) {
      case RateCategory.standard:      return 'Standard';
      case RateCategory.specialScheme: return 'Special Scheme';
    }
  }

  bool get isSpecialScheme => this == RateCategory.specialScheme;
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
// TenureDomain — mirrors PostgreSQL tenure_domain enum (Migration 009)
// ============================================================

/// Identifies the tenure representation model for a rate.
///
/// days:     Integer day range (min_tenure_days / max_tenure_days).
///           Used for all existing SBI + ICICI records.
///           Day values are authoritative — never approximate.
///
/// calendar: Year/month/day components with boundary operators.
///           Used for future Axis / HDFC / Unity records.
///           Day columns are NULL. No integer-day conversion ever.
enum TenureDomain {
  days,
  calendar;

  factory TenureDomain.fromString(String? s) {
    switch ((s ?? '').toUpperCase()) {
      case 'CALENDAR': return TenureDomain.calendar;
      case 'DAYS':
      default:         return TenureDomain.days;
    }
  }

  String get apiValue {
    switch (this) {
      case TenureDomain.days:     return 'DAYS';
      case TenureDomain.calendar: return 'CALENDAR';
    }
  }
}

// ============================================================
// BoundaryOperator — mirrors PostgreSQL boundary_op enum (Migration 009)
// ============================================================

/// Encodes whether a CALENDAR tenure endpoint is inclusive or exclusive.
///
/// GTE / GT apply to the lower bound (min):
///   GTE = >= (inclusive lower), GT = > (exclusive lower)
///
/// LTE / LT apply to the upper bound (max):
///   LTE = <= (inclusive upper), LT = < (exclusive upper)
enum BoundaryOperator {
  gte,
  gt,
  lte,
  lt;

  factory BoundaryOperator.fromString(String? s) {
    switch ((s ?? '').toUpperCase()) {
      case 'GTE': return BoundaryOperator.gte;
      case 'GT':  return BoundaryOperator.gt;
      case 'LTE': return BoundaryOperator.lte;
      case 'LT':  return BoundaryOperator.lt;
      default:    return BoundaryOperator.gte;
    }
  }

  String get apiValue {
    switch (this) {
      case BoundaryOperator.gte: return 'GTE';
      case BoundaryOperator.gt:  return 'GT';
      case BoundaryOperator.lte: return 'LTE';
      case BoundaryOperator.lt:  return 'LT';
    }
  }

  bool get isInclusive => this == BoundaryOperator.gte || this == BoundaryOperator.lte;
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
  // ── DAYS domain fields (nullable — null for CALENDAR records) ──────────
  /// Integer day lower bound. Authoritative for DAYS records.
  /// NULL for CALENDAR records — do NOT substitute a heuristic.
  final int? minTenureDays;
  /// Integer day upper bound. Authoritative for DAYS records.
  /// NULL for CALENDAR records — do NOT substitute a heuristic.
  final int? maxTenureDays;
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
  // ── Migration 007 fields ──────────────────────────────────────────────
  /// Rate category: STANDARD card-rate slab or SPECIAL_SCHEME promotion.
  final RateCategory rateCategory;
  /// Normalised scheme name (upper-cased, trimmed). Non-null only when
  /// [rateCategory] is [RateCategory.specialScheme].
  final String? schemeName;
  // ── Migration 009 fields ──────────────────────────────────────────────
  /// Which tenure model this record uses.
  final TenureDomain tenureDomain;
  /// Verbatim text from the bank rate card (always set in Migration 009+).
  /// For CALENDAR records this is the authoritative display string.
  /// For DAYS records it is a deterministic day-range wording.
  final String? sourceTenureText;
  // Calendar lower endpoint (null for DAYS records)
  final int? minYears;
  final int? minMonths;
  final int? minDaysCal;
  final BoundaryOperator? minOperator;
  // Calendar upper endpoint (null for DAYS records)
  final int? maxYears;
  final int? maxMonths;
  final int? maxDaysCal;
  final BoundaryOperator? maxOperator;

  const VerifiedFdRate({
    required this.id,
    required this.bankId,
    required this.bankName,
    required this.bankShortName,
    this.bankSourceDomain,
    required this.customerType,
    this.minTenureDays,
    this.maxTenureDays,
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
    this.rateCategory = RateCategory.standard,
    this.schemeName,
    this.tenureDomain = TenureDomain.days,
    this.sourceTenureText,
    this.minYears,
    this.minMonths,
    this.minDaysCal,
    this.minOperator,
    this.maxYears,
    this.maxMonths,
    this.maxDaysCal,
    this.maxOperator,
  });

  factory VerifiedFdRate.fromJson(Map<String, dynamic> json) {
    return VerifiedFdRate(
      id:                   json['id']?.toString() ?? '',
      bankId:               json['bank_id']?.toString() ?? '',
      bankName:             json['bank_name']?.toString() ?? '',
      bankShortName:        json['bank_short_name']?.toString() ?? '',
      bankSourceDomain:     json['bank_source_domain']?.toString(),
      customerType:         VerifiedCustomerType.fromString(json['customer_type']?.toString() ?? 'REGULAR'),
      // DAYS fields: nullable — null for CALENDAR records
      minTenureDays:        (json['min_tenure_days'] as int?),
      maxTenureDays:        (json['max_tenure_days'] as int?),
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
      // Migration 007: default to standard when field is absent (old API compat)
      rateCategory:         RateCategory.fromString(json['rate_category']?.toString()),
      schemeName:           json['scheme_name']?.toString(),
      // Migration 009
      tenureDomain:         TenureDomain.fromString(json['tenure_domain']?.toString()),
      sourceTenureText:     json['source_tenure_text']?.toString(),
      minYears:             (json['min_years'] as int?),
      minMonths:            (json['min_months'] as int?),
      minDaysCal:           (json['min_days_cal'] as int?),
      minOperator:          json['min_operator'] != null
                              ? BoundaryOperator.fromString(json['min_operator'].toString())
                              : null,
      maxYears:             (json['max_years'] as int?),
      maxMonths:            (json['max_months'] as int?),
      maxDaysCal:           (json['max_days_cal'] as int?),
      maxOperator:          json['max_operator'] != null
                              ? BoundaryOperator.fromString(json['max_operator'].toString())
                              : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id':                    id,
    'bank_id':               bankId,
    'bank_name':             bankName,
    'bank_short_name':       bankShortName,
    'bank_source_domain':    bankSourceDomain,
    'customer_type':         customerType.name.toUpperCase(),
    'min_tenure_days':       minTenureDays,
    'max_tenure_days':       maxTenureDays,
    'min_deposit':           minDeposit,
    'max_deposit':           maxDeposit,
    'interest_rate':         interestRate,
    'is_callable':           isCallable,
    'compounding_frequency': compoundingFrequency.name.toUpperCase(),
    'effective_from':        effectiveFrom.toIso8601String(),
    'effective_until':       effectiveUntil?.toIso8601String(),
    'source_url':            sourceUrl,
    'verified_at':           verifiedAt?.toIso8601String(),
    'review_notes':          reviewNotes,
    // Migration 007
    'rate_category':         rateCategory.apiValue,
    'scheme_name':           schemeName,
    // Migration 009
    'tenure_domain':         tenureDomain.apiValue,
    'source_tenure_text':    sourceTenureText,
    'min_years':             minYears,
    'min_months':            minMonths,
    'min_days_cal':          minDaysCal,
    'min_operator':          minOperator?.apiValue,
    'max_years':             maxYears,
    'max_months':            maxMonths,
    'max_days_cal':          maxDaysCal,
    'max_operator':          maxOperator?.apiValue,
  };

  /// Human-readable tenure string.
  ///
  /// For CALENDAR records: returns [sourceTenureText] exactly as received
  /// from the bank's rate card — no integer-day conversion.
  ///
  /// For DAYS records: formats the integer day range into a human-readable
  /// string using exact day arithmetic (no heuristic month estimates).
  String get tenureDescription {
    if (tenureDomain == TenureDomain.calendar) {
      // CALENDAR: authoritative verbatim text from source.
      // NEVER convert to integer days here.
      return sourceTenureText ?? '';
    }
    // DAYS: integer day range formatting.
    final minD = minTenureDays ?? 0;
    final maxD = maxTenureDays ?? 0;
    if (minD == maxD) return _formatDays(minD);
    return '${_formatDays(minD)} – ${_formatDays(maxD)}';
  }

  /// Formats an integer day count for display.
  ///
  /// NOTE: The ~/ 30 and ~/ 365 conversions here are only ever used for
  /// DAYS-domain records where the integer day value is already authoritative
  /// (e.g. 365 = exactly 365 days, not "1 year" from a bank card).
  /// CALENDAR records never reach this method.
  static String _formatDays(int days) {
    if (days < 30) return '$days day${days == 1 ? '' : 's'}';
    if (days < 365) {
      final m = days ~/ 30;
      final d = days % 30;
      return d == 0
          ? '$m month${m > 1 ? 's' : ''}'
          : '$m month${m > 1 ? 's' : ''} $d day${d == 1 ? '' : 's'}';
    }
    final y = days ~/ 365;
    final rem = days % 365;
    if (rem == 0) return '$y year${y > 1 ? 's' : ''}';
    final m = rem ~/ 30;
    return m > 0
        ? '$y year${y > 1 ? 's' : ''} $m month${m > 1 ? 's' : ''}'
        : '$y year${y > 1 ? 's' : ''} $rem day${rem == 1 ? '' : 's'}';
  }

  /// Whether this DAYS-domain rate covers a given integer tenure.
  /// Always returns false for CALENDAR records (integer-day comparison is not
  /// valid for symbolic calendar ranges — use source text instead).
  bool coverstenure(int days) {
    if (tenureDomain == TenureDomain.calendar) return false;
    final minD = minTenureDays;
    final maxD = maxTenureDays;
    if (minD == null || maxD == null) return false;
    return days >= minD && days <= maxD;
  }

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
