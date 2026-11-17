import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../data/models/rate_audit_record.dart';
import '../../data/models/staged_candidate.dart';
import '../../data/services/admin_api_service.dart';
import '../../data/services/admin_auth_service.dart';
import '../widgets/admin_status_badge.dart';
import '../widgets/audit_log_list_widget.dart';
import '../widgets/review_confirmation_dialog.dart';

/// Dedicated candidate review screen for verified rate review console.
class CandidateReviewScreen extends StatefulWidget {
  const CandidateReviewScreen({
    Key? key,
    required this.candidate,
  }) : super(key: key);

  final StagedCandidate candidate;

  @override
  State<CandidateReviewScreen> createState() => _CandidateReviewScreenState();
}

class _CandidateReviewScreenState extends State<CandidateReviewScreen> {
  late StagedCandidate _candidate;
  bool _isPromoting = false;
  bool _isRejecting = false;
  String? _actionError;
  String? _actionSuccess;

  List<RateAuditRecord> _auditRecords = [];
  bool _isLoadingAudit = false;

  @override
  void initState() {
    super.initState();
    _candidate = widget.candidate;
    _fetchAuditHistory();
  }

  Future<void> _fetchAuditHistory() async {
    final rateId = _candidate.promotedRateId ?? _candidate.id;
    if (rateId.isEmpty) return;

    setState(() {
      _isLoadingAudit = true;
    });

    try {
      final apiService = GetIt.instance<AdminApiService>();
      final records = await apiService.getRateAuditLog(rateId);
      if (mounted) {
        setState(() {
          _auditRecords = records;
          _isLoadingAudit = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingAudit = false;
        });
      }
    }
  }

  Future<void> _launchSourceUrl() async {
    final urlStr = _candidate.sourceUrl;
    if (urlStr == null || urlStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No source URL available for this candidate')),
      );
      return;
    }

    try {
      final uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open external URL: $urlStr')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
      }
    }
  }

  Future<void> _handlePromote() async {
    final authService = GetIt.instance<AdminAuthService>();

    // Client-side role check
    if (!authService.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission Denied: Only ADMIN role can promote candidates (REVIEWER cannot promote).'),
          backgroundColor: FeroColors.error,
        ),
      );
      return;
    }

    if (_candidate.isInvalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot promote an INVALID candidate. Resolve validation errors first.'),
          backgroundColor: FeroColors.error,
        ),
      );
      return;
    }

    // Require explicit confirmation
    final notes = await ReviewConfirmationDialog.show(
      context: context,
      actionType: ReviewActionType.promote,
      candidate: _candidate,
    );

    if (notes == null) return; // User cancelled

    setState(() {
      _isPromoting = true;
      _actionError = null;
      _actionSuccess = null;
    });

    try {
      final apiService = GetIt.instance<AdminApiService>();
      final result = await apiService.promoteCandidate(
        candidateId: _candidate.id,
        notes: notes.isNotEmpty ? notes : 'Admin manual verification and promotion',
      );

      if (mounted) {
        setState(() {
          _isPromoting = false;
          _actionSuccess = 'Candidate successfully promoted and published to VERIFIED status!';
          // Update local status
          _candidate = StagedCandidate(
            id: _candidate.id,
            bankCode: _candidate.bankCode,
            sourceId: _candidate.sourceId,
            productType: _candidate.productType,
            customerType: _candidate.customerType,
            tenureDomain: _candidate.tenureDomain,
            tenureLabel: _candidate.tenureLabel,
            sourceTenureText: _candidate.sourceTenureText,
            displayTenure: _candidate.displayTenure,
            minTenureDays: _candidate.minTenureDays,
            maxTenureDays: _candidate.maxTenureDays,
            minYears: _candidate.minYears,
            minMonths: _candidate.minMonths,
            minDaysCal: _candidate.minDaysCal,
            minOperator: _candidate.minOperator,
            maxYears: _candidate.maxYears,
            maxMonths: _candidate.maxMonths,
            maxDaysCal: _candidate.maxDaysCal,
            maxOperator: _candidate.maxOperator,
            tenureUnit: _candidate.tenureUnit,
            legacyTenureUnit: _candidate.legacyTenureUnit,
            interestRate: _candidate.interestRate,
            seniorCitizenRate: _candidate.seniorCitizenRate,
            superSeniorRate: _candidate.superSeniorRate,
            minDeposit: _candidate.minDeposit,
            maxDeposit: _candidate.maxDeposit,
            isCallable: _candidate.isCallable,
            compoundingFrequency: _candidate.compoundingFrequency,
            effectiveFrom: _candidate.effectiveFrom,
            effectiveUntil: _candidate.effectiveUntil,
            sourceUrl: _candidate.sourceUrl,
            sourceDocumentUrl: _candidate.sourceDocumentUrl,
            sourceContentHash: _candidate.sourceContentHash,
            parserId: _candidate.parserId,
            parserVersion: _candidate.parserVersion,
            extractedAt: _candidate.extractedAt,
            validationStatus: _candidate.validationStatus,
            validationErrors: _candidate.validationErrors,
            anomalyFlags: _candidate.anomalyFlags,
            stagingStatus: 'PROMOTED',
            diff: _candidate.diff,
            promotedRateId: result['promotedRate']?['id']?.toString() ?? _candidate.promotedRateId,
            promotedAt: DateTime.now().toIso8601String(),
            promotedBy: authService.currentSession?.userId,
            notes: notes,
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rate promoted to VERIFIED successfully!'),
            backgroundColor: FeroColors.verified,
          ),
        );

        _fetchAuditHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPromoting = false;
          _actionError = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleReject() async {
    // Require explicit confirmation with rejection reason
    final reason = await ReviewConfirmationDialog.show(
      context: context,
      actionType: ReviewActionType.reject,
      candidate: _candidate,
    );

    if (reason == null) return; // User cancelled

    setState(() {
      _isRejecting = true;
      _actionError = null;
      _actionSuccess = null;
    });

    try {
      final apiService = GetIt.instance<AdminApiService>();
      await apiService.rejectCandidate(
        candidateId: _candidate.id,
        reason: reason,
      );

      if (mounted) {
        setState(() {
          _isRejecting = false;
          _actionSuccess = 'Candidate marked as REJECTED.';
          // Update local status
          _candidate = StagedCandidate(
            id: _candidate.id,
            bankCode: _candidate.bankCode,
            sourceId: _candidate.sourceId,
            productType: _candidate.productType,
            customerType: _candidate.customerType,
            tenureDomain: _candidate.tenureDomain,
            tenureLabel: _candidate.tenureLabel,
            sourceTenureText: _candidate.sourceTenureText,
            displayTenure: _candidate.displayTenure,
            minTenureDays: _candidate.minTenureDays,
            maxTenureDays: _candidate.maxTenureDays,
            minYears: _candidate.minYears,
            minMonths: _candidate.minMonths,
            minDaysCal: _candidate.minDaysCal,
            minOperator: _candidate.minOperator,
            maxYears: _candidate.maxYears,
            maxMonths: _candidate.maxMonths,
            maxDaysCal: _candidate.maxDaysCal,
            maxOperator: _candidate.maxOperator,
            tenureUnit: _candidate.tenureUnit,
            legacyTenureUnit: _candidate.legacyTenureUnit,
            interestRate: _candidate.interestRate,
            seniorCitizenRate: _candidate.seniorCitizenRate,
            superSeniorRate: _candidate.superSeniorRate,
            minDeposit: _candidate.minDeposit,
            maxDeposit: _candidate.maxDeposit,
            isCallable: _candidate.isCallable,
            compoundingFrequency: _candidate.compoundingFrequency,
            effectiveFrom: _candidate.effectiveFrom,
            effectiveUntil: _candidate.effectiveUntil,
            sourceUrl: _candidate.sourceUrl,
            sourceDocumentUrl: _candidate.sourceDocumentUrl,
            sourceContentHash: _candidate.sourceContentHash,
            parserId: _candidate.parserId,
            parserVersion: _candidate.parserVersion,
            extractedAt: _candidate.extractedAt,
            validationStatus: _candidate.validationStatus,
            validationErrors: _candidate.validationErrors,
            anomalyFlags: _candidate.anomalyFlags,
            stagingStatus: 'REJECTED',
            diff: _candidate.diff,
            notes: reason,
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Candidate rejected.'),
            backgroundColor: FeroColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRejecting = false;
          _actionError = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  String _formatCurrency(double? amount) {
    if (amount == null) return 'N/A';
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final authService = GetIt.instance<AdminAuthService>();
    final isAdmin = authService.isAdmin;
    final isAlreadyPromoted = _candidate.isPromoted;
    final isAlreadyRejected = _candidate.isRejected;

    return Scaffold(
      appBar: CustomAppBar(
        title: '${_candidate.bankCode} Review',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Status Card
                _buildHeaderCard(),
                const SizedBox(height: 16),

                // Error / Success Feedback
                if (_actionError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FeroColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: FeroColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: FeroColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_actionError!, style: const TextStyle(color: FeroColors.error, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_actionSuccess != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FeroColors.verified.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: FeroColors.verified.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: FeroColors.verified, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_actionSuccess!, style: const TextStyle(color: FeroColors.verified, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Bar (Promote / Reject buttons)
                _buildActionBar(isAdmin, isAlreadyPromoted, isAlreadyRejected),
                const SizedBox(height: 20),

                // Rate Specifications Card
                _buildSectionTitle('RATE SPECIFICATIONS'),
                _buildRateSpecsCard(),
                const SizedBox(height: 16),

                // Tenure & Domain Details
                _buildSectionTitle('TENURE & CALENDAR DOMAIN'),
                _buildTenureDomainCard(),
                const SizedBox(height: 16),

                // Deposit & Policy Parameters
                _buildSectionTitle('DEPOSIT & POLICY RULES'),
                _buildDepositRulesCard(),
                const SizedBox(height: 16),

                // Validation & Anomaly Checks
                _buildSectionTitle('VALIDATION & ANOMALY SIGNALS'),
                _buildValidationCard(),
                const SizedBox(height: 16),

                // Verification & Official Source
                _buildSectionTitle('VERIFICATION & SOURCE PROVENANCE'),
                _buildSourceProvenanceCard(),
                const SizedBox(height: 20),

                // Audit History Section
                _buildSectionTitle('AUDIT HISTORY'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AuditLogListWidget(
                    records: _auditRecords,
                    isLoading: _isLoadingAudit,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: FeroColors.gold,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: FeroColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _candidate.bankCode,
                  style: const TextStyle(
                    color: FeroColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _candidate.productType ?? 'Retail Domestic FD',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Candidate ID: ${_candidate.id}',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AdminStatusBadge.forStagingStatus(_candidate.stagingStatus),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(bool isAdmin, bool isAlreadyPromoted, bool isAlreadyRejected) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FeroColors.gold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REVIEW DECISION ACTIONS',
            style: TextStyle(
              color: FeroColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Promote Button
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FeroColors.verified,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    disabledBackgroundColor: Colors.grey.withValues(alpha: 0.2),
                  ),
                  onPressed: (_isPromoting || _isRejecting || isAlreadyPromoted || !isAdmin || _candidate.isInvalid)
                      ? null
                      : _handlePromote,
                  icon: _isPromoting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.black)),
                        )
                      : const Icon(Icons.verified, size: 18),
                  label: Text(
                    isAlreadyPromoted ? 'Already Promoted' : 'Approve & Promote',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Reject Button
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FeroColors.error,
                    side: const BorderSide(color: FeroColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: (_isPromoting || _isRejecting || isAlreadyRejected) ? null : _handleReject,
                  icon: _isRejecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(FeroColors.error)),
                        )
                      : const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(
                    isAlreadyRejected ? 'Already Rejected' : 'Reject Candidate',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          if (!isAdmin) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: FeroColors.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Promote disabled: Signed in with REVIEWER role. Candidate promotion strictly requires ADMIN privileges.',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_candidate.isInvalid) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: FeroColors.error),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Promote disabled: Candidate validation status is INVALID.',
                    style: TextStyle(color: FeroColors.error, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRateSpecsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildMetricTile('Regular Rate', '${_candidate.interestRate.toStringAsFixed(2)}%', isProminent: true),
              _buildMetricTile(
                'Senior Citizen',
                _candidate.seniorCitizenRate != null ? '${_candidate.seniorCitizenRate!.toStringAsFixed(2)}%' : 'None',
              ),
              _buildMetricTile(
                'Super Senior',
                _candidate.superSeniorRate != null ? '${_candidate.superSeniorRate!.toStringAsFixed(2)}%' : 'None',
              ),
            ],
          ),
          if (_candidate.diff != null) ...[
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate Diff vs Active Verified',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AdminStatusBadge.forDiffType(
                      _candidate.diff!.diffType,
                      rateDelta: _candidate.diff!.rateDelta,
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                if (_candidate.diff!.previousVerifiedRate != null) ...[
                  _buildMetricTile(
                    'Previous Active Rate',
                    '${_candidate.diff!.previousVerifiedRate!.toStringAsFixed(2)}%',
                  ),
                ],
                if (_candidate.diff!.details != null) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Diff Details',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _candidate.diff!.details!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTenureDomainCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildMetricTile('Tenure Domain', _candidate.tenureDomain),
              _buildMetricTile('Display Tenure', _candidate.displayTenure),
              _buildMetricTile('Unit', _candidate.tenureUnit ?? 'DAYS'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Source Published Text: "${_candidate.sourceTenureText ?? _candidate.tenureLabel ?? 'N/A'}"',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.9),
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (_candidate.isCalendarDomain) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Canonical Calendar Coordinates:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    'Min: ${_candidate.minYears ?? 0}y ${_candidate.minMonths ?? 0}m ${_candidate.minDaysCal ?? 0}d (${_candidate.minOperator ?? 'GTE'})',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Max: ${_candidate.maxYears ?? 0}y ${_candidate.maxMonths ?? 0}m ${_candidate.maxDaysCal ?? 0}d (${_candidate.maxOperator ?? 'LTE'})',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'Boundary Days: ${_candidate.minTenureDays ?? 'N/A'} to ${_candidate.maxTenureDays ?? 'N/A'} days',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDepositRulesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildMetricTile('Min Deposit', _formatCurrency(_candidate.minDeposit)),
              _buildMetricTile('Max Deposit', _formatCurrency(_candidate.maxDeposit)),
              _buildMetricTile('Callable Deposit', _candidate.isCallable ? 'YES' : 'NO'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricTile('Compounding', _candidate.compoundingFrequency ?? 'QUARTERLY'),
              _buildMetricTile('Customer Type', _candidate.customerType),
              _buildMetricTile('Effective From', _candidate.effectiveFrom ?? 'N/A'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValidationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Status: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              AdminStatusBadge.forValidationStatus(_candidate.validationStatus),
              const Spacer(),
              if (_candidate.isValid)
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: FeroColors.verified, size: 16),
                    SizedBox(width: 4),
                    Text('Automated Rules Passed', style: TextStyle(color: FeroColors.verified, fontSize: 12)),
                  ],
                ),
            ],
          ),
          if (_candidate.validationErrors.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Validation Errors:', style: TextStyle(color: FeroColors.error, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            ..._candidate.validationErrors.map(
              (err) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.circle, size: 6, color: FeroColors.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(err, style: const TextStyle(color: FeroColors.error, fontSize: 12))),
                  ],
                ),
              ),
            ),
          ],
          if (_candidate.anomalyFlags.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Anomaly Warnings:', style: TextStyle(color: FeroColors.warning, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            ..._candidate.anomalyFlags.map(
              (flag) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.circle, size: 6, color: FeroColors.warning),
                    const SizedBox(width: 8),
                    Expanded(child: Text(flag, style: const TextStyle(color: FeroColors.warning, fontSize: 12))),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourceProvenanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Official Bank Source URL', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      _candidate.sourceUrl ?? 'None',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64FFDA)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FeroColors.gold.withValues(alpha: 0.15),
                  foregroundColor: FeroColors.gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _launchSourceUrl,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open Source'),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              _buildMetricTile('Parser ID', _candidate.parserId ?? 'N/A'),
              _buildMetricTile('Parser Version', _candidate.parserVersion ?? '1.0.0'),
              _buildMetricTile('Extracted At', _candidate.extractedAt?.split('T').first ?? 'N/A'),
            ],
          ),
          if (_candidate.sourceContentHash != null) ...[
            const SizedBox(height: 12),
            Text(
              'SHA-256 Content Hash: ${_candidate.sourceContentHash}',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6) ?? Colors.grey,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, {bool isProminent = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isProminent ? 18 : 13,
              fontWeight: FontWeight.bold,
              color: isProminent ? FeroColors.gold : Theme.of(context).textTheme.bodyLarge?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
