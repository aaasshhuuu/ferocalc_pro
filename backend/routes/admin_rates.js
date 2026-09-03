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
// POST /api/admin/rates/draft
// Create a new DRAFT rate.
// Validated fields only. No rate is marked VERIFIED here.
// ============================================================

router.post('/rates/draft', requireAdmin, async (req, res) => {
  try {
    const {
      bank_id, customer_type, min_tenure_days, max_tenure_days,
      min_deposit, max_deposit, interest_rate,
      is_callable, compounding_frequency,
      effective_from, source_url, review_notes,
    } = req.body;

    // Server-side field validation
    const errors = [];
    if (!bank_id) errors.push('bank_id is required');
    if (!customer_type) errors.push('customer_type is required');
    if (min_tenure_days == null || min_tenure_days < 0) errors.push('min_tenure_days must be >= 0');
    if (max_tenure_days == null || max_tenure_days < min_tenure_days) errors.push('max_tenure_days must be >= min_tenure_days');
    if (min_deposit == null || min_deposit < 0) errors.push('min_deposit must be >= 0');
    if (max_deposit != null && max_deposit < min_deposit) errors.push('max_deposit must be >= min_deposit');
    if (interest_rate == null || interest_rate < 0) errors.push('interest_rate must be >= 0');
    if (!effective_from) errors.push('effective_from is required');

    if (errors.length > 0) {
      return res.status(400).json({ status: 'error', message: 'Validation failed', errors });
    }

    const { data, error } = await supabaseAdmin
      .from('fd_rates')
      .insert({
        bank_id,
        customer_type: customer_type.toUpperCase(),
        min_tenure_days: parseInt(min_tenure_days),
        max_tenure_days: parseInt(max_tenure_days),
        min_deposit: parseFloat(min_deposit) || 0,
        max_deposit: max_deposit != null ? parseFloat(max_deposit) : null,
        interest_rate: parseFloat(interest_rate),
        is_callable: is_callable !== false,
        compounding_frequency: compounding_frequency ?? 'QUARTERLY',
        effective_from,
        status: 'DRAFT',
        source_url: source_url ?? null,
        created_by: req.adminUser.id,
        review_notes: review_notes ?? null,
      })
      .select()
      .single();

    if (error) throw error;

    // Write audit log
    await supabaseAdmin.from('rate_audit_log').insert({
      rate_id: data.id,
      action: 'CREATE',
      old_value: null,
      new_value: { status: 'DRAFT', interest_rate, bank_id },
      performed_by: req.adminUser.id,
      notes: 'Draft rate created',
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

    // Before VERIFY: validate source is official domain, then check for
    // an existing active VERIFIED rate in the same logical bucket.
    if (new_status === 'VERIFIED') {
      const { data: rate, error: fetchErr } = await supabaseAdmin
        .from('fd_rates')
        .select('source_url, bank_id, customer_type, min_tenure_days, max_tenure_days, min_deposit, max_deposit, is_callable')
        .eq('id', id)
        .single();

      if (fetchErr || !rate) {
        return res.status(404).json({ status: 'error', message: 'Rate not found' });
      }

      if (!rate.source_url) {
        return res.status(400).json({
          status: 'error',
          message: 'Cannot verify a rate without a source_url. Add the official bank URL first.',
        });
      }
      if (!isOfficialDomain(rate.source_url)) {
        return res.status(400).json({
          status: 'error',
          message: `source_url must be from an official bank domain: ${ALLOWED_SOURCE_DOMAINS.join(', ')}. ` +
                   `Got: ${rate.source_url}`,
        });
      }

      // ================================================================
      // Look for an existing ACTIVE VERIFIED rate for the same bucket.
      // "Active" = status VERIFIED AND effective_until IS NULL.
      // If found, we must atomically archive it and verify the new one
      // using archive_and_supersede — the same transaction that creates
      // the new VERIFIED record also sets effective_until on the old one.
      // This mirrors the DB uniqueness constraint and preserves history.
      // ================================================================
      let existingQuery = supabaseAdmin
        .from('fd_rates')
        .select('id')
        .neq('id', id)               // exclude the rate we are about to verify
        .eq('bank_id', rate.bank_id)
        .eq('customer_type', rate.customer_type)
        .eq('min_tenure_days', rate.min_tenure_days)
        .eq('max_tenure_days', rate.max_tenure_days)
        .eq('min_deposit', rate.min_deposit)
        .eq('is_callable', rate.is_callable)
        .eq('status', 'VERIFIED')
        .is('effective_until', null)
        .limit(1);

      // max_deposit: NULL means open ceiling and must match NULL-to-NULL
      if (rate.max_deposit !== null && rate.max_deposit !== undefined) {
        existingQuery = existingQuery.eq('max_deposit', rate.max_deposit);
      } else {
        existingQuery = existingQuery.is('max_deposit', null);
      }

      const { data: existing, error: existErr } = await existingQuery;
      if (existErr) throw existErr;

      if (existing && existing.length > 0) {
        // Supersede: archive old → verify new, atomically in PostgreSQL
        const { data, error } = await supabaseAdmin
          .rpc('archive_and_supersede', {
            p_old_rate_id:  existing[0].id,
            p_new_rate_id:  id,
            p_performed_by: req.adminUser.id,
            p_effective_at: new Date().toISOString(),
            p_notes:        notes ?? null,
          });

        if (error) throw error;
        return res.json({ status: 'ok', superseded: true, data });
      }

      // No existing active VERIFIED rate — simple transition
      const { data, error } = await supabaseAdmin
        .rpc('transition_rate_status', {
          p_rate_id:      id,
          p_new_status:   new_status,
          p_performed_by: req.adminUser.id,
          p_notes:        notes ?? null,
        });

      if (error) throw error;
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
// PATCH /api/admin/rates/:id
// Edit a DRAFT or REJECTED rate's field values.
// Cannot edit VERIFIED or ARCHIVED rates.
// ============================================================

router.patch('/rates/:id', requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;

    // Only allow editing mutable states
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
        status: 'error',
        message: `Cannot edit a rate in status ${existing.status}. Only DRAFT or REJECTED rates can be edited.`,
      });
    }

    const allowedFields = [
      'customer_type', 'min_tenure_days', 'max_tenure_days',
      'min_deposit', 'max_deposit', 'interest_rate',
      'is_callable', 'compounding_frequency',
      'effective_from', 'source_url', 'review_notes',
    ];

    const patch = {};
    for (const field of allowedFields) {
      if (req.body[field] !== undefined) {
        patch[field] = req.body[field];
      }
    }

    if (Object.keys(patch).length === 0) {
      return res.status(400).json({ status: 'error', message: 'No valid fields to update' });
    }

    const { data, error } = await supabaseAdmin
      .from('fd_rates')
      .update(patch)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    // Write audit log
    await supabaseAdmin.from('rate_audit_log').insert({
      rate_id: id,
      action: 'EDIT',
      old_value: { status: existing.status },
      new_value: patch,
      performed_by: req.adminUser.id,
      notes: 'Draft fields updated',
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
          status: 'error',
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
