// Batch discovery of official bank FD pages; no staging, database writes, or promotion.
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { parseHtmlTables, cleanCellText } = require('../parsers/html_table_parser');

const SOURCES = [
  {
    "code": "IDFC_FIRST",
    "url": "https://www.idfcfirst.bank.in/personal-banking/deposits/fixed-deposit/fd-interest-rates",
    "domains": [
      "idfcfirst.bank.in"
    ]
  },
  {
    "code": "AU_SMALL_FINANCE",
    "url": "https://www.au.bank.in/interest-rates/fixed-deposit-interest-rates",
    "domains": [
      "au.bank.in"
    ]
  },
  {
    "code": "PNB",
    "url": "https://www.pnb.bank.in/Interest-Rates-Deposit.html",
    "domains": [
      "pnb.bank.in"
    ]
  },
  {
    "code": "UNION_BANK",
    "url": "https://www.unionbankofindia.bank.in/en/details/rate-of-interest",
    "domains": [
      "unionbankofindia.bank.in"
    ]
  },
  {
    "code": "KOTAK",
    "url": "https://m.kotak.com/td-rates/",
    "domains": [
      "kotak.com"
    ]
  },
  {
    "code": "INDUSIND",
    "url": "https://www.indusind.bank.in/in/en/personal/fixed-deposit-interest-rate.html",
    "domains": [
      "indusind.bank.in"
    ]
  },
  {
    "code": "UCO",
    "url": "https://uco.bank.in/web/guest/interest-rates-on-deposit-schemes",
    "domains": [
      "uco.bank.in"
    ]
  }
];
const OUT_DIR = path.join(__dirname, '../review/source-discovery');
const MAX_BYTES = 6 * 1024 * 1024;
const MAX_REDIRECTS = 4;
const TIMEOUT_MS = 25000;
const CONCURRENCY = 3;

function isAllowedUrl(value, allowedDomains) {
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:') return false;
    const host = url.hostname.toLowerCase();
    return allowedDomains.some(domain => host === domain || host.endsWith('.' + domain));
  } catch {
    return false;
  }
}

async function fetchOfficialSource(source) {
  let currentUrl = source.url;
  for (let redirectCount = 0; redirectCount <= MAX_REDIRECTS; redirectCount++) {
    if (!isAllowedUrl(currentUrl, source.domains)) {
      throw new Error('Refused redirect outside approved official HTTPS domain allowlist: ' + currentUrl);
    }
    const response = await fetch(currentUrl, {
      redirect: 'manual',
      headers: {
        'User-Agent': 'FeroCalcOfficialRateSourceDiscovery/1.0',
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'en-IN,en;q=0.9',
        'Cache-Control': 'no-cache'
      },
      signal: AbortSignal.timeout(TIMEOUT_MS)
    });
    if ([301, 302, 303, 307, 308].includes(response.status)) {
      const location = response.headers.get('location');
      if (!location || redirectCount === MAX_REDIRECTS) {
        throw new Error('Redirect limit reached or redirect location missing');
      }
      currentUrl = new URL(location, currentUrl).href;
      continue;
    }
    if (!response.ok) throw new Error('HTTP ' + response.status);
    const contentType = response.headers.get('content-type') || '';
    if (!/text\/html|application\/xhtml\+xml/i.test(contentType)) {
      throw new Error('Unexpected content type: ' + contentType);
    }
    const length = Number(response.headers.get('content-length') || 0);
    if (length > MAX_BYTES) throw new Error('Response exceeds 6 MB cap');
    const body = Buffer.from(await response.arrayBuffer());
    if (body.length > MAX_BYTES) throw new Error('Response body exceeds 6 MB cap');
    return { finalUrl: currentUrl, status: response.status, contentType, body };
  }
  throw new Error('Redirect limit exceeded');
}

function summarizeTables(html) {
  return parseHtmlTables(html).map((rows, tableIndex) => ({
    tableIndex,
    rowCount: rows.length,
    maxColumns: rows.reduce((max, row) => Math.max(max, row.length), 0),
    rows: rows.slice(0, 100).map((row, rowIndex) => ({
      rowIndex,
      cells: row.map(cell => String(cell).slice(0, 220))
    }))
  }));
}

function findDateMarkers(html) {
  const text = cleanCellText(html).replace(/(\d{1,2})\s+(st|nd|rd|th)\b/gi, '$1$2');
  const pattern = /(?:w\.?e\.?f\.?|effective\s+from|revised\s+(?:w\.?e\.?f\.?\s*)?from|applicable\s+(?:interest\s+)?rates?\s+(?:on\s+)?fixed\s+deposits?\s+w\.?e\.?f\.?)[^.!?]{0,100}/ig;
  const hits = [];
  for (const match of text.matchAll(pattern)) {
    hits.push(match[0].replace(/\s+/g, ' ').trim());
    if (hits.length >= 30) break;
  }
  return [...new Set(hits)];
}

async function processSource(source) {
  const slug = source.code.toLowerCase().replace(/[^a-z0-9]+/g, '-');
  const item = {
    bankCode: source.code,
    requestedUrl: source.url,
    fetchStatus: 'NOT_STARTED',
    observedAt: new Date().toISOString()
  };
  try {
    const result = await fetchOfficialSource(source);
    const html = result.body.toString('utf8');
    const sha256 = crypto.createHash('sha256').update(result.body).digest('hex');
    fs.writeFileSync(path.join(OUT_DIR, slug + '.html'), result.body);
    Object.assign(item, {
      fetchStatus: 'SUCCESS',
      finalUrl: result.finalUrl,
      httpStatus: result.status,
      contentType: result.contentType,
      bodyBytes: result.body.length,
      sourceContentSha256: sha256,
      title: ((html.match(/<title[^>]*>([\s\S]*?)<\/title>/i) || [])[1] || '').replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 240),
      dateMarkers: findDateMarkers(html),
      tables: summarizeTables(html)
    });
  } catch (error) {
    item.fetchStatus = 'FAILED';
    item.error = error.message;
  }
  console.log(JSON.stringify({
    bankCode: item.bankCode,
    fetchStatus: item.fetchStatus,
    httpStatus: item.httpStatus || null,
    bodyBytes: item.bodyBytes || null,
    tableCount: item.tables?.length ?? null,
    sourceContentSha256: item.sourceContentSha256 || null,
    error: item.error || null
  }));
  return item;
}

async function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const results = new Array(SOURCES.length);
  let next = 0;
  async function worker() {
    while (true) {
      const idx = next++;
      if (idx >= SOURCES.length) return;
      results[idx] = await processSource(SOURCES[idx]);
    }
  }
  await Promise.all(Array.from({ length: Math.min(CONCURRENCY, SOURCES.length) }, worker));
  const report = {
    observedAt: new Date().toISOString(),
    purpose: 'Official public page discovery only; does not prove parsed-rate correctness or authorize source activation.',
    successfulFetches: results.filter(x => x.fetchStatus === 'SUCCESS').length,
    failedFetches: results.filter(x => x.fetchStatus !== 'SUCCESS').length,
    results
  };
  fs.writeFileSync(path.join(OUT_DIR, 'source-discovery-inventory.json'), JSON.stringify(report, null, 2) + '\n');
  console.log('SOURCE_DISCOVERY_SUMMARY ' + JSON.stringify({
    successfulFetches: report.successfulFetches,
    failedFetches: report.failedFetches,
    banks: results.map(x => ({ bankCode: x.bankCode, fetchStatus: x.fetchStatus, tableCount: x.tables?.length || 0 }))
  }));
  if (report.successfulFetches === 0) process.exitCode = 1;
}
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
