// FeroCalc Verified FD Rate Engine — Bank Pilot Collectors
//
// Individual bank adapters extending BaseCollector.
// Allows custom extraction hooks and site-specific DOM/table normalization.

'use strict';

const { BaseCollector } = require('./base_collector');

/**
 * Extract a complete Liferay content article by its stable analytics marker.
 * Counting nested div tags avoids truncating nested rate tables at the first
 * closing div, and excludes volatile portal navigation outside the article.
 *
 * @param {string} html
 * @returns {string|null}
 */
function extractSbiInterestRateArticle(html) {
  const opener = /<div\b(?=[^>]*\bdata-analytics-asset-id=["']INTEREST_RATE["'])[^>]*>/i.exec(html);
  if (!opener) return null;

  const start = opener.index;
  const divTags = /<\/?div\b[^>]*>/gi;
  divTags.lastIndex = start + opener[0].length;
  let depth = 1;
  let match;

  while ((match = divTags.exec(html)) !== null) {
    if (/^<\//.test(match[0])) {
      depth -= 1;
    } else if (!/\/\s*>$/.test(match[0])) {
      depth += 1;
    }

    if (depth === 0) {
      return html.slice(start, divTags.lastIndex).trim();
    }
  }

  return null;
}

/**
 * Extract the stable official ICICI interest-table component. ICICI's page
 * shell contains promotional and navigation content that can change without
 * any FD rate change; the interest-tables component holds the callable and
 * non-callable rate table used by the parser.
 *
 * @param {string} html
 * @returns {string|null}
 */
function extractIciciInterestTables(html) {
  const opener = /<div\b(?=[^>]*\bdata-component=["']interest-tables["'])[^>]*>/i.exec(html);
  if (!opener) return null;

  const start = opener.index;
  const divTags = /<\/?div\b[^>]*>/gi;
  divTags.lastIndex = start + opener[0].length;
  let depth = 1;
  let match;

  while ((match = divTags.exec(html)) !== null) {
    if (/^<\//.test(match[0])) {
      depth -= 1;
    } else if (!/\/\s*>$/.test(match[0])) {
      depth += 1;
    }

    if (depth === 0) {
      return html.slice(start, divTags.lastIndex).trim();
    }
  }

  return null;
}

class SbiCollector extends BaseCollector {
  constructor(config = {}) {
    super({
      id: 'sbi-retail-domestic',
      bankCode: 'SBI',
      bankName: 'State Bank of India',
      sourceUrl: 'https://sbi.co.in/web/interest-rates/deposit-rates/retail-domestic-term-deposits',
      sourceType: 'HTML',
      parserId: 'sbi_retail_html',
      parserVersion: '1.0.0',
      enabled: true,
      ...config,
    });
  }

  /**
   * Hash only SBI's official INTEREST_RATE article, not the Liferay portal
   * shell. The shell contains volatile navigation, portlet IDs, and request
   * timestamps which change between identical rate-table fetches. The table,
   * senior-citizen rows, special schemes, and effective-date text remain inside
   * the hashed article, so real rate/effective-date changes still change SHA-256.
   *
   * If SBI changes the marker, fall back to the full normalized HTML rather
   * than returning empty or fabricated content.
   */
  normalize(buffer) {
    const raw = super.normalize(buffer).toString('utf8');
    const rateArticle = extractSbiInterestRateArticle(raw);
    return Buffer.from(rateArticle || raw, 'utf8');
  }
}

class HdfcCollector extends BaseCollector {
  constructor(config = {}) {
    super({
      id: 'hdfc-retail-domestic',
      bankCode: 'HDFC',
      bankName: 'HDFC Bank',
      sourceUrl: 'https://www.hdfc.bank.in/fixed-deposit/fd-interest-rate',
      sourceType: 'HTML',
      parserId: 'hdfc_retail_html',
      parserVersion: '1.0.0',
      enabled: true,
      ...config,
    });
  }
}

class IciciCollector extends BaseCollector {
  constructor(config = {}) {
    super({
      id: 'icici-retail-domestic',
      bankCode: 'ICICI',
      bankName: 'ICICI Bank',
      sourceUrl: 'https://www.icicibank.com/personal-banking/deposits/fixed-deposit/fd-interest-rates',
      sourceType: 'HTML',
      parserId: 'icici_retail_html',
      parserVersion: '1.0.0',
      enabled: true,
      ...config,
    });
  }

  /**
   * Hash the official interest tables rather than the volatile full page.
   * If the component marker disappears after an upstream redesign, fail safe
   * by hashing the full normalized HTML so the change is still detected.
   */
  normalize(buffer) {
    const raw = super.normalize(buffer).toString('utf8');
    const rateTables = extractIciciInterestTables(raw);
    return Buffer.from(rateTables || raw, 'utf8');
  }
}

/**
 * Factory for instantiating the right collector by source configuration or ID.
 */
function createCollector(sourceConfig) {
  switch (sourceConfig.bankCode?.toUpperCase()) {
    case 'SBI':
      return new SbiCollector(sourceConfig);
    case 'HDFC':
      return new HdfcCollector(sourceConfig);
    case 'ICICI':
      return new IciciCollector(sourceConfig);
    default:
      return new BaseCollector(sourceConfig);
  }
}

module.exports = {
  SbiCollector,
  HdfcCollector,
  IciciCollector,
  createCollector,
};
