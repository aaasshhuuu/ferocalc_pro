'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');

const DEFAULT_MAX_REDIRECTS = 3;
const DEFAULT_MAX_BYTES = 5 * 1024 * 1024;
const DEFAULT_MIN_BYTES = 1000;
const DEFAULT_TIMEOUT_MS = 30000;

const DEFAULT_WAF_PATTERNS = [
  /<title>Just a moment\.\.\.<\/title>/i,
  /Attention Required!\s*\|\s*Cloudflare/i,
  /Cloudflare Ray ID:/i,
  /Request Rejected/i,
  /The requested URL was rejected/i,
  /Access Denied/i,
  /Security Check\s*\|\s*Cloudflare/i,
  /Checking your browser before accessing/i,
];

/**
 * Resolves the appropriate curl binary for the host platform.
 *
 * @returns {string}
 */
function getCurlBinary() {
  return process.platform === 'win32' ? 'curl.exe' : 'curl';
}

/**
 * Parses raw HTTP header dump from curl into a normalized dictionary and status code.
 *
 * @param {string} raw - Raw header text
 * @returns {{ status: number|null, statusLine: string|null, headers: Object.<string, string> }}
 */
function parseHttpHeaders(raw) {
  const headers = {};
  let status = null;
  let statusLine = null;

  if (!raw || typeof raw !== 'string') {
    return { status, statusLine, headers };
  }

  const lines = raw.split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;

    // HTTP status line: e.g. HTTP/1.1 200 OK, HTTP/2 302
    const statusMatch = trimmed.match(/^HTTP\/(?:1\.[01]|2|3)\s+(\d{3})(?:\s+(.*))?$/i);
    if (statusMatch) {
      status = Number(statusMatch[1]);
      statusLine = trimmed;
      continue;
    }

    const colonIdx = trimmed.indexOf(':');
    if (colonIdx > 0) {
      const key = trimmed.slice(0, colonIdx).trim().toLowerCase();
      const val = trimmed.slice(colonIdx + 1).trim();
      headers[key] = val;
    }
  }

  return { status, statusLine, headers };
}

/**
 * Executes a single-hop curl call without following redirects (-L is strictly prohibited).
 * Uses argument-based process invocation (execFileSync) to eliminate shell injection.
 *
 * @param {string} url - Target URL to fetch
 * @param {object} [options]
 * @param {number} [options.maxBytes]
 * @param {number} [options.timeoutMs]
 * @param {object} [options.headers]
 * @param {function} [options.execFileFn]
 * @returns {{ status: number, contentType: string, urlEffective: string, headers: Object.<string, string>, body: Buffer }}
 */
function executeSingleHopCurl(url, options = {}) {
  const maxBytes = options.maxBytes || DEFAULT_MAX_BYTES;
  const timeoutMs = options.timeoutMs || DEFAULT_TIMEOUT_MS;
  const execFn = options.execFileFn || execFileSync;
  const curlBin = getCurlBinary();

  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ferocalc-curl-'));
  const headerFile = path.join(tmpDir, 'headers.txt');
  const bodyFile = path.join(tmpDir, 'body.bin');

  try {
    const args = [
      '-s',
      '-S',
      '--max-filesize', String(maxBytes + 65536),
      '-D', headerFile,
      '-o', bodyFile,
      '-w', '%{http_code}\n%{content_type}\n%{url_effective}',
    ];

    const customHeaders = Object.assign({
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-IN,en;q=0.9',
    }, options.headers || {});

    for (const [key, val] of Object.entries(customHeaders)) {
      args.push('-H', `${key}: ${val}`);
    }

    args.push(url);

    let stdoutBuf;
    try {
      stdoutBuf = execFn(curlBin, args, {
        timeout: timeoutMs,
        maxBuffer: 1024 * 1024,
      });
    } catch (procErr) {
      throw new Error(`Curl execution failed: ${procErr.message}`);
    }

    const stdoutStr = (stdoutBuf || '').toString('utf-8');
    const writeoutLines = stdoutStr.trim().split('\n').map(s => s.trim());
    const writeoutStatus = Number(writeoutLines[0]) || null;
    const writeoutContentType = writeoutLines[1] || '';
    const writeoutEffectiveUrl = writeoutLines[2] || url;

    let parsedHeaders = { status: null, headers: {} };
    if (fs.existsSync(headerFile)) {
      const rawHeaderStr = fs.readFileSync(headerFile, 'utf-8');
      parsedHeaders = parseHttpHeaders(rawHeaderStr);
    }

    const finalStatus = writeoutStatus || parsedHeaders.status;
    if (!finalStatus) {
      throw new Error('Curl did not return a valid HTTP status code');
    }

    const body = fs.existsSync(bodyFile) ? fs.readFileSync(bodyFile) : Buffer.alloc(0);
    const contentType = parsedHeaders.headers['content-type'] || writeoutContentType;

    return {
      status: finalStatus,
      contentType,
      urlEffective: writeoutEffectiveUrl,
      headers: parsedHeaders.headers,
      body,
    };
  } finally {
    try {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    } catch (_) {}
  }
}

/**
 * Hardened multi-hop curl fetcher.
 * Guarantees:
 * 1. Strict HTTPS protocol enforcement on every hop (no HTTP, no protocol downgrade).
 * 2. Per-hop domain allowlist validation via caller-provided allowed(url).
 * 3. Manual redirect handling with strict limit (<= 3 hops). Curl -L is NEVER used.
 * 4. Captures and returns genuine HTTP status, genuine Content-Type, and effective URL.
 * 5. Rejects non-2xx responses (404, 500, etc.) with fail-closed error.
 * 6. Validates expected Content-Type against RegExp or substring.
 * 7. Enforces body size restrictions (maxBytes and minBytes).
 * 8. Detects WAF / bot-challenge block pages fail-closed.
 * 9. Uses argument-based process invocation (execFileSync) with array arguments.
 *
 * @param {string} startUrl
 * @param {object} options
 * @param {function} options.allowed - Validation function: (url: string) => boolean
 * @param {RegExp|string} [options.expectedType] - Expected Content-Type pattern
 * @param {number} [options.maxBytes] - Maximum allowed response body size
 * @param {number} [options.minBytes] - Minimum expected body size (checks for truncated/empty)
 * @param {number} [options.maxRedirects] - Maximum allowed redirect hops (default 3)
 * @param {number} [options.timeoutMs] - Request timeout in ms (default 30000)
 * @param {object} [options.headers] - Custom request headers
 * @param {Array<string|RegExp>} [options.wafPatterns] - WAF / bot-challenge detection patterns
 * @param {function} [options.execFileFn] - Injectable process executor for testing
 * @param {function} [options.singleHopFn] - Injectable single hop executor for testing
 * @returns {{ url: string, status: number, type: string, body: Buffer, fetchMethod: string, hopCount: number }}
 */
function fetchWithHardenedCurl(startUrl, options = {}) {
  const allowed = options.allowed;
  if (typeof allowed !== 'function') {
    throw new Error('fetchWithHardenedCurl requires an "allowed(url)" validation function');
  }

  const maxRedirects = options.maxRedirects !== undefined ? options.maxRedirects : DEFAULT_MAX_REDIRECTS;
  const maxBytes = options.maxBytes || DEFAULT_MAX_BYTES;
  const minBytes = options.minBytes !== undefined ? options.minBytes : DEFAULT_MIN_BYTES;
  const expectedType = options.expectedType || /text\/html|application\/xhtml\+xml/i;
  const wafPatterns = options.wafPatterns || DEFAULT_WAF_PATTERNS;

  let currentUrl = startUrl;

  for (let hop = 0; hop <= maxRedirects; hop++) {
    // A. URL parsing and protocol verification (strictly HTTPS)
    let parsedUrl;
    try {
      parsedUrl = new URL(currentUrl);
    } catch (e) {
      throw new Error(`Invalid URL: ${currentUrl}`);
    }

    if (parsedUrl.protocol !== 'https:') {
      throw new Error(`Refusing non-HTTPS URL (downgrade or insecure scheme): ${currentUrl}`);
    }

    // B. Per-hop domain allowlist validation
    if (!allowed(currentUrl)) {
      throw new Error(`Refusing off-domain or unallowed redirect URL: ${currentUrl}`);
    }

    // C. Execute single hop (via options.singleHopFn if mocked, otherwise executeSingleHopCurl)
    const hopResult = typeof options.singleHopFn === 'function'
      ? options.singleHopFn(currentUrl, hop)
      : executeSingleHopCurl(currentUrl, options);

    const statusCode = hopResult.status;

    // D. Manual redirect handling (301, 302, 303, 307, 308)
    if ([301, 302, 303, 307, 308].includes(statusCode)) {
      if (hop === maxRedirects) {
        throw new Error(`Redirect limit exceeded (${maxRedirects} max)`);
      }

      const loc = hopResult.headers ? hopResult.headers['location'] : null;
      if (!loc) {
        throw new Error(`Redirect HTTP ${statusCode} missing Location header`);
      }

      // Resolve relative or absolute redirect
      try {
        currentUrl = new URL(loc, currentUrl).href;
      } catch (e) {
        throw new Error(`Invalid redirect Location header: "${loc}"`);
      }

      continue;
    }

    // E. Status validation: must be 2xx
    if (statusCode < 200 || statusCode >= 300) {
      throw new Error(`Official source HTTP status ${statusCode}`);
    }

    // F. Content-type validation
    const actualType = hopResult.contentType || (hopResult.headers && hopResult.headers['content-type']) || '';
    if (expectedType) {
      const typeMatches = expectedType instanceof RegExp
        ? expectedType.test(actualType)
        : actualType.toLowerCase().includes(String(expectedType).toLowerCase());
      if (!typeMatches) {
        throw new Error(`Unexpected content type: "${actualType}" (expected matching ${expectedType})`);
      }
    }

    // G. Body size validation
    const body = hopResult.body || Buffer.alloc(0);
    if (body.length > maxBytes) {
      throw new Error(`Curl response exceeds ${maxBytes} bytes limit (received ${body.length} bytes)`);
    }

    if (minBytes > 0 && body.length < minBytes) {
      throw new Error(`Curl response suspiciously small (${body.length} bytes, expected at least ${minBytes} bytes)`);
    }

    // H. WAF challenge / bot block validation
    const checkSample = body.slice(0, 10000).toString('utf-8');
    for (const pat of wafPatterns) {
      const isWaf = pat instanceof RegExp ? pat.test(checkSample) : checkSample.includes(pat);
      if (isWaf) {
        throw new Error(`WAF challenge or bot block detected in response: ${pat}`);
      }
    }

    // I. Return verified result
    return {
      url: currentUrl,
      status: statusCode,
      type: actualType,
      body: body,
      fetchMethod: 'curl',
      hopCount: hop,
    };
  }

  throw new Error(`Redirect limit exceeded (${maxRedirects} max)`);
}

module.exports = {
  getCurlBinary,
  parseHttpHeaders,
  executeSingleHopCurl,
  fetchWithHardenedCurl,
  DEFAULT_MAX_REDIRECTS,
  DEFAULT_MAX_BYTES,
  DEFAULT_MIN_BYTES,
  DEFAULT_TIMEOUT_MS,
  DEFAULT_WAF_PATTERNS,
};
