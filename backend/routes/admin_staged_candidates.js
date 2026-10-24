// FeroCalc Verified FD Rate Engine — Admin Staged Candidates & Promotion Router
//
// Endpoints:
// - GET  /api/admin/staged-candidates           (List & filter staged candidates with diff vs verified)
// - POST /api/admin/staged-candidates/:id/promote (Admin manual candidate promotion to VERIFIED)
// - POST /api/admin/staged-candidates/:id/reject  (Admin manual rejection)
// - POST /api/admin/rates/:id/rollback          (Admin safe historical rate rollback)
//
// Security:
// - Protected by requireAdmin middleware (Bearer JWT + ADMIN/REVIEWER role check).
// - NEVER exposes service-role keys or credentials.

'use strict';

const express = require('express');
const router = express.Router();
const {
  supabaseAdmin,
  verifySupabaseUser,
  isFeroCalcAdmin,
  isSupabaseAvailable,
} = require('../supabase/supabase_client');
const { RateDiffEngine } = require('../promotion/rate_diff_engine');
const { PromotionService } = require('../promotion/promotion_service');

const diffEngine = new RateDiffEngine();
const promotionService = new PromotionService({ diffEngine });

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
// GET /api/admin/staged-candidates
// ============================================================

router.get('/staged-candidates', requireAdmin, async (req, res) => {
  try {
    const {
      status,
      bankId,
      bankCode,
      sourceId,
      parserId,
      startDate,
      endDate,
      hasAnomalies,
      limit = 50,
      offset = 0,
    } = req.query;

    let query = supabaseAdmin
      .from('staged_rate_candidates')
      .select('*', { count: 'exact' });

    if (status) {
      query = query.eq('staging_status', status.toUpperCase());
    }
    if (bankCode || bankId) {
      query = query.eq('bank_code', (bankCode || bankId).toUpperCase());
    }
    if (sourceId) {
      query = query.eq('source_id', sourceId);
    }
    if (parserId) {
      query = query.eq('parser_id', parserId);
    }
    if (startDate) {
      query = query.gte('extracted_at', startDate);
    }
    if (endDate) {
      query = query.lte('extracted_at', endDate);
    }

    query = query
      .order('extracted_at', { ascending: false })
      .range(Number(offset), Number(offset) + Number(limit) - 1);

    const { data: candidates, error, count } = await query;

    if (error) {
      return res.status(500).json({ status: 'error', message: error.message });
    }

    // Filter by anomaly presence in memory if requested
    let filteredCandidates = candidates || [];
    if (hasAnomalies !== undefined) {
      const wantAnomalies = hasAnomalies === 'true' || hasAnomalies === true;
      filteredCandidates = filteredCandidates.filter(c => {
        const flags = Array.isArray(c.anomaly_flags) ? c.anomaly_flags : [];
        return wantAnomalies ? flags.length > 0 : flags.length === 0;
      });
    }

    // Fetch active verified rates to enrich candidates with diffs
    const uniqueBanks = [...new Set(filteredCandidates.map(c => c.bank_code))];
    const { data: activeRates } = await supabaseAdmin
      .from('fd_rates')
      .select('id, bank_id, customer_type, min_tenure_days, max_tenure_days, tenure_domain, min_years, min_months, min_days_cal, min_operator, max_years, max_months, max_days_cal, max_operator, source_tenure_text, min_deposit, max_deposit, interest_rate, is_callable, rate_category, scheme_name, banks!inner(code)')
      .eq('status', 'VERIFIED')
      .in('banks.code', uniqueBanks);

    const verifiedByBank = new Map();
    (activeRates || []).forEach(r => {
      const bCode = r.banks ? r.banks.code : r.bank_id;
      if (!verifiedByBank.has(bCode)) verifiedByBank.set(bCode, []);
      verifiedByBank.get(bCode).push(r);
    });

    const enriched = filteredCandidates.map(c => {
      const bankActive = verifiedByBank.get(c.bank_code) || [];
      const diff = diffEngine.diffCandidate(c, bankActive);

      return {
        id: c.id,
        bankCode: c.bank_code,
        sourceId: c.source_id,
        productType: c.product_type,
        customerType: c.customer_type,
        tenureDomain: c.tenure_domain || 'DAYS',
        tenureLabel: c.tenure_label,
        sourceTenureText: c.source_tenure_text ?? c.tenure_label,
        displayTenure: (c.tenure_domain === 'CALENDAR')
          ? (c.source_tenure_text ?? c.tenure_label)
          : (c.tenure_label || (c.min_tenure_days && c.max_tenure_days ? `${c.min_tenure_days} - ${c.max_tenure_days} days` : c.tenure_label)),
        minTenureDays: c.min_tenure_days,
        maxTenureDays: c.max_tenure_days,
        minYears: c.min_years ?? null,
        minMonths: c.min_months ?? null,
        minDaysCal: c.min_days_cal ?? null,
        minOperator: c.min_operator ?? null,
        maxYears: c.max_years ?? null,
        maxMonths: c.max_months ?? null,
        maxDaysCal: c.max_days_cal ?? null,
        maxOperator: c.max_operator ?? null,
        tenureUnit: (c.tenure_domain === 'CALENDAR') ? 'CALENDAR' : (c.tenure_unit || 'DAYS'),
        legacyTenureUnit: c.tenure_unit,
        interestRate: c.interest_rate,
        seniorCitizenRate: c.senior_citizen_rate,
        superSeniorRate: c.super_senior_rate,
        minDeposit: c.min_deposit,
        maxDeposit: c.max_deposit,
        isCallable: c.is_callable,
        compoundingFrequency: c.compounding_frequency,
        effectiveFrom: c.effective_from,
        effectiveUntil: c.effective_until,
        sourceUrl: c.source_url,
        sourceDocumentUrl: c.source_document_url,
        sourceContentHash: c.source_content_hash,
        parserId: c.parser_id,
        parserVersion: c.parser_version,
        extractedAt: c.extracted_at,
        validationStatus: c.validation_status,
        validationErrors: c.validation_errors,
        anomalyFlags: c.anomaly_flags,
        stagingStatus: c.staging_status,
        diff: {
          diffType: diff.diffType,
          previousVerifiedRate: diff.previousRate,
          rateDelta: diff.rateDelta,
          details: diff.details,
        },
      };
    });

    return res.json({
      status: 'ok',
      total: count || enriched.length,
      limit: Number(limit),
      offset: Number(offset),
      candidates: enriched,
    });

  } catch (err) {
    console.error('[admin/staged-candidates]', err.message);
    return res.status(500).json({ status: 'error', message: err.message });
  }
});

// ============================================================
// POST /api/admin/staged-candidates/:id/promote
// Admin manual promotion of an IN_REVIEW or DRAFT candidate to VERIFIED.
// ============================================================

router.post('/staged-candidates/:id/promote', requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { notes } = req.body;

    const { data: candidate, error } = await supabaseAdmin
      .from('staged_rate_candidates')
      .select('*')
      .eq('id', id)
      .single();

    if (error || !candidate) {
      return res.status(404).json({ status: 'error', message: 'Candidate not found' });
    }

    if (candidate.validation_status === 'INVALID') {
      return res.status(400).json({
        status: 'error',
        message: 'Cannot promote INVALID candidate',
        errors: candidate.validation_errors,
      });
    }

    const result = await promotionService.promoteCandidate({
      candidate,
      actorType: 'ADMIN',
      actorId: req.adminUser.id,
      reason: notes || 'Admin manual verification and promotion',
      overridePolicy: true,
    });

    // Update staged record
    await supabaseAdmin
      .from('staged_rate_candidates')
      .update({
        staging_status: 'PROMOTED',
        promoted_rate_id: result.newVerifiedRate.id,
        promoted_at: new Date().toISOString(),
        promoted_by: req.adminUser.id,
        promotion_reason: notes || 'Admin manual verification and promotion',
      })
      .eq('id', id);

    return res.json({
      status: 'ok',
      promotedRate: result.newVerifiedRate,
      supersededRate: result.supersededRecord,
      reason: result.reason,
    });

  } catch (err) {
    console.error('[admin/staged-candidates/promote]', err.message);
    return res.status(500).json({ status: 'error', message: err.message });
  }
});

// ============================================================
// POST /api/admin/staged-candidates/:id/reject
// ============================================================

router.post('/staged-candidates/:id/reject', requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;

    const { data: candidate, error } = await supabaseAdmin
      .from('staged_rate_candidates')
      .select('*')
      .eq('id', id)
      .single();

    if (error || !candidate) {
      return res.status(404).json({ status: 'error', message: 'Candidate not found' });
    }

    await promotionService.rejectCandidate(candidate, req.adminUser.id, reason || 'Admin rejection');

    await supabaseAdmin
      .from('staged_rate_candidates')
      .update({
        staging_status: 'REJECTED',
        notes: reason || 'Admin rejection',
      })
      .eq('id', id);

    return res.json({ status: 'ok', message: 'Candidate rejected', id });

  } catch (err) {
    console.error('[admin/staged-candidates/reject]', err.message);
    return res.status(500).json({ status: 'error', message: err.message });
  }
});

// ============================================================
// POST /api/admin/rates/:id/rollback
// Non-destructive rollback restoring previous verified rate.
// ============================================================

router.post('/rates/:id/rollback', requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { notes } = req.body;

    const result = await promotionService.rollbackRate({
      rateId: id,
      adminUserId: req.adminUser.id,
      notes: notes || 'Administrative rollback',
    });

    return res.json({
      status: 'ok',
      message: 'Rate rolled back successfully',
      restoredRate: result.restoredRate,
      rolledBackRate: result.rolledBackRate,
    });

  } catch (err) {
    console.error('[admin/rates/rollback]', err.message);
    return res.status(500).json({ status: 'error', message: err.message });
  }
});

module.exports = router;
