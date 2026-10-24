// FeroCalc Verified FD Rate Engine — Base Collector
//
// Core abstraction for fetching, normalizing, hashing, and detecting changes.
// Bank-specific adapters extend this class or override normalize() as needed.
//
// States:
// - FIRST_SEEN: First time hash has been computed for this source.
// - UNCHANGED: Hash matches previous hash exactly.
// - CHANGED: Hash differs from previous hash (requires review/extraction).
// - FETCH_FAILED: Network, HTTP status, or timeout error occurred.

'use strict';

const crypto = require('crypto');
const { fetchWithRetry } = require('./http_fetcher');

class BaseCollector {
  /**
   * @param {Object} sourceConfig
   */
  constructor(sourceConfig) {
    if (!sourceConfig || !sourceConfig.id || !sourceConfig.sourceUrl) {
      throw new Error('BaseCollector requires sourceConfig with id and sourceUrl');
    }
    this.config = Object.freeze({ ...sourceConfig });
  }

  get id() {
    return this.config.id;
  }

  get bankCode() {
    return this.config.bankCode;
  }

  get sourceUrl() {
    return this.config.sourceUrl;
  }

  get sourceType() {
    return this.config.sourceType || 'HTML';
  }

  get parserVersion() {
    return this.config.parserVersion || '1.0.0';
  }

  /**
   * Normalize source content before hashing.
   * Strips dynamic transient artifacts (timestamps, csrf tokens, session cookies)
   * while preserving table data and text markup.
   *
   * @param {Buffer} buffer
   * @returns {Buffer}
   */
  normalize(buffer) {
    if (this.sourceType === 'HTML') {
      let str = buffer.toString('utf8');
      // Normalize whitespace and carriage returns
      str = str.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
      // Strip script and style blocks which often contain timestamps/analytics
      str = str.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
      str = str.replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '');
      return Buffer.from(str.trim(), 'utf8');
    }
    return buffer;
  }

  /**
   * Compute deterministic SHA-256 hash over normalized buffer.
   *
   * @param {Buffer} buffer
   * @returns {string} hex hash
   */
  calculateSha256(buffer) {
    const normalized = this.normalize(buffer);
    return crypto.createHash('sha256').update(normalized).digest('hex');
  }

  /**
   * Determine collection status given previous hash and current hash.
   *
   * @param {string|null} previousHash
   * @param {string} currentHash
   * @returns {'FIRST_SEEN'|'UNCHANGED'|'CHANGED'}
   */
  detectChange(previousHash, currentHash) {
    if (!previousHash) {
      return 'FIRST_SEEN';
    }
    if (previousHash.toLowerCase() === currentHash.toLowerCase()) {
      return 'UNCHANGED';
    }
    return 'CHANGED';
  }

  /**
   * Execute collection for this source.
   *
   * @param {Object} options
   * @param {string|null} [options.previousHash]
   * @param {Object} [options.fetcher] custom fetcher override (e.g. for mock testing)
   * @returns {Promise<CollectionResult>}
   */
  async collect(options = {}) {
    const startTime = Date.now();
    const previousHash = options.previousHash || null;
    const fetchFunc = options.fetchFunc || fetchWithRetry;

    try {
      const fetchResponse = await fetchFunc(this.sourceUrl, {
        timeoutMs: options.timeoutMs,
        maxRetries: options.maxRetries,
        maxBytes: options.maxBytes,
      });

      const fetchDurationMs = Date.now() - startTime;
      const normalizedBuffer = this.normalize(fetchResponse.bodyBuffer);
      const contentHash = crypto.createHash('sha256').update(normalizedBuffer).digest('hex');
      const status = this.detectChange(previousHash, contentHash);
      const changed = status === 'CHANGED' || status === 'FIRST_SEEN';

      return {
        sourceId: this.id,
        bankCode: this.bankCode,
        sourceUrl: this.sourceUrl,
        sourceType: this.sourceType,
        fetchedAt: new Date().toISOString(),
        httpStatus: fetchResponse.statusCode,
        contentType: fetchResponse.contentType,
        contentHash,
        previousHash,
        status,
        changed,
        byteLength: fetchResponse.byteLength,
        fetchDurationMs,
        error: null,
        parserVersion: this.parserVersion,
        bodyBuffer: fetchResponse.bodyBuffer, // Available in-memory for extraction
        normalizedBuffer, // Exact normalized bytes hashed for reproducibility
      };

    } catch (err) {
      const fetchDurationMs = Date.now() - startTime;
      return {
        sourceId: this.id,
        bankCode: this.bankCode,
        sourceUrl: this.sourceUrl,
        sourceType: this.sourceType,
        fetchedAt: new Date().toISOString(),
        httpStatus: err.statusCode || null,
        contentType: null,
        contentHash: null,
        previousHash,
        status: 'FETCH_FAILED',
        changed: false,
        byteLength: 0,
        fetchDurationMs,
        error: err.message,
        parserVersion: this.parserVersion,
        bodyBuffer: null,
      };
    }
  }
}

module.exports = {
  BaseCollector,
};
