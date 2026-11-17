import '../../core/models/bank.dart';
import '../../core/models/verified_fd_rate.dart';
import '../../core/utils/financial_math.dart' hide CompoundingFrequency;

/// Customer category for FD Discovery.
enum CustomerCategory {
  regular,
  seniorCitizen;

  String get label => this == regular ? 'Regular' : 'Senior Citizen';
  String get apiValue => this == regular ? 'REGULAR' : 'SENIOR_CITIZEN';
}

/// Tenure unit for discovery inputs.
enum TenureUnit {
  days,
  months,
  years;

  String get label {
    switch (this) {
      case TenureUnit.days:
        return 'Days';
      case TenureUnit.months:
        return 'Months';
      case TenureUnit.years:
        return 'Years';
    }
  }
}

/// Callable / Non-callable liquidity preference.
enum CallablePreference {
  any,
  callableOnly,
  nonCallableOnly;

  String get label {
    switch (this) {
      case CallablePreference.any:
        return 'Any (All Products)';
      case CallablePreference.callableOnly:
        return 'Callable (Premature Withdrawal Allowed)';
      case CallablePreference.nonCallableOnly:
        return 'Non-Callable (Higher Rate, Locked)';
    }
  }
}

/// Sorting criteria for matching results.
enum FdSortOption {
  maturityAmount,
  interestRate,
  bankName;

  String get label {
    switch (this) {
      case FdSortOption.maturityAmount:
        return 'Highest Return';
      case FdSortOption.interestRate:
        return 'Highest Interest Rate';
      case FdSortOption.bankName:
        return 'Bank Name (A-Z)';
    }
  }
}

/// User input criteria for smart FD discovery.
class FdDiscoveryCriteria {
  const FdDiscoveryCriteria({
    this.depositAmount = 100000.0,
    this.tenureUnit = TenureUnit.years,
    this.tenureValue = 1,
    this.customerCategory = CustomerCategory.regular,
    this.callablePreference = CallablePreference.any,
    this.selectedBankId,
    this.selectedBankType = 'All',
  });

  final double depositAmount;
  final TenureUnit tenureUnit;
  final int tenureValue;
  final CustomerCategory customerCategory;
  final CallablePreference callablePreference;
  final String? selectedBankId;
  final String selectedBankType;

  /// Validates inputs and returns an honest human-readable error, or null if valid.
  String? validate() {
    if (depositAmount <= 0) {
      return 'Deposit amount must be greater than zero.';
    }
    if (depositAmount > 1000000000) {
      // 100 Crores sanity cap
      return 'Deposit amount exceeds maximum allowable entry (₹100 Cr).';
    }
    if (tenureValue <= 0) {
      return 'Tenure value must be greater than zero.';
    }
    switch (tenureUnit) {
      case TenureUnit.days:
        if (tenureValue < 7) {
          return 'Minimum FD tenure across Indian banks is 7 days.';
        }
        if (tenureValue > 3650) {
          return 'Maximum FD tenure across Indian banks is 10 years (3,650 days).';
        }
        break;
      case TenureUnit.months:
        if (tenureValue > 120) {
          return 'Maximum FD tenure is 120 months (10 years).';
        }
        break;
      case TenureUnit.years:
        if (tenureValue > 10) {
          return 'Maximum FD tenure across Indian banks is 10 years.';
        }
        break;
    }
    return null;
  }

  /// Total tenure converted to days approximation for DAYS domain matching.
  int get tenureInDays {
    switch (tenureUnit) {
      case TenureUnit.days:
        return tenureValue;
      case TenureUnit.months:
        if (tenureValue % 12 == 0) {
          return (tenureValue ~/ 12) * 365;
        }
        return (tenureValue * 365.25 / 12).round();
      case TenureUnit.years:
        return tenureValue * 365;
    }
  }

  /// Total tenure in fractional years for financial calculation.
  double get tenureInYears {
    switch (tenureUnit) {
      case TenureUnit.days:
        return tenureValue / 365.0;
      case TenureUnit.months:
        return tenureValue / 12.0;
      case TenureUnit.years:
        return tenureValue.toDouble();
    }
  }

  /// Calendar components tuple (years, months, days) for CALENDAR domain matching.
  Map<String, int> get calendarComponents {
    switch (tenureUnit) {
      case TenureUnit.days:
        return {
          'years': tenureValue ~/ 365,
          'months': (tenureValue % 365) ~/ 30,
          'days': (tenureValue % 365) % 30,
        };
      case TenureUnit.months:
        return {
          'years': tenureValue ~/ 12,
          'months': tenureValue % 12,
          'days': 0,
        };
      case TenureUnit.years:
        return {
          'years': tenureValue,
          'months': 0,
          'days': 0,
        };
    }
  }

  /// Human-readable label for the selected tenure.
  String get formattedTenureLabel {
    switch (tenureUnit) {
      case TenureUnit.days:
        return '$tenureValue Day${tenureValue == 1 ? '' : 's'}';
      case TenureUnit.months:
        return '$tenureValue Month${tenureValue == 1 ? '' : 's'}';
      case TenureUnit.years:
        return '$tenureValue Year${tenureValue == 1 ? '' : 's'}';
    }
  }

  FdDiscoveryCriteria copyWith({
    double? depositAmount,
    TenureUnit? tenureUnit,
    int? tenureValue,
    CustomerCategory? customerCategory,
    CallablePreference? callablePreference,
    String? selectedBankId,
    String? selectedBankType,
  }) {
    return FdDiscoveryCriteria(
      depositAmount: depositAmount ?? this.depositAmount,
      tenureUnit: tenureUnit ?? this.tenureUnit,
      tenureValue: tenureValue ?? this.tenureValue,
      customerCategory: customerCategory ?? this.customerCategory,
      callablePreference: callablePreference ?? this.callablePreference,
      selectedBankId: selectedBankId ?? this.selectedBankId,
      selectedBankType: selectedBankType ?? this.selectedBankType,
    );
  }
}

/// A matched verified FD record with computed returns and metadata.
class FdDiscoveryMatch {
  const FdDiscoveryMatch({
    required this.rate,
    required this.criteria,
    required this.estimatedMaturity,
    required this.estimatedInterest,
    required this.tenureInYears,
    String? matchingTenureText,
  }) : _matchingTenureTextOverride = matchingTenureText;

  final VerifiedFdRate rate;
  final FdDiscoveryCriteria criteria;
  final double estimatedMaturity;
  final double estimatedInterest;
  final double tenureInYears;
  final String? _matchingTenureTextOverride;
  String get matchingTenureText =>
      _matchingTenureTextOverride ??
      ((rate.sourceTenureText != null && rate.sourceTenureText!.isNotEmpty)
          ? rate.sourceTenureText!
          : rate.tenureDescription);

  String get bankId => rate.bankId;
  String get bankName => rate.bankName;
  String get bankShortName => rate.bankShortName;
  double get interestRate => rate.interestRate;
  bool get isCallable => rate.isCallable;
  CompoundingFrequency get compoundingFrequency => rate.compoundingFrequency;
  double get minDeposit => rate.minDeposit;
  double? get maxDeposit => rate.maxDeposit;
  DateTime get effectiveFrom => rate.effectiveFrom;
  DateTime? get effectiveUntil => rate.effectiveUntil;
  DateTime? get verifiedAt => rate.verifiedAt;
  String? get sourceUrl => rate.sourceUrl;
  String? get schemeName => rate.schemeName;
  RateCategory get rateCategory => rate.rateCategory;

  /// Effective compounding periods per year
  int get compoundingPeriodsPerYear => compoundingFrequency.periodsPerYear;

  /// Formatted deposit range string
  String get depositRangeLabel {
    final minStr = FinancialMath.formatCurrencyRounded(minDeposit);
    if (maxDeposit == null) {
      return 'Min $minStr (No upper limit)';
    }
    final maxStr = FinancialMath.formatCurrencyRounded(maxDeposit!);
    return '$minStr – $maxStr';
  }
}

/// Core matching, evaluation, and ranking engine for Smart FD Discovery.
class FdDiscoveryEngine {
  /// Evaluates an array of verified FD rates against user criteria.
  ///
  /// Guarantees:
  /// - Only active, unexpired, VERIFIED records are included.
  /// - Exact customer category matching (Regular vs Senior Citizen).
  /// - Exact deposit minimum and maximum eligibility.
  /// - Rigorous tenure matching across both DAYS and CALENDAR domains.
  /// - Compounding-aware maturity estimation via [FinancialMath.calculateFDMaturity].
  /// - Deterministic sorting without bias.
  static List<FdDiscoveryMatch> findMatches({
    required List<VerifiedFdRate> rates,
    required FdDiscoveryCriteria criteria,
    List<Bank>? banks,
    DateTime? anchorDate,
  }) {
    final validationError = criteria.validate();
    if (validationError != null) {
      return [];
    }

    final now = anchorDate ?? DateTime.now();
    final matches = <FdDiscoveryMatch>[];

    // Bank map for bank-type filtering
    final bankMap = <String, Bank>{};
    if (banks != null) {
      for (final b in banks) {
        bankMap[b.id] = b;
      }
    }

    for (final rate in rates) {
      // 1. Exclude expired rates
      if (rate.effectiveUntil != null && rate.effectiveUntil!.isBefore(now)) {
        continue;
      }
      // 2. Exclude future effective dates
      if (rate.effectiveFrom.isAfter(now)) {
        continue;
      }

      // 3. Customer Category Matching
      if (criteria.customerCategory == CustomerCategory.regular) {
        if (rate.customerType != VerifiedCustomerType.regular) {
          continue;
        }
      } else {
        if (rate.customerType != VerifiedCustomerType.seniorCitizen &&
            rate.customerType != VerifiedCustomerType.superSeniorCitizen) {
          continue;
        }
      }

      // 4. Deposit Amount Boundaries
      if (!rate.coversAmount(criteria.depositAmount)) {
        continue;
      }

      // 5. Callable / Non-callable Preference
      if (criteria.callablePreference == CallablePreference.callableOnly && !rate.isCallable) {
        continue;
      }
      if (criteria.callablePreference == CallablePreference.nonCallableOnly && rate.isCallable) {
        continue;
      }

      // 6. Bank Filter
      if (criteria.selectedBankId != null &&
          criteria.selectedBankId!.isNotEmpty &&
          criteria.selectedBankId != 'all') {
        if (rate.bankId != criteria.selectedBankId) {
          continue;
        }
      }

      // 7. Bank Type Filter
      if (criteria.selectedBankType != 'All') {
        final bank = bankMap[rate.bankId] ?? rate.toBank();
        final typeMatches = bank.typeLabel
            .toLowerCase()
            .contains(criteria.selectedBankType.toLowerCase());
        if (!typeMatches) {
          continue;
        }
      }

      // 8. Tenure Matching (DAYS vs CALENDAR domains)
      bool isTenureCovered = false;

      if (rate.tenureDomain == TenureDomain.days) {
        final days = criteria.tenureInDays;
        isTenureCovered = rate.coverstenure(days);
      } else if (rate.tenureDomain == TenureDomain.calendar) {
        final cal = criteria.calendarComponents;
        final res = rate.coversCalendarTenure(
          years: cal['years'] ?? 0,
          months: cal['months'] ?? 0,
          daysCal: cal['days'] ?? 0,
          anchorDate: now,
        );
        isTenureCovered = res == true;
      }

      if (!isTenureCovered) {
        continue;
      }

      // 9. Maturity & Interest Calculation using FinancialMath
      final tenureYears = criteria.tenureInYears;
      final periods = rate.compoundingFrequency.periodsPerYear;

      final double maturity = FinancialMath.calculateFDMaturity(
        principal: criteria.depositAmount,
        annualRate: rate.interestRate,
        years: tenureYears,
        compoundingFrequency: periods,
      );

      final double interest = maturity - criteria.depositAmount;

      matches.add(
        FdDiscoveryMatch(
          rate: rate,
          criteria: criteria,
          estimatedMaturity: maturity,
          estimatedInterest: interest,
          tenureInYears: tenureYears,
        ),
      );
    }

    return matches;
  }

  /// Sorts discovery matches according to [sortOption].
  static List<FdDiscoveryMatch> sortMatches(
    List<FdDiscoveryMatch> matches,
    FdSortOption sortOption,
  ) {
    final sorted = List<FdDiscoveryMatch>.from(matches);

    switch (sortOption) {
      case FdSortOption.maturityAmount:
        // Highest return first; break ties with highest interest rate, then bank name
        sorted.sort((a, b) {
          final cmpMaturity = b.estimatedMaturity.compareTo(a.estimatedMaturity);
          if (cmpMaturity != 0) return cmpMaturity;
          final cmpRate = b.interestRate.compareTo(a.interestRate);
          if (cmpRate != 0) return cmpRate;
          return a.bankName.compareTo(b.bankName);
        });
        break;
      case FdSortOption.interestRate:
        // Highest interest rate first; break ties with highest maturity, then bank name
        sorted.sort((a, b) {
          final cmpRate = b.interestRate.compareTo(a.interestRate);
          if (cmpRate != 0) return cmpRate;
          final cmpMaturity = b.estimatedMaturity.compareTo(a.estimatedMaturity);
          if (cmpMaturity != 0) return cmpMaturity;
          return a.bankName.compareTo(b.bankName);
        });
        break;
      case FdSortOption.bankName:
        // Alphabetical by bank name; break ties with interest rate
        sorted.sort((a, b) {
          final cmpName = a.bankName.compareTo(b.bankName);
          if (cmpName != 0) return cmpName;
          return b.interestRate.compareTo(a.interestRate);
        });
        break;
    }

    return sorted;
  }
}
