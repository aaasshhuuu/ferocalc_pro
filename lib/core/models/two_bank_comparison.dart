import '../data/bank_data.dart';
import '../data/bank_rate_repository.dart';
import 'bank.dart';
import 'fd_rate.dart';

enum ComparisonWinner { bankA, bankB, tie, notAvailable }

/// Holds side-by-side comparison for a specific FD tenure slab.
class TenureComparisonItem {
  const TenureComparisonItem({
    required this.tenureKey,
    required this.tenureLabel,
    required this.tenureDays,
    this.rateA,
    this.rateB,
    this.statusA = VerificationStatus.pendingReview,
    this.statusB = VerificationStatus.pendingReview,
  });

  final String tenureKey;
  final String tenureLabel;
  final int tenureDays;
  final double? rateA;
  final double? rateB;
  final VerificationStatus statusA;
  final VerificationStatus statusB;

  /// Absolute interest rate difference if both rates exist.
  double? get difference {
    if (rateA == null || rateB == null) return null;
    return (rateA! - rateB!).abs();
  }

  /// Indicates which bank has the higher rate for this tenure.
  ComparisonWinner get winner {
    if (rateA == null || rateB == null) return ComparisonWinner.notAvailable;
    if ((rateA! - rateB!).abs() < 0.0001) return ComparisonWinner.tie;
    return rateA! > rateB! ? ComparisonWinner.bankA : ComparisonWinner.bankB;
  }
}

/// Comprehensive side-by-side comparison data model between two distinct banks.
class TwoBankComparison {
  const TwoBankComparison({
    required this.bankA,
    required this.bankB,
    this.bankInfoA,
    this.bankInfoB,
    required this.customerType,
    required this.tenureComparisons,
  });

  final Bank bankA;
  final Bank bankB;
  final BankInfo? bankInfoA;
  final BankInfo? bankInfoB;
  final CustomerType customerType;
  final List<TenureComparisonItem> tenureComparisons;

  /// Standard like-for-like tenures to compare
  static const List<Map<String, dynamic>> standardTenures = [
    {'key': '1y', 'label': '1 Year (365 days)', 'days': 365},
    {'key': '2y', 'label': '2 Years (730 days)', 'days': 730},
    {'key': '3y', 'label': '3 Years (1,095 days)', 'days': 1095},
    {'key': '5y', 'label': '5 Years (1,825 days)', 'days': 1825},
  ];

  /// Factory to build a complete side-by-side comparison between Bank A & Bank B.
  /// Standard comparisons strictly select callable retail FD rates by default,
  /// preventing apples-to-oranges comparisons against non-callable lock-in products.
  factory TwoBankComparison.build({
    required Bank bankA,
    required Bank bankB,
    CustomerType customerType = CustomerType.regular,
    bool isCallable = true,
  }) {
    final infoA = BankDataService.getBankByName(bankA.name);
    final infoB = BankDataService.getBankByName(bankB.name);

    final ratesA = BankRateRepository.findRates(
      bankId: bankA.id,
      customerType: customerType,
    );
    final ratesB = BankRateRepository.findRates(
      bankId: bankB.id,
      customerType: customerType,
    );

    final List<TenureComparisonItem> comparisons = [];

    for (final tenure in standardTenures) {
      final days = tenure['days'] as int;
      final key = tenure['key'] as String;
      final label = tenure['label'] as String;

      // Find rate for Bank A (strictly match requested product callable dimension)
      FdRate? matchedRateA;
      for (final r in ratesA) {
        if (r.appliesToTenure(days) && r.prematureWithdrawalAllowed == isCallable) {
          matchedRateA = r;
          break;
        }
      }

      // Find rate for Bank B (strictly match requested product callable dimension)
      FdRate? matchedRateB;
      for (final r in ratesB) {
        if (r.appliesToTenure(days) && r.prematureWithdrawalAllowed == isCallable) {
          matchedRateB = r;
          break;
        }
      }

      // Fallback to legacy bankInfo if rate model lookup didn't find entry (only for callable)
      final double? finalRateA = matchedRateA?.interestRate ??
          (isCallable && infoA != null
              ? (customerType == CustomerType.seniorCitizen
                  ? (infoA.fdRates[key] != null ? infoA.fdRates[key]! + infoA.seniorCitizenExtra : null)
                  : infoA.fdRates[key])
              : null);

      final double? finalRateB = matchedRateB?.interestRate ??
          (isCallable && infoB != null
              ? (customerType == CustomerType.seniorCitizen
                  ? (infoB.fdRates[key] != null ? infoB.fdRates[key]! + infoB.seniorCitizenExtra : null)
                  : infoB.fdRates[key])
              : null);

      comparisons.add(
        TenureComparisonItem(
          tenureKey: key,
          tenureLabel: label,
          tenureDays: days,
          rateA: finalRateA,
          rateB: finalRateB,
          statusA: matchedRateA?.verificationStatus ?? VerificationStatus.pendingReview,
          statusB: matchedRateB?.verificationStatus ?? VerificationStatus.pendingReview,
        ),
      );
    }

    return TwoBankComparison(
      bankA: bankA,
      bankB: bankB,
      bankInfoA: infoA,
      bankInfoB: infoB,
      customerType: customerType,
      tenureComparisons: comparisons,
    );
  }
}
