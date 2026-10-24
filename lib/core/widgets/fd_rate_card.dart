import 'package:flutter/material.dart';
import '../models/bank.dart';
import '../models/fd_rate.dart';
import '../services/rate_display_config.dart';
import '../services/rate_freshness_service.dart';
import 'verification_badge.dart';

/// Production-grade FD rate card that always shows full context:
/// - Bank name
/// - Applicable interest rate
/// - Exact/bounded tenure
/// - Customer type
/// - Deposit applicability
/// - Verification status
/// - Last verified date
/// - Source
///
/// NEVER displays a bare "8.50%" without context.
class FdRateCard extends StatelessWidget {
  final Bank bank;
  final FdRate rate;
  final VoidCallback? onTap;
  final bool showSource;
  final String? tenureLabel;

  const FdRateCard({
    Key? key,
    required this.bank,
    required this.rate,
    this.onTap,
    this.showSource = true,
    this.tenureLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = const Color(0xFFC9A96E);
    final freshness = RateFreshnessService.getRateFreshness(rate);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1D2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
          boxShadow: [
            if (!isDark) BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Bank name + Verification badge
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bank.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (bank.shortName.isNotEmpty)
                        Text(
                          bank.shortName,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!RateDisplayConfig.isLiveRateDisplayEnabled && rate.verificationStatus != VerificationStatus.verified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                    ),
                    child: const Text(
                      'Verification in Progress',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF60A5FA),
                      ),
                    ),
                  )
                else
                  VerificationBadge(status: rate.verificationStatus, rate: rate, bankName: bank.name),
              ],
            ),

            // Special Scheme Badge & Disclosure (e.g. SBI We-Care)
            if (rate.isSpecialScheme) ...[
              const SizedBox(height: 8),
              Container(
                key: const ValueKey('special_scheme_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, size: 14, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Special Scheme: ${rate.schemeName ?? 'Promotional Scheme'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (rate.qualificationNotes != null && rate.qualificationNotes!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    rate.qualificationNotes!,
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ],

            if (!RateDisplayConfig.isLiveRateDisplayEnabled && rate.verificationStatus != VerificationStatus.verified) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF132235) : Colors.amber.shade50.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: gold.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        RateDisplayConfig.verificationPendingMessage,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),

              // Row 2: Rate + Tenure + Customer Type
              Row(
                children: [
                  // Interest Rate — always with context
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${rate.interestRate.toStringAsFixed(2)}% p.a.',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: gold,
                        ),
                      ),
                      Text(
                        rate.isSpecialScheme
                            ? '${_customerTypeLabel(rate.customerType)} \u2022 Scheme Terms Apply'
                            : _customerTypeLabel(rate.customerType),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: rate.customerType == CustomerType.seniorCitizen
                              ? const Color(0xFF10B981)
                              : (isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Tenure
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        tenureLabel ?? _formatTenure(rate.minTenureDays, rate.maxTenureDays),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      Text(
                        'Tenure',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 3: Deposit info + Freshness
              Row(
                children: [
                  if (rate.minDeposit != null)
                    Text(
                      'Min. Deposit: \u20B9${_formatAmount(rate.minDeposit!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                  const Spacer(),
                  FreshnessBadge(
                    freshnessLabel: freshness.label,
                    isStale: freshness == RateFreshness.verificationRequired ||
                             freshness == RateFreshness.suspicious,
                  ),
                ],
              ),

              // Row 4: Source (optional)
              if (showSource && rate.sourceName != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Source: ${rate.sourceName}',
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static String _customerTypeLabel(CustomerType type) {
    switch (type) {
      case CustomerType.regular: return 'Regular';
      case CustomerType.seniorCitizen: return 'Senior Citizen';
      case CustomerType.superSeniorCitizen: return 'Super Senior Citizen';
      case CustomerType.staff: return 'Staff';
      case CustomerType.nre: return 'NRE';
      case CustomerType.nro: return 'NRO';
    }
  }

  static String formatTenure(int minDays, int maxDays) => _formatTenure(minDays, maxDays);

  static String _formatTenure(int minDays, int maxDays) {
    if (minDays == maxDays) {
      return _daysToLabel(minDays);
    }
    return '${_daysToLabel(minDays)} – ${_daysToLabel(maxDays)}';
  }

  static String _daysToLabel(int days) {
    if (days >= 365 && days % 365 == 0) {
      final years = days ~/ 365;
      return years == 1 ? '1 Year' : '$years Years';
    }
    if (days >= 30 && days % 30 == 0) {
      final months = days ~/ 30;
      return months == 1 ? '1 Month' : '$months Months';
    }
    return days == 1 ? '1 Day' : '$days Days';
  }

  static String _formatAmount(double amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(1)} Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)} L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toStringAsFixed(0);
  }
}
