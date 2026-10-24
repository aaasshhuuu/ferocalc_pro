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
  {
    id: 'union-bank-retail-callable',
    bankCode: 'UNION_BANK',
    bankName: 'Union Bank of India',
    sourceUrl: 'https://www.unionbankofindia.bank.in/en/details/rate-of-interest',
    sourceType: 'HTML',
    parserId: 'union_bank_callable_retail_html',
    parserVersion: '1.0.0',
    enabled: false,
    pollingIntervalHours: 24,
    description: 'Callable retail regular FD rates below Rs. 3 crore; disabled pending live parity and human review',
  },
  {
    id: 'pnb-retail-domestic',
    bankCode: 'PNB',
    bankName: 'Punjab National Bank',
    sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
    sourceType: 'HTML',
    parserId: 'pnb_retail_html',
    parserVersion: '1.0.0',
    enabled: false,
    pollingIntervalHours: 24,
    description: 'Callable retail domestic/NRO FD rates below Rs. 3 crore; disabled due to contradictory published "304 Days to >1 Year" boundary and pending official review',
  },
  {
    id: 'indusind-retail-domestic',
    bankCode: 'INDUSIND',
    bankName: 'IndusInd Bank',
    sourceUrl: 'https://www.indusind.bank.in/in/en/personal/fixed-deposit-interest-rate.html',
    sourceType: 'HTML',
    parserId: 'indusind_retail_html',
    parserVersion: '1.0.0',
    enabled: false,
    pollingIntervalHours: 24,
    description: 'Callable retail domestic/NRO/NRE FD rates below Rs. 3 crore; disabled pending full live-source parity and human review',
  },
  {
    id: 'uco-retail-domestic',
    bankCode: 'UCO',
    bankName: 'UCO Bank',
    sourceUrl: 'https://uco.bank.in/web/guest/interest-rates-on-deposit-schemes',
    sourceType: 'HTML',
    parserId: 'uco_retail_html',
    parserVersion: '1.0.0',
    enabled: false,
    pollingIntervalHours: 24,
    description: 'Callable retail domestic/NRO FD rates below Rs. 3 crore; disabled due to expired special schemes (333 and 444 days expired 30.06.2026) pending official resolution and review',
  },
  {
    id: 'au-small-finance-retail-domestic',
    bankCode: 'AU_SMALL_FINANCE',
    bankName: 'AU Small Finance Bank',
    sourceUrl: 'https://www.au.bank.in/interest-rates/fixed-deposit-interest-rates',
    sourceType: 'HTML',
    parserId: 'au_small_finance_retail_html',
    parserVersion: '1.0.0',
    enabled: false,
    pollingIntervalHours: 24,
    description: 'Callable retail domestic/NRE/NRO FD rates below Rs. 3 crore; disabled pending full live-source parity and human review',
  },
  {
    id: 'canara-retail-domestic',
    bankCode: 'CANARA',
    bankName: 'Canara Bank',
    sourceUrl: 'https://www.canarabank.bank.in/term-deposits-rate-of-interest-p.a.',
    sourceType: 'HTML',
    parserId: 'canara_retail_html',
    parserVersion: '1.0.0',
    enabled: false,
    pollingIntervalHours: 24,
    description: 'Callable retail domestic FD rates below Rs. 3 crore; disabled pending full live-source parity and human review',
  },
  {
    id: 'central-bank-retail-domestic',
    bankCode: 'CENTRAL_BANK',
    bankName: 'Central Bank of India',
    sourceUrl: 'https://www.centralbank.bank.in/en/interest-rates-on-deposit',
    sourceType: 'HTML',
    parserId: 'central_bank_retail_html',
    parserVersion: '1.0.0',
    enabled: false,
    pollingIntervalHours: 24,
    description: 'Callable retail domestic FD rates below Rs. 3 crore and special schemes (333, 444, 555 days); disabled pending full live-source parity and human review',
  },
  {
    id: 'axis-retail-domestic',
    bankCode: 'AXIS',
    bankName: 'Axis Bank',
    sourceUrl: 'https://www.axis.bank.in/docs/default-source/default-document-library/interest-rates/domestic-fixed-deposit-interest-rates-less-than-3-crores-08-october-2026.pdf?sfvrsn=15a73678_1',
    landingPageUrl: 'https://www.axis.bank.in/deposits/fixed-deposits/fd-interest-rates',
    sourceType: 'PDF',
    parserId: 'axis_retail_pdf',
    parserVersion: '1.0.0',
    enabled: false,
    pollingIntervalHours: 24,
    description: 'Callable retail domestic FD rates below Rs. 3 crore from official PDF schedule; disabled pending full live-source parity and human review',
  },
  {
    id: 'indian-bank-retail-domestic',
    bankCode: 'INDIAN_BANK',
    bankName: 'Indian Bank',
    sourceUrl: 'https://indianbank.bank.in/en/deposit-rates',
    sourceType: 'HTML',
    parserId: 'indian_bank_retail_html',
    parserVersion: '1.0.0',
    enabled: false,
    pollingIntervalHours: 24,
    description: 'Callable retail domestic FD rates below Rs. 3 crore and special schemes (IND Supreme 2.0, Ind Green, Ind Grow, Ind Prosper); disabled pending full live-source parity and human review',
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
