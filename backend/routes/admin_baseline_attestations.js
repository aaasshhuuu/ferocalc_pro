// FeroCalc Verified FD Rate Engine — Admin Baseline Attestations Router
//
// Endpoints:
// - GET  /api/admin/baseline-attestations           (List all baseline attestations)
// - GET  /api/admin/baseline-attestations/:id       (Get single attestation details & candidate batch)
// - POST /api/admin/baseline-attestations/:id/attest (Admin attests source baseline)
// - POST /api/admin/baseline-attestations/:id/reject (Admin rejects baseline)
// - POST /api/admin/baseline-attestations/:id/promote (Admin triggers safe baseline promotion)
//
// Security:
// - Protected by requireAdmin middleware (Bearer JWT + ADMIN/REVIEWER role check).
// - NEVER exposes service-role keys or admin credentials.

'use strict';

const express = require('express');
const router = express.Router();
const {
  supabaseAdmin,
  verifySupabaseUser,
  isFeroCalcAdmin,
  isSupabaseAvailable,
} = require('../supabase/supabase_client');
const { BaselineAttestationService } = require('../attestation/baseline_attestation_service');

const attestationService = new BaselineAttestationService();

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
// GET /api/admin/baseline-attestations
// ============================================================
router.get('/baseline-attestations', requireAdmin, async (req, res) => {
  try {
    const filters = {};
    if (req.query.bank) filters.bankCode = req.query.bank.toUpperCase();
    if (req.query.status) filters.status = req.query.status.toUpperCase();

    const attestations = await attestationService.listAttestations(filters);
    res.json({
      status: 'ok',
      count: attestations.length,
      data: attestations,
    });
  } catch (err) {
    res.status(500).json({ status: 'error', message: err.message });
  }
});

// ============================================================
// GET /api/admin/baseline-attestations/:id
// ============================================================
router.get('/baseline-attestations/:id', requireAdmin, async (req, res) => {
  try {
    const attestation = await attestationService.getAttestationById(req.params.id);
    if (!attestation) {
      return res.status(404).json({ status: 'error', message: 'Baseline attestation not found' });
    }

    const candidates = await attestationService.getCandidatesForBatch(
      attestation.batchId,
      attestation.bankCode,
      attestation.sourceContentHash
    );

    res.json({
      status: 'ok',
      data: {
        ...attestation,
        candidates,
      },
    });
  } catch (err) {
    res.status(500).json({ status: 'error', message: err.message });
  }
});

// ============================================================
// POST /api/admin/baseline-attestations/:id/attest
// ============================================================
router.post('/baseline-attestations/:id/attest', requireAdmin, async (req, res) => {
  try {
    const notes = req.body.notes || '';
    const adminUserId = req.adminUser.id;

    const updated = await attestationService.attestBaseline({
      attestationId: req.params.id,
      adminUserId,
      notes,
    });

    res.json({
      status: 'ok',
      message: `Baseline attestation ${updated.batchId} marked ATTESTED`,
      data: updated,
    });
  } catch (err) {
    res.status(400).json({ status: 'error', message: err.message });
  }
});

// ============================================================
// POST /api/admin/baseline-attestations/:id/reject
// ============================================================
router.post('/baseline-attestations/:id/reject', requireAdmin, async (req, res) => {
  try {
    const rejectionReason = req.body.reason;
    if (!rejectionReason) {
      return res.status(400).json({ status: 'error', message: 'Rejection reason is required' });
    }

    const adminUserId = req.adminUser.id;
    const notes = req.body.notes || '';

    const updated = await attestationService.rejectBaseline({
      attestationId: req.params.id,
      adminUserId,
      rejectionReason,
      notes,
    });

    res.json({
      status: 'ok',
      message: `Baseline attestation ${updated.batchId} marked REJECTED`,
      data: updated,
    });
  } catch (err) {
    res.status(400).json({ status: 'error', message: err.message });
  }
});

function parseIsCallableBodyOrQuery(req) {
  const raw = req.body?.isCallable !== undefined
    ? req.body.isCallable
    : (req.query?.isCallable !== undefined ? req.query.isCallable : req.query?.is_callable);

  if (raw === undefined || raw === null || raw === '') {
    return { filterValue: 'all', hasError: false };
  }
  if (raw === true || raw === 1) {
    return { filterValue: true, hasError: false };
  }
  if (raw === false || raw === 0) {
    return { filterValue: false, hasError: false };
  }
  if (typeof raw === 'string') {
    const s = raw.trim().toLowerCase();
    if (s === 'true' || s === '1') return { filterValue: true, hasError: false };
    if (s === 'false' || s === '0') return { filterValue: false, hasError: false };
    if (s === 'all') return { filterValue: 'all', hasError: false };
  }
  return {
    filterValue: null,
    hasError: true,
    errorMessage: `Invalid isCallable parameter: "${raw}". Must be one of: true, false, all.`,
  };
}

// ============================================================
// POST /api/admin/baseline-attestations/:id/promote
// ============================================================
router.post('/baseline-attestations/:id/promote', requireAdmin, async (req, res) => {
  try {
    const dryRun = req.body.dryRun === true || req.query.dryRun === 'true';
    const adminUserId = req.adminUser.id;

    const callableCheck = parseIsCallableBodyOrQuery(req);
    if (callableCheck.hasError) {
      return res.status(400).json({ status: 'error', message: callableCheck.errorMessage });
    }

    const result = await attestationService.promoteBaseline({
      attestationId: req.params.id,
      adminUserId,
      dryRun,
      isCallable: callableCheck.filterValue,
    });

    res.json({
      status: 'ok',
      message: dryRun
        ? `Dry run baseline promotion completed for ${result.batchId}`
        : `Baseline promotion completed for ${result.batchId}`,
      data: result,
    });
  } catch (err) {
    res.status(400).json({ status: 'error', message: err.message });
  }
});

module.exports = {
  adminAttestationRouter: router,
  attestationService,
  requireAdmin,
  parseIsCallableBodyOrQuery,
};
