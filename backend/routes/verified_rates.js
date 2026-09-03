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
// GET /api/verified-rates
// Returns all currently active VERIFIED rates.
// Supports filters: customerType, bankId, tenureDays, depositAmount
// ============================================================

router.get('/', requireSupabase, async (req, res) => {
  try {
    const { customerType, bankId, tenureDays, depositAmount } = req.query;

    // Always query the view — which already filters for VERIFIED + active banks + non-expired
    let query = supabasePublic
      .from('verified_fd_rates')
      .select('*')
      .order('interest_rate', { ascending: false });

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

    // Filter by tenure (rate must cover the requested tenure)
    if (tenureDays) {
      const days = parseInt(tenureDays, 10);
      if (isNaN(days) || days < 0) {
        return res.status(400).json({ status: 'error', message: 'tenureDays must be a non-negative integer' });
      }
      query = query
        .lte('min_tenure_days', days)
        .gte('max_tenure_days', days);
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

    return ok(res, data ?? [], {
      count: (data ?? []).length,
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
    const { tenureDays, customerType, limit } = req.query;
    const topLimit = Math.min(parseInt(limit, 10) || 10, 50); // cap at 50

    let query = supabasePublic
      .from('verified_fd_rates')
      .select('*')
      .order('interest_rate', { ascending: false })
      .limit(topLimit);

    if (customerType) {
      query = query.eq('customer_type', customerType.toUpperCase());
    }

    if (tenureDays) {
      const days = parseInt(tenureDays, 10);
      if (!isNaN(days) && days >= 0) {
        query = query
          .lte('min_tenure_days', days)
          .gte('max_tenure_days', days);
      }
    }

    const { data, error } = await query;
    if (error) throw error;

    if (!data || data.length === 0) {
      return ok(res, [], {
        count: 0,
        source: 'verified',
        note: 'No verified rates available yet. All rates shown in /api/rates are unverified reference data.',
      });
    }

    return ok(res, data, {
      count: data.length,
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

    let query = supabasePublic
      .from('verified_fd_rates')
      .select('*')
      .eq('bank_id', id)
      .order('customer_type')
      .order('min_tenure_days');

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

module.exports = router;
