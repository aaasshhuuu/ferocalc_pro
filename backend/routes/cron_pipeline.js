// FeroCalc Verified FD Rate Engine — Internal Scheduled Job Router
//
// Authenticated endpoint for triggering the rate collection & promotion pipeline.
// Intended for invocation by Vercel Cron, GitHub Actions, or external cloud triggers.
//
// Endpoints:
// - POST /api/internal/jobs/run-pipeline
//
// Security Guarantees:
// 1. Strictly requires valid CRON_SECRET header (x-cron-secret or Bearer token).
// 2. Constant-time secret comparison to prevent timing attacks.
// 3. Secrets are NEVER logged or returned in responses.

'use strict';

const express = require('express');
const crypto = require('crypto');
const router = express.Router();
const { PipelineSchedulerService } = require('../scheduling/pipeline_scheduler_service');

const pipelineScheduler = new PipelineSchedulerService();

/**
 * Constant-time string equality check to prevent timing side-channel attacks.
 */
function safeCompare(a, b) {
  if (!a || !b) return false;
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

/**
 * Cron Authentication Middleware
 */
function requireCronSecret(req, res, next) {
  const configuredSecret = process.env.CRON_SECRET;
  if (!configuredSecret) {
    return res.status(503).json({
      status: 'error',
      message: 'CRON_SECRET is not configured on this server',
    });
  }

  // Extract from x-cron-secret header or Authorization: Bearer <token>
  const customHeader = req.headers['x-cron-secret'];
  const authHeader = req.headers['authorization'] || '';
  const bearerToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

  const providedSecret = customHeader || bearerToken;

  if (!providedSecret || !safeCompare(providedSecret, configuredSecret)) {
    return res.status(401).json({
      status: 'error',
      message: 'Unauthorized: Invalid or missing cron secret',
    });
  }

  next();
}

/**
 * POST /api/internal/jobs/run-pipeline
 * Triggers the automated rate collection, extraction, validation, diff, and safe promotion pipeline.
 */
router.post('/run-pipeline', requireCronSecret, async (req, res) => {
  const isDryRun = req.query.dryRun === 'true' || req.body.dryRun === true;
  const forceReExtract = req.query.forceReExtract === 'true' || req.body.forceReExtract === true;
  const triggerType = req.body.triggerType || (req.headers['x-vercel-cron'] ? 'CRON' : 'API');

  try {
    const summary = await pipelineScheduler.executePipeline({
      triggerType,
      dryRun: isDryRun,
      forceReExtract,
    });

    if (summary.status === 'LOCKED') {
      return res.status(409).json({
        status: 'locked',
        message: summary.reason,
        jobId: summary.jobId,
      });
    }

    return res.status(200).json({
      status: 'success',
      data: summary,
    });

  } catch (err) {
    return res.status(500).json({
      status: 'error',
      message: 'Pipeline execution failed: ' + err.message,
    });
  }
});

module.exports = {
  cronRouter: router,
  requireCronSecret,
  safeCompare,
  pipelineScheduler,
};
