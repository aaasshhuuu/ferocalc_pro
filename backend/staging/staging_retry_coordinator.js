// FeroCalc Verified FD Rate Engine — Staging Retry & Rollback Coordinator
//
// Provides fail-closed safety routines for uncertain candidate persistence outcomes:
// 1. Candidate Identity Key derivation
// 2. Pre-insert state reconciliation (idempotent timeout recovery vs partial insert detection)
// 3. Write-receipt verification
// 4. Exact-ID scoped rollback guarding against accidental deletion of pre-existing rows

'use strict';

/**
 * Computes the deterministic Candidate Identity Key for a rate offering.
 * Business identity independent of source content hash or parser version.
 * Aligns with PostgreSQL 15+ NULLS NOT DISTINCT partial unique index:
 *   idx_staged_candidates_active_identity
 *
 * Preserves SQL NULL for nullable fields (min_deposit, max_deposit, is_callable, scheme_name)
 * so they remain distinct from explicit 0, -1, true, or empty string.
 * Normalizes scheme_name via upper(btrim(scheme_name)) preserving NULL.
 * Uses structured JSON array serialization to eliminate delimiter collisions.
 *
 * @param {Object} candidate
 * @returns {string} Structured identity key string
 */
/**
 * Normalizes a deposit value to an exact canonical NUMERIC(18,2) decimal string representation.
 * Preserves exact decimal precision without IEEE 754 float precision collapse.
 *
 * Requirements:
 * - null or undefined -> null
 * - Valid numeric string or safe number -> normalized to exact 'X.YY' decimal string
 * - Trailing zeros normalized: '1000' -> '1000.00', '1000.0' -> '1000.00', '1000.00' -> '1000.00'
 * - Leading zeros normalized: '001000.00' -> '1000.00'
 * - Zero normalized: 0 / '0' / '0.00' / '-0.00' -> '0.00'
 * - Negative values preserved: -1 / '-1' -> '-1.00'
 * - High precision values beyond float64 (> 9007199254740991):
 *   - If passed as exact string (e.g. '9007199254740992.00', '9007199254740993.00'):
 *     normalized losslessly as string without float conversion, keeping them strictly distinct!
 *   - If passed as JS number: fails closed with an error because float64 has already lost precision.
 * - Invalid values (NaN, Infinity, non-numeric strings, empty strings, >2 decimal places):
 *   fail closed with explicit error.
 *
 * @param {number|string|null|undefined} val
 * @param {string} [fieldName='deposit']
 * @returns {string|null}
 */
function normalizeExactDecimal(val, fieldName = 'deposit') {
  if (val === null || val === undefined) {
    return null;
  }

  if (typeof val === 'number') {
    if (isNaN(val)) {
      throw new Error(`Invalid numeric value: ${fieldName} cannot be NaN`);
    }
    if (!Number.isFinite(val)) {
      throw new Error(`Invalid numeric value: ${fieldName} cannot be non-finite (${val})`);
    }
    // Fail closed if any number exceeds safe decimal threshold (1e12).
    // Demonstrably, Number.isInteger() cannot be trusted above 1e12 because JSON.parse
    // on fractional decimal values rounds to integers (e.g. JSON.parse('140737488355328.01')
    // evaluates to integer 140737488355328, and JSON.parse('9007199254740993.00') evaluates to
    // integer 9007199254740992).
    // Therefore, ANY JavaScript number exceeding 1e12 is rejected, integer or not.
    if (Math.abs(val) > 1e12) {
      throw new Error(
        `Unsafe float precision loss: ${fieldName} number value ${val} exceeds safe decimal ` +
        `precision threshold (1e12). Pass exact NUMERIC(18,2) values as strings to prevent cent-level ` +
        `precision collapse or JSON parser rounding ambiguity.`
      );
    }
  }

  const s = String(val).trim();
  if (s === '') {
    throw new Error(`Invalid numeric value: ${fieldName} cannot be an empty string`);
  }

  const match = /^([+-])?(\d+)(?:\.(\d+))?$/.exec(s);
  if (!match) {
    throw new Error(`Invalid numeric format: ${fieldName} has invalid decimal format "${val}"`);
  }

  const sign = match[1] === '-' ? '-' : '';
  let intPart = match[2].replace(/^0+(?=\d)/, '');
  const fracRaw = match[3] || '';

  if (fracRaw.length > 2) {
    throw new Error(`Invalid numeric scale: ${fieldName} exceeds NUMERIC(18,2) scale with ${fracRaw.length} decimal places ("${val}")`);
  }

  if (intPart.length > 16) {
    throw new Error(`Invalid numeric precision: ${fieldName} exceeds NUMERIC(18,2) maximum of 16 integer digits ("${val}")`);
  }

  const fracPart = fracRaw.padEnd(2, '0');

  // Handle -0.00 -> 0.00
  if (intPart === '0' && fracPart === '00') {
    return '0.00';
  }

  return `${sign}${intPart}.${fracPart}`;
}

/**
 * Normalizes a scheme name according to category-specific PostgreSQL schema rules:
 * - STANDARD: scheme_name must be NULL (Migration 015 staged_rates_scheme_name_standard_null).
 *   Canonicalizes null, undefined, '', and whitespace-only strings to null.
 *   Throws an error if a non-empty scheme name is provided for a STANDARD rate.
 * - SPECIAL_SCHEME: scheme_name must be non-NULL and btrim(scheme_name) <> ''
 *   (Migration 015 staged_rates_scheme_name_required).
 *   Throws an error if scheme name is null, undefined, '', or whitespace-only.
 *   Returns upper(btrim(scheme_name)) with all tabs, newlines, and NBSP sanitized.
 *
 * @param {string|null|undefined} raw
 * @param {string} [rateCategory='STANDARD']
 * @returns {string|null}
 */
function normalizeSchemeName(raw, rateCategory = 'STANDARD') {
  const category = (rateCategory || 'STANDARD').toUpperCase().trim();
  const s = (raw === null || raw === undefined) ? null : String(raw).replace(/[\t\r\n\u00a0\v\f]+/g, ' ').trim();

  if (category === 'SPECIAL_SCHEME') {
    if (!s) {
      throw new Error(`Special scheme candidate requires a non-empty scheme_name (received: ${JSON.stringify(raw)})`);
    }
    return s.toUpperCase();
  }

  if (category === 'STANDARD') {
    if (s) {
      throw new Error(`Standard rate candidate cannot have a non-empty scheme_name: "${raw}"`);
    }
    return null;
  }

  throw new Error(`Invalid rateCategory: "${rateCategory}". Must be STANDARD or SPECIAL_SCHEME.`);
}

/**
 * Computes the deterministic Candidate Identity Key for a rate offering.
 * Business identity independent of source content hash or parser version.
 * Aligns with PostgreSQL 15+ NULLS NOT DISTINCT partial unique index:
 *   idx_staged_candidates_active_identity
 *
 * Preserves SQL NULL for nullable fields (min_deposit, max_deposit, is_callable, scheme_name)
 * so they remain distinct from explicit 0, -1, true, or empty string.
 * Normalizes deposit fields via normalizeExactDecimal to prevent float precision collapse.
 * Normalizes scheme_name via normalizeSchemeName enforcing category rules.
 * Uses structured JSON array serialization to eliminate delimiter collisions.
 *
 * @param {Object} candidate
 * @returns {string} Structured identity key string
 */
function getCandidateIdentityKey(candidate) {
  const bank = (candidate.bankCode || candidate.bank_code || '').toUpperCase().trim();
  const product = (candidate.productType || candidate.product_type || 'RETAIL_DOMESTIC_TERM_DEPOSIT').toUpperCase().trim();
  const customer = (candidate.customerType || candidate.customer_type || 'REGULAR').toUpperCase().trim();

  const rawMinTenure = candidate.minTenureDays !== undefined ? candidate.minTenureDays : candidate.min_tenure_days;
  const minTenure = (rawMinTenure !== undefined && rawMinTenure !== null) ? Number(rawMinTenure) : null;

  const rawMaxTenure = candidate.maxTenureDays !== undefined ? candidate.maxTenureDays : candidate.max_tenure_days;
  const maxTenure = (rawMaxTenure !== undefined && rawMaxTenure !== null) ? Number(rawMaxTenure) : null;

  const rawMinDeposit = candidate.minDeposit !== undefined ? candidate.minDeposit : candidate.min_deposit;
  const minDeposit = normalizeExactDecimal(rawMinDeposit, 'min_deposit');

  const rawMaxDeposit = candidate.maxDeposit !== undefined ? candidate.maxDeposit : candidate.max_deposit;
  const maxDeposit = normalizeExactDecimal(rawMaxDeposit, 'max_deposit');

  const rawIsCallable = candidate.isCallable !== undefined ? candidate.isCallable : candidate.is_callable;
  const isCallable = (rawIsCallable !== undefined && rawIsCallable !== null) ? Boolean(rawIsCallable) : null;

  const category = (candidate.rateCategory || candidate.rate_category || 'STANDARD').toUpperCase().trim();

  const rawScheme = candidate.schemeName !== undefined ? candidate.schemeName : candidate.scheme_name;
  const scheme = normalizeSchemeName(rawScheme, category);

  return JSON.stringify([
    bank,
    product,
    customer,
    minTenure,
    maxTenure,
    minDeposit,
    maxDeposit,
    isCallable,
    category,
    scheme,
  ]);
}

class StagingRetryCoordinator {
  constructor(options = {}) {
    this.logger = options.logger || console;
  }

  /**
   * Reconciles the staging database state before an insert or retry.
   *
   * @param {Object} params
   * @param {Object} params.supabaseClient
   * @param {string} params.bankCode
   * @param {string} params.sourceContentHash
   * @param {Array<Object>} params.expectedCandidates
   * @returns {Promise<{
   *   status: 'CLEAN_FOR_INSERT' | 'ALREADY_COMMITTED' | 'PARTIAL_INSERT_DETECTED' | 'IDENTITY_MISMATCH' | 'UNEXPECTED_STATUS',
   *   existingRows: Array<Object>,
   *   writeReceipt?: Array<Object>,
   *   reason?: string
   * }>}
   */
  async reconcileStagingState({ supabaseClient, bankCode, sourceContentHash, expectedCandidates }) {
    if (!supabaseClient) throw new Error('supabaseClient is required for reconciliation');
    if (!bankCode) throw new Error('bankCode is required');
    if (!sourceContentHash) throw new Error('sourceContentHash is required');
    if (!Array.isArray(expectedCandidates) || expectedCandidates.length === 0) {
      throw new Error('expectedCandidates array is required');
    }

    const { data: existingRows, error } = await supabaseClient
      .from('staged_rate_candidates')
      .select('*')
      .eq('bank_code', bankCode)
      .eq('source_content_hash', sourceContentHash);

    if (error) {
      return {
        status: 'UNEXPECTED_STATUS',
        existingRows: [],
        reason: `Database query failed during reconciliation: ${error.message}`,
      };
    }

    const rows = existingRows || [];

    // Case 1: Clean table, ready for initial insert
    if (rows.length === 0) {
      return {
        status: 'CLEAN_FOR_INSERT',
        canProceed: true,
        existingRows: [],
      };
    }

    // Case 2: Partial commit detected (fewer rows than expected batch)
    if (rows.length > 0 && rows.length < expectedCandidates.length) {
      return {
        status: 'PARTIAL_INSERT_DETECTED',
        canProceed: false,
        existingRows: rows,
        reason: `Incomplete batch detected: Expected ${expectedCandidates.length} rows, but found ${rows.length} rows in staged_rate_candidates. Manual review required.`,
      };
    }

    // Case 3: Overflow commit detected (more rows than expected batch)
    if (rows.length > expectedCandidates.length) {
      return {
        status: 'PARTIAL_INSERT_DETECTED',
        canProceed: false,
        existingRows: rows,
        reason: `Duplicate or excess rows detected: Found ${rows.length} rows for bank ${bankCode} and hash ${sourceContentHash.substring(0, 12)}... (expected ${expectedCandidates.length}). Manual cleanup required.`,
      };
    }

    // Case 4: Exactly expected count found -> Verify Candidate Identity Keys, Rates, and Status
    const expectedMap = new Map();
    for (const c of expectedCandidates) {
      expectedMap.set(getCandidateIdentityKey(c), c);
    }

    const mismatchedRows = [];
    const nonDraftRows = [];
    const rateConflictRows = [];

    for (const r of rows) {
      const rowKey = getCandidateIdentityKey(r);
      const expected = expectedMap.get(rowKey);
      if (!expected) {
        mismatchedRows.push(r);
      } else {
        const expectedRate = Number(expected.interestRate !== undefined ? expected.interestRate : expected.interest_rate);
        const existingRate = Number(r.interest_rate);
        if (expectedRate !== existingRate) {
          rateConflictRows.push({
            id: r.id,
            key: rowKey,
            existingRate,
            expectedRate,
          });
        }
      }
      if (r.staging_status !== 'DRAFT' || r.promoted_rate_id) {
        nonDraftRows.push(r);
      }
    }

    if (mismatchedRows.length > 0) {
      return {
        status: 'IDENTITY_MISMATCH',
        canProceed: false,
        existingRows: rows,
        reason: `${mismatchedRows.length} existing candidate rows do not match expected Candidate Identity Keys.`,
      };
    }

    if (rateConflictRows.length > 0) {
      return {
        status: 'IDENTITY_MISMATCH',
        canProceed: false,
        existingRows: rows,
        reason: `Rate change conflict detected for ${rateConflictRows.length} candidates (e.g. existing rate ${rateConflictRows[0].existingRate}% vs new candidate ${rateConflictRows[0].expectedRate}%). Earlier draft must be reviewed or rejected before staging new rate.`,
      };
    }

    if (nonDraftRows.length > 0) {
      return {
        status: 'UNEXPECTED_STATUS',
        canProceed: false,
        existingRows: rows,
        reason: `${nonDraftRows.length} matching candidate rows have already progressed beyond DRAFT status or have been promoted. Cannot retry.`,
      };
    }

    // All rows match expected batch perfectly in DRAFT -> Safe idempotent recovery
    const writeReceipt = rows.map(r => ({
      id: r.id,
      candidateIdentityKey: getCandidateIdentityKey(r),
      minTenureDays: r.min_tenure_days,
      customerType: r.customer_type,
    }));

    return {
      status: 'ALREADY_COMMITTED',
      canProceed: true,
      existingRows: rows,
      writeReceipt,
      reason: `All ${rows.length} candidates were already committed in DRAFT under hash ${sourceContentHash.substring(0, 12)}... Idempotent retry verified.`,
    };
  }

  /**
   * Verifies that newly inserted rows constitute a valid write receipt.
   *
   * @param {Object} params
   * @param {number} params.attemptedCount
   * @param {Array<Object>} params.insertedRows
   * @returns {{ valid: boolean, writeReceipt: Array<Object>, reason?: string }}
   */
  verifyWriteReceipt({ attemptedCount, insertedRows }) {
    if (!Array.isArray(insertedRows)) {
      return { valid: false, writeReceipt: [], reason: 'insertedRows is not an array' };
    }

    if (insertedRows.length !== attemptedCount) {
      return {
        valid: false,
        writeReceipt: [],
        reason: `Mismatched row count: Expected ${attemptedCount} rows, received ${insertedRows.length}`,
      };
    }

    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    const writeReceipt = [];

    for (const r of insertedRows) {
      if (!r.id || !uuidRegex.test(r.id)) {
        return {
          valid: false,
          writeReceipt: [],
          reason: `Invalid or missing primary key UUID in write receipt: "${r.id}"`,
        };
      }
      writeReceipt.push({
        id: r.id,
        candidateIdentityKey: getCandidateIdentityKey(r),
        minTenureDays: r.min_tenure_days,
        customerType: r.customer_type,
      });
    }

    return { valid: true, writeReceipt };
  }

  /**
   * Performs an isolated, fail-closed rollback scoped strictly to captured primary key UUIDs.
   *
   * @param {Object} params
   * @param {Object} params.supabaseClient
   * @param {Array<{ id: string }>} params.writeReceipt
   * @param {string} params.expectedBankCode
   * @returns {Promise<{ rolledBack: boolean, deletedCount: number, reason?: string }>}
   */
  async safeRollback({ supabaseClient, writeReceipt, expectedBankCode }) {
    if (!supabaseClient) throw new Error('supabaseClient is required for safe rollback');
    if (!Array.isArray(writeReceipt) || writeReceipt.length === 0) {
      throw new Error('Non-empty writeReceipt is required for safe rollback');
    }
    if (!expectedBankCode) throw new Error('expectedBankCode is required');

    const targetIds = writeReceipt.map(r => r.id);

    // Step 1: Pre-rollback verification query (assert ownership and status)
    const { data: rowsToVerify, error: verifyError } = await supabaseClient
      .from('staged_rate_candidates')
      .select('id, bank_code, staging_status, promoted_rate_id')
      .in('id', targetIds);

    if (verifyError) {
      return {
        rolledBack: false,
        deletedCount: 0,
        reason: `Pre-rollback verification query failed: ${verifyError.message}`,
      };
    }

    const verified = rowsToVerify || [];
    if (verified.length !== targetIds.length) {
      return {
        rolledBack: false,
        deletedCount: 0,
        reason: `Rollback aborted: Found ${verified.length} rows matching receipt IDs (expected ${targetIds.length}). State is inconsistent.`,
      };
    }

    for (const r of verified) {
      if (r.bank_code !== expectedBankCode) {
        return {
          rolledBack: false,
          deletedCount: 0,
          reason: `Rollback aborted: Row ${r.id} belongs to bank ${r.bank_code}, not expected ${expectedBankCode}.`,
        };
      }
      if (r.staging_status !== 'DRAFT') {
        return {
          rolledBack: false,
          deletedCount: 0,
          reason: `Rollback aborted: Row ${r.id} has status "${r.staging_status}", not "DRAFT". Manual review required.`,
        };
      }
      if (r.promoted_rate_id) {
        return {
          rolledBack: false,
          deletedCount: 0,
          reason: `Rollback aborted: Row ${r.id} has already been promoted to rate ${r.promoted_rate_id}. Destructive rollback prohibited.`,
        };
      }
    }

    // Step 2: Exact UUID deletion
    const { data: deletedRows, error: deleteError } = await supabaseClient
      .from('staged_rate_candidates')
      .delete()
      .in('id', targetIds)
      .select('id');

    if (deleteError) {
      return {
        rolledBack: false,
        deletedCount: 0,
        reason: `Rollback delete statement failed: ${deleteError.message}`,
      };
    }

    const deletedCount = (deletedRows && deletedRows.length) ? deletedRows.length : targetIds.length;
    return {
      rolledBack: true,
      deletedCount,
    };
  }
}

module.exports = {
  getCandidateIdentityKey,
  computeCandidateIdentity: getCandidateIdentityKey,
  normalizeExactDecimal,
  normalizeSchemeName,
  StagingRetryCoordinator,
};
