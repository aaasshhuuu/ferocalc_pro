// FeroCalc Verified FD Rate Engine — Notifications & Personalization Router (Phase 5.0.6)
//
// Endpoints:
// - POST /api/notifications/device-token       (Public: anonymous device registration & preference sync)
// - GET  /api/notifications/events             (Public: verified rate change ledger for in-app inbox sync)
// - POST /api/notifications/admin/test-dispatch (Admin: strictly guarded test event dispatch)

'use strict';

const express = require('express');
const router = express.Router();
const {
  supabaseAdmin,
  verifySupabaseUser,
  isFeroCalcAdmin,
  isSupabaseAvailable,
} = require('../supabase/supabase_client');
const { verifiedRateNotificationService } = require('../notifications/verified_rate_notification_service');

// Auth middleware for privileged notification operations
async function requireAdmin(req, res, next) {
  const authHeader = req.headers['authorization'] ?? '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

  if (!token) {
    return res.status(401).json({ status: 'error', message: 'Missing authorization token' });
  }

  if (!isSupabaseAvailable() || !supabaseAdmin) {
    return res.status(503).json({ status: 'error', message: 'Admin service unavailable' });
  }

  try {
    const user = await verifySupabaseUser(token);
    if (!isFeroCalcAdmin(user)) {
      return res.status(403).json({ status: 'error', message: 'Insufficient permissions' });
    }
    req.adminUser = user;
    next();
  } catch (err) {
    return res.status(401).json({ status: 'error', message: 'Invalid or expired token: ' + err.message });
  }
}

// ============================================================
// Public Consumer Endpoints
// ============================================================

// POST /api/notifications/device-token
// Registers device installation token & consumer notification preferences anonymously.
// Supports an optional installationToken for tamper-proof ownership verification during deletion.
// Hardened with strict payload size, type, and field validation.
router.post('/device-token', (req, res) => {
  try {
    const { installationId, token, preferences, favoriteBankIds, installationToken: bodyToken } = req.body || {};
    const installationToken = req.headers['x-installation-token'] || bodyToken;

    // 1. Validate installationId
    if (!installationId || typeof installationId !== 'string' || installationId.trim().length === 0) {
      return res.status(400).json({
        status: 'error',
        message: 'Valid installationId string is required',
      });
    }

    const trimmedInstallationId = installationId.trim();
    if (trimmedInstallationId.length > 128) {
      return res.status(400).json({
        status: 'error',
        message: 'installationId must not exceed 128 characters',
      });
    }

    // 2. Validate installationToken if present
    if (installationToken !== undefined && installationToken !== null) {
      if (typeof installationToken !== 'string' || installationToken.trim().length > 256) {
        return res.status(400).json({
          status: 'error',
          message: 'installationToken must be a string up to 256 characters',
        });
      }
    }

    // 3. Validate token if present
    if (token !== undefined && token !== null) {
      if (typeof token !== 'string' || token.trim().length > 512) {
        return res.status(400).json({
          status: 'error',
          message: 'device token must be a string up to 512 characters',
        });
      }
    }

    // 4. Validate favoriteBankIds if present
    if (favoriteBankIds !== undefined && favoriteBankIds !== null) {
      if (!Array.isArray(favoriteBankIds)) {
        return res.status(400).json({
          status: 'error',
          message: 'favoriteBankIds must be an array of bank identifier strings',
        });
      }
      if (favoriteBankIds.length > 50) {
        return res.status(400).json({
          status: 'error',
          message: 'favoriteBankIds array exceeds maximum length of 50',
        });
      }
      for (const bankId of favoriteBankIds) {
        if (typeof bankId !== 'string' || bankId.length > 64) {
          return res.status(400).json({
            status: 'error',
            message: 'Each item in favoriteBankIds must be a string up to 64 characters',
          });
        }
      }
    }

    // 5. Validate preferences if present
    const sanitizedPrefs = {};
    if (preferences !== undefined && preferences !== null) {
      if (typeof preferences !== 'object' || Array.isArray(preferences)) {
        return res.status(400).json({
          status: 'error',
          message: 'preferences must be a JSON object',
        });
      }
      const allowedPreferenceKeys = [
        'masterEnabled',
        'favoriteBankRateChanges',
        'newlyPromotedSlabs',
        'significantRateChanges',
        'productAnnouncements',
      ];
      for (const [key, val] of Object.entries(preferences)) {
        if (!allowedPreferenceKeys.includes(key)) {
          return res.status(400).json({
            status: 'error',
            message: `Unrecognized preference key: ${key}`,
          });
        }
        if (typeof val !== 'boolean') {
          return res.status(400).json({
            status: 'error',
            message: `Preference value for ${key} must be a boolean`,
          });
        }
        sanitizedPrefs[key] = val;
      }
    }

    const regResult = verifiedRateNotificationService.registerDevice(trimmedInstallationId, {
      token: token ? token.trim() : null,
      preferences: sanitizedPrefs,
      favoriteBankIds: favoriteBankIds || [],
      installationToken: (typeof installationToken === 'string' && installationToken.trim().length > 0)
        ? installationToken.trim()
        : null,
    });

    return res.json({
      status: 'ok',
      data: regResult,
    });
  } catch (err) {
    if (err.message && (err.message.includes('Invalid installationToken') || err.message.includes('requires matching installationToken'))) {
      return res.status(403).json({ status: 'error', message: err.message });
    }
    return res.status(500).json({ status: 'error', message: err.message });
  }
});

// DELETE /api/notifications/device-token
// POST   /api/notifications/delete-device-data
// Deletes and revokes remote device registration data, including device token,
// alert preferences, and favorite bank associations.
// Strictly requires authentication via installationToken when the record was registered with tokenAuth.
function handleDeviceDeletion(req, res) {
  try {
    const installationId = req.body?.installationId || req.query?.installationId;
    const installationToken = req.headers['x-installation-token'] || req.body?.installationToken || req.query?.installationToken;

    if (!installationId || typeof installationId !== 'string' || installationId.trim().length === 0) {
      return res.status(400).json({
        status: 'error',
        message: 'Valid installationId string is required',
      });
    }

    const trimmedInstallationId = installationId.trim();
    if (trimmedInstallationId.length > 128) {
      return res.status(400).json({
        status: 'error',
        message: 'installationId must not exceed 128 characters',
      });
    }

    const trimmedToken = (typeof installationToken === 'string' && installationToken.trim().length > 0)
      ? installationToken.trim()
      : null;

    const delResult = verifiedRateNotificationService.deleteDevice(trimmedInstallationId, trimmedToken);

    if (delResult.unauthorized) {
      return res.status(403).json({
        status: 'error',
        message: delResult.message || 'Unauthorized: invalid or missing installation authorization token',
      });
    }

    return res.json({
      status: 'ok',
      data: delResult,
    });
  } catch (err) {
    return res.status(500).json({ status: 'error', message: err.message });
  }
}

router.delete('/device-token', handleDeviceDeletion);
router.post('/delete-device-data', handleDeviceDeletion);

// GET /api/notifications/events
// Returns recent genuine verified rate notifications for in-app inbox sync.
router.get('/events', async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 20, 50);
    const events = await verifiedRateNotificationService.getRecentEvents(limit);

    // Sanitize to guarantee no internal DB keys or reviewer notes leak
    const sanitized = events.map(e => ({
      id: e.id,
      eventId: e.eventId,
      bankId: e.bankId,
      bankName: e.bankName,
      type: e.type,
      title: e.title,
      message: e.message,
      effectiveDate: e.effectiveDate,
      verifiedTimestamp: e.verifiedTimestamp,
      actionRoute: e.actionRoute,
    }));

    return res.json({
      status: 'ok',
      data: sanitized,
      meta: {
        count: sanitized.length,
        pushConfigured: verifiedRateNotificationService.isPushConfigured,
      },
    });
  } catch (err) {
    return res.status(500).json({ status: 'error', message: err.message });
  }
});

// ============================================================
// Admin-Only Endpoints (Strictly Guarded)
// ============================================================

// POST /api/notifications/admin/test-dispatch
// Dispatches a verified rate notification event for end-to-end testing.
router.post('/admin/test-dispatch', requireAdmin, async (req, res) => {
  try {
    // Strict RBAC: only ADMIN can trigger test dispatches
    if (req.adminUser?.app_metadata?.ferocalc_role !== 'ADMIN') {
      return res.status(403).json({
        status: 'error',
        message: 'Admin privileges required for notification testing',
      });
    }

    const {
      status = 'VERIFIED',
      bankCode,
      bankName,
      bankId,
      newRate,
      previousRate,
      tenureDescription,
      effectiveDate,
      type,
      candidateId,
      promotedRateId,
      customerType,
      rateCategory,
      tenureDomain,
      minTenureDays,
      maxTenureDays,
      minDeposit,
      maxDeposit,
      isCallable,
      schemeName,
    } = req.body || {};

    const result = await verifiedRateNotificationService.dispatchVerifiedRateEvent({
      status,
      bankCode,
      bankName,
      bankId,
      newRate,
      previousRate,
      tenureDescription,
      effectiveDate,
      type,
      candidateId,
      promotedRateId,
      customerType,
      rateCategory,
      tenureDomain,
      minTenureDays,
      maxTenureDays,
      minDeposit,
      maxDeposit,
      isCallable,
      schemeName,
    });

    if (result.rejected) {
      return res.status(400).json({
        status: 'error',
        message: result.reason,
      });
    }

    return res.json({
      status: 'ok',
      data: result,
    });
  } catch (err) {
    return res.status(500).json({ status: 'error', message: err.message });
  }
});

module.exports = router;
