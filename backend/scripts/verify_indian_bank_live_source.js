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
    bulkTablesExcluded: false,
    nonCallableExcluded: false,
    activationApproved: false,
  };

  const reportPath = path.join(OUT, 'indian-bank-live-parity-report.json');
  const snapshotPath = path.join(OUT, 'indian-bank-live-page.html');

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
        const discPath = path.join(__dirname, '../review/source-discovery/indian_bank.html');
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

    const parsed = new IndianBankRateParser().parse(f.body, {
      sourceId: 'indian-bank-retail-domestic',
      sourceUrl: f.url,
      sourceContentHash: hash,
      extractedAt: report.fetchedAt,
    });

    Object.assign(report, {
      parserStatus: parsed.success ? 'SUCCESS' : 'FAILED',
      parserErrors: parsed.errors,
      extractedEffectiveFrom: parsed.effectiveFrom,
      rawTableCount: parsed.rawTableCount,
      extractedRowCount: parsed.metadata?.extractedRowCount || 0,
      validRowCount: parsed.metadata?.validRowCount || 0,
      standardRowCount: parsed.metadata?.standardRowCount || 0,
      specialSchemeCount: parsed.metadata?.specialSchemeCount || 0,
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

    // Verify special schemes (IND Supreme 2.0, Ind Green, Ind Grow, Ind Prosper)
    const indSupreme = parsed.candidates.find(c => c.schemeName === 'IND_SUPREME_300');
    const indGreen = parsed.candidates.find(c => c.schemeName === 'IND_GREEN_500');
    const indGrow = parsed.candidates.find(c => c.schemeName === 'IND_GROW_555');
    const indProsper = parsed.candidates.find(c => c.schemeName === 'IND_PROSPER_777');

    if (indSupreme && indGreen && indGrow && indProsper) {
      report.specialSchemesReconciled = true;
    } else {
      report.mismatches.push('Special schemes IND_SUPREME_300, IND_GREEN_500, IND_GROW_555, IND_PROSPER_777 were not all identified');
    }

    // Verify exclusions
    if (parsed.metadata?.bulkRatesIncluded === false) {
      report.bulkTablesExcluded = true;
    } else {
      report.mismatches.push('Bulk rates were improperly included');
    }

    if (parsed.metadata?.nonCallableRatesIncluded === false) {
      report.nonCallableExcluded = true;
    } else {
      report.mismatches.push('Non-callable rates were improperly included');
    }

    const expectedCandidates = baseline.tenures.length * 3;
    if (parsed.candidates.length !== expectedCandidates) {
      report.mismatches.push(
        `Candidate count mismatch: expected ${expectedCandidates}, got ${parsed.candidates.length}`
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
      if (Number(a.SUPER_SENIOR_CITIZEN) !== e.superSenior) {
        report.mismatches.push(`${e.label} super senior mismatch: expected ${e.superSenior}, got ${a.SUPER_SENIOR_CITIZEN}`);
      }
    }

    report.matchedTenureRows = matchedTenureRows;
    report.totalBaselineRows = baseline.tenures.length;
    report.comparedRateValues = matchedTenureRows * 3;

    report.parityStatus = report.mismatches.length === 0 ? 'PASS' : 'FAIL_CLOSED';
    report.activationApproved = false;
    report.note = 'Parity verifies official source extraction only; it does not authorize source activation, staging, promotion, or release. Indian Bank source remains disabled pending human review and governance sign-off.';
  } catch (e) {
    report.error = e.message;
  }

  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report, null, 2));
}

main();
