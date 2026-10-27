// FeroCalc Verified FD Rate Engine — Bank Pilot Collectors
//
// Individual bank adapters extending BaseCollector.
// Allows custom extraction hooks and site-specific DOM/table normalization.

'use strict';

const { BaseCollector } = require('./base_collector');

/**
 * Return the full div element containing an exact Liferay analytics article.
 * This scopes SBI content hashes to the published rate article instead of
 * transient navigation, session timestamps, and unrelated portal widgets.
 *
 * @param {string} html
 * @param {string} assetId
 * @returns {string|null}
 */
function extractDivByAnalyticsAssetId(html, assetId) {
  const escapedAssetId = String(assetId).replace(/[.*+?^${}()|[\]\\]/g, '\\class SbiCollector extends BaseCollector {');
  const opener = new RegExp(
    `<div\\b(?=[^>]*\\bdata-analytics-asset-id=["']${escapedAssetId}["'])[^>]*>`,
    'i',
  ).exec(html);

  if (!opener) return null;

  const start = opener.index;
  const tagEnd = start + opener[0].length;
  const divTags = /<\\/?div\\b[^>]*>/gi;
  divTags.lastIndex = tagEnd;
  let depth = 1;
  let match;

  while ((match = divTags.exec(html)) !== null) {
    if (/^<\\//.test(match[0])) {
      depth -= 1;
    } else if (!/\\/\\s*>$/.test(match[0])) {
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
   * SBI's Liferay shell includes changing navigation, portlet IDs, and form
   * timestamps even when the rate table has not changed. Hash the exact official
   * INTEREST_RATE article so real table/effective-date edits change the hash,
   * while unrelated shell churn does not.
   *
   * If SBI changes its marker, preserve the full normalized HTML rather than
   * returning empty or fabricated content.
   */
  normalize(buffer) {
    const raw = super.normalize(buffer).toString('utf8');
    const rateArticle = extractDivByAnalyticsAssetId(raw, 'INTEREST_RATE');
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
