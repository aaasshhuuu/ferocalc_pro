import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/data_trust_models.dart';
import '../models/fd_rate.dart';
import '../services/rate_freshness_service.dart';
import '../services/verified_rate_service.dart';

/// Shows a bottom sheet explaining the verification status of a rate.
/// Tappable from any VerificationBadge.
class VerificationDetailSheet {
  static void show(BuildContext context, FdRate rate, {String? bankName}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0D1B2A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _VerificationDetailSheetContent(rate: rate, bankName: bankName),
    );
  }
}

class _VerificationDetailSheetContent extends StatefulWidget {
  const _VerificationDetailSheetContent({
    Key? key,
    required this.rate,
    this.bankName,
  }) : super(key: key);

  final FdRate rate;
  final String? bankName;

  @override
  State<_VerificationDetailSheetContent> createState() => _VerificationDetailSheetContentState();
}

class _VerificationDetailSheetContentState extends State<_VerificationDetailSheetContent> {
  bool _isLoadingHistory = false;
  List<VerifiedRateHistoryEntry> _history = [];
  bool _historyLoaded = false;

  @override
  void initState() {
    super.initState();
    _fetchHistoryIfApplicable();
  }

  Future<void> _fetchHistoryIfApplicable() async {
    if (widget.rate.bankId.isEmpty) return;

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final res = await VerifiedRateService.fetchHistory(
        widget.rate.bankId,
        customerType: _customerTypeWireValue(widget.rate.customerType),
        isCallable: widget.rate.productType == FdProductType.callable,
      );
      if (mounted) {
        setState(() {
          _history = res.history;
          _isLoadingHistory = false;
          _historyLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
          _historyLoaded = true;
        });
      }
    }
  }

  String _customerTypeWireValue(CustomerType type) {
    switch (type) {
      case CustomerType.regular:
        return 'REGULAR';
      case CustomerType.seniorCitizen:
        return 'SENIOR_CITIZEN';
      case CustomerType.superSeniorCitizen:
        return 'SUPER_SENIOR_CITIZEN';
      case CustomerType.staff:
        return 'STAFF';
      case CustomerType.nre:
        return 'NRE';
      case CustomerType.nro:
        return 'NRO';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFC9A96E);
    final freshness = RateFreshnessService.getRateFreshness(widget.rate);
    final isVerified = widget.rate.verificationStatus == VerificationStatus.verified;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title and Bank Name
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rate Verification Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (widget.bankName != null) ...[
                        const SizedBox(height: 4),
                        Text(widget.bankName!, style: const TextStyle(fontSize: 14, color: gold)),
                      ],
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/trust-center?tab=2&bankId=${widget.rate.bankId}');
                  },
                  icon: const Icon(Icons.shield_outlined, size: 16, color: gold),
                  label: const Text('Trust Center', style: TextStyle(color: gold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status row
            _buildRow(
              context,
              'Verification Status',
              _statusLabel(widget.rate.verificationStatus),
              _statusColor(widget.rate.verificationStatus),
              icon: _statusIcon(widget.rate.verificationStatus),
            ),
            const SizedBox(height: 12),

            // Why this status explanation
            _buildExplanation(context, widget.rate),
            const SizedBox(height: 16),

            // Freshness row
            _buildRow(
              context,
              'Data Freshness',
              freshness.label,
              _freshnessColor(freshness),
              icon: Icons.history,
            ),
            const SizedBox(height: 12),

            // Verification timestamp
            if (widget.rate.verifiedAt != null) ...[
              _buildRow(
                context,
                'Last Verified',
                _formatDate(widget.rate.verifiedAt!),
                null,
              ),
              const SizedBox(height: 12),
            ],

            // Effective dates
            if (widget.rate.effectiveFrom != null) ...[
              _buildRow(
                context,
                'Effective From',
                _formatDate(widget.rate.effectiveFrom!),
                null,
              ),
              const SizedBox(height: 12),
            ],
            if (widget.rate.effectiveUntil != null) ...[
              _buildRow(
                context,
                'Effective Until',
                _formatDate(widget.rate.effectiveUntil!),
                null,
              ),
              const SizedBox(height: 12),
            ],

            // Source URL
            if (widget.rate.sourceUrl != null && widget.rate.sourceUrl!.isNotEmpty) ...[
              _buildSourceRow(context, widget.rate),
              const SizedBox(height: 12),
            ],

            // Rate characteristics
            _buildRow(
              context,
              'Interest Rate',
              '${widget.rate.interestRate.toStringAsFixed(2)}% p.a.',
              gold,
            ),
            const SizedBox(height: 12),
            _buildRow(context, 'Tenure', widget.rate.tenureDescription, null),
            const SizedBox(height: 12),
            _buildRow(context, 'Customer Type', _customerTypeLabel(widget.rate.customerType), null),
            const SizedBox(height: 12),
            _buildRow(
              context,
              'Product Type',
              widget.rate.productType == FdProductType.callable ? 'Callable' : 'Non-Callable',
              null,
            ),

            const SizedBox(height: 20),

            // Historical Rate Changes Section
            if (isVerified) ...[
              const Text(
                'HISTORICAL RATE TRANSITIONS',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: gold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              if (_isLoadingHistory)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: gold),
                      ),
                      SizedBox(width: 8),
                      Text('Checking historical revisions...', style: TextStyle(fontSize: 11.5, color: Colors.white54)),
                    ],
                  ),
                )
              else if (_historyLoaded && _history.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: [
                      for (final entry in _history.take(2))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                entry.isCurrent ? Icons.check_circle : Icons.history,
                                size: 14,
                                color: entry.isCurrent ? const Color(0xFF10B981) : Colors.white38,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${entry.interestRate.toStringAsFixed(2)}% p.a.${entry.previousRate != null ? " (was ${entry.previousRate!.toStringAsFixed(2)}%)" : ""}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: entry.isCurrent ? FontWeight.bold : FontWeight.normal,
                                    color: entry.isCurrent ? Colors.white : Colors.white70,
                                  ),
                                ),
                              ),
                              if (entry.effectiveFrom != null)
                                Text(
                                  _formatDate(entry.effectiveFrom!),
                                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ] else if (_historyLoaded) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Initial verified baseline active. No prior rate changes recorded.',
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],

            // Disclaimer Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.08 : 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isVerified
                          ? 'Rate values are verified against official bank publications. Always confirm with the bank before placing deposits.'
                          : 'This rate has not been independently verified. Please confirm with the bank before making financial decisions.',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Open Data Trust Center Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/trust-center?tab=0&bankId=${widget.rate.bankId}');
                },
                icon: const Icon(Icons.verified_user_outlined, size: 16, color: gold),
                label: const Text('Open Full Data Trust Center', style: TextStyle(color: gold, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: gold),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildRow(BuildContext context, String label, String value, Color? valueColor, {IconData? icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: valueColor ?? (isDark ? Colors.white54 : Colors.black54)),
          const SizedBox(width: 8),
        ],
        Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  static Widget _buildExplanation(BuildContext context, FdRate rate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String explanation;

    switch (rate.verificationStatus) {
      case VerificationStatus.verified:
        explanation = 'This rate has been independently verified against an official bank source.';
        break;
      case VerificationStatus.pendingReview:
        explanation = 'This rate is from static data and has not yet been verified against the bank\'s current published rates. It may be outdated.';
        break;
      case VerificationStatus.stale:
        explanation = 'This rate was previously verified but the verification has expired. The bank may have updated their rates since.';
        break;
      case VerificationStatus.suspicious:
        explanation = 'This rate change triggered an anomaly check. It is under review to confirm whether it is accurate.';
        break;
      case VerificationStatus.rejected:
        explanation = 'This rate has been determined to be incorrect and should not be relied upon.';
        break;
      case VerificationStatus.archived:
        explanation = 'This rate is historical and no longer current. It is kept for reference only.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_outline, size: 16, color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              explanation,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSourceRow(BuildContext context, FdRate rate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFC9A96E);
    final isVerifiedSource = rate.verificationStatus == VerificationStatus.verified;
    final sourceLabel = isVerifiedSource ? 'Official Bank Source' : 'Source: Bank Website (Unverified)';

    return Row(
      children: [
        Icon(Icons.link, size: 16, color: isDark ? Colors.white54 : Colors.black54),
        const SizedBox(width: 8),
        Text('Source', style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54)),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            final url = rate.sourceUrl;
            if (url != null && url.isNotEmpty) {
              final uri = Uri.tryParse(url);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sourceLabel,
                style: const TextStyle(fontSize: 12, color: gold, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.open_in_new, size: 12, color: gold),
            ],
          ),
        ),
      ],
    );
  }

  static String _statusLabel(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.verified: return 'Verified';
      case VerificationStatus.pendingReview: return 'Pending Review';
      case VerificationStatus.stale: return 'Stale';
      case VerificationStatus.suspicious: return 'Under Review';
      case VerificationStatus.rejected: return 'Rejected';
      case VerificationStatus.archived: return 'Archived';
    }
  }

  static IconData _statusIcon(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.verified: return Icons.verified;
      case VerificationStatus.pendingReview: return Icons.schedule;
      case VerificationStatus.stale: return Icons.warning_amber;
      case VerificationStatus.suspicious: return Icons.error_outline;
      case VerificationStatus.rejected: return Icons.cancel;
      case VerificationStatus.archived: return Icons.archive;
    }
  }

  static Color _statusColor(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.verified: return const Color(0xFF10B981);
      case VerificationStatus.pendingReview: return const Color(0xFFF59E0B);
      case VerificationStatus.stale: return Colors.grey;
      case VerificationStatus.suspicious: return const Color(0xFFEF4444);
      case VerificationStatus.rejected: return const Color(0xFF991B1B);
      case VerificationStatus.archived: return Colors.grey;
    }
  }

  static Color _freshnessColor(RateFreshness freshness) {
    switch (freshness) {
      case RateFreshness.recentlyVerified: return const Color(0xFF10B981);
      case RateFreshness.verifiedRecently: return const Color(0xFF10B981);
      case RateFreshness.olderData: return const Color(0xFFF59E0B);
      case RateFreshness.verificationRequired: return Colors.grey;
      case RateFreshness.pendingReview: return const Color(0xFFF59E0B);
      case RateFreshness.suspicious: return const Color(0xFFEF4444);
      case RateFreshness.unverified: return Colors.grey;
    }
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

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
