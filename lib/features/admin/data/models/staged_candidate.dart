import 'package:equatable/equatable.dart';
import 'candidate_rate_diff.dart';

/// Represents a candidate FD rate staged for review and verification.
class StagedCandidate extends Equatable {
  const StagedCandidate({
    required this.id,
    required this.bankCode,
    this.sourceId,
    this.productType,
    required this.customerType,
    this.tenureDomain = 'DAYS',
    this.tenureLabel,
    this.sourceTenureText,
    required this.displayTenure,
    this.minTenureDays,
    this.maxTenureDays,
    this.minYears,
    this.minMonths,
    this.minDaysCal,
    this.minOperator,
    this.maxYears,
    this.maxMonths,
    this.maxDaysCal,
    this.maxOperator,
    this.tenureUnit,
    this.legacyTenureUnit,
    required this.interestRate,
    this.seniorCitizenRate,
    this.superSeniorRate,
    this.minDeposit,
    this.maxDeposit,
    this.isCallable = true,
    this.compoundingFrequency,
    this.effectiveFrom,
    this.effectiveUntil,
    this.sourceUrl,
    this.sourceDocumentUrl,
    this.sourceContentHash,
    this.parserId,
    this.parserVersion,
    this.extractedAt,
    this.validationStatus = 'VALID',
    this.validationErrors = const [],
    this.anomalyFlags = const [],
    this.stagingStatus = 'DRAFT',
    this.diff,
    this.promotedRateId,
    this.promotedAt,
    this.promotedBy,
    this.notes,
  });

  factory StagedCandidate.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic list) {
      if (list is List) {
        return list.map((e) => e.toString()).toList();
      }
      return const [];
    }

    double? parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    int? parseInt(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    bool parseBool(dynamic val, {bool defaultValue = true}) {
      if (val is bool) return val;
      if (val is String) {
        final lower = val.toLowerCase().trim();
        if (lower == 'true' || lower == '1' || lower == 'yes') return true;
        if (lower == 'false' || lower == '0' || lower == 'no') return false;
      }
      return defaultValue;
    }

    final diffJson = json['diff'] as Map<String, dynamic>?;

    return StagedCandidate(
      id: json['id']?.toString() ?? '',
      bankCode: (json['bankCode'] ?? json['bank_code'])?.toString() ?? '',
      sourceId: (json['sourceId'] ?? json['source_id'])?.toString(),
      productType: (json['productType'] ?? json['product_type'])?.toString(),
      customerType: (json['customerType'] ?? json['customer_type'])?.toString() ?? 'REGULAR',
      tenureDomain: (json['tenureDomain'] ?? json['tenure_domain'])?.toString() ?? 'DAYS',
      tenureLabel: (json['tenureLabel'] ?? json['tenure_label'])?.toString(),
      sourceTenureText: (json['sourceTenureText'] ?? json['source_tenure_text'])?.toString(),
      displayTenure: (json['displayTenure'] ?? json['display_tenure'] ?? json['tenureLabel'] ?? json['tenure_label'])?.toString() ?? 'N/A',
      minTenureDays: parseInt(json['minTenureDays'] ?? json['min_tenure_days']),
      maxTenureDays: parseInt(json['maxTenureDays'] ?? json['max_tenure_days']),
      minYears: parseInt(json['minYears'] ?? json['min_years']),
      minMonths: parseInt(json['minMonths'] ?? json['min_months']),
      minDaysCal: parseInt(json['minDaysCal'] ?? json['min_days_cal']),
      minOperator: (json['minOperator'] ?? json['min_operator'])?.toString(),
      maxYears: parseInt(json['maxYears'] ?? json['max_years']),
      maxMonths: parseInt(json['maxMonths'] ?? json['max_months']),
      maxDaysCal: parseInt(json['maxDaysCal'] ?? json['max_days_cal']),
      maxOperator: (json['maxOperator'] ?? json['max_operator'])?.toString(),
      tenureUnit: (json['tenureUnit'] ?? json['tenure_unit'])?.toString(),
      legacyTenureUnit: (json['legacyTenureUnit'] ?? json['legacy_tenure_unit'])?.toString(),
      interestRate: parseDouble(json['interestRate'] ?? json['interest_rate']) ?? 0.0,
      seniorCitizenRate: parseDouble(json['seniorCitizenRate'] ?? json['senior_citizen_rate']),
      superSeniorRate: parseDouble(json['superSeniorRate'] ?? json['super_senior_rate']),
      minDeposit: parseDouble(json['minDeposit'] ?? json['min_deposit']),
      maxDeposit: parseDouble(json['maxDeposit'] ?? json['max_deposit']),
      isCallable: parseBool(json['isCallable'] ?? json['is_callable'], defaultValue: true),
      compoundingFrequency: (json['compoundingFrequency'] ?? json['compounding_frequency'])?.toString(),
      effectiveFrom: (json['effectiveFrom'] ?? json['effective_from'])?.toString(),
      effectiveUntil: (json['effectiveUntil'] ?? json['effective_until'])?.toString(),
      sourceUrl: (json['sourceUrl'] ?? json['source_url'])?.toString(),
      sourceDocumentUrl: (json['sourceDocumentUrl'] ?? json['source_document_url'])?.toString(),
      sourceContentHash: (json['sourceContentHash'] ?? json['source_content_hash'])?.toString(),
      parserId: (json['parserId'] ?? json['parser_id'])?.toString(),
      parserVersion: (json['parserVersion'] ?? json['parser_version'])?.toString(),
      extractedAt: (json['extractedAt'] ?? json['extracted_at'])?.toString(),
      validationStatus: (json['validationStatus'] ?? json['validation_status'])?.toString().toUpperCase() ?? 'VALID',
      validationErrors: parseStringList(json['validationErrors'] ?? json['validation_errors']),
      anomalyFlags: parseStringList(json['anomalyFlags'] ?? json['anomaly_flags']),
      stagingStatus: (json['stagingStatus'] ?? json['staging_status'])?.toString().toUpperCase() ?? 'DRAFT',
      diff: diffJson != null ? CandidateRateDiff.fromJson(diffJson) : null,
      promotedRateId: (json['promotedRateId'] ?? json['promoted_rate_id'])?.toString(),
      promotedAt: (json['promotedAt'] ?? json['promoted_at'])?.toString(),
      promotedBy: (json['promotedBy'] ?? json['promoted_by'])?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  final String id;
  final String bankCode;
  final String? sourceId;
  final String? productType;
  final String customerType;
  final String tenureDomain;
  final String? tenureLabel;
  final String? sourceTenureText;
  final String displayTenure;
  final int? minTenureDays;
  final int? maxTenureDays;
  final int? minYears;
  final int? minMonths;
  final int? minDaysCal;
  final String? minOperator;
  final int? maxYears;
  final int? maxMonths;
  final int? maxDaysCal;
  final String? maxOperator;
  final String? tenureUnit;
  final String? legacyTenureUnit;
  final double interestRate;
  final double? seniorCitizenRate;
  final double? superSeniorRate;
  final double? minDeposit;
  final double? maxDeposit;
  final bool isCallable;
  final String? compoundingFrequency;
  final String? effectiveFrom;
  final String? effectiveUntil;
  final String? sourceUrl;
  final String? sourceDocumentUrl;
  final String? sourceContentHash;
  final String? parserId;
  final String? parserVersion;
  final String? extractedAt;
  final String validationStatus;
  final List<String> validationErrors;
  final List<String> anomalyFlags;
  final String stagingStatus;
  final CandidateRateDiff? diff;
  final String? promotedRateId;
  final String? promotedAt;
  final String? promotedBy;
  final String? notes;

  bool get isDraft => stagingStatus == 'DRAFT';
  bool get isInReview => stagingStatus == 'IN_REVIEW';
  bool get isPromoted => stagingStatus == 'PROMOTED';
  bool get isRejected => stagingStatus == 'REJECTED';

  bool get isValid => validationStatus == 'VALID';
  bool get isInvalid => validationStatus == 'INVALID';
  bool get hasWarnings => validationStatus == 'WARNING' || anomalyFlags.isNotEmpty;

  bool get isCalendarDomain => tenureDomain.toUpperCase() == 'CALENDAR';
  bool get isDaysDomain => tenureDomain.toUpperCase() == 'DAYS';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bankCode': bankCode,
      'sourceId': sourceId,
      'productType': productType,
      'customerType': customerType,
      'tenureDomain': tenureDomain,
      'tenureLabel': tenureLabel,
      'sourceTenureText': sourceTenureText,
      'displayTenure': displayTenure,
      'minTenureDays': minTenureDays,
      'maxTenureDays': maxTenureDays,
      'minYears': minYears,
      'minMonths': minMonths,
      'minDaysCal': minDaysCal,
      'minOperator': minOperator,
      'maxYears': maxYears,
      'maxMonths': maxMonths,
      'maxDaysCal': maxDaysCal,
      'maxOperator': maxOperator,
      'tenureUnit': tenureUnit,
      'legacyTenureUnit': legacyTenureUnit,
      'interestRate': interestRate,
      'seniorCitizenRate': seniorCitizenRate,
      'superSeniorRate': superSeniorRate,
      'minDeposit': minDeposit,
      'maxDeposit': maxDeposit,
      'isCallable': isCallable,
      'compoundingFrequency': compoundingFrequency,
      'effectiveFrom': effectiveFrom,
      'effectiveUntil': effectiveUntil,
      'sourceUrl': sourceUrl,
      'sourceDocumentUrl': sourceDocumentUrl,
      'sourceContentHash': sourceContentHash,
      'parserId': parserId,
      'parserVersion': parserVersion,
      'extractedAt': extractedAt,
      'validationStatus': validationStatus,
      'validationErrors': validationErrors,
      'anomalyFlags': anomalyFlags,
      'stagingStatus': stagingStatus,
      'diff': diff?.toJson(),
      'promotedRateId': promotedRateId,
      'promotedAt': promotedAt,
      'promotedBy': promotedBy,
      'notes': notes,
    };
  }

  @override
  List<Object?> get props => [
        id,
        bankCode,
        sourceId,
        productType,
        customerType,
        tenureDomain,
        displayTenure,
        interestRate,
        seniorCitizenRate,
        superSeniorRate,
        minDeposit,
        maxDeposit,
        isCallable,
        effectiveFrom,
        sourceUrl,
        validationStatus,
        validationErrors,
        anomalyFlags,
        stagingStatus,
        diff,
        promotedRateId,
      ];
}
