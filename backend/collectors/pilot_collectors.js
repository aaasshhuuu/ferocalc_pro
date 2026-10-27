// FeroCalc Verified FD Rate Engine — Bank Pilot Collectors
//
// Individual bank adapters extending BaseCollector.
// Allows custom extraction hooks and site-specific DOM/table normalization.

'use strict';

const { BaseCollector } = require('./base_collector');

/**
 * Extract a complete div selected by an authoritative, bank-specific marker.
 * A balanced div scan is used instead of a non-greedy regex so nested
 * containers/tables are preserved in full.
 *
 * @param {string} html
 * @param {RegExp} openerPattern
 * @returns {string|null}
 */
function extractMarkedDiv(html, openerPattern) {
  const opener = openerPattern.exec(html);
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
 * Extract the full official SBI INTEREST_RATE article, excluding the changing
 * Liferay portal navigation, generated portlet IDs, and request timestamps.
 *
 * @param {string} html
 * @returns {string|null}
 */
function extractSbiInterestRateArticle(html) {
  return extractMarkedDiv(
    html,
    /<div\b(?=[^>]*\bdata-analytics-asset-id=["']INTEREST_RATE["'])[^>]*>/i,
  );
}

/**
 * Extract the ICICI component containing the callable/non-callable FD rate
 * tables, excluding unrelated navigation and promotional AEM components.
 *
 * @param {string} html
 * @returns {string|null}
 */
function extractIciciInterestTables(html) {
  return extractMarkedDiv(
    html,
    /<div\b(?=[^>]*\bdata-component=["']interest-tables["'])[^>]*>/i,
  );
}

/**
 * Extract the smallest stable HDFC section containing both the effective-date
 * heading and the < Rs. 3 Crore rate table. Hashing only the table would miss a
 * date-only update; hashing the whole page includes unrelated AEM shell noise.
 *
 * @param {string} html
 * @returns {string|null}
 */
function extractHdfcRateSection(html) {
  const tableOpener = /<div\b(?=[^>]*\bid=["']IR-less-than-3-cr["'])[^>]*>/i.exec(html);
  if (!tableOpener) return null;

  const tableStart = tableOpener.index;
  const divTags = /<\/?div\b[^>]*>/gi;
  const ancestors = [];
  let match;

  // Build the open-div stack immediately before the under-3-Crore component.
  while ((match = divTags.exec(html)) !== null && match.index < tableStart) {
    if (/^<\//.test(match[0])) {
      ancestors.pop();
    } else if (!/\/\s*>$/.test(match[0])) {
      ancestors.push({ start: match.index });
    }
  }

  const requiredHeading = 'domestic / nro / nre fixed deposit rate';
  const selected = ancestors
    .filter((ancestor) => html
      .slice(ancestor.start, tableStart)
      .replace(/\s+/g, ' ')
      .toLowerCase()
      .includes(requiredHeading))
    .pop();

  if (!selected) return null;

  const section = extractMarkedDiv(
    html.slice(selected.start),
    /^<div\b[^>]*>/i,
  );
  if (!section) return null;
  if (!/id=["']IR-less-than-3-cr["']/i.test(section)) return null;
  if (!/domestic\s*\/\s*nro\s*\/\s*nre\s+fixed\s+deposit\s+rate/i.test(section)) return null;

  return section;
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
   * Hash the official rate article, not volatile Liferay navigation and session
   * timestamps. If the marker disappears, fall back to full normalized HTML so
   * an upstream redesign is still detected.
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

  /**
   * Hash the official retail FD section including its effective date and rate
   * table. Unrelated AEM shell changes must not trigger false rate changes.
   * Fall back to the full normalized page if the semantic markers disappear.
   */
  normalize(buffer) {
    const raw = super.normalize(buffer).toString('utf8');
    const rateSection = extractHdfcRateSection(raw);
    return Buffer.from(rateSection || raw, 'utf8');
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
   * Hash only the official interest-tables component. Fall back to the full
   * normalized page if the upstream component marker changes.
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
