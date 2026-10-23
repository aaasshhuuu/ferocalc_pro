// FeroCalc Verified FD Rate Engine — Parser Factory
// Maps source configurations to bank-specific parser instances.

'use strict';

const { SbiRateParser } = require('./sbi_parser');
const { HdfcRateParser } = require('./hdfc_parser');
const { IciciRateParser } = require('./icici_parser');
const { IdfcFirstRateParser } = require('./idfc_first_parser');
const { UnionBankRateParser } = require('./union_bank_parser');
const { PnbRateParser } = require('./pnb_parser');
const { IndusIndRateParser } = require('./indusind_parser');
const { UcoRateParser } = require('./uco_parser');

const PARSER_MAP = {
  SBI: new SbiRateParser(),
  HDFC: new HdfcRateParser(),
  ICICI: new IciciRateParser(),
  IDFC_FIRST: new IdfcFirstRateParser(),
  UNION_BANK: new UnionBankRateParser(),
  PNB: new PnbRateParser(),
  INDUSIND: new IndusIndRateParser(),
  UCO: new UcoRateParser(),
};

/**
 * Returns the parser instance for a given bank code.
 *
 * @param {string} bankCode
 * @returns {BaseRateParser|null}
 */
function getParserForBank(bankCode) {
  if (!bankCode) return null;
  const code = String(bankCode).trim().toUpperCase();
  return PARSER_MAP[code] || null;
}

/**
 * Returns the parser instance for a given source config or collector result.
 *
 * @param {Object} source
 * @returns {BaseRateParser|null}
 */
function getParserForSource(source) {
  if (!source) return null;
  const bankCode = source.bankCode || source.bankId;
  return getParserForBank(bankCode);
}

module.exports = {
  getParserForBank,
  getParserForSource,
  PARSER_MAP,
};
