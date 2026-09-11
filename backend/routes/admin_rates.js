// FeroCalc Verified FD Rate Engine
// Admin API router — protected, server-side only
//
// Auth flow:
//   1. Admin logs in via Supabase Auth (email+password)
//   2. Client sends the Supabase JWT in Authorization: Bearer <token>
//   3. This router verifies the JWT server-side via supabaseAdmin.auth.getUser()
//   4. Checks ferocalc_role in app_metadata == ADMIN or REVIEWER
//
// NEVER exposed publicly. All DB operations use supabaseAdmin (service-role).
// The service-role key NEVER leaves the server.

'use strict';

const express = require('express');
const router  = express.Router();
const {
  supabaseAdmin,
  verifySupabaseUser,
  isFeroCalcAdmin,
  isSupabaseAvailable,
} = require('../supabase/supabase_client');

// ============================================================
// Auth middleware
// ============================================================

async function requireAdmin(req, res, next) {
  if (!isSupabaseAvailable() || !supabaseAdmin) {
    return res.status(503).json({ status: 'error', message: 'Admin service unavailable' });
  }

  const authHeader = req.headers['authorization'] ?? '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

  if (!token) {
    return res.status(401).json({ status: 'error', message: 'Missing authorization token' });
  }

  try {
    const user = await verifySupabaseUser(token);
    if (!isFeroCalcAdmin(user)) {
      return res.status(403).json({ status: 'error', message: 'Insufficient permissions' });
    }
    req.adminUser = user;
    next();
  } catch {
    return res.status(401).json({ status: 'error', message: 'Invalid or expired token' });
  }
}

// ============================================================
// Allowed source domains (Phase H: source rule)
// ============================================================

const ALLOWED_SOURCE_DOMAINS = [
  'sbi.co.in',
  'hdfcbank.com',
  'icicibank.com',
  'axisbank.com',
  'theunitybank.com',
];

function isOfficialDomain(url) {
  if (!url) return false;
  try {
    const parsed = new URL(url);
    const host = parsed.hostname.toLowerCase().replace(/^www\./, '');
    return ALLOWED_SOURCE_DOMAINS.some(d => host === d || host.endsWith('.' + d));
  } catch {
    return false;
  }
}

// ============================================================
// Helpers: rate_category / scheme_name validation
// ============================================================

const VALID_RATE_CATEGORIES = ['STANDARD', 'SPECIAL_SCHEME'];

/**
 * Validate and normalize rate_category + scheme_name.
 * Returns { rateCategory, schemeName } on success or pushes to errors[].
 */
function validateCategoryFields(body, errors) {
  const rateCategory = (body.rate_category ?? 'STANDARD').toString().toUpperCase().trim();
  if (!VALID_RATE_CATEGORIES.includes(rateCategory)) {
    errors.push(`rate_category must be one of: ${VALID_RATE_CATEGORIES.join(', ')}`);
    return { rateCategory: 'STANDARD', schemeName: null };
  }

  const rawScheme = body.scheme_name != null ? String(body.scheme_name).trim().toUpperCase() : null;

  if (rateCategory === 'SPECIAL_SCHEME') {
    if (!rawScheme || rawScheme === '') {
      errors.push('scheme_name is required and must be non-empty for SPECIAL_SCHEME rates');
    }
  } else {
    // STANDARD must not carry a scheme_name
    if (rawScheme != null && rawScheme !== '') {
      errors.push('scheme_name must be null/absent for STANDARD rates');
    }
  }

  return {
    rateCategory,
    schemeName: rateCategory === 'SPECIAL_SCHEME' ? rawScheme : null,
  };
}

// ============================================================
// Helpers: tenure_domain validation (Migration 009)
// ============================================================

const VALID_TENURE_DOMAINS = ['DAYS', 'CALENDAR'];
const VALID_MIN_OPERATORS  = ['GTE', 'GT'];
const VALID_MAX_OPERATORS  = ['LTE', 'LT'];

// Fields that belong exclusively to the DAYS domain
const DAYS_ONLY_FIELDS = ['min_tenure_days', 'max_tenure_days'];

// Fields that belong exclusively to the CALENDAR domain
const CALENDAR_ONLY_FIELDS = [
  'min_years', 'min_months', 'min_days_cal', 'min_operator',
  'max_years', 'max_months', 'max_days_cal', 'max_operator',
  'source_tenure_text',
];

/**
 * Validate tenure_domain and its associated fields.
 * Returns { tenureDomain, tenurePayload } on success, pushes to errors[].
 *
 * DAYS:
 *   - min_tenure_days + max_tenure_days required, non-negative, max >= min
 *   - All calendar-only fields must be absent / null
 *
 * CALENDAR:
 *   - min_tenure_days + max_tenure_days must be absent / null
 *   - source_tenure_text required and non-empty
 *   - at least one calendar component required
 *   - min_operator in GTE/GT, max_operator in LTE/LT
 *   - all present components non-negative, months in [0,11]
 */
function validateTenureDomain(body, errors) {
  const tenureDomain = (body.tenure_domain ?? 'DAYS').toString().toUpperCase().trim();

  if (!VALID_TENURE_DOMAINS.includes(tenureDomain)) {
    errors.push(`tenure_domain must be one of: ${VALID_TENURE_DOMAINS.join(', ')}`);
    return { tenureDomain: 'DAYS', tenurePayload: {} };
  }

  const payload = { tenure_domain: tenureDomain };

  if (tenureDomain === 'DAYS') {
    // Reject calendar-only fields in a DAYS payload
    for (const f of CALENDAR_ONLY_FIELDS) {
      if (body[f] != null && body[f] !== '') {
        errors.push(`Field '${f}' must not be present for tenure_domain=DAYS`);
      }
    }
    // Day fields are validated in the main field validation block (existing code).
    // Just pass them through.
    payload.min_tenure_days = body.min_tenure_days;
    payload.max_tenure_days = body.max_tenure_days;
    // source_tenure_text for DAYS is set by backfill/update path; not required from API
    if (body.source_tenure_text != null) {
      payload.source_tenure_text = body.source_tenure_text;
    }

  } else {
    // CALENDAR

    // Reject DAYS fields in a CALENDAR payload
    if (body.min_tenure_days != null || body.max_tenure_days != null) {
      errors.push('Fields min_tenure_days and max_tenure_days must not be present for tenure_domain=CALENDAR');
    }
    payload.min_tenure_days = null;
    payload.max_tenure_days = null;

    // source_tenure_text required
    const srcText = body.source_tenure_text != null ? String(body.source_tenure_text).trim() : '';
    if (!srcText) {
      errors.push('source_tenure_text is required and must be non-empty for tenure_domain=CALENDAR');
    }
    payload.source_tenure_text = srcText || null;

    // Calendar components
    const toIntOrNull = v => (v == null ? null : parseInt(v, 10));
    const minYears   = toIntOrNull(body.min_years);
    const minMonths  = toIntOrNull(body.min_months);
    const minDaysCal = toIntOrNull(body.min_days_cal);
    const maxYears   = toIntOrNull(body.max_years);
    const maxMonths  = toIntOrNull(body.max_months);
    const maxDaysCal = toIntOrNull(body.max_days_cal);

    // Non-negative validation
    if (minYears   != null && (isNaN(minYears)   || minYears   < 0)) errors.push('min_years must be a non-negative integer');
    if (minMonths  != null && (isNaN(minMonths)  || minMonths  < 0 || minMonths  > 11)) errors.push('min_months must be 0–11');
    if (minDaysCal != null && (isNaN(minDaysCal) || minDaysCal < 0)) errors.push('min_days_cal must be a non-negative integer');
    if (maxYears   != null && (isNaN(maxYears)   || maxYears   < 0)) errors.push('max_years must be a non-negative integer');
    if (maxMonths  != null && (isNaN(maxMonths)  || maxMonths  < 0 || maxMonths  > 11)) errors.push('max_months must be 0–11');
    if (maxDaysCal != null && (isNaN(maxDaysCal) || maxDaysCal < 0)) errors.push('max_days_cal must be a non-negative integer');

    // Operator validation
    const minOp = body.min_operator != null ? String(body.min_operator).toUpperCase().trim() : null;
    const maxOp = body.max_operator != null ? String(body.max_operator).toUpperCase().trim() : null;

    if (minOp != null && !VALID_MIN_OPERATORS.includes(minOp)) {
      errors.push(`min_operator must be one of: ${VALID_MIN_OPERATORS.join(', ')} (got ${minOp})`);
    }
    if (maxOp != null && !VALID_MAX_OPERATORS.includes(maxOp)) {
      errors.push(`max_operator must be one of: ${VALID_MAX_OPERATORS.join(', ')} (got ${maxOp})`);
    }

    payload.min_years    = isNaN(minYears)   ? null : minYears;
    payload.min_months   = isNaN(minMonths)  ? null : minMonths;
    payload.min_days_cal = isNaN(minDaysCal) ? null : minDaysCal;
    payload.min_operator = minOp;
    payload.max_years    = isNaN(maxYears)   ? null : maxYears;
    payload.max_months   = isNaN(maxMonths)  ? null : maxMonths;
    payload.max_days_cal = isNaN(maxDaysCal) ? null : maxDaysCal;
    payload.max_operator = maxOp;
  }

  return { tenureDomain, tenurePayload: payload };
}

// ============================================================
// Helper: build application-layer overlap pre-flight query.
// Returns { conflicts, error }.
// conflicts: array of conflicting rate objects (may be empty).
// This check is for UX (returns useful 409 details) only.
// The DB function's advisory-lock-protected check is authoritative.
// ============================================================

async function findOverlappingVerifiedRates(rate, excludeId) {
  // For CALENDAR tenure domain, the symbolic overlap check cannot be expressed
  // via simple Supabase filter operators. We defer entirely to the authoritative
  // DB advisory-lock-protected check in transition_rate_status().
  // This means CALENDAR conflicts always surface via the DB (HTTP 409 from RPC
  // error translation), which is the correct and safe behaviour.
  if (rate.tenure_domain === 'CALENDAR') {
    return { data: [], error: null };
  }

  // DAYS domain: existing integer overlap logic (unchanged)
  // Base query: same conflict domain (DAYS), VERIFIED, active
  let query = supabaseAdmin
    .from('fd_rates')
    .select('id, min_tenure_days, max_tenure_days, min_deposit, max_deposit, interest_rate, tenure_domain')
    .neq('id', excludeId)
    .eq('bank_id', rate.bank_id)
    .eq('customer_type', rate.customer_type)
    .eq('is_callable', rate.is_callable)
    .eq('rate_category', rate.rate_category)
    .eq('status', 'VERIFIED')
    .is('effective_until', null)
    .eq('tenure_domain', 'DAYS')
    // Tenure overlap (closed-inclusive): conflict.min <= target.max AND target.min <= conflict.max
    .lte('min_tenure_days', rate.max_tenure_days)
    .gte('max_tenure_days', rate.min_tenure_days);

  // For SPECIAL_SCHEME: only same scheme_name conflicts (stored normalized)
  if (rate.rate_category === 'SPECIAL_SCHEME' && rate.scheme_name) {
    query = query.eq('scheme_name', rate.scheme_name); // already normalized on write
  }

  // Deposit overlap (closed-inclusive, NULL = unbounded ceiling):
  // Condition A: conflict.max_deposit IS NULL OR conflict.max_deposit >= target.min_deposit
  query = query.or(`max_deposit.is.null,max_deposit.gte.${rate.min_deposit}`);

  // Condition B: target.max_deposit IS NULL OR target.max_deposit >= conflict.min_deposit
  // If target has a ceiling, add filter: conflict.min_deposit <= target.max_deposit
  if (rate.max_deposit !== null && rate.max_deposit !== undefined) {
    query = query.lte('min_deposit', rate.max_deposit);
  }
  // If target.max_deposit IS NULL (unbounded), condition B is always true — no filter needed.

  return query.limit(10);
}


// ============================================================
// POST /api/admin/rates/draft
// Create a new DRAFT rate.
// Validated fields only. No rate is marked VERIFIED here.
// ============================================================

router.post('/rates/draft', requireAdmin, async (req, res) => {
  try {
    const {
      bank_id, customer_type,
      min_deposit, max_deposit, interest_rate,
      is_callable, compounding_frequency,
      effective_from, source_url, review_notes,
    } = req.body;

    const errors = [];

    // Core field validation (always required regardless of tenure domain)
    if (!bank_id)                                    errors.push('bank_id is required');
    if (!customer_type)                              errors.push('customer_type is required');
    if (min_deposit == null || min_deposit < 0)      errors.push('min_deposit must be >= 0');
    if (max_deposit != null && max_deposit < min_deposit)
      errors.push('max_deposit must be >= min_deposit');
    if (interest_rate == null || interest_rate < 0)  errors.push('interest_rate must be >= 0');
    if (!effective_from)                             errors.push('effective_from is required');

    // tenure_domain routing
    const { tenureDomain, tenurePayload } = validateTenureDomain(req.body, errors);

    // DAYS-specific validation (only when tenure_domain = DAYS)
    if (tenureDomain === 'DAYS') {
      const minD = req.body.min_tenure_days;
      const maxD = req.body.max_tenure_days;
      if (minD == null || minD < 0)              errors.push('min_tenure_days must be >= 0');
      if (maxD == null || maxD < minD)
        errors.push('max_tenure_days must be >= min_tenure_days');
    }

    // rate_category + scheme_name
    const { rateCategory, schemeName } = validateCategoryFields(req.body, errors);

    if (errors.length > 0) {
      return res.status(400).json({ status: 'error', message: 'Validation failed', errors });
    }

    // Build insert object — tenure fields come from tenurePayload
    const insertObj = {
      bank_id,
      customer_type:         customer_type.toUpperCase(),
      min_deposit:           parseFloat(min_deposit) || 0,
      max_deposit:           max_deposit != null ? parseFloat(max_deposit) : null,
      interest_rate:         parseFloat(interest_rate),
      is_callable:           is_callable !== false,
      compounding_frequency: compounding_frequency ?? 'QUARTERLY',
      effective_from,
      status:                'DRAFT',
      source_url:            source_url ?? null,
      created_by:            req.adminUser.id,
      review_notes:          review_notes ?? null,
      rate_category:         rateCategory,
      scheme_name:           schemeName,
      tenure_domain:         tenureDomain,
      ...tenurePayload,
    };

    // For DAYS: parse day integers
    if (tenureDomain === 'DAYS') {
      insertObj.min_tenure_days = parseInt(req.body.min_tenure_days, 10);
      insertObj.max_tenure_days = parseInt(req.body.max_tenure_days, 10);
    }

    const { data, error } = await supabaseAdmin
      .from('fd_rates')
      .insert(insertObj)
      .select()
      .single();

    if (error) throw error;

    await supabaseAdmin.from('rate_audit_log').insert({
      rate_id:      data.id,
      action:       'CREATE',
      old_value:    null,
      new_value:    { status: 'DRAFT', interest_rate, bank_id, rate_category: rateCategory, tenure_domain: tenureDomain },
      performed_by: req.adminUser.id,
      notes:        'Draft rate created',
    });

    return res.status(201).json({ status: 'ok', data });

  } catch (err) {
    console.error('[admin/rates/draft]', err?.message);
    return res.status(500).json({ status: 'error', message: err?.message ?? 'Internal error' });
  }
});


// ============================================================
// PATCH /api/admin/rates/:id/transition
// Transition a rate's status using the server-side state machine.
//
// For VERIFIED transitions:
//   1. Validates source_url domain.
//   2. Runs application-layer range-overlap pre-flight (UX quality check).
//      On overlap → HTTP 409 with conflict details and supersede hint.
//      NO automatic archiving. Explicit intent required.
//   3. If no preflight conflict → calls transition_rate_status RPC, which
//      is the authoritative concurrency-safe check (advisory lock + overlap).
//   4. Translates DB "Overlap conflict" exception → HTTP 409.
// ============================================================

router.patch('/rates/:id/transition', requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { new_status, notes } = req.body;

    const validStatuses = ['IN_REVIEW', 'VERIFIED', 'REJECTED', 'ARCHIVED', 'DRAFT'];
    if (!validStatuses.includes(new_status)) {
      return res.status(400).json({
        status: 'error',
        message: `new_status must be one of: ${validStatuses.join(', ')}`,
      });
    }

    if (new_status === 'VERIFIED') {
      // ── Fetch rate fields for preflight checks ───────────────────────
      const { data: rate, error: fetchErr } = await supabaseAdmin
        .from('fd_rates')
        .select(
          'source_url, bank_id, customer_type, min_tenure_days, max_tenure_days, ' +
          'min_deposit, max_deposit, is_callable, rate_category, scheme_name, tenure_domain'
        )
        .eq('id', id)
        .single();

      if (fetchErr || !rate) {
        return res.status(404).json({ status: 'error', message: 'Rate not found' });
      }

      // ── Source URL validation ────────────────────────────────────────
      if (!rate.source_url) {
        return res.status(400).json({
          status: 'error',
          message: 'Cannot verify a rate without a source_url. Add the official bank URL first.',
        });
      }
      if (!isOfficialDomain(rate.source_url)) {
        return res.status(400).json({
          status: 'error',
          message:
            `source_url must be from an official bank domain: ${ALLOWED_SOURCE_DOMAINS.join(', ')}. ` +
            `Got: ${rate.source_url}`,
        });
      }

      // ── Application-layer overlap pre-flight ─────────────────────────
      // For DAYS: provides actionable HTTP 409 with conflicting rate IDs.
      // For CALENDAR: deferred entirely to DB RPC (cannot express symbolically).
      // We NEVER automatically archive an overlapping rate from here.
      const { data: conflicts, error: conflictErr } =
        await findOverlappingVerifiedRates(rate, id);

      if (conflictErr) throw conflictErr;

      if (conflicts && conflicts.length > 0) {
        return res.status(409).json({
          status:    'conflict',
          message:   'Cannot verify: overlapping active VERIFIED rate(s) exist.',
          conflicts: conflicts.map(c => ({
            id:               c.id,
            min_tenure_days:  c.min_tenure_days,
            max_tenure_days:  c.max_tenure_days,
            min_deposit:      c.min_deposit,
            max_deposit:      c.max_deposit,
            interest_rate:    c.interest_rate,
          })),
          hint: 'To intentionally replace an existing rate, use POST /api/admin/rates/:id/supersede with old_rate_id.',
        });
      }

      // ── Call the authoritative DB state machine (advisory-lock protected) ──
      const { data, error } = await supabaseAdmin
        .rpc('transition_rate_status', {
          p_rate_id:      id,
          p_new_status:   new_status,
          p_performed_by: req.adminUser.id,
          p_notes:        notes ?? null,
        });

      if (error) {
        // Translate DB overlap / cross-domain exception → HTTP 409
        if (error.message && (
          error.message.includes('Overlap conflict') ||
          error.message.includes('Cross-domain conflict')
        )) {
          return res.status(409).json({
            status:  'conflict',
            message: error.message,
          });
        }
        throw error;
      }

      return res.json({ status: 'ok', superseded: false, data });
    }


    // Non-VERIFIED transition: call state machine directly
    const { data, error } = await supabaseAdmin
      .rpc('transition_rate_status', {
        p_rate_id:      id,
        p_new_status:   new_status,
        p_performed_by: req.adminUser.id,
        p_notes:        notes ?? null,
      });

    if (error) throw error;
    return res.json({ status: 'ok', data });

  } catch (err) {
    console.error('[admin/rates/transition]', err?.message);
    return res.status(500).json({ status: 'error', message: err?.message ?? 'Internal error' });
  }
});

// ============================================================
// POST /api/admin/rates/:id/supersede
// Explicit, human-initiated replacement of one VERIFIED rate
// by the rate identified by :id (which must be IN_REVIEW).
//
// Body: { old_rate_id: "<uuid>", notes?: "..." }
//
// Validation:
//   - :id (new rate) must be IN_REVIEW
//   - old_rate_id must be VERIFIED with effective_until IS NULL
//   - Both rates must belong to the same bank
//   - Both rates must share the same conflict domain fields
//     (customer_type, is_callable, rate_category)
//
// On success: calls archive_and_supersede() atomically.
// ============================================================

router.post('/rates/:id/supersede', requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { old_rate_id, notes } = req.body;

    // Basic presence check
    if (!old_rate_id) {
      return res.status(400).json({
        status:  'error',
        message: 'old_rate_id is required in the request body',
      });
    }

    const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!UUID_RE.test(id) || !UUID_RE.test(old_rate_id)) {
      return res.status(400).json({ status: 'error', message: 'Both :id and old_rate_id must be valid UUIDs' });
    }
    if (id === old_rate_id) {
      return res.status(400).json({ status: 'error', message: ':id and old_rate_id must be different rates' });
    }

    // Fetch both rates in parallel
    const [newRateResult, oldRateResult] = await Promise.all([
      supabaseAdmin.from('fd_rates')
        .select('id, status, bank_id, customer_type, is_callable, rate_category, scheme_name, source_url')
        .eq('id', id).single(),
      supabaseAdmin.from('fd_rates')
        .select('id, status, bank_id, customer_type, is_callable, rate_category, effective_until')
        .eq('id', old_rate_id).single(),
    ]);

    if (newRateResult.error || !newRateResult.data) {
      return res.status(404).json({ status: 'error', message: `New rate ${id} not found` });
    }
    if (oldRateResult.error || !oldRateResult.data) {
      return res.status(404).json({ status: 'error', message: `Old rate ${old_rate_id} not found` });
    }

    const newRate = newRateResult.data;
    const oldRate = oldRateResult.data;

    const errors = [];

    if (newRate.status !== 'IN_REVIEW') {
      errors.push(`New rate must be IN_REVIEW (currently ${newRate.status})`);
    }
    if (oldRate.status !== 'VERIFIED') {
      errors.push(`Old rate must be VERIFIED (currently ${oldRate.status})`);
    }
    if (oldRate.effective_until !== null) {
      errors.push('Old rate is already expired (effective_until is set)');
    }
    if (newRate.bank_id !== oldRate.bank_id) {
      errors.push('Both rates must belong to the same bank');
    }
    if (newRate.customer_type !== oldRate.customer_type) {
      errors.push('Both rates must have the same customer_type');
    }
    if (newRate.is_callable !== oldRate.is_callable) {
      errors.push('Both rates must have the same is_callable value');
    }
    if (newRate.rate_category !== oldRate.rate_category) {
      errors.push('Both rates must have the same rate_category');
    }
    if (!newRate.source_url) {
      errors.push('New rate must have a source_url before superseding');
    } else if (!isOfficialDomain(newRate.source_url)) {
      errors.push(`source_url must be from an official bank domain: ${ALLOWED_SOURCE_DOMAINS.join(', ')}`);
    }

    if (errors.length > 0) {
      return res.status(400).json({ status: 'error', message: 'Validation failed', errors });
    }

    // Call archive_and_supersede atomically (advisory-lock protected in DB)
    const { data, error } = await supabaseAdmin
      .rpc('archive_and_supersede', {
        p_old_rate_id:  old_rate_id,
        p_new_rate_id:  id,
        p_performed_by: req.adminUser.id,
        p_effective_at: new Date().toISOString(),
        p_notes:        notes ?? null,
      });

    if (error) {
      if (error.message && error.message.includes('Overlap conflict')) {
        return res.status(409).json({
          status:  'conflict',
          message: error.message,
        });
      }
      throw error;
    }

    return res.json({ status: 'ok', superseded: true, data });

  } catch (err) {
    console.error('[admin/rates/supersede]', err?.message);
    return res.status(500).json({ status: 'error', message: err?.message ?? 'Internal error' });
  }
});

// ============================================================
// PATCH /api/admin/rates/:id
// Edit a DRAFT or REJECTED rate's field values.
// Cannot edit VERIFIED or ARCHIVED rates.
// ============================================================

router.patch('/rates/:id', requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;

    const { data: existing } = await supabaseAdmin
      .from('fd_rates')
      .select('status')
      .eq('id', id)
      .single();

    if (!existing) {
      return res.status(404).json({ status: 'error', message: 'Rate not found' });
    }
    if (!['DRAFT', 'REJECTED'].includes(existing.status)) {
      return res.status(400).json({
        status:  'error',
        message: `Cannot edit a rate in status ${existing.status}. Only DRAFT or REJECTED rates can be edited.`,
      });
    }

    const allowedFields = [
      'customer_type', 'min_tenure_days', 'max_tenure_days',
      'min_deposit', 'max_deposit', 'interest_rate',
      'is_callable', 'compounding_frequency',
      'effective_from', 'source_url', 'review_notes',
      // Migration 009: calendar tenure fields
      'source_tenure_text',
      'min_years', 'min_months', 'min_days_cal', 'min_operator',
      'max_years', 'max_months', 'max_days_cal', 'max_operator',
    ];

    const patch = {};
    for (const field of allowedFields) {
      if (req.body[field] !== undefined) {
        patch[field] = req.body[field];
      }
    }

    // Handle tenure_domain if it or any tenure field is being updated
    if (req.body.tenure_domain !== undefined ||
        CALENDAR_ONLY_FIELDS.some(f => req.body[f] !== undefined) ||
        DAYS_ONLY_FIELDS.some(f => req.body[f] !== undefined)) {
      // Fetch existing tenure_domain to validate against
      const { data: current } = await supabaseAdmin
        .from('fd_rates').select('tenure_domain').eq('id', id).single();
      const effectiveDomain = (req.body.tenure_domain ?? current?.tenure_domain ?? 'DAYS')
        .toString().toUpperCase().trim();

      const tenureErrors = [];
      const { tenureDomain, tenurePayload } = validateTenureDomain(
        { ...req.body, tenure_domain: effectiveDomain },
        tenureErrors,
      );
      if (tenureErrors.length > 0) {
        return res.status(400).json({ status: 'error', message: 'Validation failed', errors: tenureErrors });
      }
      // Merge tenure payload into patch (only actually-changed fields)
      Object.assign(patch, { tenure_domain: tenureDomain, ...tenurePayload });
    }

    // Handle rate_category + scheme_name if either is being updated
    if (req.body.rate_category !== undefined || req.body.scheme_name !== undefined) {
      let effectiveCategory = req.body.rate_category ?? null;
      if (effectiveCategory === null) {
        const { data: current } = await supabaseAdmin
          .from('fd_rates').select('rate_category').eq('id', id).single();
        effectiveCategory = current?.rate_category ?? 'STANDARD';
      }

      const tempBody = {
        rate_category: effectiveCategory,
        scheme_name:   req.body.scheme_name,
      };
      const errors = [];
      const { rateCategory, schemeName } = validateCategoryFields(tempBody, errors);
      if (errors.length > 0) {
        return res.status(400).json({ status: 'error', message: 'Validation failed', errors });
      }
      patch.rate_category = rateCategory;
      patch.scheme_name   = schemeName;
    }


    if (Object.keys(patch).length === 0) {
      return res.status(400).json({ status: 'error', message: 'No valid fields to update' });
    }

    const { data, error } = await supabaseAdmin
      .from('fd_rates')
      .update(patch)
      .eq('id', id)
      // FIX 1 (Migration 008 hardening): make the UPDATE itself the race guard.
      // If the rate's status changed concurrently (e.g. DRAFT → IN_REVIEW between
      // the pre-check above and this UPDATE), no row will match and maybeSingle()
      // returns null — we then return HTTP 409 rather than silently mutating an
      // IN_REVIEW rate's conflict-domain fields.
      .in('status', ['DRAFT', 'REJECTED'])
      .select()
      .maybeSingle();

    if (error) throw error;

    if (!data) {
      // No matching row: either the rate was not found or its status changed
      // concurrently between the pre-check and this UPDATE.
      return res.status(409).json({
        status:  'conflict',
        message: 'Rate status changed concurrently — cannot edit. The rate may have been submitted for review. Refresh and try again.',
      });
    }

    await supabaseAdmin.from('rate_audit_log').insert({
      rate_id:      id,
      action:       'EDIT',
      old_value:    { status: existing.status },
      new_value:    patch,
      performed_by: req.adminUser.id,
      notes:        'Draft fields updated',
    });

    return res.json({ status: 'ok', data });

  } catch (err) {
    console.error('[admin/rates patch]', err?.message);
    return res.status(500).json({ status: 'error', message: err?.message ?? 'Internal error' });
  }
});

// ============================================================
// GET /api/admin/rates
// List rates by status (for admin dashboard panels).
// ============================================================

router.get('/rates', requireAdmin, async (req, res) => {
  try {
    const { status } = req.query;
    const validStatuses = ['DRAFT', 'IN_REVIEW', 'VERIFIED', 'REJECTED', 'ARCHIVED'];

    let query = supabaseAdmin
      .from('fd_rates')
      .select(`
        *,
        banks ( name, short_name, official_website )
      `)
      .order('created_at', { ascending: false });

    if (status) {
      const statusUpper = status.toUpperCase();
      if (!validStatuses.includes(statusUpper)) {
        return res.status(400).json({
          status:  'error',
          message: `status must be one of: ${validStatuses.join(', ')}`,
        });
      }
      query = query.eq('status', statusUpper);
    }

    const { data, error } = await query;
    if (error) throw error;

    return res.json({ status: 'ok', data: data ?? [], count: (data ?? []).length });

  } catch (err) {
    console.error('[admin/rates list]', err?.message);
    return res.status(500).json({ status: 'error', message: err?.message ?? 'Internal error' });
  }
});

// ============================================================
// GET /api/admin/rates/:id/audit
// Fetch full audit history for a specific rate.
// ============================================================

router.get('/rates/:id/audit', requireAdmin, async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('rate_audit_log')
      .select('*')
      .eq('rate_id', req.params.id)
      .order('performed_at', { ascending: false });

    if (error) throw error;
    return res.json({ status: 'ok', data: data ?? [] });

  } catch (err) {
    return res.status(500).json({ status: 'error', message: err?.message ?? 'Internal error' });
  }
});

module.exports = router;
