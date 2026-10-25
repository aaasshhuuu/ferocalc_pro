// FeroCalc Verified FD Rate Engine — Environment Configuration Loader
// Resolves environment configuration deterministically and independently of process.cwd().
// Prevents accidental cross-project operations and silent shell variable overrides.

'use strict';

const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');

const BACKEND_DIR = path.resolve(__dirname);
const CRITICAL_KEYS = ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'SUPABASE_SERVICE_ROLE_KEY'];

/**
 * Determines whether the current invocation is explicitly targeting staging.
 */
function determineTargetEnvironment(options = {}) {
  if (options.environment) {
    return options.environment;
  }
  const argv = options.argv || process.argv || [];
  const env = options.env || process.env || {};

  if (argv.includes('--staging') || argv.some(a => a.startsWith('--env=staging')) || env.APP_ENV === 'staging') {
    return 'staging';
  }
  return 'default';
}

/**
 * Loads and validates environment configuration.
 *
 * @param {Object} [options]
 * @param {string} [options.environment] - Explicit 'staging' or 'default'
 * @param {string} [options.envPath] - Explicit path to env file
 * @param {boolean} [options.silent] - Suppress informational logs
 * @returns {Object} Metadata about the loaded environment (values redacted)
 */
function loadEnv(options = {}) {
  const targetEnv = determineTargetEnvironment(options);
  const isStaging = targetEnv === 'staging';
  const defaultFileName = isStaging ? '.env.staging' : '.env';
  const filePath = options.envPath ? path.resolve(options.envPath) : path.join(BACKEND_DIR, defaultFileName);
  const fileName = path.basename(filePath);

  if (!fs.existsSync(filePath)) {
    // If staging was explicitly requested, missing .env.staging is a fatal error
    if (isStaging) {
      throw new Error(`[EnvLoader:FileNotFound] Staging environment file not found at: ${filePath}`);
    }
    // In default mode, if .env doesn't exist, return gracefully without crashing (e.g. CI/mock test environment)
    return {
      environment: 'default',
      loaded: false,
      reason: 'File not found',
      filePath,
    };
  }

  const rawContent = fs.readFileSync(filePath, 'utf8');
  const parsed = dotenv.parse(rawContent);

  // Requirement 4: Ensure shell variables cannot silently override the intended project.
  // If pre-existing shell variables differ from the target env file, FAIL CLOSED.
  const conflicts = [];
  for (const key of CRITICAL_KEYS) {
    if (process.env[key] !== undefined && parsed[key] !== undefined) {
      if (process.env[key] !== parsed[key]) {
        conflicts.push(key);
      }
    }
  }

  if (conflicts.length > 0) {
    // NEVER reveal values, URLs, or secrets in error message (Requirement 5)
    throw new Error(
      `[EnvConflictError] Pre-existing shell environment variable(s) [${conflicts.join(', ')}] ` +
      `conflict with ${fileName}. Failing closed to prevent accidental cross-project operations. ` +
      `Please unset conflicting shell variable(s) or run in a clean environment.`
    );
  }

  // If staging is selected, ensure required credentials exist
  if (isStaging) {
    const missing = CRITICAL_KEYS.filter(k => !parsed[k] || !parsed[k].trim());
    if (missing.length > 0) {
      throw new Error(
        `[EnvMissingError] Staging configuration in ${fileName} is missing required key(s): [${missing.join(', ')}]. Failing closed.`
      );
    }
  }

  // Populate process.env
  for (const [key, val] of Object.entries(parsed)) {
    process.env[key] = val;
  }

  process.env.APP_ENV = isStaging ? 'staging' : (process.env.APP_ENV || 'production');
  process.env.FEROCALC_ENV_LOADED = targetEnv;

  if (!options.silent) {
    const redactedInfo = `Loaded ${isStaging ? 'STAGING' : 'DEFAULT'} environment from ${fileName} (${Object.keys(parsed).length} keys, 0 conflicts)`;
    console.log(`[EnvLoader] ${redactedInfo}`);
  }

  return {
    environment: targetEnv,
    loaded: true,
    filePath,
    keyCount: Object.keys(parsed).length,
    keys: Object.keys(parsed),
  };
}

module.exports = {
  loadEnv,
  determineTargetEnvironment,
  BACKEND_DIR,
  CRITICAL_KEYS,
};
