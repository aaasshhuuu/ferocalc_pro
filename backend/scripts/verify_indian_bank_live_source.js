'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');
const baseline = require('../review/indian_bank_official_baseline_2026-10-23.json');
const { IndianBankRateParser, normalizeTenureLabel } = require('../parsers/indian_bank_parser');

const OUT = path.join(__dirname, '../review/live-evidence');
const MAX_BYTES = 5 * 1024 * 1024;
const MAX_REDIRECTS = 3;

function allowed(url) {
  const u = new URL(url);
  const host = u.hostname.toLowerCase();
  return u.protocol === 'https:' && (
    host === 'indianbank.in' ||
    host.endsWith('.indianbank.in') ||
    host === 'indianbank.bank.in' ||
    host.endsWith('.indianbank.bank.in')
  );
}

async function fetchOfficial(start) {
  let url = start;
  let lastHttpStatus = null;

  for (let i = 0; i <= MAX_REDIRECTS; i++) {
    if (!allowed(url)) throw new Error('Refusing non-HTTPS or non-Indian Bank redirect URL: ' + url);
    const res = await fetch(url, {
      redirect: 'manual',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-IN,en;q=0.9',
        'Cache-Control': 'no-cache',
      },
      signal: AbortSignal.timeout(20000),
    });

    lastHttpStatus = res.status;

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
    const bodyStr = body.toString('utf-8', 0, Math.min(body.length, 2048));
    if (body.length < 5000 || bodyStr.includes('Request Rejected') || bodyStr.includes('The requested URL was rejected')) {
      throw new Error('WAF challenge or Request Rejected block on node-fetch (length: ' + body.length + ')');
    }
    return { url, status: res.status, type, body, fetchMethod: 'node-fetch' };
  }
  throw new Error('Redirect limit exceeded');
}

function fetchWithCurl(url) {
  if (!allowed(url)) throw new Error('Refusing non-HTTPS or non-Indian Bank URL for curl: ' + url);
  const curlCmd = `curl.exe -s -L --max-redirs 3 --max-filesize 5242880 ` +
    `-H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36" ` +
    `-H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" ` +
    `-H "Accept-Language: en-IN,en;q=0.9" ` +
    `"${url}"`;
  const buf = execSync(curlCmd, { timeout: 30000, maxBuffer: MAX_BYTES });
  if (buf.length > MAX_BYTES) throw new Error('Curl response exceeds 5 MB limit');
  const str = buf.toString('utf-8');
  if (str.includes('<title>Just a moment...</title>') || str.includes('Attention Required! | Cloudflare') || str.includes('Request Rejected') || str.includes('The requested URL was rejected')) {
    throw new Error('Cloudflare / WAF block detected on datacenter IP');
  }
  if (buf.length < 5000) throw new Error('Curl response suspiciously small');
  return { url, status: 200, type: 'text/html', body: buf, fetchMethod: 'curl' };
}

function norm(s) {
  return normalizeTenureLabel(s).replace(/\s+/g, ' ').trim().toLowerCase();
}

/**
 * Reconciles parsed candidates and metadata against baseline specification.
 * Pure verification logic decoupled from transport/fetch.
 */
function verifyContent(parsed, baselineConfig, context = {}) {
  const mismatches = [];
  const schemeDatesValidation = {};

  if (!parsed.success) {
    mismatches.push('Parser failed closed: ' + (parsed.errors || []).join('; '));
  }

  // 1. Effective date of main table
  if (parsed.effectiveFrom !== baselineConfig.effectiveFrom) {
    mismatches.push(
      `Main effective date mismatch: expected ${baselineConfig.effectiveFrom}, got ${parsed.effectiveFrom || 'null'}`
    );
  }

  // 2. Special scheme effective dates
  const expectedSchemeDates = baselineConfig.effectiveDatesByTable || {};
  const extractedSchemeDates = parsed.metadata?.effectiveDatesByTable || {};
  const schemeSources = parsed.metadata?.schemeEffectiveDatesSource || {};

  const schemeKeys = ['indSupreme300', 'indGreen500', 'indGrow555', 'indProsper777'];
  for (const scheme of schemeKeys) {
    const expectedDate = expectedSchemeDates[scheme];
    const extractedDate = extractedSchemeDates[scheme];
    const sourceKind = schemeSources[scheme];

    if (!expectedDate) continue;

    if (sourceKind === 'EXTRACTED_FROM_SOURCE' && extractedDate) {
      if (extractedDate === expectedDate) {
        schemeDatesValidation[scheme] = {
          verifiedInContent: true,
          date: extractedDate,
          source: 'EXTRACTED_FROM_SOURCE',
        };
      } else {
        mismatches.push(
          `Scheme ${scheme} effective date mismatch: expected ${expectedDate}, got ${extractedDate}`
        );
        schemeDatesValidation[scheme] = {
          verifiedInContent: false,
          expected: expectedDate,
          extracted: extractedDate,
          source: 'EXTRACTED_FROM_SOURCE',
        };
      }
    } else {
      // Content does not independently expose this scheme's date
      schemeDatesValidation[scheme] = {
        verifiedInContent: false,
        date: expectedDate,
        source: 'BASELINE_METADATA_UNVERIFIED_IN_CONTENT',
        note: 'Baseline metadata only; date was not independently exposed in fetched HTML content',
      };
    }
  }

  // 3. Special schemes identified
  const indSupreme = parsed.candidates.find(c => c.schemeName === 'IND_SUPREME_300');
  const indGreen = parsed.candidates.find(c => c.schemeName === 'IND_GREEN_500');
  const indGrow = parsed.candidates.find(c => c.schemeName === 'IND_GROW_555');
  const indProsper = parsed.candidates.find(c => c.schemeName === 'IND_PROSPER_777');

  const specialSchemesReconciled = Boolean(indSupreme && indGreen && indGrow && indProsper);
  if (!specialSchemesReconciled) {
    mismatches.push('Special schemes IND_SUPREME_300, IND_GREEN_500, IND_GROW_555, IND_PROSPER_777 were not all identified');
  }

  // 4. Verify exclusions
  const bulkTablesExcluded = parsed.metadata?.bulkRatesIncluded === false;
  if (!bulkTablesExcluded) {
    mismatches.push('Bulk rates were improperly included');
  }

  const nonCallableExcluded = parsed.metadata?.nonCallableRatesIncluded === false;
  if (!nonCallableExcluded) {
    mismatches.push('Non-callable rates were improperly included');
  }

  const yieldExcluded = parsed.metadata?.yieldIncludedAsRate === false;
  if (!yieldExcluded) {
    mismatches.push('Annualized yield was improperly used as interest rate');
  }

  // 5. Candidate count: 18 tenures * 3 customer types = 54
  const expectedCandidates = baselineConfig.tenures.length * 3;
  if (parsed.candidates.length !== expectedCandidates) {
    mismatches.push(
      `Candidate count mismatch: expected ${expectedCandidates}, got ${parsed.candidates.length}`
    );
  }

  // 6. Check duplicates & map actual rates
  const actual = new Map();
  for (const c of parsed.candidates) {
    const key = norm(c.tenureLabel);
    if (!actual.has(key)) actual.set(key, {});
    if (actual.get(key)[c.customerType] !== undefined) {
      mismatches.push(`Duplicate candidate for tenure "${c.tenureLabel}" / ${c.customerType}`);
    }
    actual.get(key)[c.customerType] = c.interestRate;
  }

  // 7. Reconcile all baseline tenures and rates
  let matchedTenureRows = 0;
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
    if (Number(a.SUPER_SENIOR_CITIZEN) !== e.superSenior) {
      mismatches.push(`${e.label} super senior mismatch: expected ${e.superSenior}, got ${a.SUPER_SENIOR_CITIZEN}`);
    }
  }

  return {
    mismatches,
    specialSchemesReconciled,
    bulkTablesExcluded,
    nonCallableExcluded,
    yieldExcluded,
    matchedTenureRows,
    totalBaselineRows: baselineConfig.tenures.length,
    comparedRateValues: matchedTenureRows * 3,
    schemeDatesValidation,
  };
}

/**
 * Main verification entrypoint.
 *
 * Live mode (default): Fetches strictly from live official source.
 * An archived snapshot CANNOT produce a live-source PASS.
 * If live fetch fails, parityStatus is FAIL_CLOSED and process exits 1.
 *
 * Offline mode (--offline or --fixture <path>): Explicitly flags fetchMethod as
 * OFFLINE_FIXTURE and sets parityStatus to OFFLINE_BASELINE_PASS (never PASS).
 */
async function runVerification(options = {}) {
  fs.mkdirSync(OUT, { recursive: true });

  const isOffline = Boolean(options.offline || process.argv.includes('--offline'));
  const fixtureArgIndex = process.argv.indexOf('--fixture');
  const fixturePath = options.fixturePath || (fixtureArgIndex !== -1 ? process.argv[fixtureArgIndex + 1] : null);

  const report = {
    bankCode: baseline.bankCode,
    sourceUrl: baseline.sourceUrl,
    expectedEffectiveFrom: baseline.effectiveFrom,
    effectiveDatesByTable: baseline.effectiveDatesByTable,
    fetchedAt: new Date().toISOString(),
    isLiveRun: !isOffline,
    sourceFetchStatus: 'NOT_STARTED',
    fetchMethod: 'NONE',
    httpStatus: null,
    parserStatus: 'NOT_RUN',
    parityStatus: 'FAIL_CLOSED',
    mismatches: [],
    specialSchemesReconciled: false,
    bulkTablesExcluded: false,
    nonCallableExcluded: false,
    activationApproved: false,
    schemeEffectiveDatesValidation: {},
  };

  const reportPath = path.join(OUT, 'indian-bank-live-parity-report.json');
  const snapshotPath = path.join(OUT, 'indian-bank-live-page.html');

  let body = null;
  let finalUrl = baseline.sourceUrl;
  let httpStatus = null;
  let contentType = 'text/html';
  let fetchMethod = 'NONE';

  if (isOffline) {
    // OFFLINE MODE: Clearly separate offline baseline test
    const targetPath = fixturePath || path.join(__dirname, '../review/source-discovery/indian_bank.html');
    if (!fs.existsSync(targetPath)) {
      report.sourceFetchStatus = 'FAILED';
      report.mismatches.push(`Offline fixture file not found: ${targetPath}`);
      fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
      return { success: false, report, exitCode: 1 };
    }
    body = fs.readFileSync(targetPath);
    fetchMethod = 'OFFLINE_FIXTURE';
    report.sourceFetchStatus = 'OFFLINE_LOADED';
    report.fetchMethod = fetchMethod;
    report.httpStatus = null; // Do NOT fabricate HTTP 200 for local file
    report.note = 'OFFLINE BASELINE RUN: Local fixture used; live source was NOT verified.';
  } else if (options.mockFetchFailure) {
    // Deterministic simulation of live-fetch failure for regression verification
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
    // An archived discovery snapshot is NEVER used here.
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

  const parsed = new IndianBankRateParser().parse(body, {
    sourceId: 'indian-bank-retail-domestic',
    sourceUrl: finalUrl,
    sourceContentHash: hash,
    extractedAt: report.fetchedAt,
  });

  report.parserStatus = parsed.success ? 'SUCCESS' : 'FAILED';
  report.parserErrors = parsed.errors;
  report.extractedEffectiveFrom = parsed.effectiveFrom;
  report.rawTableCount = parsed.rawTableCount;
  report.extractedRowCount = parsed.metadata?.extractedRowCount || 0;
  report.validRowCount = parsed.metadata?.validRowCount || 0;
  report.standardRowCount = parsed.metadata?.standardRowCount || 0;
  report.specialSchemeCount = parsed.metadata?.specialSchemeCount || 0;
  report.candidateCount = parsed.candidates.length;

  const verification = verifyContent(parsed, baseline, { isOffline, hash });

  report.mismatches.push(...verification.mismatches);
  report.specialSchemesReconciled = verification.specialSchemesReconciled;
  report.bulkTablesExcluded = verification.bulkTablesExcluded;
  report.nonCallableExcluded = verification.nonCallableExcluded;
  report.yieldExcluded = verification.yieldExcluded;
  report.matchedTenureRows = verification.matchedTenureRows;
  report.totalBaselineRows = verification.totalBaselineRows;
  report.comparedRateValues = verification.comparedRateValues;
  report.schemeEffectiveDatesValidation = verification.schemeDatesValidation;

  if (isOffline) {
    report.parityStatus = report.mismatches.length === 0 ? 'OFFLINE_BASELINE_PASS' : 'FAIL_CLOSED';
    report.activationApproved = false;
  } else {
    report.parityStatus = report.mismatches.length === 0 ? 'PASS' : 'FAIL_CLOSED';
    report.activationApproved = false;
    report.note = 'Parity verifies official live source extraction only; it does not authorize source activation, staging, promotion, or release. Indian Bank source remains disabled pending human review and governance sign-off.';
  }

  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report, null, 2));

  const passed = report.mismatches.length === 0;
  return { success: passed, report, exitCode: passed ? 0 : 1 };
}

if (require.main === module) {
  runVerification()
    .then(({ exitCode }) => {
      process.exit(exitCode);
    })
    .catch((err) => {
      console.error('Fatal verification error:', err);
      process.exit(1);
    });
}

module.exports = {
  fetchOfficial,
  fetchWithCurl,
  verifyContent,
  runVerification,
  allowed,
};
