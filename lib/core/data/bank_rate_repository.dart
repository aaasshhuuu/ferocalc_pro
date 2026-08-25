import '../models/bank.dart';
import '../models/fd_rate.dart';
import '../services/rate_freshness_service.dart';
import 'bank_data.dart';

/// Bridge layer that converts legacy BankInfo data to production-grade
/// Bank/FdRate models with verification tracking.
///
/// All existing rates are marked PENDING_REVIEW because they have not
/// been verified against official bank sources. No rate is marked VERIFIED
/// without evidence.
class BankRateRepository {
  static final List<Bank> _banks = _buildBanks();
  static final List<FdRate> _rates = _buildRates();

  // ═══════════════════════════════════════════════════════════════
  // BANK QUERIES
  // ═══════════════════════════════════════════════════════════════

  static List<Bank> getAllBanks() => List.unmodifiable(_banks);

  static List<Bank> getActiveBanks() =>
      _banks.where((b) => b.isOperational).toList();

  static List<Bank> getBanksByType(BankType type) =>
      _banks.where((b) => b.type == type).toList();

  static Bank? getBankById(String id) {
    try {
      return _banks.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // RATE QUERIES
  // ═══════════════════════════════════════════════════════════════

  /// Get all rates for a bank
  static List<FdRate> getRatesForBank(String bankId) =>
      _rates.where((r) => r.bankId == bankId).toList();

  /// Get rates matching specific criteria
  static List<FdRate> findRates({
    String? bankId,
    CustomerType customerType = CustomerType.regular,
    int? tenureDays,
    double? depositAmount,
    bool includeUnverified = true,
  }) {
    return _rates.where((r) {
      if (bankId != null && r.bankId != bankId) return false;
      if (r.customerType != customerType) return false;
      if (tenureDays != null && !r.appliesToTenure(tenureDays)) return false;
      if (depositAmount != null && !r.appliesToAmount(depositAmount)) return false;
      if (!includeUnverified && r.verificationStatus != VerificationStatus.verified) return false;
      return true;
    }).toList();
  }

  /// Get the best rate for given criteria, sorted by interest rate descending
  static List<FdRate> getTopRates({
    CustomerType customerType = CustomerType.regular,
    int tenureDays = 365,
    double? depositAmount,
    int limit = 10,
  }) {
    final matching = findRates(
      customerType: customerType,
      tenureDays: tenureDays,
      depositAmount: depositAmount,
    );
    matching.sort((a, b) => b.interestRate.compareTo(a.interestRate));
    return matching.take(limit).toList();
  }

  /// Get rates for comparison — only returns rates for matching criteria
  static List<Map<String, dynamic>> compareRates({
    required int tenureDays,
    required CustomerType customerType,
    double? depositAmount,
  }) {
    final rates = findRates(
      customerType: customerType,
      tenureDays: tenureDays,
      depositAmount: depositAmount,
    );
    rates.sort((a, b) => b.interestRate.compareTo(a.interestRate));

    return rates.map((rate) {
      final bank = getBankById(rate.bankId);
      final freshness = RateFreshnessService.getRateFreshness(rate);
      return {
        'bank': bank,
        'rate': rate,
        'freshness': freshness,
      };
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // DATA BUILDERS — Convert legacy BankInfo → Bank + FdRate
  // ═══════════════════════════════════════════════════════════════

  static BankType _parseBankType(String type) {
    switch (type.toLowerCase()) {
      case 'public': return BankType.public;
      case 'private': return BankType.private;
      case 'small_finance': return BankType.smallFinance;
      case 'foreign': return BankType.foreign;
      default: return BankType.private;
    }
  }

  static String _bankId(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

  static List<Bank> _buildBanks() {
    final legacyBanks = BankDataService.getAllBanks()
        .where((b) => b.country == 'India')
        .toList();

    return legacyBanks.map((b) => Bank(
      id: _bankId(b.name),
      name: b.name,
      shortName: b.shortName,
      type: _parseBankType(b.type),
      status: BankStatus.active,
      officialWebsite: b.website.isNotEmpty ? b.website : null,
      established: b.established.isNotEmpty ? b.established : null,
      headquarters: b.headquarters.isNotEmpty ? b.headquarters : null,
      customerCareNumber: b.customerCare.isNotEmpty ? b.customerCare : null,
      totalBranches: b.totalBranches.isNotEmpty ? b.totalBranches : null,
    )).toList();
  }

  /// Tenure key to day ranges mapping
  static Map<String, List<int>> get _tenureMap => {
    '1y': [365, 365],
    '2y': [730, 730],
    '3y': [1095, 1095],
    '5y': [1825, 1825],
  };

  static List<FdRate> _buildRates() {
    final legacyBanks = BankDataService.getAllBanks()
        .where((b) => b.country == 'India')
        .toList();
    final List<FdRate> rates = [];
    int rateCounter = 0;

    for (final bank in legacyBanks) {
      final bankId = _bankId(bank.name);
      final sourceUrl = bank.website.isNotEmpty ? bank.website : null;

      // Convert each tenure key → FdRate for REGULAR customer
      for (final entry in bank.fdRates.entries) {
        final tenureRange = _tenureMap[entry.key];
        if (tenureRange == null) continue;

        rateCounter++;
        rates.add(FdRate(
          rateId: 'legacy_${bankId}_regular_${entry.key}_$rateCounter',
          bankId: bankId,
          customerType: CustomerType.regular,
          minTenureDays: tenureRange[0],
          maxTenureDays: tenureRange[1],
          minDeposit: bank.minFdAmount.toDouble(),
          interestRate: entry.value,
          verificationStatus: VerificationStatus.pendingReview,
          // No verifiedAt — these are unverified
          sourceUrl: sourceUrl,
          sourceName: sourceUrl != null ? 'Bank website (unverified)' : null,
        ));

        // Add senior citizen rate if premium exists
        if (bank.seniorCitizenExtra > 0) {
          rateCounter++;
          rates.add(FdRate(
            rateId: 'legacy_${bankId}_senior_${entry.key}_$rateCounter',
            bankId: bankId,
            customerType: CustomerType.seniorCitizen,
            minTenureDays: tenureRange[0],
            maxTenureDays: tenureRange[1],
            minDeposit: bank.minFdAmount.toDouble(),
            interestRate: entry.value + bank.seniorCitizenExtra,
            verificationStatus: VerificationStatus.pendingReview,
            sourceUrl: sourceUrl,
            sourceName: sourceUrl != null ? 'Bank website (unverified)' : null,
          ));
        }
      }
    }

    return rates;
  }
}
