/// FeroCalc Verified FD Rate Engine — Calendar Tenure Domain Tests (Migration 009)
///
/// Tests cover:
/// - TenureDomain enum parsing and apiValue
/// - BoundaryOperator enum parsing, apiValue, and isInclusive
/// - VerifiedFdRate.fromJson with CALENDAR fields (nullable day columns)
/// - VerifiedFdRate.toJson round-trip for CALENDAR records
/// - tenureDescription returns sourceTenureText for CALENDAR records
/// - tenureDescription uses _formatDays for DAYS records (not sourceTenureText)
/// - coverstenure returns false for CALENDAR records (always)
/// - coverstenure works correctly for DAYS records (nullable int?)
/// - Backward compatibility: records without tenure_domain default to DAYS

import 'package:flutter_test/flutter_test.dart';
import 'package:fincalc_pro/core/models/verified_fd_rate.dart';

// ============================================================
// Test data helpers
// ============================================================

/// Minimal DAYS record with all required fields.
VerifiedFdRate makeCalendarRate({
  String sourceTenureText = '1 year to less than 2 years',
  int? minYears = 1,
  int? minMonths = 0,
  int? minDaysCal = 0,
  BoundaryOperator? minOperator = BoundaryOperator.gte,
  int? maxYears = 2,
  int? maxMonths = 0,
  int? maxDaysCal = 0,
  BoundaryOperator? maxOperator = BoundaryOperator.lt,
}) {
  return VerifiedFdRate(
    id: 'cal-rate-001',
    bankId: 'bank-axis',
    bankName: 'Axis Bank',
    bankShortName: 'AXIS',
    customerType: VerifiedCustomerType.regular,
    minDeposit: 1000,
    interestRate: 7.10,
    isCallable: true,
    compoundingFrequency: CompoundingFrequency.quarterly,
    effectiveFrom: DateTime(2026, 1, 1),
    tenureDomain: TenureDomain.calendar,
    sourceTenureText: sourceTenureText,
    minYears: minYears,
    minMonths: minMonths,
    minDaysCal: minDaysCal,
    minOperator: minOperator,
    maxYears: maxYears,
    maxMonths: maxMonths,
    maxDaysCal: maxDaysCal,
    maxOperator: maxOperator,
  );
}

/// Minimal DAYS record — mirrors the legacy constructor call pattern.
VerifiedFdRate makeDaysRate({
  int? minTenureDays = 365,
  int? maxTenureDays = 729,
  String? sourceTenureText = '365 days to 729 days',
}) {
  return VerifiedFdRate(
    id: 'days-rate-001',
    bankId: 'bank-sbi',
    bankName: 'State Bank of India',
    bankShortName: 'SBI',
    customerType: VerifiedCustomerType.regular,
    minTenureDays: minTenureDays,
    maxTenureDays: maxTenureDays,
    minDeposit: 1000,
    interestRate: 6.25,
    isCallable: true,
    compoundingFrequency: CompoundingFrequency.quarterly,
    effectiveFrom: DateTime(2026, 1, 1),
    tenureDomain: TenureDomain.days,
    sourceTenureText: sourceTenureText,
  );
}

Map<String, dynamic> makeCalendarJson({
  String? tenureDomain = 'CALENDAR',
  String sourceTenureText = '1 year to less than 2 years',
  int? minYears = 1,
  int? minMonths = 0,
  int? minDaysCal = 0,
  String? minOperator = 'GTE',
  int? maxYears = 2,
  int? maxMonths = 0,
  int? maxDaysCal = 0,
  String? maxOperator = 'LT',
}) {
  return {
    'id': 'cal-json-001',
    'bank_id': 'bank-axis',
    'bank_name': 'Axis Bank',
    'bank_short_name': 'AXIS',
    'bank_source_domain': 'axisbank.com',
    'customer_type': 'REGULAR',
    'min_tenure_days': null,  // Must be null for CALENDAR
    'max_tenure_days': null,  // Must be null for CALENDAR
    'min_deposit': 1000.0,
    'max_deposit': null,
    'interest_rate': 7.10,
    'is_callable': true,
    'compounding_frequency': 'QUARTERLY',
    'effective_from': '2026-01-01T00:00:00.000Z',
    'effective_until': null,
    'source_url': 'https://axisbank.com/interest-rates',
    'verified_at': '2026-09-01T12:00:00.000Z',
    'review_notes': null,
    'rate_category': 'STANDARD',
    'scheme_name': null,
    'tenure_domain': tenureDomain,
    'source_tenure_text': sourceTenureText,
    'min_years': minYears,
    'min_months': minMonths,
    'min_days_cal': minDaysCal,
    'min_operator': minOperator,
    'max_years': maxYears,
    'max_months': maxMonths,
    'max_days_cal': maxDaysCal,
    'max_operator': maxOperator,
  };
}

// ============================================================
// Tests
// ============================================================

void main() {
  // ----------------------------------------------------------
  // 1. TenureDomain enum
  // ----------------------------------------------------------

  group('TenureDomain enum', () {
    test('fromString parses DAYS', () {
      expect(TenureDomain.fromString('DAYS'), TenureDomain.days);
    });

    test('fromString parses CALENDAR', () {
      expect(TenureDomain.fromString('CALENDAR'), TenureDomain.calendar);
    });

    test('fromString is case-insensitive', () {
      expect(TenureDomain.fromString('calendar'), TenureDomain.calendar);
      expect(TenureDomain.fromString('days'), TenureDomain.days);
    });

    test('fromString defaults to days for unknown values', () {
      expect(TenureDomain.fromString('WEEKS'), TenureDomain.days);
      expect(TenureDomain.fromString(null), TenureDomain.days);
      expect(TenureDomain.fromString(''), TenureDomain.days);
    });

    test('apiValue returns correct wire value', () {
      expect(TenureDomain.days.apiValue, 'DAYS');
      expect(TenureDomain.calendar.apiValue, 'CALENDAR');
    });
  });

  // ----------------------------------------------------------
  // 2. BoundaryOperator enum
  // ----------------------------------------------------------

  group('BoundaryOperator enum', () {
    test('fromString parses all four operators', () {
      expect(BoundaryOperator.fromString('GTE'), BoundaryOperator.gte);
      expect(BoundaryOperator.fromString('GT'),  BoundaryOperator.gt);
      expect(BoundaryOperator.fromString('LTE'), BoundaryOperator.lte);
      expect(BoundaryOperator.fromString('LT'),  BoundaryOperator.lt);
    });

    test('fromString is case-insensitive', () {
      expect(BoundaryOperator.fromString('gte'), BoundaryOperator.gte);
      expect(BoundaryOperator.fromString('lte'), BoundaryOperator.lte);
    });

    test('fromString defaults to gte for unknown values', () {
      expect(BoundaryOperator.fromString('UNKNOWN'), BoundaryOperator.gte);
      expect(BoundaryOperator.fromString(null), BoundaryOperator.gte);
    });

    test('apiValue returns correct wire value', () {
      expect(BoundaryOperator.gte.apiValue, 'GTE');
      expect(BoundaryOperator.gt.apiValue,  'GT');
      expect(BoundaryOperator.lte.apiValue, 'LTE');
      expect(BoundaryOperator.lt.apiValue,  'LT');
    });

    test('isInclusive is true only for GTE and LTE', () {
      expect(BoundaryOperator.gte.isInclusive, isTrue);
      expect(BoundaryOperator.lte.isInclusive, isTrue);
      expect(BoundaryOperator.gt.isInclusive,  isFalse);
      expect(BoundaryOperator.lt.isInclusive,  isFalse);
    });
  });

  // ----------------------------------------------------------
  // 3. CALENDAR record deserialization
  // ----------------------------------------------------------

  group('CALENDAR record fromJson', () {
    test('parses all CALENDAR fields correctly', () {
      final json = makeCalendarJson();
      final rate = VerifiedFdRate.fromJson(json);

      expect(rate.tenureDomain, TenureDomain.calendar);
      expect(rate.sourceTenureText, '1 year to less than 2 years');
      expect(rate.minTenureDays, isNull);
      expect(rate.maxTenureDays, isNull);
      expect(rate.minYears, 1);
      expect(rate.minMonths, 0);
      expect(rate.minDaysCal, 0);
      expect(rate.minOperator, BoundaryOperator.gte);
      expect(rate.maxYears, 2);
      expect(rate.maxMonths, 0);
      expect(rate.maxDaysCal, 0);
      expect(rate.maxOperator, BoundaryOperator.lt);
    });

    test('null min/max_tenure_days in CALENDAR record are preserved as null', () {
      final json = makeCalendarJson();
      json['min_tenure_days'] = null;
      json['max_tenure_days'] = null;
      final rate = VerifiedFdRate.fromJson(json);
      // Critical: must NOT fall back to 0 for CALENDAR records
      expect(rate.minTenureDays, isNull, reason: 'CALENDAR must not substitute 0 for null day columns');
      expect(rate.maxTenureDays, isNull, reason: 'CALENDAR must not substitute 0 for null day columns');
    });

    test('null operators are preserved as null', () {
      final json = makeCalendarJson(minOperator: null, maxOperator: null);
      final rate = VerifiedFdRate.fromJson(json);
      expect(rate.minOperator, isNull);
      expect(rate.maxOperator, isNull);
    });

    test('fromJson backward compat: absent tenure_domain field defaults to DAYS', () {
      final json = makeCalendarJson();
      json.remove('tenure_domain');
      final rate = VerifiedFdRate.fromJson(json);
      // If field is absent, TenureDomain.fromString(null) should return days
      expect(rate.tenureDomain, TenureDomain.days, reason: 'Absent tenure_domain defaults to DAYS for backward compat');
    });
  });

  // ----------------------------------------------------------
  // 4. CALENDAR record serialization (toJson round-trip)
  // ----------------------------------------------------------

  group('CALENDAR record toJson', () {
    test('toJson produces correct wire values', () {
      final rate = makeCalendarRate();
      final json = rate.toJson();

      expect(json['tenure_domain'], 'CALENDAR');
      expect(json['source_tenure_text'], '1 year to less than 2 years');
      expect(json['min_tenure_days'], isNull);
      expect(json['max_tenure_days'], isNull);
      expect(json['min_years'], 1);
      expect(json['min_operator'], 'GTE');
      expect(json['max_years'], 2);
      expect(json['max_operator'], 'LT');
    });

    test('toJson + fromJson round-trip preserves all CALENDAR fields', () {
      final original = makeCalendarRate();
      final restored = VerifiedFdRate.fromJson(original.toJson());

      expect(restored.tenureDomain,     original.tenureDomain);
      expect(restored.sourceTenureText, original.sourceTenureText);
      expect(restored.minTenureDays,    isNull);
      expect(restored.maxTenureDays,    isNull);
      expect(restored.minYears,         original.minYears);
      expect(restored.minMonths,        original.minMonths);
      expect(restored.minDaysCal,       original.minDaysCal);
      expect(restored.minOperator,      original.minOperator);
      expect(restored.maxYears,         original.maxYears);
      expect(restored.maxMonths,        original.maxMonths);
      expect(restored.maxDaysCal,       original.maxDaysCal);
      expect(restored.maxOperator,      original.maxOperator);
    });
  });

  // ----------------------------------------------------------
  // 5. tenureDescription — CALENDAR vs DAYS dispatch
  // ----------------------------------------------------------

  group('tenureDescription', () {
    test('CALENDAR records return sourceTenureText verbatim', () {
      final rate = makeCalendarRate(sourceTenureText: '1 year to less than 2 years');
      expect(rate.tenureDescription, '1 year to less than 2 years',
        reason: 'CALENDAR tenureDescription must be verbatim sourceTenureText, not a day/month/year conversion');
    });

    test('CALENDAR records return sourceTenureText with special chars verbatim', () {
      const txt = '15 months < tenure <= 18 months';
      final rate = makeCalendarRate(sourceTenureText: txt);
      expect(rate.tenureDescription, txt);
    });

    test('CALENDAR records with null sourceTenureText return empty string', () {
      final rate = VerifiedFdRate(
        id: 'x', bankId: 'b', bankName: 'B', bankShortName: 'B',
        customerType: VerifiedCustomerType.regular,
        minDeposit: 0, interestRate: 5.0, isCallable: true,
        compoundingFrequency: CompoundingFrequency.quarterly,
        effectiveFrom: DateTime(2026),
        tenureDomain: TenureDomain.calendar,
        sourceTenureText: null, // explicitly null
      );
      expect(rate.tenureDescription, '');
    });

    test('DAYS records use integer day formatting, not sourceTenureText', () {
      // 7 days — must show "7 days", not sourceTenureText
      final rate = makeDaysRate(
        minTenureDays: 7, maxTenureDays: 7,
        sourceTenureText: 'SHOULD NOT APPEAR',
      );
      expect(rate.tenureDescription, '7 days');
    });

    test('DAYS records format 365-729 day range correctly', () {
      final rate = makeDaysRate(minTenureDays: 365, maxTenureDays: 729);
      expect(rate.tenureDescription, contains('year'));
      // Should NOT contain any 30-day month heuristic numbers like "24 months"
    });

    test('DAYS records format single-day point tenure', () {
      final rate = makeDaysRate(minTenureDays: 90, maxTenureDays: 90);
      expect(rate.tenureDescription, '3 months');
    });
  });

  // ----------------------------------------------------------
  // 6. coverstenure — domain dispatch
  // ----------------------------------------------------------

  group('coverstenure', () {
    test('CALENDAR records always return false for integer day query', () {
      final rate = makeCalendarRate();
      // Integer day queries are meaningless for symbolic calendar records
      expect(rate.coverstenure(365), isFalse,
        reason: 'CALENDAR records must never match integer-day queries');
      expect(rate.coverstenure(500), isFalse);
      expect(rate.coverstenure(0),   isFalse);
    });

    test('DAYS records return true when days is within range', () {
      final rate = makeDaysRate(minTenureDays: 180, maxTenureDays: 364);
      expect(rate.coverstenure(180), isTrue);
      expect(rate.coverstenure(270), isTrue);
      expect(rate.coverstenure(364), isTrue);
    });

    test('DAYS records return false when days is out of range', () {
      final rate = makeDaysRate(minTenureDays: 180, maxTenureDays: 364);
      expect(rate.coverstenure(179), isFalse);
      expect(rate.coverstenure(365), isFalse);
    });

    test('DAYS records with null day columns return false', () {
      // A DAYS record that somehow has null day columns (defensive)
      final rate = makeDaysRate(minTenureDays: null, maxTenureDays: null);
      expect(rate.coverstenure(365), isFalse);
    });
  });

  // ----------------------------------------------------------
  // 7. DAYS record backward compatibility
  // ----------------------------------------------------------

  group('DAYS record backward compatibility', () {
    test('DAYS records preserve minTenureDays and maxTenureDays', () {
      final rate = makeDaysRate(minTenureDays: 365, maxTenureDays: 729);
      expect(rate.minTenureDays, 365);
      expect(rate.maxTenureDays, 729);
    });

    test('DAYS records have null calendar component fields', () {
      final rate = makeDaysRate();
      expect(rate.minYears,    isNull);
      expect(rate.minMonths,   isNull);
      expect(rate.minDaysCal,  isNull);
      expect(rate.minOperator, isNull);
      expect(rate.maxYears,    isNull);
      expect(rate.maxMonths,   isNull);
      expect(rate.maxDaysCal,  isNull);
      expect(rate.maxOperator, isNull);
    });

    test('fromJson DAYS record: min/max_tenure_days are preserved as int', () {
      final json = {
        'id': 'days-001', 'bank_id': 'b', 'bank_name': 'B', 'bank_short_name': 'B',
        'customer_type': 'REGULAR', 'min_tenure_days': 365, 'max_tenure_days': 729,
        'min_deposit': 1000.0, 'interest_rate': 6.25, 'is_callable': true,
        'compounding_frequency': 'QUARTERLY', 'effective_from': '2026-01-01T00:00:00.000Z',
        'effective_until': null, 'source_url': null, 'verified_at': null, 'review_notes': null,
        'rate_category': 'STANDARD', 'scheme_name': null,
        'tenure_domain': 'DAYS', 'source_tenure_text': '365 days to 729 days',
        'min_years': null, 'min_months': null, 'min_days_cal': null, 'min_operator': null,
        'max_years': null, 'max_months': null, 'max_days_cal': null, 'max_operator': null,
      };
      final rate = VerifiedFdRate.fromJson(json);
      expect(rate.minTenureDays, 365);
      expect(rate.maxTenureDays, 729);
      expect(rate.tenureDomain, TenureDomain.days);
    });
  });
}
