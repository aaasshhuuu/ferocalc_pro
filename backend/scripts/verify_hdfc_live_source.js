// FeroCalc Verified FD Rate Engine — HDFC Official Live Source Parity Verifier
//
// Revalidates official HDFC callable domestic retail (< Rs. 3 Crore) FD rates against baseline.
// Official source: https://www.hdfc.bank.in/fixed-deposit/fd-interest-rate
// Effective from: 19 August 2026
// Slabs: 19 domestic retail tenure buckets across Regular and Senior Citizen (38 candidate records)
// Dual-domain architecture: Slabs 1-5 (DAYS), Slabs 6-19 (CALENDAR)
//
// Rules:
// 1. Strict live-source verification: fetches from official HDFC domain only.
// 2. An archived/cached snapshot CANNOT produce a live-source PASS.
// 3. Strict fail-closed on fetch failure, incomplete tables, wrong effective date,
//    missing/duplicate rows, or incorrect rates.
// 4. Offline mode (--offline) is distinct and produces OFFLINE_BASELINE_PASS only.
// 5. Does NOT approve source activation or promote candidates.

'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const baseline = require('../review/hdfc_official_baseline_2026-08-19.json');
const { HdfcRateParser } = require('../parsers/hdfc_parser');
const { normalizeLabelKey } = require('../parsers/hdfc_canonical_tenure');
const { fetchWithHardenedCurl } = require('./curl_transport');

const OUT = path.join(__dirname, '../review/live-evidence');
const MAX_BYTES = 5 * 1024 * 1024;
const MAX_REDIRECTS = 3;

function allowed(url) {
  const u = new URL(url);
  const host = u.hostname.toLowerCase();
  return u.protocol === 'https:' && (
    host === 'hdfc.bank.in' ||
    host.endsWith('.hdfc.bank.in') ||
    host === 'hdfcbank.com' ||
    host.endsWith('.hdfcbank.com')
  );
}

async function fetchOfficial(start) {
  let url = start;
  for (let i = 0; i <= MAX_REDIRECTS; i++) {
    if (!allowed(url)) throw new Error('Refusing non-HTTPS or non-HDFC redirect URL: ' + url);
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

function fetchWithCurl(url, overrides = {}) {
  return fetchWithHardenedCurl(url, {
    allowed,
    expectedType: /text\/html|application\/xhtml\+xml/i,
    maxBytes: MAX_BYTES,
    minBytes: 5000,
    maxRedirects: MAX_REDIRECTS,
    ...overrides,
  });
}

function norm(s) {
  return normalizeLabelKey(s);
}

/**
 * Reconciles parsed HDFC candidates and metadata against baseline specification.
 * Pure verification logic decoupled from transport/fetch.
 */
function verifyContent(parsed, baselineConfig, context = {}) {
  const mismatches = [];
  const rowDetails = [];

  if (!parsed.success) {
    mismatches.push('Parser failed closed: ' + (parsed.errors || []).join('; '));
  }

  // 1. Effective date check
  const effectiveDateMatched = parsed.effectiveFrom === baselineConfig.effectiveFrom;
  if (!effectiveDateMatched) {
    mismatches.push(
      `Effective date mismatch: expected ${baselineConfig.effectiveFrom}, got ${parsed.effectiveFrom || 'null'}`
    );
  }

  // 2. Candidate count check: 19 slabs * 2 customer types = 38
  const expectedCandidates = baselineConfig.tenures.length * 2;
  if (parsed.candidates.length !== expectedCandidates) {
    mismatches.push(
      `Candidate count mismatch: expected ${expectedCandidates}, got ${parsed.candidates.length}`
    );
  }

  // 3. Map candidates by normalized tenure and customer type
  const actual = new Map();
  for (const c of parsed.candidates) {
    const key = norm(c.tenureLabel);
    if (!actual.has(key)) actual.set(key, {});
    const existing = actual.get(key);
    if (existing[c.customerType] !== undefined) {
      mismatches.push(`Duplicate candidate for tenure "${c.tenureLabel}" / ${c.customerType}`);
    }
    existing[c.customerType] = c;
  }

  // 4. Reconcile each baseline slab row-by-row
  let matchedTenureRows = 0;
  let spreadsReconciled = true;
  let eligibilityNotesVerified = true;

  for (const e of baselineConfig.tenures) {
    const matchedSlab = actual.get(norm(e.label));
    if (!matchedSlab) {
      mismatches.push(`Missing tenure row: "${e.label}"`);
      rowDetails.push({
        slabNumber: e.slabNumber,
        label: e.label,
        expectedRegular: e.regular,
        actualRegular: null,
        expectedSenior: e.senior,
        actualSenior: null,
        status: 'MISSING',
      });
      continue;
    }

    matchedTenureRows++;
    const regCand = matchedSlab.REGULAR;
    const senCand = matchedSlab.SENIOR_CITIZEN;

    const actualReg = regCand ? regCand.interestRate : null;
    const actualSen = senCand ? senCand.interestRate : null;

    let slabStatus = 'MATCH';

    // Verify Regular Rate
    if (actualReg === null || Number(actualReg) !== e.regular) {
      mismatches.push(`${e.label} Regular rate mismatch: expected ${e.regular}%, got ${actualReg}%`);
      slabStatus = 'MISMATCH';
    }

    // Verify Senior Citizen Rate
    if (actualSen === null || Number(actualSen) !== e.senior) {
      mismatches.push(`${e.label} Senior rate mismatch: expected ${e.senior}%, got ${actualSen}%`);
      slabStatus = 'MISMATCH';
    }

    // Verify Senior Citizen Spread
    if (actualReg !== null && actualSen !== null) {
      const spreadBps = Math.round((actualSen - actualReg) * 100);
      if (spreadBps !== e.spreadBps) {
        mismatches.push(
          `${e.label} Senior spread mismatch: expected ${e.spreadBps} bps, got ${spreadBps} bps`
        );
        spreadsReconciled = false;
        slabStatus = 'MISMATCH';
      }
    }

    // Verify Minimum Deposit (5000.00)
    if (regCand && regCand.minDeposit !== '5000.00') {
      mismatches.push(`${e.label} Regular minDeposit mismatch: expected 5000.00, got ${regCand.minDeposit}`);
    }
    if (senCand && senCand.minDeposit !== '5000.00') {
      mismatches.push(`${e.label} Senior minDeposit mismatch: expected 5000.00, got ${senCand.minDeposit}`);
    }

    // Verify Maximum Deposit (29999999.00)
    if (regCand && regCand.maxDeposit !== '29999999.00') {
      mismatches.push(`${e.label} Regular maxDeposit mismatch: expected 29999999.00, got ${regCand.maxDeposit}`);
    }

    // Verify Tenure Domain
    if (regCand && regCand.tenureDomain !== e.tenureDomain) {
      mismatches.push(`${e.label} tenureDomain mismatch: expected ${e.tenureDomain}, got ${regCand.tenureDomain}`);
    }

    // Verify Senior Eligibility Notes (resident senior citizen restriction)
    if (senCand) {
      const notes = String(senCand.notes || '').toLowerCase();
      const hasResidentRestriction = notes.includes('resident') || notes.includes('nri');
      if (!hasResidentRestriction) {
        mismatches.push(`${e.label} Senior candidate missing resident eligibility restriction note`);
        eligibilityNotesVerified = false;
      }
    }

    rowDetails.push({
      slabNumber: e.slabNumber,
      label: e.label,
      expectedRegular: e.regular,
      actualRegular: actualReg,
      expectedSenior: e.senior,
      actualSenior: actualSen,
      expectedSpreadBps: e.spreadBps,
      actualSpreadBps: actualReg !== null && actualSen !== null ? Math.round((actualSen - actualReg) * 100) : null,
      tenureDomain: e.tenureDomain,
      status: slabStatus,
    });
  }

  const allTenuresReconciled = matchedTenureRows === baselineConfig.tenures.length && mismatches.length === 0;

  return {
    mismatches,
    effectiveDateMatched,
    allTenuresReconciled,
    spreadsReconciled,
    eligibilityNotesVerified,
    matchedTenureRows,
    totalBaselineRows: baselineConfig.tenures.length,
    comparedRateValues: matchedTenureRows * 2,
    rowDetails,
  };
}

/**
 * Main verification entrypoint for HDFC.
 *
 * Live mode (default): Strictly live network fetch.
 * An archived snapshot CANNOT produce a live-source PASS.
 * If live fetch fails, parityStatus is FAIL_CLOSED and process exits 1.
 *
 * Offline mode (--offline or options.offline): Explicitly flags fetchMethod as
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
    fetchedAt: new Date().toISOString(),
    isLiveRun: !isOffline,
    sourceFetchStatus: 'NOT_STARTED',
    fetchMethod: 'NONE',
    httpStatus: null,
    parserStatus: 'NOT_RUN',
    parityStatus: 'FAIL_CLOSED',
    mismatches: [],
    effectiveDateMatched: false,
    allTenuresReconciled: false,
    spreadsReconciled: false,
    eligibilityNotesVerified: false,
    activationApproved: false,
    totalPublishedSlabs: baseline.tenures.length,
    matchedTenureRows: 0,
    comparedRateValues: 0,
    rowDetails: [],
  };

  const reportPath = path.join(OUT, 'hdfc-live-parity-report.json');
  const snapshotPath = path.join(OUT, 'hdfc-live-page.html');

  let body = null;
  let finalUrl = baseline.sourceUrl;
  let httpStatus = null;
  let contentType = 'text/html';
  let fetchMethod = 'NONE';

  if (isOffline) {
    if (options.body) {
      body = Buffer.isBuffer(options.body) ? options.body : Buffer.from(options.body);
    } else {
      const targetPath = fixturePath || path.join(__dirname, '../data/snapshots/snapshot_hdfc-retail-domestic_3fa74d2cb4eb9215d904b5209a1f9681bf6b075a1cf37e1eb125bf7cc6f8949c.raw.bin');
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
    report.note = 'Live source fetch failed. Cached snapshots are strictly prohibited from generating a live-source PASS.';

    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
    return { success: false, report, exitCode: 1 };
  } else {
    // LIVE MODE: Strictly live network fetch
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
      report.sourceFetchStatus = 'FAILED';
      report.fetchMethod = 'NONE';
      report.httpStatus = null;
      report.parityStatus = 'FAIL_CLOSED';
      report.mismatches.push(`Live official source fetch failed on all methods: ${fetchErrors.join('; ')}`);
      report.note = 'Live source fetch failed. Cached snapshots are strictly prohibited from generating a live-source PASS.';

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

  const parser = new HdfcRateParser();
  const parsed = parser.parse(body, {
    sourceId: 'hdfc-retail-domestic',
    sourceUrl: finalUrl,
    sourceContentHash: hash,
    extractedAt: report.fetchedAt,
  });

  report.parserStatus = parsed.success ? 'SUCCESS' : 'FAILED';
  report.parserErrors = parsed.errors;
  report.extractedEffectiveFrom = parsed.effectiveFrom;
  report.rawTableCount = parsed.rawTableCount;
  report.candidateCount = parsed.candidates.length;

  const verification = verifyContent(parsed, baseline, { isOffline, hash });

  report.mismatches.push(...verification.mismatches);
  report.effectiveDateMatched = verification.effectiveDateMatched;
  report.allTenuresReconciled = verification.allTenuresReconciled;
  report.spreadsReconciled = verification.spreadsReconciled;
  report.eligibilityNotesVerified = verification.eligibilityNotesVerified;
  report.matchedTenureRows = verification.matchedTenureRows;
  report.comparedRateValues = verification.comparedRateValues;
  report.rowDetails = verification.rowDetails;

  if (isOffline) {
    report.parityStatus = report.mismatches.length === 0 ? 'OFFLINE_BASELINE_PASS' : 'FAIL_CLOSED';
    report.activationApproved = false;
  } else {
    report.parityStatus = report.mismatches.length === 0 ? 'PASS' : 'FAIL_CLOSED';
    report.activationApproved = false;
    report.note = 'Parity verifies official live source extraction only; it does not authorize staging, promotion, or release. Unresolved HDFC rows remain REVIEW_REQUIRED pending human review.';
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
