// FeroCalc Verified FD Rate Engine — Narrow CORS Allowlist Policy
// Strictly governs browser origin access for production web and scoped Vercel preview environments.
//
// Rules:
// 1. Production web origin and local dev origins are matched from ALLOWED_ORIGINS.
// 2. Preview origins are restricted strictly to this repository's Vercel project scope:
//    Pattern: https://web-<deployment-hash>-kuldip12490-8771s-projects.vercel.app
// 3. Wildcards (*) and blanket .vercel.app matches are STRICTLY PROHIBITED.
// 4. Non-browser requests (null/undefined origin, mobile Dio/native apps, server-to-server) are allowed.

'use strict';

// Strict regex anchored to project 'web' and team scope 'kuldip12490-8771s-projects'
const NARROW_PREVIEW_PATTERN = /^https:\/\/web-[a-z0-9]+-kuldip12490-8771s-projects\.vercel\.app$/;

/**
 * Evaluates whether an inbound browser Origin header is permitted.
 *
 * @param {string} origin - Inbound Origin header string
 * @param {string[]} [configuredOrigins=[]] - Explicitly allowed origins from environment
 * @returns {boolean} True if origin is permitted, false otherwise
 */
function isOriginAllowed(origin, configuredOrigins = []) {
  if (!origin || typeof origin !== 'string') {
    return false;
  }

  const cleanOrigin = origin.trim();

  // 1. Exact match against configured allowlist (e.g. production web origin, localhost)
  if (configuredOrigins.includes(cleanOrigin)) {
    return true;
  }

  // 2. Narrow scoped Vercel preview pattern
  if (NARROW_PREVIEW_PATTERN.test(cleanOrigin)) {
    return true;
  }

  return false;
}

/**
 * Returns parsed origin array from comma-separated ALLOWED_ORIGINS string.
 *
 * @param {string|undefined} envVarValue
 * @returns {string[]}
 */
function parseAllowedOrigins(envVarValue) {
  if (!envVarValue || typeof envVarValue !== 'string') {
    return ['http://localhost:3000', 'http://localhost:8080'];
  }

  return envVarValue
    .split(',')
    .map(s => s.trim())
    .filter(Boolean);
}

/**
 * Express cors middleware origin delegate.
 *
 * @param {string[]} configuredOrigins
 * @returns {function(string, function)}
 */
function createCorsOriginValidator(configuredOrigins) {
  return function (origin, callback) {
    // Non-browser requests (mobile clients, curl, server-to-server) omit the Origin header
    if (!origin) {
      return callback(null, true);
    }

    if (isOriginAllowed(origin, configuredOrigins)) {
      return callback(null, true);
    }

    // Origin is not allowed; suppress Access-Control-Allow-Origin header
    return callback(null, false);
  };
}

module.exports = {
  NARROW_PREVIEW_PATTERN,
  isOriginAllowed,
  parseAllowedOrigins,
  createCorsOriginValidator,
};
