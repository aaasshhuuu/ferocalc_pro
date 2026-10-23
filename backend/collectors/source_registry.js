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
    sourceUrl: 'https://www.hdfc.bank.in/fixed-deposit/fd-interest-rate',
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
  {
    id: 'idfc-first-retail-domestic',
    bankCode: 'IDFC_FIRST',
    bankName: 'IDFC FIRST Bank',
    sourceUrl: 'https://www.idfcfirst.bank.in/personal-banking/deposits/fixed-deposit/fd-interest-rates',
    sourceType: 'HTML',
    parserId: 'idfc_first_retail_html',
    parserVersion: '1.0.0',
    enabled: false,
    pollingIntervalHours: 24,
    description: 'Retail fixed deposits below Rs. 3 crore; disabled pending live-fetch and official HTML parity verification',
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
