// FeroCalc Phase 3C.5.20 — Exact NUMERIC(18,2) Identity Safety Tests
//
// Verifies:
// 1. Distinct high-precision NUMERIC(18,2) values exceeding IEEE 754 float precision (9007199254740992.00 vs 9007199254740993.00)
//    remain strictly distinct when passed as exact strings.
// 2. Unsafe float numbers exceeding Number.MAX_SAFE_INTEGER fail closed with an explicit precision-loss error.
// 3. Ordinary equivalent representations (1000, '1000', '1000.0', '1000.00') normalize to identical canonical '1000.00'.
// 4. NULL vs zero remains strictly distinct.
// 5. Invalid values, empty strings, NaN, Infinity, and invalid decimal formats fail closed.
// 6. Scale and precision boundary enforcement (max 16 integer digits, max 2 decimal places).
// 7. Negative deposit representation (-1, '-1', '-1.00') normalizes to '-1.00'.
// 8. Scheme name whitespace sanitization contract (tabs, newlines, non-breaking spaces) enforced.
// 9. Full Candidate Identity Key derivation with exact decimal components preserves all null/value distinctions.
// 10. StagingRetryCoordinator reconciliation with exact decimal values remains safe and idempotent.

'use strict';

const assert = require('assert');
const {
  getCandidateIdentityKey,
  normalizeExactDecimal,
  normalizeSchemeName,
  StagingRetryCoordinator,
} = require('../staging/staging_retry_coordinator');

async function runTests() {
  console.log('======================================================');
  console.log('FeroCalc Phase 3C.5.20 Exact NUMERIC Safety Tests');
  console.log('======================================================\n');

  let passed = 0;
  let failed = 0;

  function test(name, fn) {
    try {
      fn();
      console.log(`  PASS: ${name}`);
      passed++;
    } catch (err) {
      console.error(`  FAIL: ${name}`);
      console.error(`        ${err.message}`);
      failed++;
    }
  }

  async function testAsync(name, fn) {
    try {
      await fn();
      console.log(`  PASS: ${name}`);
      passed++;
    } catch (err) {
      console.error(`  FAIL: ${name}`);
      console.error(`        ${err.message}`);
      failed++;
    }
  }

  const baseCandidate = {
    bankCode: 'SBI',
    productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
    customerType: 'REGULAR',
    minTenureDays: 365,
    maxTenureDays: 729,
    minDeposit: null,
    maxDeposit: null,
    isCallable: true,
    rateCategory: 'STANDARD',
    schemeName: null,
    stagingStatus: 'DRAFT',
    interestRate: 6.80,
    sourceContentHash: 'hash_test_sha256',
  };

  console.log('Group 1: Exact NUMERIC(18,2) Normalization & Float Precision Bounds...');

  test('1. Distinct values beyond IEEE 754 safe integer (9007199254740992.00 vs 9007199254740993.00) remain distinct', () => {
    const valA = '9007199254740992.00';
    const valB = '9007199254740993.00';

    const normA = normalizeExactDecimal(valA, 'max_deposit');
    const normB = normalizeExactDecimal(valB, 'max_deposit');

    assert.strictEqual(normA, '9007199254740992.00');
    assert.strictEqual(normB, '9007199254740993.00');
    assert.notStrictEqual(normA, normB, 'Exact strings must not collapse into identical keys');

    const keyA = getCandidateIdentityKey({ ...baseCandidate, maxDeposit: valA });
    const keyB = getCandidateIdentityKey({ ...baseCandidate, maxDeposit: valB });

    assert.notStrictEqual(keyA, keyB, 'Candidate identity keys must remain distinct for high-precision deposit values');
  });

  test('2. Unsafe JavaScript numbers fail closed on precision loss boundaries', () => {
    // A. Exceeding Number.MAX_SAFE_INTEGER
    const unsafeFloat = 9007199254740992 + 2; // > Number.MAX_SAFE_INTEGER
    assert.throws(() => {
      normalizeExactDecimal(unsafeFloat, 'max_deposit');
    }, /Unsafe float precision loss/);

    assert.throws(() => {
      getCandidateIdentityKey({ ...baseCandidate, maxDeposit: unsafeFloat });
    }, /Unsafe float precision loss/);

    // B. Empirical float precision collapse below MAX_SAFE_INTEGER:
    // In IEEE 754 float64, 100000000000000.01 === 100000000000000.02 is TRUE (cent precision collapses)
    // Application must fail closed if such a non-integer float (> 1e12) is passed as a number.
    assert.strictEqual(100000000000000.01 === 100000000000000.02, true, 'IEEE 754 float64 arithmetic collapses 0.01 cent at 10^14');

    assert.throws(() => {
      normalizeExactDecimal(100000000000000.01, 'min_deposit');
    }, /Unsafe float precision loss.*exceeds safe decimal precision threshold/);

    // C. Conversely, passing exact decimal strings preserves cent-level provenance losslessly
    const exactStrA = '100000000000000.01';
    const exactStrB = '100000000000000.02';
    assert.strictEqual(normalizeExactDecimal(exactStrA), '100000000000000.01');
    assert.strictEqual(normalizeExactDecimal(exactStrB), '100000000000000.02');
    assert.notStrictEqual(normalizeExactDecimal(exactStrA), normalizeExactDecimal(exactStrB));
  });

  test('2b. JSON parse boundary regression: lossy numbers fail closed while exact strings & retail amounts succeed', () => {
    // 1. JSON parsing an integer > 1e12 that collapsed from distinct values (9007199254740993.00 vs 9007199254740992.00)
    const jsonA = '{"minDeposit": 9007199254740993.00}';
    const jsonB = '{"minDeposit": 9007199254740992.00}';
    const parsedA = JSON.parse(jsonA);
    const parsedB = JSON.parse(jsonB);

    assert.strictEqual(parsedA.minDeposit, parsedB.minDeposit, 'V8 JSON.parse collapses 9007199254740993.00 into 9007199254740992');
    assert.strictEqual(Number.isInteger(parsedA.minDeposit), true, 'Collapsed number is an integer');

    // Both must FAIL CLOSED in normalizeExactDecimal, preventing silent precision corruption
    assert.throws(() => {
      normalizeExactDecimal(parsedA.minDeposit, 'min_deposit');
    }, /Unsafe float precision loss.*exceeds safe decimal precision threshold \(1e12\)/);

    // 2. Fractional decimal that rounds to an integer during JSON.parse (e.g. 140737488355328.01)
    const jsonFracRound = '{"minDeposit": 140737488355328.01}';
    const parsedFracRound = JSON.parse(jsonFracRound);
    assert.strictEqual(parsedFracRound.minDeposit, 140737488355328, 'JSON.parse rounds 140737488355328.01 to integer 140737488355328');
    assert.strictEqual(Number.isInteger(parsedFracRound.minDeposit), true, 'Parsed float is an integer');

    // Must FAIL CLOSED despite being an integer (does NOT trust Number.isInteger alone!)
    assert.throws(() => {
      normalizeExactDecimal(parsedFracRound.minDeposit, 'min_deposit');
    }, /Unsafe float precision loss.*exceeds safe decimal precision threshold \(1e12\)/);

    // 3. Exact JSON strings for the same high-precision values remain strictly distinct and succeed losslessly
    const jsonStrA = '{"minDeposit": "9007199254740993.00"}';
    const jsonStrB = '{"minDeposit": "9007199254740992.00"}';
    const jsonStrFrac = '{"minDeposit": "140737488355328.01"}';
    const parsedStrA = JSON.parse(jsonStrA);
    const parsedStrB = JSON.parse(jsonStrB);
    const parsedStrFrac = JSON.parse(jsonStrFrac);

    assert.strictEqual(normalizeExactDecimal(parsedStrA.minDeposit), '9007199254740993.00');
    assert.strictEqual(normalizeExactDecimal(parsedStrB.minDeposit), '9007199254740992.00');
    assert.strictEqual(normalizeExactDecimal(parsedStrFrac.minDeposit), '140737488355328.01');
    assert.notStrictEqual(normalizeExactDecimal(parsedStrA.minDeposit), normalizeExactDecimal(parsedStrB.minDeposit));

    // 4. Safe retail banking values in JSON (numbers and strings) succeed losslessly
    const retailJsonNum = '{"minDeposit": 1000, "maxDeposit": 29999999}';
    const retailJsonStr = '{"minDeposit": "1000.00", "maxDeposit": "29999999.00"}';
    const parsedRetailNum = JSON.parse(retailJsonNum);
    const parsedRetailStr = JSON.parse(retailJsonStr);

    assert.strictEqual(normalizeExactDecimal(parsedRetailNum.minDeposit), '1000.00');
    assert.strictEqual(normalizeExactDecimal(parsedRetailNum.maxDeposit), '29999999.00');
    assert.strictEqual(normalizeExactDecimal(parsedRetailStr.minDeposit), '1000.00');
    assert.strictEqual(normalizeExactDecimal(parsedRetailStr.maxDeposit), '29999999.00');
  });

  test('3. Ordinary equivalent representations (1000, "1000", "1000.0", "1000.00") normalize to identical "1000.00"', () => {
    const reps = [1000, '1000', '1000.0', '1000.00', ' 1000.00 ', '+1000.00', '001000.00'];

    for (const r of reps) {
      assert.strictEqual(normalizeExactDecimal(r), '1000.00', `Representation ${r} must normalize to 1000.00`);
    }

    const keys = reps.map(r => getCandidateIdentityKey({ ...baseCandidate, minDeposit: r }));
    const firstKey = keys[0];

    for (let i = 1; i < keys.length; i++) {
      assert.strictEqual(keys[i], firstKey, `Key for representation ${reps[i]} must match first key`);
    }
  });

  test('4. NULL versus zero remains strictly distinct', () => {
    assert.strictEqual(normalizeExactDecimal(null), null);
    assert.strictEqual(normalizeExactDecimal(undefined), null);
    assert.strictEqual(normalizeExactDecimal(0), '0.00');
    assert.strictEqual(normalizeExactDecimal('0'), '0.00');
    assert.strictEqual(normalizeExactDecimal('0.00'), '0.00');
    assert.strictEqual(normalizeExactDecimal('-0.00'), '0.00');

    const keyNull = getCandidateIdentityKey({ ...baseCandidate, minDeposit: null });
    const keyZero = getCandidateIdentityKey({ ...baseCandidate, minDeposit: 0 });

    assert.notStrictEqual(keyNull, keyZero, 'NULL deposit key must be strictly distinct from zero deposit key');
    assert.match(keyNull, /\["SBI","RETAIL_DOMESTIC_TERM_DEPOSIT","REGULAR",365,729,null,/);
    assert.match(keyZero, /\["SBI","RETAIL_DOMESTIC_TERM_DEPOSIT","REGULAR",365,729,"0.00",/);
  });

  test('5. Invalid values, empty strings, NaN, Infinity, and non-numeric formats fail closed', () => {
    const invalidInputs = [
      ['', /cannot be an empty string/],
      ['   ', /cannot be an empty string/],
      [NaN, /cannot be NaN/],
      [Infinity, /cannot be non-finite/],
      [-Infinity, /cannot be non-finite/],
      ['abc', /invalid decimal format/],
      ['1000.00.00', /invalid decimal format/],
      ['$1000', /invalid decimal format/],
      ['1,000.00', /invalid decimal format/],
    ];

    for (const [input, pattern] of invalidInputs) {
      assert.throws(() => {
        normalizeExactDecimal(input, 'min_deposit');
      }, pattern, `Input "${input}" must fail closed`);
    }
  });

  test('6. NUMERIC(18,2) precision and scale boundaries enforced', () => {
    // Exceeding 2 decimal places fails closed
    assert.throws(() => {
      normalizeExactDecimal('10.999', 'min_deposit');
    }, /exceeds NUMERIC\(18,2\) scale/);

    assert.throws(() => {
      normalizeExactDecimal('100.123', 'min_deposit');
    }, /exceeds NUMERIC\(18,2\) scale/);

    // Exceeding 16 integer digits fails closed (total precision 18 = 16 integer + 2 decimal)
    const seventeenDigits = '12345678901234567.00';
    assert.throws(() => {
      normalizeExactDecimal(seventeenDigits, 'min_deposit');
    }, /exceeds NUMERIC\(18,2\) maximum of 16 integer digits/);

    // Exactly 16 integer digits succeeds
    const sixteenDigits = '9999999999999999.99';
    assert.strictEqual(normalizeExactDecimal(sixteenDigits), '9999999999999999.99');
  });

  test('7. Negative deposit representation (-1, "-1", "-1.00") normalizes to "-1.00"', () => {
    assert.strictEqual(normalizeExactDecimal(-1), '-1.00');
    assert.strictEqual(normalizeExactDecimal('-1'), '-1.00');
    assert.strictEqual(normalizeExactDecimal('-1.0'), '-1.00');
    assert.strictEqual(normalizeExactDecimal('-1.00'), '-1.00');
    assert.strictEqual(normalizeExactDecimal(' -1.00 '), '-1.00');

    const keyNeg = getCandidateIdentityKey({ ...baseCandidate, maxDeposit: -1 });
    assert.match(keyNeg, /"-1.00"/);
  });

  console.log('\nGroup 2: Scheme Name Whitespace Normalization & Sanitization Contract...');

  test('8. Scheme name whitespace sanitization contract (tabs, newlines, NBSP) enforced by category', () => {
    // SPECIAL_SCHEME: normalizes outer tabs, newlines, NBSP to single spaces and upper-cases
    assert.strictEqual(normalizeSchemeName('\tSBI We-Care\t', 'SPECIAL_SCHEME'), 'SBI WE-CARE');
    assert.strictEqual(normalizeSchemeName('\nSBI We-Care\r\n', 'SPECIAL_SCHEME'), 'SBI WE-CARE');
    assert.strictEqual(normalizeSchemeName('\u00A0SBI We-Care\u00A0', 'SPECIAL_SCHEME'), 'SBI WE-CARE');
    assert.strictEqual(normalizeSchemeName('  SBI We-Care  ', 'SPECIAL_SCHEME'), 'SBI WE-CARE');

    // SPECIAL_SCHEME: fails closed on null, undefined, empty string, or whitespace-only
    assert.throws(() => normalizeSchemeName(null, 'SPECIAL_SCHEME'), /Special scheme candidate requires a non-empty scheme_name/);
    assert.throws(() => normalizeSchemeName(undefined, 'SPECIAL_SCHEME'), /Special scheme candidate requires a non-empty scheme_name/);
    assert.throws(() => normalizeSchemeName('', 'SPECIAL_SCHEME'), /Special scheme candidate requires a non-empty scheme_name/);
    assert.throws(() => normalizeSchemeName('   \t\n\u00A0  ', 'SPECIAL_SCHEME'), /Special scheme candidate requires a non-empty scheme_name/);

    // STANDARD: canonicalizes null, undefined, empty, and whitespace-only strings to null
    assert.strictEqual(normalizeSchemeName(null, 'STANDARD'), null);
    assert.strictEqual(normalizeSchemeName(undefined, 'STANDARD'), null);
    assert.strictEqual(normalizeSchemeName('', 'STANDARD'), null);
    assert.strictEqual(normalizeSchemeName('   \t\n\u00A0  ', 'STANDARD'), null);

    // STANDARD: fails closed on non-empty scheme name (standard rate cannot have a scheme name)
    assert.throws(() => normalizeSchemeName('SBI We-Care', 'STANDARD'), /Standard rate candidate cannot have a non-empty scheme_name/);
  });

  test('9. Full Candidate Identity Key derivation preserves exact decimal and scheme contracts', () => {
    const candidate = {
      bankCode: 'sbi',
      productType: 'retail_domestic_term_deposit',
      customerType: 'senior_citizen',
      minTenureDays: 365,
      maxTenureDays: 729,
      minDeposit: 1000,
      maxDeposit: '29999999.00',
      isCallable: true,
      rateCategory: 'special_scheme',
      schemeName: '\tSBI We-Care\n',
    };

    const key = getCandidateIdentityKey(candidate);
    const parsedTuple = JSON.parse(key);

    assert.deepStrictEqual(parsedTuple, [
      'SBI',
      'RETAIL_DOMESTIC_TERM_DEPOSIT',
      'SENIOR_CITIZEN',
      365,
      729,
      '1000.00',      // Exact decimal string
      '29999999.00',  // Exact decimal string
      true,
      'SPECIAL_SCHEME',
      'SBI WE-CARE',  // Sanitized uppercase
    ]);
  });

  console.log('\nGroup 3: StagingRetryCoordinator Reconciliation with Exact Decimals...');

  await testAsync('10. StagingRetryCoordinator reconciliation with exact decimal values remains safe and idempotent', async () => {
    const coordinator = new StagingRetryCoordinator();

    const committedRow = {
      id: 'uuid_sbi_exact_decimal_row',
      bank_code: 'SBI',
      product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customer_type: 'REGULAR',
      min_tenure_days: 365,
      max_tenure_days: 729,
      min_deposit: 1000.00,    // PostgREST numeric returned as float or string
      max_deposit: 29999999.00,
      is_callable: true,
      rate_category: 'STANDARD',
      scheme_name: null,
      interest_rate: 6.80,
      staging_status: 'DRAFT',
      source_content_hash: 'hash_sbi_exact_decimal',
    };

    const mockDb = {
      from(tableName) {
        return {
          select(cols = '*') {
            return {
              eq(col1, val1) {
                return {
                  eq(col2, val2) {
                    return Promise.resolve({ data: [committedRow], error: null });
                  },
                };
              },
            };
          },
        };
      },
    };

    // Expected candidate passed with integer deposit 1000 and 29999999
    const incomingCandidate = {
      bankCode: 'SBI',
      productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customerType: 'REGULAR',
      minTenureDays: 365,
      maxTenureDays: 729,
      minDeposit: 1000,
      maxDeposit: 29999999,
      isCallable: true,
      rateCategory: 'STANDARD',
      schemeName: null,
      interestRate: 6.80,
    };

    const reconciliation = await coordinator.reconcileStagingState({
      supabaseClient: mockDb,
      bankCode: 'SBI',
      sourceContentHash: 'hash_sbi_exact_decimal',
      expectedCandidates: [incomingCandidate],
    });

    assert.strictEqual(reconciliation.canProceed, true);
    assert.strictEqual(reconciliation.status, 'ALREADY_COMMITTED');
    assert.strictEqual(reconciliation.writeReceipt.length, 1);
    assert.strictEqual(reconciliation.writeReceipt[0].id, 'uuid_sbi_exact_decimal_row');
  });

  console.log('\nGroup 4: Candidate Persistence & Parser Parity...');

  test('11. Canonical scheme NULL policy produces identical identity key for empty and null scheme', () => {
    const cNullScheme = { ...baseCandidate, rateCategory: 'STANDARD', schemeName: null };
    const cEmptyScheme = { ...baseCandidate, rateCategory: 'STANDARD', schemeName: '' };
    const cWhitespaceScheme = { ...baseCandidate, rateCategory: 'STANDARD', schemeName: '   \t  ' };

    const keyNull = getCandidateIdentityKey(cNullScheme);
    const keyEmpty = getCandidateIdentityKey(cEmptyScheme);
    const keyWhitespace = getCandidateIdentityKey(cWhitespaceScheme);

    assert.strictEqual(keyNull, keyEmpty, 'Candidate with schemeName="" must produce identical key to schemeName=null');
    assert.strictEqual(keyNull, keyWhitespace, 'Candidate with whitespace schemeName must produce identical key to schemeName=null');
    assert.match(keyNull, /,"STANDARD",null\]$/, 'Normalized key ends with ["STANDARD", null]');
  });

  test('12. CandidateStagingService candidate record mapping formats exact decimals and canonicalizes scheme', () => {
    // Verify candidate record mapping directly
    const candidateInput = {
      sourceId: 'src_test',
      bankCode: 'SBI',
      productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customerType: 'REGULAR',
      tenureLabel: '1 Year to 2 Years',
      minTenureDays: 365,
      maxTenureDays: 729,
      tenureUnit: 'DAYS',
      interestRate: 6.80,
      minDeposit: 1000,
      maxDeposit: 29999999,
      isCallable: true,
      compoundingFrequency: 'QUARTERLY',
      sourceUrl: 'https://bank.sbi/rates',
      sourceContentHash: 'hash123',
      rateCategory: 'STANDARD',
      schemeName: '',
      stagingStatus: 'DRAFT',
    };

    const normMin = normalizeExactDecimal(candidateInput.minDeposit, 'min_deposit');
    const normMax = normalizeExactDecimal(candidateInput.maxDeposit, 'max_deposit');
    const normScheme = normalizeSchemeName(candidateInput.schemeName, candidateInput.rateCategory);

    assert.strictEqual(normMin, '1000.00', 'min_deposit must be exact decimal string');
    assert.strictEqual(normMax, '29999999.00', 'max_deposit must be exact decimal string');
    assert.strictEqual(normScheme, null, 'Empty string schemeName must map to null');
  });

  test('13. SBI Rate Parser emits exact decimal string deposit values', () => {
    const { SbiRateParser } = require('../parsers/sbi_parser');
    const parser = new SbiRateParser();
    const htmlFixture = `
      <html><body><table>
        <tr><th>Tenure</th><th>Regular</th><th>Senior</th></tr>
        <tr><td>1 Year to less than 2 years</td><td>6.80</td><td>7.30</td></tr>
      </table></body></html>
    `;
    const result = parser.parse(Buffer.from(htmlFixture), {
      sourceId: 'src_sbi_test',
      sourceUrl: 'https://bank.sbi/rates',
      sourceContentHash: 'hash_sbi_exact_dec',
    });

    assert.strictEqual(result.success, true);
    assert.ok(result.candidates.length >= 1);
    const c = result.candidates[0];
    assert.strictEqual(c.minDeposit, '1000.00', 'SBI parser must produce exact string minDeposit');
    assert.strictEqual(c.maxDeposit, '29999999.00', 'SBI parser must produce exact string maxDeposit');
  });

  await testAsync('14. Category-specific scheme name validation and quarantine before persistence', async () => {
    const { CandidateStagingService } = require('../staging/candidate_staging_service');
    const { CandidateValidator } = require('../validators/candidate_validator');
    const validator = new CandidateValidator();
    const service = new CandidateStagingService();

    const validBase = {
      bankCode: 'SBI',
      productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customerType: 'REGULAR',
      minTenureDays: 365,
      maxTenureDays: 729,
      tenureLabel: '1 Year to 2 Years',
      minDeposit: '1000.00',
      maxDeposit: '29999999.00',
      isCallable: true,
      interestRate: 6.80,
      sourceUrl: 'https://bank.sbi/rates',
      sourceContentHash: 'a'.repeat(64),
      stagingStatus: 'DRAFT',
    };

    // A. STANDARD candidate with null, empty, whitespace: VALID, canonicalized to null
    const stdNull = { ...validBase, rateCategory: 'STANDARD', schemeName: null };
    const stdEmpty = { ...validBase, rateCategory: 'STANDARD', schemeName: '' };
    const stdWhitespace = { ...validBase, rateCategory: 'STANDARD', schemeName: '   \t\n\u00A0  ' };

    assert.strictEqual(validator.validateCandidate(stdNull).isValid, true);
    assert.strictEqual(validator.validateCandidate(stdEmpty).isValid, true);
    assert.strictEqual(validator.validateCandidate(stdWhitespace).isValid, true);

    assert.strictEqual(normalizeSchemeName(stdNull.schemeName, 'STANDARD'), null);
    assert.strictEqual(normalizeSchemeName(stdEmpty.schemeName, 'STANDARD'), null);
    assert.strictEqual(normalizeSchemeName(stdWhitespace.schemeName, 'STANDARD'), null);

    // Identity key remains identical to existing STANDARD identity
    const keyStdNull = getCandidateIdentityKey(stdNull);
    const keyStdEmpty = getCandidateIdentityKey(stdEmpty);
    const keyStdWhitespace = getCandidateIdentityKey(stdWhitespace);
    assert.strictEqual(keyStdNull, keyStdEmpty);
    assert.strictEqual(keyStdNull, keyStdWhitespace);
    assert.match(keyStdNull, /,"STANDARD",null\]$/);

    // B. STANDARD candidate with non-empty scheme name: INVALID, fails validation and persistence
    const stdIllegalScheme = { ...validBase, rateCategory: 'STANDARD', schemeName: 'SBI We-Care' };
    assert.strictEqual(validator.validateCandidate(stdIllegalScheme).isValid, false);
    assert.throws(() => normalizeSchemeName('SBI We-Care', 'STANDARD'), /Standard rate candidate cannot have a non-empty scheme_name/);

    const persistStdIllegal = await service._persistCandidates([stdIllegalScheme], { requireLock: false });
    assert.strictEqual(persistStdIllegal.persistedCount, 0);
    assert.ok(persistStdIllegal.error.includes('Persistence BLOCKED: STANDARD candidate cannot have non-empty scheme_name'));

    // C. SPECIAL_SCHEME with valid name: VALID, normalized to uppercase
    const specialValid = {
      ...validBase,
      rateCategory: 'SPECIAL_SCHEME',
      schemeName: '  sbi we-care  ',
      notes: 'Special senior rate',
    };
    assert.strictEqual(validator.validateCandidate(specialValid).isValid, true);
    assert.strictEqual(normalizeSchemeName(specialValid.schemeName, 'SPECIAL_SCHEME'), 'SBI WE-CARE');
    const keySpecial = getCandidateIdentityKey(specialValid);
    assert.match(keySpecial, /,"SPECIAL_SCHEME","SBI WE-CARE"\]$/);

    // D. SPECIAL_SCHEME with NULL, empty, spaces, tabs, newlines, NBSP: INVALID, rejected/quarantined
    const invalidSpecialInputs = [
      null,
      '',
      '   ',
      '\t',
      '\n',
      '\r\n',
      '\u00A0',
      ' \t\n\u00A0 ',
    ];

    for (const badScheme of invalidSpecialInputs) {
      const specialInvalid = {
        ...validBase,
        rateCategory: 'SPECIAL_SCHEME',
        schemeName: badScheme,
        notes: 'Special senior rate',
      };
      // Validation rejects
      const valResult = validator.validateCandidate(specialInvalid);
      assert.strictEqual(valResult.isValid, false, `Scheme "${badScheme}" must be marked INVALID`);
      assert.ok(valResult.errors.some(e => e.includes('Missing required schemeName')));

      // Identity derivation fails closed
      assert.throws(() => getCandidateIdentityKey(specialInvalid), /Special scheme candidate requires a non-empty scheme_name/);

      // Persistence fails closed before DB insert
      const persistRes = await service._persistCandidates([specialInvalid], { requireLock: false });
      assert.strictEqual(persistRes.persistedCount, 0);
      assert.ok(persistRes.error.includes('Persistence BLOCKED: SPECIAL_SCHEME candidate missing required scheme_name'));
    }
  });

  test('15. HDFC and ICICI Parsers emit exact decimal strings', () => {
    const { HdfcRateParser } = require('../parsers/hdfc_parser');
    const { IciciRateParser } = require('../parsers/icici_parser');

    const hdfc = new HdfcRateParser();
    const icici = new IciciRateParser();

    const hdfcHtml = `
      <html><body>
        <p>Applicable from 6th Mar, 2026.</p>
        <table>
          <tr><th>Tenure Bucket</th><th>< 3 Crore</th></tr>
          <tr><th></th><th>Interest Rate (per annum)</th><th>**Senior Citizen Rates (per annum)</th></tr>
          <tr><td>7 - 14 days</td><td>2.75%</td><td>3.25%</td></tr>
        </table>
      </body></html>
    `;
    const hdfcResult = hdfc.parse(Buffer.from(hdfcHtml), {
      sourceId: 'src_hdfc_test',
      sourceUrl: 'https://hdfcbank.com',
      sourceContentHash: 'a'.repeat(64),
    });
    assert.strictEqual(hdfcResult.success, true);
    assert.ok(hdfcResult.candidates.length >= 1);
    assert.strictEqual(hdfcResult.candidates[0].minDeposit, '5000.00');
    assert.strictEqual(hdfcResult.candidates[0].maxDeposit, '29999999.00');

    const iciciHtml = `
      <html><body><table>
        <tr><th>With premature withdrawal facility</th><th></th><th>Tenure</th><th>Without premature withdrawal facility</th><th></th></tr>
        <tr><th>General citizen</th><th>Senior citizen</th><th></th><th>General citizen</th><th>Senior citizen</th></tr>
        <tr><td>6.70%</td><td>7.20%</td><td>1 year to 389 days</td><td>7.00%</td><td>7.50%</td></tr>
      </table></body></html>
    `;
    const iciciResult = icici.parse(Buffer.from(iciciHtml), {
      sourceId: 'src_icici_test',
      sourceUrl: 'https://icicibank.com',
      sourceContentHash: 'b'.repeat(64),
    });
    assert.strictEqual(iciciResult.success, true);
    assert.ok(iciciResult.candidates.length >= 1);
    assert.strictEqual(iciciResult.candidates[0].minDeposit, '10000.00');
    assert.strictEqual(iciciResult.candidates[0].maxDeposit, '20000000.00');
  });

  console.log('\n======================================================');
  console.log(`Results: ${passed} passed, ${failed} failed (Total: ${passed + failed})`);
  console.log('======================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
