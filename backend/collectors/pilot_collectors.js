// FeroCalc Verified FD Rate Engine — Bank Pilot Collectors
//
// Individual bank adapters extending BaseCollector.
// Allows custom extraction hooks and site-specific DOM/table normalization.

'use strict';

const { BaseCollector } = require('./base_collector');

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

  // Specialized normalization for SBI pages if needed
  normalize(buffer) {
    let raw = super.normalize(buffer).toString('utf8');
    // Extract only main content area if present to eliminate dynamic navigation noise
    const mainMatch = raw.match(/<div[^>]*class=["'][^"']*deposit-rates[^"']*["'][^>]*>([\s\S]*?)<\/div>/i);
    if (mainMatch) {
      return Buffer.from(mainMatch[1].trim(), 'utf8');
    }
    return Buffer.from(raw, 'utf8');
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
