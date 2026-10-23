// FeroCalc Verified FD Rate Engine — Source Registry
// Central configuration for official bank interest rate sources.
//
// Rules:
// - Official registered domains only (e.g., sbi.co.in, hdfcbank.com, icicibank.com)
// - No hardcoded rates in this registry.
// - URLs must match banks established in banks table / ALLOWED_SOURCE_DOMAINS.

'use strict';

const PILOT_SOURCES = [
  {
    id: 'sbi-retail-domestic',
    bankCode: 'SBI',
    bankName: 'State Bank of India',
    sourceUrl: 'https://sbi.co.in/web/interest-rates/deposit-rates/retail-domestic-term-deposits',
    sourceType: 'HTML',
    parserId: 'sbi_retail_html',
    parserVersion: '1.0.0',
    enabled: true,
    pollingIntervalHours: 24,
    description: 'SBI Retail Domestic Term Deposits (< Rs. 3 Crore)',
  },
  {
    id: 'hdfc-retail-domestic',
    bankCode: 'HDFC',
    bankName: 'HDFC Bank',
    sourceUrl: 'https://www.hdfcbank.com/personal/resources/rates',
    sourceType: 'HTML',
    parserId: 'hdfc_retail_html',
    parserVersion: '1.0.0',
    enabled: true,
    pollingIntervalHours: 24,
    description: 'HDFC Fixed Deposit Interest Rates',
  },
  {
    id: 'icici-retail-domestic',
    bankCode: 'ICICI',
    bankName: 'ICICI Bank',
    sourceUrl: 'https://www.icicibank.com/personal-banking/deposits/fixed-deposit/fd-interest-rates',
    sourceType: 'HTML',
    parserId: 'icici_retail_html',
    parserVersion: '1.0.0',
    enabled: true,
    pollingIntervalHours: 24,
    description: 'ICICI Domestic Fixed Deposit Rates',
  },
];

class SourceRegistry {
  constructor(sources = PILOT_SOURCES) {
    this._sources = new Map();
    for (const src of sources) {
      this._sources.set(src.id, Object.freeze({ ...src }));
    }
  }

  getSource(id) {
    return this._sources.get(id) || null;
  }

  getAllSources() {
    return Array.from(this._sources.values());
  }

  getEnabledSources() {
    return Array.from(this._sources.values()).filter(s => s.enabled);
  }

  getByBankCode(bankCode) {
    const code = String(bankCode).trim().toUpperCase();
    return Array.from(this._sources.values()).filter(s => s.bankCode === code);
  }
}

module.exports = {
  PILOT_SOURCES,
  SourceRegistry,
  defaultRegistry: new SourceRegistry(),
};
