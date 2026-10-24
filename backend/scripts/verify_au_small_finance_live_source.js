'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const baseline = require('../review/au_small_finance_official_baseline_2026-09-01.json');
const { AuSmallFinanceRateParser, normalizeTenureLabel } = require('../parsers/au_small_finance_parser');
const { fetchWithHardenedCurl } = require('./curl_transport');

const OUT = path.join(__dirname, '../review/live-evidence');
const MAX_BYTES = 5 * 1024 * 1024;
const MAX_REDIRECTS = 3;

function allowed(url) {
  const u = new URL(url);
  const host = u.hostname.toLowerCase();
  return u.protocol === 'https:' && (
    host === 'au.bank.in' ||
    host.endsWith('.au.bank.in') ||
    host === 'aubank.in' ||
    host.endsWith('.aubank.in')
  );
}

async function fetchOfficial(start) {
  let url = start;
  for (let i = 0; i <= MAX_REDIRECTS; i++) {
    if (!allowed(url)) throw new Error('Refusing non-HTTPS or non-AU redirect URL: ' + url);
    const res = await fetch(url, {
      redirect: 'manual',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-IN,en;q=0.9',
        'Cache-Control': 'no-cache',
      },
      signal: AbortSignal.timeout(20000),
    });

    if ([301, 302, 303, 307, 308].includes(res.status)) {
      const loc = res.headers.get('location');
      if (!loc || i === MAX_REDIRECTS) throw new Error('Missing redirect location or redirect limit exceeded');
      url = new URL(loc, url).href;
      continue;
    }

    if (!res.ok) throw new Error('Official source HTTP status ' + res.status);
    const type = res.headers.get('content-type') || '';
    if (!/text\/html|application\/xhtml\+xml/i.test(type)) throw new Error('Unexpected content type: ' + type);
    if (Number(res.headers.get('content-length') || 0) > MAX_BYTES) throw new Error('Official source exceeds 5 MB limit');

    const body = Buffer.from(await res.arrayBuffer());
    if (body.length > MAX_BYTES) throw new Error('Official source body exceeds 5 MB limit');
    return { url, status: res.status, type, body, fetchMethod: 'node-fetch' };
  }
  throw new Error('Redirect limit exceeded');
}

function fetchWithCurl(url, overrides = {}) {
  return fetchWithHardenedCurl(url, {
    allowed,
    expectedType: /text\/html|application\/xhtml\+xml/i,
    maxBytes: MAX_BYTES,
    minBytes: 1000,
    maxRedirects: MAX_REDIRECTS,
    ...overrides,
  });
}

function norm(s) {
  return normalizeTenureLabel(s).replace(/\s+/g, ' ').trim().toLowerCase();
}

/**
 * Reconciles parsed AU candidates and metadata against baseline specification.
 * Pure verification logic decoupled from transport/fetch.
 */
function verifyContent(parsed, baselineConfig, context = {}) {
  const mismatches = [];
  let scopedEffectiveDatesReconciled = false;
  let nonCallableTableExcluded = false;
  let monthlyPayoutTableExcluded = false;
  let yieldExcludedFromRates = false;
  let matchedTenureRows = 0;

  if (!parsed.success) {
    mismatches.push('Live parser failed closed: ' + (parsed.errors || []).join('; '));
  }

  const effectiveDateMatched = parsed.effectiveFrom === baselineConfig.effectiveFrom;
  if (!effectiveDateMatched) {
    mismatches.push(
      'Effective date mismatch: expected ' + baselineConfig.effectiveFrom + ', got ' + (parsed.effectiveFrom || 'null')
    );
  }

  // Verify scoped table dates
  const effectiveDates = parsed.metadata?.effectiveDatesByTable || {};
  if (effectiveDates.regularCallable === baselineConfig.effectiveDatesByTable.regularCallable &&
      effectiveDates.seniorCitizenCallable === baselineConfig.effectiveDatesByTable.seniorCitizenCallable) {
    scopedEffectiveDatesReconciled = true;
  } else {
    mismatches.push(
      `Scoped effective dates mismatch: regular=${effectiveDates.regularCallable} (expected ${baselineConfig.effectiveDatesByTable.regularCallable}), ` +
      `senior=${effectiveDates.seniorCitizenCallable} (expected ${baselineConfig.effectiveDatesByTable.seniorCitizenCallable})`
    );
  }

  // Verify exclusion of non-callable and monthly payout tables
  if (parsed.metadata?.nonCallableRatesIncluded === false) {
    nonCallableTableExcluded = true;
  } else {
    mismatches.push('Non-callable rates were improperly included in candidates');
  }

  if (parsed.metadata?.monthlyPayoutRatesIncluded === false) {
    monthlyPayoutTableExcluded = true;
  } else {
    mismatches.push('Monthly payout rates were improperly included in candidates');
  }

  if (parsed.metadata?.yieldIncludedAsRate === false) {
    yieldExcludedFromRates = true;
  } else {
    mismatches.push('Annualized yield was improperly used as interest rate');
  }

  if (parsed.candidates.length !== baselineConfig.tenures.length * 2) {
    mismatches.push(
      `Candidate count mismatch: expected ${baselineConfig.tenures.length * 2}, got ${parsed.candidates.length}`
    );
  }

  // Group candidates by normalized tenure label and customer type
  const actual = new Map();
  for (const c of parsed.candidates) {
    const key = norm(c.tenureLabel);
    if (!actual.has(key)) actual.set(key, {});
    if (actual.get(key)[c.customerType] !== undefined) {
      mismatches.push(`Duplicate candidate for tenure "${c.tenureLabel}" / ${c.customerType}`);
    }
    actual.get(key)[c.customerType] = c.interestRate;
  }

  // Compare against baseline
  for (const e of baselineConfig.tenures) {
    const a = actual.get(norm(e.label));
    if (!a) {
      mismatches.push('Missing tenure row: ' + e.label);
      continue;
    }
    matchedTenureRows++;
    if (Number(a.REGULAR) !== e.regular) {
      mismatches.push(`${e.label} regular mismatch: expected ${e.regular}, got ${a.REGULAR}`);
    }
    if (Number(a.SENIOR_CITIZEN) !== e.senior) {
      mismatches.push(`${e.label} senior mismatch: expected ${e.senior}, got ${a.SENIOR_CITIZEN}`);
    }
  }

  return {
    mismatches,
    effectiveDateMatched,
    scopedEffectiveDatesReconciled,
    nonCallableTableExcluded,
    monthlyPayoutTableExcluded,
    yieldExcludedFromRates,
    matchedTenureRows,
    totalBaselineRows: baselineConfig.tenures.length,
    comparedRateValues: matchedTenureRows * 2,
  };
}

/**
 * Runs AU Small Finance Bank live source verification or offline baseline check.
 *
 * @param {object} [options]
 * @param {boolean} [options.offline] - Run in offline mode using fixture
 * @param {string} [options.fixturePath] - Path to offline fixture file
 * @param {Buffer|string} [options.body] - In-memory fixture body
 * @param {string} [options.mockFetchFailure] - Deterministic simulation of live-fetch failure
 * @param {number|null} [options.mockHttpStatus] - Status code for mock fetch failure
 * @returns {Promise<{ success: boolean, report: object, exitCode: number }>}
 */
async function runVerification(options = {}) {
  const isOffline = Boolean(options.offline || process.argv.includes('--offline'));
  const fixturePath = options.fixturePath || null;

  fs.mkdirSync(OUT, { recursive: true });

  const report = {
    bankCode: baseline.bankCode,
    sourceUrl: baseline.sourceUrl,
    expectedEffectiveFrom: baseline.effectiveFrom,
    fetchedAt: new Date().toISOString(),
    isLiveRun: !isOffline,
    sourceFetchStatus: 'NOT_STARTED',
    fetchMethod: 'NONE',
    httpStatus: null,
    finalUrl: baseline.sourceUrl,
    contentType: null,
    parserStatus: 'NOT_RUN',
    parityStatus: 'FAIL_CLOSED',
    mismatches: [],
    scopedEffectiveDatesReconciled: false,
    nonCallableTableExcluded: false,
    monthlyPayoutTableExcluded: false,
    yieldExcludedFromRates: false,
    matchedTenureRows: 0,
    totalBaselineRows: baseline.tenures.length,
    comparedRateValues: 0,
    activationApproved: false,
  };

  const reportPath = path.join(OUT, 'au-small-finance-live-parity-report.json');
  const snapshotPath = path.join(OUT, 'au-small-finance-live-page.html');

  let body = null;
  let finalUrl = baseline.sourceUrl;
  let httpStatus = null;
  let contentType = 'text/html';
  let fetchMethod = 'NONE';

  if (isOffline) {
    if (options.body) {
      body = Buffer.isBuffer(options.body) ? options.body : Buffer.from(options.body);
    } else {
      const targetPath = fixturePath || path.join(__dirname, '../review/source-discovery/au.html');
      if (!fs.existsSync(targetPath)) {
        report.sourceFetchStatus = 'FAILED';
        report.mismatches.push(`Offline fixture file not found: ${targetPath}`);
        fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
        return { success: false, report, exitCode: 1 };
      }
      body = fs.readFileSync(targetPath);
    }
    fetchMethod = 'OFFLINE_FIXTURE';
    report.sourceFetchStatus = 'OFFLINE_LOADED';
    report.fetchMethod = fetchMethod;
    report.httpStatus = null; // Do NOT fabricate HTTP 200 for local file
    report.note = 'OFFLINE BASELINE RUN: Local fixture used; live source was NOT verified.';
  } else if (options.mockFetchFailure) {
    report.sourceFetchStatus = 'FAILED';
    report.fetchMethod = 'NONE';
    report.httpStatus = options.mockHttpStatus || null;
    report.parityStatus = 'FAIL_CLOSED';
    report.mismatches.push(`Live official source fetch failed on all methods: ${options.mockFetchFailure}`);
    report.note = 'Live source fetch failed. Archived snapshots are strictly prohibited from generating a live-source PASS.';

    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
    return { success: false, report, exitCode: 1 };
  } else {
    // LIVE MODE: Strictly live network fetch.
    // Archived discovery snapshots are strictly prohibited from being used here.
    const fetchErrors = [];

    // Attempt 1: Node fetch
    try {
      const f = await fetchOfficial(baseline.sourceUrl);
      body = f.body;
      finalUrl = f.url;
      httpStatus = f.status;
      contentType = f.type;
      fetchMethod = f.fetchMethod;
    } catch (e1) {
      fetchErrors.push('node-fetch: ' + e1.message);

      // Attempt 2: curl
      try {
        const c = fetchWithCurl(baseline.sourceUrl);
        body = c.body;
        finalUrl = c.url;
        httpStatus = c.status;
        contentType = c.type;
        fetchMethod = c.fetchMethod;
      } catch (e2) {
        fetchErrors.push('curl: ' + e2.message);
      }
    }

    if (!body) {
      // Both live fetch attempts failed: FAIL CLOSED, record actual error, do NOT fallback to snapshot!
      report.sourceFetchStatus = 'FAILED';
      report.fetchMethod = 'NONE';
      report.httpStatus = null;
      report.parityStatus = 'FAIL_CLOSED';
      report.mismatches.push(`Live official source fetch failed on all methods: ${fetchErrors.join('; ')}`);
      report.note = 'Live source fetch failed. Archived snapshots are strictly prohibited from generating a live-source PASS.';

      fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
      console.error(JSON.stringify(report, null, 2));
      return { success: false, report, exitCode: 1 };
    }

    report.sourceFetchStatus = 'SUCCESS';
    report.fetchMethod = fetchMethod;
    report.httpStatus = httpStatus;
    report.finalUrl = finalUrl;
    report.contentType = contentType;
  }

  const hash = crypto.createHash('sha256').update(body).digest('hex');
  if (!isOffline) {
    fs.writeFileSync(snapshotPath, body);
  }

  report.bodyBytes = body.length;
  report.sourceContentSha256 = hash;

  const parsed = new AuSmallFinanceRateParser().parse(body, {
    sourceId: 'au-small-finance-retail-domestic',
    sourceUrl: finalUrl,
    sourceContentHash: hash,
    extractedAt: report.fetchedAt,
  });

  report.parserStatus = parsed.success ? 'SUCCESS' : 'FAILED';
  report.parserErrors = parsed.errors;
  report.extractedEffectiveFrom = parsed.effectiveFrom;
  report.rawTableCount = parsed.rawTableCount;
  report.extractedRows = parsed.metadata?.extractedRows || 0;
  report.validRows = parsed.metadata?.validRows || 0;
  report.candidateCount = parsed.candidates.length;

  const verification = verifyContent(parsed, baseline, { isOffline, hash });

  report.mismatches.push(...verification.mismatches);
  report.scopedEffectiveDatesReconciled = verification.scopedEffectiveDatesReconciled;
  report.nonCallableTableExcluded = verification.nonCallableTableExcluded;
  report.monthlyPayoutTableExcluded = verification.monthlyPayoutTableExcluded;
  report.yieldExcludedFromRates = verification.yieldExcludedFromRates;
  report.matchedTenureRows = verification.matchedTenureRows;
  report.totalBaselineRows = verification.totalBaselineRows;
  report.comparedRateValues = verification.comparedRateValues;

  if (isOffline) {
    report.parityStatus = report.mismatches.length === 0 ? 'OFFLINE_BASELINE_PASS' : 'FAIL_CLOSED';
    report.activationApproved = false;
  } else {
    report.parityStatus = report.mismatches.length === 0 ? 'PASS' : 'FAIL_CLOSED';
    report.activationApproved = false;
    report.note = 'Parity verifies official source extraction only; it does not authorize source activation, staging, promotion, or release. AU Small Finance Bank source remains disabled pending human review and governance sign-off.';
  }

  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report, null, 2));

  const passed = report.mismatches.length === 0;
  return { success: passed, report, exitCode: passed ? 0 : 1 };
}

async function main() {
  const isOffline = process.argv.includes('--offline');
  const fixtureIdx = process.argv.indexOf('--fixture');
  const fixturePath = fixtureIdx !== -1 && fixtureIdx + 1 < process.argv.length ? process.argv[fixtureIdx + 1] : null;
  const result = await runVerification({ offline: isOffline, fixturePath });
  process.exit(result.exitCode);
}

if (require.main === module) {
  main();
}

module.exports = {
  fetchOfficial,
  fetchWithCurl,
  allowed,
  verifyContent,
  runVerification,
  main,
};
