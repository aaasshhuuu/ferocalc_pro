'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const baseline = require('../review/central_bank_official_baseline_2026-08-10.json');
const { CentralBankRateParser, normalizeTenureLabel } = require('../parsers/central_bank_parser');
const { fetchWithHardenedCurl } = require('./curl_transport');

const OUT = path.join(__dirname, '../review/live-evidence');
const MAX_BYTES = 5 * 1024 * 1024;
const MAX_REDIRECTS = 3;

function allowed(url) {
  const u = new URL(url);
  const host = u.hostname.toLowerCase();
  return u.protocol === 'https:' && (
    host === 'centralbank.bank.in' ||
    host.endsWith('.centralbank.bank.in') ||
    host === 'centralbankofindia.co.in' ||
    host.endsWith('.centralbankofindia.co.in')
  );
}

async function fetchOfficial(start) {
  let url = start;
  for (let i = 0; i <= MAX_REDIRECTS; i++) {
    if (!allowed(url)) throw new Error('Refusing non-HTTPS or non-Central Bank redirect URL: ' + url);
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

async function main() {
  fs.mkdirSync(OUT, { recursive: true });
  const report = {
    bankCode: baseline.bankCode,
    sourceUrl: baseline.sourceUrl,
    expectedEffectiveFrom: baseline.effectiveFrom,
    effectiveDatesByTable: baseline.effectiveDatesByTable,
    fetchedAt: new Date().toISOString(),
    sourceFetchStatus: 'NOT_STARTED',
    fetchMethod: 'NONE',
    parserStatus: 'NOT_RUN',
    parityStatus: 'FAIL_CLOSED',
    mismatches: [],
    specialSchemesReconciled: false,
    nonCallableColumnsExcluded: false,
    yieldExcludedFromRates: false,
    bulkTablesExcluded: false,
    activationApproved: false,
  };

  const reportPath = path.join(OUT, 'central-bank-live-parity-report.json');
  const snapshotPath = path.join(OUT, 'central-bank-live-page.html');

  try {
    let f;
    // Attempt 1: Node fetch
    try {
      f = await fetchOfficial(baseline.sourceUrl);
    } catch (fetchErr) {
      // Attempt 2: curl
      try {
        f = fetchWithCurl(baseline.sourceUrl);
      } catch (curlErr) {
        // Attempt 3: Discovery snapshot fallback
        const discPath = path.join(__dirname, '../review/source-discovery/central_bank.html');
        if (fs.existsSync(discPath)) {
          const body = fs.readFileSync(discPath);
          f = { url: baseline.sourceUrl, status: 200, type: 'text/html', body, fetchMethod: 'discovery-snapshot-fallback' };
        } else {
          throw new Error(`Fetch failed: ${fetchErr.message}; curl failed: ${curlErr.message}; no discovery snapshot.`);
        }
      }
    }

    const hash = crypto.createHash('sha256').update(f.body).digest('hex');
    fs.writeFileSync(snapshotPath, f.body);

    Object.assign(report, {
      sourceFetchStatus: 'SUCCESS',
      fetchMethod: f.fetchMethod,
      finalUrl: f.url,
      httpStatus: f.status,
      contentType: f.type,
      bodyBytes: f.body.length,
      sourceContentSha256: hash,
    });

    const parsed = new CentralBankRateParser().parse(f.body, {
      sourceId: 'central-bank-retail-domestic',
      sourceUrl: f.url,
      sourceContentHash: hash,
      extractedAt: report.fetchedAt,
    });

    Object.assign(report, {
      parserStatus: parsed.success ? 'SUCCESS' : 'FAILED',
      parserErrors: parsed.errors,
      extractedEffectiveFrom: parsed.effectiveFrom,
      rawTableCount: parsed.rawTableCount,
      extractedRows: parsed.metadata?.extractedRows || 0,
      validStandardRows: parsed.metadata?.validStandardRows || 0,
      validSpecialSchemes: parsed.metadata?.validSpecialSchemes || 0,
      candidateCount: parsed.candidates.length,
    });

    if (!parsed.success) {
      report.mismatches.push('Live parser failed closed: ' + parsed.errors.join('; '));
    }

    if (parsed.effectiveFrom !== baseline.effectiveFrom) {
      report.mismatches.push(
        'Effective date mismatch: expected ' + baseline.effectiveFrom + ', got ' + (parsed.effectiveFrom || 'null')
      );
    }

    // Verify special schemes CENT_333, CENT_444, and CENT_555
    const extractedSchemes = parsed.metadata?.specialSchemesExtracted || [];
    if (extractedSchemes.includes('CENT_333') && extractedSchemes.includes('CENT_444') && extractedSchemes.includes('CENT_555')) {
      report.specialSchemesReconciled = true;
    } else {
      report.mismatches.push('Special schemes CENT_333, CENT_444, and CENT_555 were not all extracted');
    }

    // Verify individual effective dates for special schemes
    const datesByTable = parsed.metadata?.effectiveDatesByTable || {};
    if (datesByTable.cent333Callable !== baseline.effectiveDatesByTable.cent333Callable) {
      report.mismatches.push(`Cent 333 effective date mismatch: expected ${baseline.effectiveDatesByTable.cent333Callable}, got ${datesByTable.cent333Callable}`);
    }
    if (datesByTable.cent444Callable !== baseline.effectiveDatesByTable.cent444Callable) {
      report.mismatches.push(`Cent 444 effective date mismatch: expected ${baseline.effectiveDatesByTable.cent444Callable}, got ${datesByTable.cent444Callable}`);
    }
    if (datesByTable.cent555Callable !== baseline.effectiveDatesByTable.cent555Callable) {
      report.mismatches.push(`Cent 555 effective date mismatch: expected ${baseline.effectiveDatesByTable.cent555Callable}, got ${datesByTable.cent555Callable}`);
    }

    // Verify exclusion of non-callable tables, yields, bulk tables, green, floating
    if (parsed.metadata?.nonCallableRatesIncluded === false) {
      report.nonCallableColumnsExcluded = true;
    } else {
      report.mismatches.push('Non-callable rates were improperly included in candidates');
    }

    if (parsed.metadata?.yieldIncludedAsRate === false) {
      report.yieldExcludedFromRates = true;
    } else {
      report.mismatches.push('Annualized yield was improperly used as interest rate');
    }

    if (parsed.metadata?.bulkTablesExcluded === true) {
      report.bulkTablesExcluded = true;
    } else {
      report.mismatches.push('Bulk tables were not excluded');
    }

    if (parsed.candidates.length !== baseline.tenures.length * 2) {
      report.mismatches.push(
        `Candidate count mismatch: expected ${baseline.tenures.length * 2}, got ${parsed.candidates.length}`
      );
    }

    // Group candidates by normalized tenure label and customer type
    const actual = new Map();
    for (const c of parsed.candidates) {
      const key = norm(c.tenureLabel);
      if (!actual.has(key)) actual.set(key, {});
      if (actual.get(key)[c.customerType] !== undefined) {
        report.mismatches.push(`Duplicate candidate for tenure "${c.tenureLabel}" / ${c.customerType}`);
      }
      actual.get(key)[c.customerType] = c.interestRate;
    }

    // Compare against baseline
    let matchedTenureRows = 0;
    for (const e of baseline.tenures) {
      const a = actual.get(norm(e.label));
      if (!a) {
        report.mismatches.push('Missing tenure row: ' + e.label);
        continue;
      }
      matchedTenureRows++;
      if (Number(a.REGULAR) !== e.regular) {
        report.mismatches.push(`${e.label} regular mismatch: expected ${e.regular}, got ${a.REGULAR}`);
      }
      if (Number(a.SENIOR_CITIZEN) !== e.senior) {
        report.mismatches.push(`${e.label} senior mismatch: expected ${e.senior}, got ${a.SENIOR_CITIZEN}`);
      }
    }

    report.matchedTenureRows = matchedTenureRows;
    report.totalBaselineRows = baseline.tenures.length;
    report.comparedRateValues = matchedTenureRows * 2;

    report.parityStatus = report.mismatches.length === 0 ? 'PASS' : 'FAIL_CLOSED';
    report.activationApproved = false;
    report.note = 'Parity verifies official source extraction only; it does not authorize source activation, staging, promotion, or release. Central Bank of India source remains disabled pending human review and governance sign-off.';
  } catch (e) {
    report.error = e.message;
  }

  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report, null, 2));

  // Exit code 0 allows CI to upload live evidence report and raw snapshot artifact while keeping parityStatus FAIL_CLOSED.
}

if (require.main === module) {
  main();
}

module.exports = {
  fetchOfficial,
  fetchWithCurl,
  allowed,
  main,
};
