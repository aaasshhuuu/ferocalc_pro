// FeroCalc Verified FD Rate Engine
// Public verified-rate API router
//
// These endpoints are publicly accessible (no auth required).
// Data integrity is guaranteed by:
//   1. Supabase RLS — only VERIFIED rows pass through the public query
//   2. The verified_fd_rates VIEW — excludes expired and non-ACTIVE banks
//   3. Explicit status filter in every query (defence in depth)
//
// CRITICAL: DRAFT, IN_REVIEW, REJECTED, ARCHIVED must NEVER appear here.

'use strict';

const express = require('express');
const router  = express.Router();
const { supabasePublic, isSupabaseAvailable } = require('../supabase/supabase_client');
const { getCanonicalMinDaysForMonths, getCanonicalMaxDaysForMonths } = require('../promotion/rate_diff_engine');

// ============================================================
// Helper: create standard response envelope
// ============================================================

function ok(res, data, meta = {}) {
  return res.json({
    status: 'ok',
    data,
    meta: { ...meta, timestamp: new Date().toISOString() },
  });
}

function unavailable(res, reason) {
  return res.status(503).json({
    status: 'unavailable',
    message: reason,
    data: null,
    meta: { timestamp: new Date().toISOString() },
  });
}

function serverError(res, err) {
  console.error('[verified-rates]', err?.message ?? err);
  return res.status(500).json({
    status: 'error',
    message: 'Internal server error',
    data: null,
    meta: { timestamp: new Date().toISOString() },
  });
}

// ============================================================
// Middleware: guard against Supabase being unavailable
// ============================================================

function requireSupabase(req, res, next) {
  if (!isSupabaseAvailable()) {
    return unavailable(res,
      'Verified rate database is not configured. ' +
      'Use /api/rates for unverified reference data.');
  }
  next();
}

// ============================================================
// Helper: Parse and validate isCallable / is_callable filter
// Rules:
// - Omitted / undefined / null / empty: defaults to true (callable only)
// - 'true' or '1': true (callable only)
// - 'false' or '0': false (non-callable only)
// - 'all': null (no filter on is_callable, returns both)
// - Any other value: returns error object (HTTP 400)
// ============================================================

function parseIsCallableFilter(query) {
  const raw = query.isCallable !== undefined ? query.isCallable : query.is_callable;

  if (raw === undefined || raw === null || String(raw).trim() === '') {
    return { filterValue: true, hasError: false };
  }

  const normalized = String(raw).trim().toLowerCase();

  if (normalized === 'true' || normalized === '1') {
    return { filterValue: true, hasError: false };
  }
  if (normalized === 'false' || normalized === '0') {
    return { filterValue: false, hasError: false };
  }
  if (normalized === 'all') {
    return { filterValue: null, hasError: false };
  }

  return {
    filterValue: null,
    hasError: true,
    errorMessage: `Invalid isCallable parameter: "${raw}". Must be one of: true, false, all.`,
  };
}

// ============================================================
// Helper: Parse and validate tenure query parameters
// Supports either:
// - tenureDays (for DAYS domain queries)
// OR
// - years, months, daysCal / days (for CALENDAR domain queries)
// Enforces mutual exclusion, component ranges, and non-empty components.
// ============================================================

function parseTenureQueryParams(query) {
  const hasTenureDays = query.tenureDays !== undefined && query.tenureDays !== null && String(query.tenureDays).trim() !== '';
  const hasYears      = query.years !== undefined && query.years !== null && String(query.years).trim() !== '';
  const hasMonths     = query.months !== undefined && query.months !== null && String(query.months).trim() !== '';
  const rawDaysCal    = query.daysCal !== undefined ? query.daysCal : query.days;
  const hasDaysCal    = rawDaysCal !== undefined && rawDaysCal !== null && String(rawDaysCal).trim() !== '';

  const hasCalendar = hasYears || hasMonths || hasDaysCal;

  // Mutual exclusion: cannot mix tenureDays and calendar components
  if (hasTenureDays && hasCalendar) {
    return {
      domain: null,
      hasError: true,
      errorMessage: 'Mutually exclusive parameters: cannot specify both tenureDays and calendar components (years, months, daysCal).',
    };
  }

  // 1. DAYS domain query
  if (hasTenureDays) {
    const rawVal = String(query.tenureDays).trim();
    const days = Number(rawVal);
    if (!Number.isInteger(days) || days < 0) {
      return {
        domain: null,
        hasError: true,
        errorMessage: 'tenureDays must be a non-negative integer.',
      };
    }
    return {
      domain: 'DAYS',
      tenureDays: days,
      hasError: false,
    };
  }

  // 2. CALENDAR domain query
  if (hasCalendar) {
    let y = 0;
    if (hasYears) {
      const val = Number(String(query.years).trim());
      if (!Number.isInteger(val) || val < 0) {
        return {
          domain: null,
          hasError: true,
          errorMessage: 'years must be a non-negative integer.',
        };
      }
      y = val;
    }

    let m = 0;
    if (hasMonths) {
      const val = Number(String(query.months).trim());
      if (!Number.isInteger(val) || val < 0 || val > 11) {
        return {
          domain: null,
          hasError: true,
          errorMessage: 'months must be an integer between 0 and 11.',
        };
      }
      m = val;
    }

    let d = 0;
    if (hasDaysCal) {
      const val = Number(String(rawDaysCal).trim());
      if (!Number.isInteger(val) || val < 0) {
        return {
          domain: null,
          hasError: true,
          errorMessage: 'daysCal must be a non-negative integer.',
        };
      }
      d = val;
    }

    if (y === 0 && m === 0 && d === 0) {
      return {
        domain: null,
        hasError: true,
        errorMessage: 'At least one calendar tenure component (years, months, daysCal) must be greater than zero.',
      };
    }

    return {
      domain: 'CALENDAR',
      years: y,
      months: m,
      daysCal: d,
      hasError: false,
    };
  }

  // 3. No tenure filter
  return {
    domain: null,
    hasError: false,
  };
}

// ============================================================
// Helper: Canonical Gregorian Calendar Comparison
// Compares two calendar tuples (y1, m1, d1) and (y2, m2, d2).
// Returns:
//   -1 if t1 < t2
//    1 if t1 > t2
//    0 if t1 == t2
//   null if indeterminate without an anchor date
// ============================================================

function compareCalendarTuples(t1, t2) {
  if (!t1 || !t2) return null;

  const y1 = Number(t1.years ?? 0);
  const m1 = Number(t1.months ?? 0);
  const d1 = Number(t1.daysCal ?? t1.days ?? 0);

  const y2 = Number(t2.years ?? 0);
  const m2 = Number(t2.months ?? 0);
  const d2 = Number(t2.daysCal ?? t2.days ?? 0);

  const totalM1 = y1 * 12 + m1;
  const totalM2 = y2 * 12 + m2;

  if (totalM1 === totalM2) {
    if (d1 < d2) return -1;
    if (d1 > d2) return 1;
    return 0;
  }

  if (totalM1 < totalM2) {
    const deltaM = totalM2 - totalM1;
    const minDays = getCanonicalMinDaysForMonths(deltaM);
    const maxDays = getCanonicalMaxDaysForMonths(deltaM);
    const dayDelta = d1 - d2;

    if (dayDelta < minDays) return -1;
    if (dayDelta > maxDays) return 1;
    return null;
  } else {
    const deltaM = totalM1 - totalM2;
    const minDays = getCanonicalMinDaysForMonths(deltaM);
    const maxDays = getCanonicalMaxDaysForMonths(deltaM);
    const dayDelta = d2 - d1;

    if (dayDelta < minDays) return 1;
    if (dayDelta > maxDays) return -1;
    return null;
  }
}

// ============================================================
// Helper: coversCalendarTenure
// Evaluates whether a VERIFIED rate record covers a requested calendar tenure.
// Returns:
//   true: candidate tenure is provably within the slab bounds
//   false: candidate tenure is outside the slab, or record is not CALENDAR
//   null: coverage is indeterminate without an anchor date (unresolved)
// ============================================================

function coversCalendarTenure(record, requested) {
  if (!record || record.tenure_domain !== 'CALENDAR') return false;

  const reqTuple = {
    years: Number(requested.years ?? 0),
    months: Number(requested.months ?? 0),
    daysCal: Number(requested.daysCal ?? requested.days ?? 0),
  };

  // 1. Lower Bound Check
  const hasLower = (record.min_operator != null || record.minOperator != null) ||
                   (record.min_years != null || record.minYears != null) ||
                   (record.min_months != null || record.minMonths != null) ||
                   (record.min_days_cal != null || record.min_days != null || record.minDaysCal != null);

  if (hasLower) {
    const lowerTuple = {
      years: Number(record.min_years ?? record.minYears ?? 0),
      months: Number(record.min_months ?? record.minMonths ?? 0),
      daysCal: Number(record.min_days_cal ?? record.min_days ?? record.minDaysCal ?? 0),
    };
    const lowerOp = String(record.min_operator || record.minOperator || 'GTE').toUpperCase();
    const cmpL = compareCalendarTuples(reqTuple, lowerTuple);
    if (cmpL === null) return null; // Unresolved without anchor date
    if (lowerOp === 'GTE' && cmpL < 0) return false;
    if (lowerOp === 'GT' && cmpL <= 0) return false;
  }

  // 2. Upper Bound Check (open-ended if no upper operator/components)
  const hasUpper = (record.max_operator != null || record.maxOperator != null) ||
                   (record.max_years != null || record.maxYears != null) ||
                   (record.max_months != null || record.maxMonths != null) ||
                   (record.max_days_cal != null || record.max_days != null || record.maxDaysCal != null);

  if (hasUpper) {
    const upperTuple = {
      years: Number(record.max_years ?? record.maxYears ?? 0),
      months: Number(record.max_months ?? record.maxMonths ?? 0),
      daysCal: Number(record.max_days_cal ?? record.max_days ?? record.maxDaysCal ?? 0),
    };
    const upperOp = String(record.max_operator || record.maxOperator || 'LTE').toUpperCase();
    const cmpU = compareCalendarTuples(reqTuple, upperTuple);
    if (cmpU === null) return null; // Unresolved without anchor date
    if (upperOp === 'LTE' && cmpU > 0) return false;
    if (upperOp === 'LT' && cmpU >= 0) return false;
  }

  return true;
}

// ============================================================
// GET /api/verified-rates
// Returns all currently active VERIFIED rates.
// Supports filters: customerType, bankId, tenureDays, depositAmount, isCallable
// ============================================================

router.get('/', requireSupabase, async (req, res) => {
  try {
    const { customerType, bankId, depositAmount } = req.query;

    const callableCheck = parseIsCallableFilter(req.query);
    if (callableCheck.hasError) {
      return res.status(400).json({
        status: 'error',
        message: callableCheck.errorMessage,
      });
    }

    const tenureCheck = parseTenureQueryParams(req.query);
    if (tenureCheck.hasError) {
      return res.status(400).json({
        status: 'error',
        message: tenureCheck.errorMessage,
      });
    }

    // Always query the view — which already filters for VERIFIED + active banks + non-expired
    let query = supabasePublic
      .from('verified_fd_rates')
      .select('*')
      .order('interest_rate', { ascending: false });

    // Filter by callable / non-callable (default: true)
    if (callableCheck.filterValue !== null) {
      query = query.eq('is_callable', callableCheck.filterValue);
    }

    // Filter by customer type
    if (customerType) {
      const validTypes = ['REGULAR', 'SENIOR_CITIZEN', 'SUPER_SENIOR_CITIZEN', 'STAFF', 'NRE', 'NRO'];
      if (!validTypes.includes(customerType.toUpperCase())) {
        return res.status(400).json({
          status: 'error',
          message: `Invalid customerType. Must be one of: ${validTypes.join(', ')}`,
        });
      }
      query = query.eq('customer_type', customerType.toUpperCase());
    }

    // Filter by bank
    if (bankId) {
      query = query.eq('bank_id', bankId);
    }

    // Filter by tenure: DAYS or CALENDAR
    if (tenureCheck.domain === 'DAYS') {
      query = query
        .eq('tenure_domain', 'DAYS')
        .lte('min_tenure_days', tenureCheck.tenureDays)
        .gte('max_tenure_days', tenureCheck.tenureDays);
    } else if (tenureCheck.domain === 'CALENDAR') {
      // CALENDAR query — match CALENDAR domain records
      query = query.eq('tenure_domain', 'CALENDAR');
    }


    // Filter by deposit amount (rate's deposit range must include this amount)
    if (depositAmount) {
      const amount = parseFloat(depositAmount);
      if (isNaN(amount) || amount < 0) {
        return res.status(400).json({ status: 'error', message: 'depositAmount must be a non-negative number' });
      }
      query = query
        .lte('min_deposit', amount)
        .or(`max_deposit.is.null,max_deposit.gte.${amount}`);
    }

    const { data, error } = await query;

    if (error) throw error;

    let resultData = data ?? [];
    if (tenureCheck.domain === 'CALENDAR') {
      resultData = resultData.filter(r => coversCalendarTenure(r, tenureCheck) === true);
    }

    return ok(res, resultData, {
      count: resultData.length,
      source: 'verified',
      note: 'All rates are manually verified against official bank sources.',
    });

  } catch (err) {
    return serverError(res, err);
  }
});

// ============================================================
// GET /api/verified-rates/top
// Returns top N banks by highest interest rate for a tenure.
// Only VERIFIED rates are ranked.
// ============================================================

router.get('/top', requireSupabase, async (req, res) => {
  try {
    const { customerType, limit } = req.query;
    const topLimit = Math.min(parseInt(limit, 10) || 10, 50); // cap at 50

    const callableCheck = parseIsCallableFilter(req.query);
    if (callableCheck.hasError) {
      return res.status(400).json({
        status: 'error',
        message: callableCheck.errorMessage,
      });
    }

    const tenureCheck = parseTenureQueryParams(req.query);
    if (tenureCheck.hasError) {
      return res.status(400).json({
        status: 'error',
        message: tenureCheck.errorMessage,
      });
    }

    let query = supabasePublic
      .from('verified_fd_rates')
      .select('*')
      .order('interest_rate', { ascending: false });

    // When tenure domain is DAYS or unspecified, push limit to the database query.
    // For CALENDAR domain, post-filtering by exact calendar coverage is performed before slicing to limit.
    if (tenureCheck.domain !== 'CALENDAR') {
      query = query.limit(topLimit);
    }

    // Filter by callable / non-callable (default: true)
    if (callableCheck.filterValue !== null) {
      query = query.eq('is_callable', callableCheck.filterValue);
    }

    if (customerType) {
      query = query.eq('customer_type', customerType.toUpperCase());
    }

    if (tenureCheck.domain === 'DAYS') {
      query = query
        .eq('tenure_domain', 'DAYS')
        .lte('min_tenure_days', tenureCheck.tenureDays)
        .gte('max_tenure_days', tenureCheck.tenureDays);
    } else if (tenureCheck.domain === 'CALENDAR') {
      query = query.eq('tenure_domain', 'CALENDAR');
    }

    const { data, error } = await query;
    if (error) throw error;

    let resultData = data ?? [];
    if (tenureCheck.domain === 'CALENDAR') {
      // Unresolved calendar coverage (null) is strictly excluded and never presented as confirmed best rate
      resultData = resultData.filter(r => coversCalendarTenure(r, tenureCheck) === true).slice(0, topLimit);
    }

    if (!resultData || resultData.length === 0) {
      return ok(res, [], {
        count: 0,
        source: 'verified',
        note: 'No verified rates available yet. All rates shown in /api/rates are unverified reference data.',
      });
    }

    return ok(res, resultData, {
      count: resultData.length,
      source: 'verified',
      ranked_by: 'interest_rate_descending',
    });

  } catch (err) {
    return serverError(res, err);
  }
});

// ============================================================
// GET /api/verified-rates/bank/:id
// Returns all VERIFIED rates for a specific bank by UUID.
// ============================================================

router.get('/bank/:id', requireSupabase, async (req, res) => {
  try {
    const { id } = req.params;
    const { customerType } = req.query;

    // Basic UUID format guard
    const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!UUID_RE.test(id)) {
      return res.status(400).json({ status: 'error', message: 'Invalid bank id format (expected UUID)' });
    }

    const callableCheck = parseIsCallableFilter(req.query);
    if (callableCheck.hasError) {
      return res.status(400).json({
        status: 'error',
        message: callableCheck.errorMessage,
      });
    }

    let query = supabasePublic
      .from('verified_fd_rates')
      .select('*')
      .eq('bank_id', id)
      .order('customer_type')
      .order('min_tenure_days');

    // Filter by callable / non-callable (default: true)
    if (callableCheck.filterValue !== null) {
      query = query.eq('is_callable', callableCheck.filterValue);
    }

    if (customerType) {
      query = query.eq('customer_type', customerType.toUpperCase());
    }

    const { data, error } = await query;
    if (error) throw error;

    if (!data || data.length === 0) {
      // Honest empty state — do NOT silently fall back to unverified data
      return ok(res, [], {
        count: 0,
        bank_id: id,
        source: 'verified',
        note: 'No verified rates found for this bank. Reference unverified data at /api/rates if needed.',
      });
    }

    return ok(res, data, { count: data.length, bank_id: id, source: 'verified' });

  } catch (err) {
    return serverError(res, err);
  }
});

// ============================================================
// GET /api/verified-rates/banks
// Returns the pilot bank registry (metadata only, no rates).
// ============================================================

router.get('/banks', requireSupabase, async (req, res) => {
  try {
    const { data, error } = await supabasePublic
      .from('banks')
      .select('id, name, short_name, type, status, official_website')
      .eq('status', 'ACTIVE')
      .order('name');

    if (error) throw error;
    return ok(res, data ?? [], { count: (data ?? []).length });

  } catch (err) {
    return serverError(res, err);
  }
});

router.parseIsCallableFilter = parseIsCallableFilter;
router.parseTenureQueryParams = parseTenureQueryParams;
router.compareCalendarTuples = compareCalendarTuples;
router.coversCalendarTenure = coversCalendarTenure;

module.exports = router;
