// FeroCalc Verified FD Rate Engine — Robust HTTP Fetcher
//
// Features:
// - Timeout control
// - Bounded exponential backoff with max retries
// - Follows safe HTTP redirects (up to maxRedirects)
// - Response size protection (caps memory buffering)
// - Validates HTTP 200..299 status
// - User-Agent identification
// - No external libraries required (pure Node http/https)

'use strict';

const http  = require('http');
const https = require('https');
const { URL } = require('url');

const DEFAULT_USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 FeroCalcRateMonitor/1.0';
const DEFAULT_TIMEOUT_MS = 15000;
const DEFAULT_MAX_RETRIES = 2;
const DEFAULT_MAX_BYTES = 5 * 1024 * 1024; // 5 MB max response limit
const DEFAULT_MAX_REDIRECTS = 3;

class FetchError extends Error {
  constructor(message, code, statusCode = null) {
    super(message);
    this.name = 'FetchError';
    this.code = code;
    this.statusCode = statusCode;
  }
}

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Performs a single raw HTTP/HTTPS request.
 */
function singleRequest(targetUrl, options) {
  return new Promise((resolve, reject) => {
    let parsed;
    try {
      parsed = new URL(targetUrl);
    } catch (e) {
      return reject(new FetchError(`Invalid URL: ${targetUrl}`, 'INVALID_URL'));
    }

    const transport = parsed.protocol === 'https:' ? https : http;
    const reqOptions = {
      protocol: parsed.protocol,
      hostname: parsed.hostname,
      port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
      path: parsed.pathname + parsed.search,
      method: 'GET',
      headers: {
        'User-Agent': options.userAgent || DEFAULT_USER_AGENT,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,application/pdf;q=0.8,*/*;q=0.7',
        'Accept-Language': 'en-US,en;q=0.9',
        'Cache-Control': 'no-cache',
      },
      timeout: options.timeoutMs || DEFAULT_TIMEOUT_MS,
    };

    const req = transport.request(reqOptions, (res) => {
      const statusCode = res.statusCode;
      const contentType = res.headers['content-type'] || '';

      // Handle Redirects
      if ([301, 302, 303, 307, 308].includes(statusCode) && res.headers.location) {
        res.resume(); // Discard redirect body
        const redirectUrl = new URL(res.headers.location, targetUrl).href;
        return resolve({ isRedirect: true, redirectUrl, statusCode });
      }

      // Check Status Code
      if (statusCode < 200 || statusCode >= 300) {
        res.resume();
        return reject(new FetchError(
          `HTTP Error ${statusCode} for ${targetUrl}`,
          'HTTP_STATUS_ERROR',
          statusCode
        ));
      }

      const chunks = [];
      let totalBytes = 0;
      const maxBytes = options.maxBytes || DEFAULT_MAX_BYTES;

      res.on('data', (chunk) => {
        totalBytes += chunk.length;
        if (totalBytes > maxBytes) {
          req.destroy(new FetchError(`Response size exceeded ${maxBytes} bytes limit`, 'MAX_SIZE_EXCEEDED'));
          return;
        }
        chunks.push(chunk);
      });

      res.on('end', () => {
        const bodyBuffer = Buffer.concat(chunks);
        resolve({
          isRedirect: false,
          statusCode,
          contentType,
          headers: res.headers,
          bodyBuffer,
          byteLength: bodyBuffer.length,
        });
      });
    });

    req.on('timeout', () => {
      req.destroy(new FetchError(`Request timed out after ${reqOptions.timeout}ms`, 'TIMEOUT'));
    });

    req.on('error', (err) => {
      reject(new FetchError(err.message, err.code || 'NETWORK_ERROR'));
    });

    req.end();
  });
}

/**
 * Fetch a URL with automatic redirects and bounded exponential backoff retries.
 */
async function fetchWithRetry(url, options = {}) {
  const maxRetries = Number.isInteger(options.maxRetries) ? options.maxRetries : DEFAULT_MAX_RETRIES;
  const maxRedirects = options.maxRedirects || DEFAULT_MAX_REDIRECTS;
  let attempt = 0;
  let currentUrl = url;
  let redirectsCount = 0;

  while (attempt <= maxRetries) {
    try {
      const result = await singleRequest(currentUrl, options);

      if (result.isRedirect) {
        redirectsCount++;
        if (redirectsCount > maxRedirects) {
          throw new FetchError(`Exceeded maximum redirect limit of ${maxRedirects}`, 'TOO_MANY_REDIRECTS');
        }
        currentUrl = result.redirectUrl;
        continue; // Immediately follow redirect without counting as a failed attempt
      }

      return {
        url: currentUrl,
        statusCode: result.statusCode,
        contentType: result.contentType,
        headers: result.headers,
        bodyBuffer: result.bodyBuffer,
        byteLength: result.byteLength,
        attemptsMade: attempt + 1,
      };

    } catch (err) {
      attempt++;
      // Do not retry on non-transient errors like 404, 403, 401, or invalid URL
      const isClientError = err.statusCode && err.statusCode >= 400 && err.statusCode < 500;
      const isUnrecoverable = ['INVALID_URL', 'MAX_SIZE_EXCEEDED', 'TOO_MANY_REDIRECTS'].includes(err.code);

      if (attempt > maxRetries || isClientError || isUnrecoverable) {
        throw err;
      }

      // Exponential backoff: 300ms, 600ms, 1200ms...
      const backoffMs = Math.min(300 * Math.pow(2, attempt - 1), 3000);
      await delay(backoffMs);
    }
  }
}

module.exports = {
  fetchWithRetry,
  FetchError,
};
