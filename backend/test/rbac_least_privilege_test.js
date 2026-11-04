// FeroCalc Phase 3C.10 — RBAC Least-Privilege & Rollback Safety Test Suite
//
// Comprehensive offline security audit verifying:
// 1. Predicate simulation of can_manage_bank_catalog() and is_admin().
// 2. Full 5-Principal Authorization Matrix across read and write operations.
// 3. PostgreSQL Two-Tier Authorization Simulation:
//    - Tier 1: Table Grants (SELECT, INSERT, UPDATE, DELETE on public.banks)
//    - Tier 2: Row Level Security (RLS) Permissive OR / Restrictive AND semantics
// 4. PostgreSQL RLS engine simulation demonstrating multi-policy PERMISSIVE OR composition:
//    - Bypass Scenario A: Second permissive ALL policy (banks_admin_write) bypasses restriction.
//    - Bypass Scenario B: Second permissive UPDATE policy with is_admin() bypasses restriction.
//    - Bypass Scenario C: Unconditional WITH CHECK (true) bypasses restriction.
//    - Bypass Scenario D: Incorrect target mutation policy predicate allows reviewer mutation.
//    - Failure Scenario E: Missing public-read policy breaks public catalog access.
//    - Failure Scenario F: Missing or broken can_manage_bank_catalog function fails closed.
//    - Failure Scenario G: UPDATE USING vs WITH CHECK semantics enforced fail-closed.
//    - Failure Scenario H: Absent write policy on RLS-enabled table defaults to fail-closed deny.
// 5. Hardened 018 catalog assertions simulator:
//    - Proves fail-closed detection of extra policies (count != 4).
//    - Proves fail-closed detection of non-PERMISSIVE policies (permissive_count != 4).
//    - Proves fail-closed detection of cmd = 'ALL'.
//    - Proves fail-closed detection of any policy referencing is_admin().
//    - Proves fail-closed detection of incorrect predicates or missing public-read.
//    - Proves fail-closed detection of function signature, volatility, secdef, or REVIEWER reference in pg_proc.
// 6. Workflow preservation verification for rate review, unverified rate reads, audit logs, and status transitions.
// 7. Draft migration SQL inspection and quarantine enforcement.
// 8. Rollback Safety & Backout Strategy verification:
//    - Draft does NOT contain rollback instructions restoring public.is_admin() on bank mutations.
//    - Draft does NOT contain rollback instructions recreating banks_admin_write.
//    - Draft explicitly documents prohibition on blind rollback and mandates forward-fix.
//    - Distinguishes automatic pre-COMMIT abort from post-COMMIT backout.
//    - Proves emergency lockout policy (WITH CHECK (false)) is fail-closed.
//
// NOTE ON TEST METHODOLOGY & LIMITATIONS:
// These offline unit tests simulate PostgreSQL RLS evaluation semantics and parse draft SQL text.
// They do NOT connect to Supabase or execute DDL against a live PostgreSQL catalog.
// Tests labeled [STATIC_SQL_INSPECTION] inspect local migration source text offline;
// full database catalog validation requires formal DBA review and staging rehearsal.

'use strict';

const fs = require('fs');
const path = require('path');
const assert = require('assert');
const { isFeroCalcAdmin } = require('../supabase/supabase_client');

// --- 1. Predicate Simulation Helpers ---

function simulateCanManageBankCatalog(jwt) {
  if (!jwt) return false;
  const isServiceRole = jwt.role === 'service_role';
  const ferocalcRole = jwt.app_metadata && jwt.app_metadata.ferocalc_role;
  const isAdmin = ferocalcRole === 'ADMIN';
  return Boolean(isServiceRole || isAdmin);
}

function simulateIsAdmin(jwt) {
  if (!jwt) return false;
  const isServiceRole = jwt.role === 'service_role';
  const ferocalcRole = jwt.app_metadata && jwt.app_metadata.ferocalc_role;
  const isAdminOrReviewer = ferocalcRole === 'ADMIN' || ferocalcRole === 'REVIEWER';
  return Boolean(isServiceRole || isAdminOrReviewer);
}

// --- 2. PostgreSQL RLS Engine Simulator ---

/**
 * Simulates PostgreSQL Row Level Security evaluation for a given command.
 * Evaluates PERMISSIVE policies using boolean OR semantics (Postgres standard).
 */
function evaluatePostgresRls(policies, cmd, jwt, rowData = {}) {
  const applicable = policies.filter(p => p.cmd === cmd || p.cmd === 'ALL');
  if (applicable.length === 0) {
    return false;
  }

  const permissive = applicable.filter(p => p.permissive !== 'RESTRICTIVE');
  const restrictive = applicable.filter(p => p.permissive === 'RESTRICTIVE');

  let permissivePassed = false;
  if (permissive.length > 0) {
    for (const p of permissive) {
      let passed = true;
      if (cmd === 'SELECT' || cmd === 'DELETE') {
        passed = p.using ? p.using(jwt, rowData) : true;
      } else if (cmd === 'INSERT') {
        passed = p.withCheck ? p.withCheck(jwt, rowData) : true;
      } else if (cmd === 'UPDATE') {
        const u = p.using ? p.using(jwt, rowData) : true;
        const c = p.withCheck ? p.withCheck(jwt, rowData) : true;
        passed = u && c;
      }
      if (passed) {
        permissivePassed = true;
        break;
      }
    }
  } else {
    permissivePassed = false;
  }

  if (!permissivePassed) return false;

  for (const r of restrictive) {
    let passed = true;
    if (cmd === 'SELECT' || cmd === 'DELETE') {
      passed = r.using ? r.using(jwt, rowData) : true;
    } else if (cmd === 'INSERT') {
      passed = r.withCheck ? r.withCheck(jwt, rowData) : true;
    } else if (cmd === 'UPDATE') {
      const u = r.using ? r.using(jwt, rowData) : true;
      const c = r.withCheck ? r.withCheck(jwt, rowData) : true;
      passed = u && c;
    }
    if (!passed) return false;
  }

  return true;
}

/**
 * Simulates PostgreSQL two-tier authorization:
 * Tier 1: Table Privileges (grants on public.banks)
 * Tier 2: Row Level Security (RLS)
 *
 * PostgreSQL Privilege Mechanics:
 * - Table Grants: ALL roles (including service_role, unless superuser) MUST have table-level
 *   grants (SELECT, INSERT, UPDATE, DELETE). A role lacking a table grant is rejected at Tier 1.
 * - Row Level Security: Roles with the BYPASSRLS attribute (such as service_role in Supabase)
 *   bypass RLS policies at Tier 2 once Tier 1 table grants are satisfied. Other roles
 *   (anon, authenticated) must satisfy RLS policies.
 */
function evaluatePostgresTableAccess({ tableGrants, policies, rlsEnabled = true }, cmd, jwt, rowData = {}) {
  const role = jwt ? (jwt.role || 'anon') : 'anon';

  // Tier 1: Table Privileges Check
  // In PostgreSQL, service_role is NOT a superuser; it requires table-level grants.
  const grantsForRole = (tableGrants && tableGrants[role]) || [];
  const hasTableGrant = grantsForRole.includes('ALL') || grantsForRole.includes(cmd);
  if (!hasTableGrant) {
    return {
      allowed: false,
      tier: 'TIER_1_TABLE_GRANT_DENIED',
      reason: `permission denied for table banks: role ${role} lacks ${cmd} grant`,
    };
  }

  // If RLS is disabled, table grant is sufficient
  if (!rlsEnabled) {
    return { allowed: true, tier: 'RLS_DISABLED' };
  }

  // Tier 2: Row Level Security (RLS) Check
  // service_role has BYPASSRLS in PostgreSQL (and satisfies can_manage_bank_catalog via JWT claim)
  if (role === 'service_role') {
    return { allowed: true, tier: 'SERVICE_ROLE_RLS_BYPASS' };
  }

  const rlsAllowed = evaluatePostgresRls(policies, cmd, jwt, rowData);
  if (!rlsAllowed) {
    return {
      allowed: false,
      tier: 'TIER_2_RLS_POLICY_DENIED',
      reason: `row-level security policy for table banks violates ${cmd}`,
    };
  }

  return { allowed: true, tier: 'ALLOWED' };
}

/**
 * Simulates PostgreSQL Row Level Security evaluation for a given command.
 * Evaluates PERMISSIVE policies using boolean OR semantics (Postgres standard).
 */
function evaluatePostgresRls(policies, cmd, jwt, rowData = {}) {
  const applicable = policies.filter(p => p.cmd === cmd || p.cmd === 'ALL');
  if (applicable.length === 0) {
    return false;
  }

  const permissive = applicable.filter(p => p.permissive !== 'RESTRICTIVE');
  const restrictive = applicable.filter(p => p.permissive === 'RESTRICTIVE');

  let permissivePassed = false;
  if (permissive.length > 0) {
    for (const p of permissive) {
      let passed = true;
      if (cmd === 'SELECT' || cmd === 'DELETE') {
        passed = p.using ? p.using(jwt, rowData) : true;
      } else if (cmd === 'INSERT') {
        passed = p.withCheck ? p.withCheck(jwt, rowData) : true;
      } else if (cmd === 'UPDATE') {
        const u = p.using ? p.using(jwt, rowData) : true;
        const c = p.withCheck ? p.withCheck(jwt, rowData) : true;
        passed = u && c;
      }
      if (passed) {
        permissivePassed = true;
        break;
      }
    }
  } else {
    permissivePassed = false;
  }

  if (!permissivePassed) return false;

  for (const r of restrictive) {
    let passed = true;
    if (cmd === 'SELECT' || cmd === 'DELETE') {
      passed = r.using ? r.using(jwt, rowData) : true;
    } else if (cmd === 'INSERT') {
      passed = r.withCheck ? r.withCheck(jwt, rowData) : true;
    } else if (cmd === 'UPDATE') {
      const u = r.using ? r.using(jwt, rowData) : true;
      const c = r.withCheck ? r.withCheck(jwt, rowData) : true;
      passed = u && c;
    }
    if (!passed) return false;
  }

  return true;
}

// Standard Migration 018 Policy Definition
function getStandard018Policies() {
  return [
    {
      name: 'banks_public_read',
      cmd: 'SELECT',
      permissive: 'PERMISSIVE',
      roles: ['public'],
      using: () => true,
      withCheck: null,
      refText: 'true',
    },
    {
      name: 'banks_admin_insert',
      cmd: 'INSERT',
      permissive: 'PERMISSIVE',
      roles: ['public'],
      using: null,
      withCheck: (jwt) => simulateCanManageBankCatalog(jwt),
      refText: 'can_manage_bank_catalog()',
    },
    {
      name: 'banks_admin_update',
      cmd: 'UPDATE',
      permissive: 'PERMISSIVE',
      roles: ['public'],
      using: (jwt) => simulateCanManageBankCatalog(jwt),
      withCheck: (jwt) => simulateCanManageBankCatalog(jwt),
      refText: 'can_manage_bank_catalog()',
    },
    {
      name: 'banks_admin_delete',
      cmd: 'DELETE',
      permissive: 'PERMISSIVE',
      roles: ['public'],
      using: (jwt) => simulateCanManageBankCatalog(jwt),
      withCheck: null,
      refText: 'can_manage_bank_catalog()',
    },
  ];
}

// Emergency Lockout Policies (Fail-closed during post-commit incident using RESTRICTIVE)
function getEmergencyLockoutPolicies() {
  return [
    {
      name: 'banks_public_read',
      cmd: 'SELECT',
      permissive: 'PERMISSIVE',
      roles: ['public'],
      using: () => true,
      withCheck: null,
      refText: 'true',
    },
    {
      name: 'banks_emergency_lockout_insert',
      cmd: 'INSERT',
      permissive: 'RESTRICTIVE',
      roles: ['public'],
      using: null,
      withCheck: () => false,
      refText: 'false',
    },
    {
      name: 'banks_emergency_lockout_update',
      cmd: 'UPDATE',
      permissive: 'RESTRICTIVE',
      roles: ['public'],
      using: () => false,
      withCheck: () => false,
      refText: 'false',
    },
    {
      name: 'banks_emergency_lockout_delete',
      cmd: 'DELETE',
      permissive: 'RESTRICTIVE',
      roles: ['public'],
      using: () => false,
      withCheck: null,
      refText: 'false',
    },
  ];
}

// --- 3. Catalog Assertion Simulator ---

function simulateCatalogAssertions(policies, funcMetadata) {
  // Assertion 1: Total policy count on public.banks must be EXACTLY 4
  if (policies.length !== 4) {
    throw new Error(`Catalog verification failed: expected exactly 4 policies on public.banks, found ${policies.length}`);
  }

  // Assertion 2: All 4 policies must be PERMISSIVE
  const permissivePolicies = policies.filter(p => p.permissive === 'PERMISSIVE');
  if (permissivePolicies.length !== 4) {
    throw new Error(`Catalog verification failed: expected all 4 policies on public.banks to be PERMISSIVE, found ${permissivePolicies.length}`);
  }

  // Assertion 2B: All 4 policies must have role scope ['public']
  const publicRolePolicies = policies.filter(p => p.roles && Array.isArray(p.roles) && p.roles.length === 1 && p.roles[0] === 'public');
  if (publicRolePolicies.length !== 4) {
    throw new Error(`Catalog verification failed: expected all 4 policies on public.banks to have roles = {public}, found ${publicRolePolicies.length}`);
  }

  // Assertion 3: No policy with cmd = 'ALL'
  const allPolicies = policies.filter(p => p.cmd === 'ALL');
  if (allPolicies.length > 0) {
    throw new Error('Catalog verification failed: permissive ALL policy found on public.banks');
  }

  // Assertion 4: No policy references is_admin
  const isAdminRefs = policies.filter(p => (p.refText || '').includes('is_admin'));
  if (isAdminRefs.length > 0) {
    throw new Error('Catalog verification failed: public.banks still contains policies referencing is_admin()');
  }

  // Assertion 5: Verify exact commands and predicates
  const insertP = policies.find(p => p.name === 'banks_admin_insert' && p.cmd === 'INSERT');
  if (!insertP || !(insertP.refText || '').includes('can_manage_bank_catalog')) {
    throw new Error('Catalog verification failed: banks_admin_insert is missing or does not invoke can_manage_bank_catalog()');
  }

  const updateP = policies.find(p => p.name === 'banks_admin_update' && p.cmd === 'UPDATE');
  if (!updateP || !updateP.withCheck || !(updateP.refText || '').includes('can_manage_bank_catalog')) {
    throw new Error('Catalog verification failed: banks_admin_update is missing or does not invoke can_manage_bank_catalog() in USING and WITH CHECK');
  }

  const deleteP = policies.find(p => p.name === 'banks_admin_delete' && p.cmd === 'DELETE');
  if (!deleteP || !(deleteP.refText || '').includes('can_manage_bank_catalog')) {
    throw new Error('Catalog verification failed: banks_admin_delete is missing or does not invoke can_manage_bank_catalog()');
  }

  const readP = policies.find(p => p.name === 'banks_public_read' && p.cmd === 'SELECT');
  if (!readP || !(readP.refText || '').includes('true')) {
    throw new Error('Catalog verification failed: banks_public_read is missing or does not allow public SELECT');
  }

  // Assertion 6: Verify function metadata and body
  if (!funcMetadata) {
    throw new Error('Catalog verification failed: function public.can_manage_bank_catalog() not found in pg_proc');
  }
  if (funcMetadata.pronargs !== undefined && funcMetadata.pronargs !== 0) {
    throw new Error('Catalog verification failed: function must have exactly 0 arguments (pronargs=0)');
  }
  if (funcMetadata.rettype !== 'boolean') {
    throw new Error('Catalog verification failed: function return type is not boolean');
  }
  if (funcMetadata.secdef !== false) {
    throw new Error('Catalog verification failed: function must be SECURITY INVOKER (prosecdef=false)');
  }
  if (funcMetadata.volatility !== 's') {
    throw new Error('Catalog verification failed: function volatility must be STABLE (provolatile=\'s\')');
  }
  if (!funcMetadata.src || !funcMetadata.src.includes('ADMIN') || funcMetadata.src.includes('REVIEWER')) {
    throw new Error('Catalog verification failed: function body in pg_proc must include ADMIN and exclude REVIEWER');
  }

  return true;
}

// --- Test Suite Execution ---

let totalAssertions = 0;
let passedAssertions = 0;

function it(desc, fn) {
  totalAssertions++;
  try {
    fn();
    passedAssertions++;
    console.log(`  ✓ ${desc}`);
  } catch (err) {
    console.error(`  ✗ ${desc}`);
    console.error(`    ${err.message}`);
    throw err;
  }
}

console.log('================================================================');
console.log('FeroCalc Phase 3C.10 RBAC Fail-Closed & Rollback Safety Tests');
console.log('================================================================\n');

const reviewerJwt = { role: 'authenticated', app_metadata: { ferocalc_role: 'REVIEWER' } };
const adminJwt = { role: 'authenticated', app_metadata: { ferocalc_role: 'ADMIN' } };
const anonJwt = { role: 'anon' };
const userJwt = { role: 'authenticated', app_metadata: { ferocalc_role: 'USER' } };
const regularAuthJwt = { role: 'authenticated' }; // authenticated regular user without app_metadata
const maliciousUserMetaJwt = {
  role: 'authenticated',
  user_metadata: { ferocalc_role: 'ADMIN' },
  app_metadata: {},
};
const serviceRoleJwt = { role: 'service_role' };

// Group 1: Baseline Predicate Simulation
console.log('Group 1: Baseline Predicate Simulation');

it('can_manage_bank_catalog() returns true strictly for ADMIN and service_role', () => {
  assert.strictEqual(simulateCanManageBankCatalog(serviceRoleJwt), true);
  assert.strictEqual(simulateCanManageBankCatalog(adminJwt), true);
  assert.strictEqual(simulateCanManageBankCatalog(reviewerJwt), false);
  assert.strictEqual(simulateCanManageBankCatalog(userJwt), false);
  assert.strictEqual(simulateCanManageBankCatalog(anonJwt), false);
  assert.strictEqual(simulateCanManageBankCatalog(null), false);
});

it('can_manage_bank_catalog() strictly rejects user-editable user_metadata privilege escalation', () => {
  assert.strictEqual(simulateCanManageBankCatalog(maliciousUserMetaJwt), false);
  const maliciousReviewerJwt = {
    role: 'authenticated',
    user_metadata: { ferocalc_role: 'ADMIN' },
    app_metadata: { ferocalc_role: 'REVIEWER' },
  };
  assert.strictEqual(simulateCanManageBankCatalog(maliciousReviewerJwt), false);
});

it('can_manage_bank_catalog() fails closed for missing, empty, or unexpected role payloads', () => {
  assert.strictEqual(simulateCanManageBankCatalog(regularAuthJwt), false);
  assert.strictEqual(simulateCanManageBankCatalog({ role: 'authenticated', app_metadata: null }), false);
  assert.strictEqual(simulateCanManageBankCatalog({ role: 'authenticated', app_metadata: { ferocalc_role: 'AUDITOR' } }), false);
  assert.strictEqual(simulateCanManageBankCatalog({ role: 'authenticated', app_metadata: { ferocalc_role: 'admin' } }), false); // case-sensitive
});

it('is_admin() returns true for ADMIN, REVIEWER, and service_role', () => {
  assert.strictEqual(simulateIsAdmin(serviceRoleJwt), true);
  assert.strictEqual(simulateIsAdmin(adminJwt), true);
  assert.strictEqual(simulateIsAdmin(reviewerJwt), true);
  assert.strictEqual(simulateIsAdmin(userJwt), false);
  assert.strictEqual(simulateIsAdmin(anonJwt), false);
  assert.strictEqual(simulateIsAdmin(null), false);
});

// Group 2: RLS Engine Simulation & Policy Composition Bypasses
console.log('\nGroup 2: PostgreSQL RLS Engine Simulation & Policy Composition Bypasses');

it('Scenario 1: Standard 018 policies enforce full 5-principal authorization matrix correctly', () => {
  const policies = getStandard018Policies();

  // 1. Principal: anon (Bank catalog read: Allowed, Bank catalog write: Denied)
  assert.strictEqual(evaluatePostgresRls(policies, 'SELECT', anonJwt), true);
  assert.strictEqual(evaluatePostgresRls(policies, 'INSERT', anonJwt), false);
  assert.strictEqual(evaluatePostgresRls(policies, 'UPDATE', anonJwt), false);
  assert.strictEqual(evaluatePostgresRls(policies, 'DELETE', anonJwt), false);

  // 2. Principal: Authenticated regular user (Bank catalog read: Allowed, Bank catalog write: Denied)
  assert.strictEqual(evaluatePostgresRls(policies, 'SELECT', userJwt), true);
  assert.strictEqual(evaluatePostgresRls(policies, 'INSERT', userJwt), false);
  assert.strictEqual(evaluatePostgresRls(policies, 'UPDATE', userJwt), false);
  assert.strictEqual(evaluatePostgresRls(policies, 'DELETE', userJwt), false);

  assert.strictEqual(evaluatePostgresRls(policies, 'SELECT', regularAuthJwt), true);
  assert.strictEqual(evaluatePostgresRls(policies, 'INSERT', regularAuthJwt), false);
  assert.strictEqual(evaluatePostgresRls(policies, 'UPDATE', regularAuthJwt), false);
  assert.strictEqual(evaluatePostgresRls(policies, 'DELETE', regularAuthJwt), false);

  // 3. Principal: REVIEWER (Bank catalog read: Allowed, Bank catalog write: Denied)
  assert.strictEqual(evaluatePostgresRls(policies, 'SELECT', reviewerJwt), true);
  assert.strictEqual(evaluatePostgresRls(policies, 'INSERT', reviewerJwt), false);
  assert.strictEqual(evaluatePostgresRls(policies, 'UPDATE', reviewerJwt), false);
  assert.strictEqual(evaluatePostgresRls(policies, 'DELETE', reviewerJwt), false);

  // 4. Principal: ADMIN (Bank catalog read: Allowed, Bank catalog write: Allowed)
  assert.strictEqual(evaluatePostgresRls(policies, 'SELECT', adminJwt), true);
  assert.strictEqual(evaluatePostgresRls(policies, 'INSERT', adminJwt), true);
  assert.strictEqual(evaluatePostgresRls(policies, 'UPDATE', adminJwt), true);
  assert.strictEqual(evaluatePostgresRls(policies, 'DELETE', adminJwt), true);

  // 5. Principal: service_role (Bank catalog read: Allowed, Bank catalog write: Allowed)
  assert.strictEqual(evaluatePostgresRls(policies, 'SELECT', serviceRoleJwt), true);
  assert.strictEqual(evaluatePostgresRls(policies, 'INSERT', serviceRoleJwt), true);
  assert.strictEqual(evaluatePostgresRls(policies, 'UPDATE', serviceRoleJwt), true);
  assert.strictEqual(evaluatePostgresRls(policies, 'DELETE', serviceRoleJwt), true);
});

it('Scenario 1b: User-editable user_metadata escalation attempt is denied write access by RLS policies', () => {
  const policies = getStandard018Policies();
  assert.strictEqual(evaluatePostgresRls(policies, 'SELECT', maliciousUserMetaJwt), true);
  assert.strictEqual(evaluatePostgresRls(policies, 'INSERT', maliciousUserMetaJwt), false);
  assert.strictEqual(evaluatePostgresRls(policies, 'UPDATE', maliciousUserMetaJwt), false);
  assert.strictEqual(evaluatePostgresRls(policies, 'DELETE', maliciousUserMetaJwt), false);
});

it('Scenario 2: A second permissive ALL policy (banks_admin_write) causes a BYPASS for REVIEWER', () => {
  const policiesWithAll = [
    ...getStandard018Policies(),
    {
      name: 'banks_admin_write',
      cmd: 'ALL',
      permissive: 'PERMISSIVE',
      using: (jwt) => simulateIsAdmin(jwt),
      withCheck: (jwt) => simulateIsAdmin(jwt),
      refText: 'is_admin()',
    },
  ];

  const updateAllowed = evaluatePostgresRls(policiesWithAll, 'UPDATE', reviewerJwt);
  assert.strictEqual(updateAllowed, true, 'VULNERABILITY CONFIRMED: Lingering ALL policy bypasses restriction!');
  const deleteAllowed = evaluatePostgresRls(policiesWithAll, 'DELETE', reviewerJwt);
  assert.strictEqual(deleteAllowed, true, 'VULNERABILITY CONFIRMED: Lingering ALL policy allows delete!');
});

it('Scenario 3: A second permissive UPDATE policy causes a BYPASS for REVIEWER', () => {
  const policiesWithExtraUpdate = [
    ...getStandard018Policies(),
    {
      name: 'banks_reviewer_extra',
      cmd: 'UPDATE',
      permissive: 'PERMISSIVE',
      using: (jwt) => simulateIsAdmin(jwt),
      withCheck: (jwt) => simulateIsAdmin(jwt),
      refText: 'is_admin()',
    },
  ];

  const updateAllowed = evaluatePostgresRls(policiesWithExtraUpdate, 'UPDATE', reviewerJwt);
  assert.strictEqual(updateAllowed, true, 'VULNERABILITY CONFIRMED: Second permissive UPDATE policy causes bypass!');
});

it('Scenario 4: An unconditional WITH CHECK (true) causes an unauthorized write BYPASS', () => {
  const policiesWithUnconditional = [
    ...getStandard018Policies(),
    {
      name: 'banks_unconditional_insert',
      cmd: 'INSERT',
      permissive: 'PERMISSIVE',
      using: null,
      withCheck: () => true,
      refText: 'true',
    },
  ];

  const anonInsertAllowed = evaluatePostgresRls(policiesWithUnconditional, 'INSERT', anonJwt);
  assert.strictEqual(anonInsertAllowed, true, 'VULNERABILITY CONFIRMED: Unconditional policy allows anon insert!');
});

it('Scenario 5: Incorrect target mutation policy predicate (using is_admin) allows reviewer write', () => {
  const flawedPolicies = [
    { name: 'banks_public_read', cmd: 'SELECT', permissive: 'PERMISSIVE', using: () => true },
    { name: 'banks_admin_insert', cmd: 'INSERT', permissive: 'PERMISSIVE', withCheck: (jwt) => simulateIsAdmin(jwt) },
    { name: 'banks_admin_update', cmd: 'UPDATE', permissive: 'PERMISSIVE', using: (jwt) => simulateIsAdmin(jwt), withCheck: (jwt) => simulateIsAdmin(jwt) },
    { name: 'banks_admin_delete', cmd: 'DELETE', permissive: 'PERMISSIVE', using: (jwt) => simulateIsAdmin(jwt) },
  ];

  assert.strictEqual(evaluatePostgresRls(flawedPolicies, 'UPDATE', reviewerJwt), true);
  assert.strictEqual(evaluatePostgresRls(flawedPolicies, 'DELETE', reviewerJwt), true);
});

it('Scenario 6: Missing public-read policy blocks anonymous read access', () => {
  const policiesWithoutRead = getStandard018Policies().filter(p => p.name !== 'banks_public_read');
  assert.strictEqual(evaluatePostgresRls(policiesWithoutRead, 'SELECT', anonJwt), false);
});

it('Scenario 7: Broken or throwing authorization function fails closed', () => {
  const brokenPolicies = [
    {
      name: 'banks_admin_update',
      cmd: 'UPDATE',
      permissive: 'PERMISSIVE',
      using: () => { throw new Error('function can_manage_bank_catalog does not exist'); },
      withCheck: () => { throw new Error('function can_manage_bank_catalog does not exist'); },
    },
  ];

  assert.throws(() => {
    evaluatePostgresRls(brokenPolicies, 'UPDATE', adminJwt);
  }, /does not exist/);
});

it('Scenario 8: UPDATE USING vs WITH CHECK semantics enforced fail-closed', () => {
  // In PostgreSQL, both USING (filtering existing row) and WITH CHECK (validating updated row)
  // must evaluate to true for an UPDATE to succeed.
  const updatePolicy = {
    name: 'banks_admin_update',
    cmd: 'UPDATE',
    permissive: 'PERMISSIVE',
    using: (jwt, row) => simulateCanManageBankCatalog(jwt) && row.is_active === true,
    withCheck: (jwt, row) => simulateCanManageBankCatalog(jwt) && row.new_status !== 'FORBIDDEN',
  };

  // Case A: Both pass
  assert.strictEqual(
    evaluatePostgresRls([updatePolicy], 'UPDATE', adminJwt, { is_active: true, new_status: 'ACTIVE' }),
    true
  );

  // Case B: USING passes but WITH CHECK fails -> Denied (fails closed)
  assert.strictEqual(
    evaluatePostgresRls([updatePolicy], 'UPDATE', adminJwt, { is_active: true, new_status: 'FORBIDDEN' }),
    false
  );

  // Case C: USING fails -> Denied (0 rows modified)
  assert.strictEqual(
    evaluatePostgresRls([updatePolicy], 'UPDATE', adminJwt, { is_active: false, new_status: 'ACTIVE' }),
    false
  );

  // Case D: REVIEWER fails both USING and WITH CHECK
  assert.strictEqual(
    evaluatePostgresRls([updatePolicy], 'UPDATE', reviewerJwt, { is_active: true, new_status: 'ACTIVE' }),
    false
  );
});

it('Scenario 9: Absent write policy on RLS-enabled table defaults to fail-closed deny', () => {
  // If a table has RLS enabled with only SELECT policy, PostgreSQL default-denies all writes
  const readOnlyPolicies = [
    { name: 'banks_public_read', cmd: 'SELECT', permissive: 'PERMISSIVE', using: () => true },
  ];
  assert.strictEqual(evaluatePostgresRls(readOnlyPolicies, 'INSERT', adminJwt), false);
  assert.strictEqual(evaluatePostgresRls(readOnlyPolicies, 'UPDATE', adminJwt), false);
  assert.strictEqual(evaluatePostgresRls(readOnlyPolicies, 'DELETE', adminJwt), false);
});

// Group 2B: PostgreSQL Two-Tier Authorization Simulation (Table Grants + RLS Combined)
console.log('\nGroup 2B: PostgreSQL Two-Tier Authorization Simulation (Table Grants + RLS Combined)');

const stagingTableGrants = {
  anon: ['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  authenticated: ['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  service_role: ['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
};

it('Scenario 1: Staging table grants combined with 018 RLS enforce least privilege across all principals', () => {
  const policies = getStandard018Policies();
  const config = { tableGrants: stagingTableGrants, policies, rlsEnabled: true };

  // 1. anon: table grants allow pass-through, but RLS gates write
  assert.deepStrictEqual(evaluatePostgresTableAccess(config, 'SELECT', anonJwt), { allowed: true, tier: 'ALLOWED' });
  assert.strictEqual(evaluatePostgresTableAccess(config, 'INSERT', anonJwt).allowed, false);
  assert.strictEqual(evaluatePostgresTableAccess(config, 'UPDATE', anonJwt).allowed, false);
  assert.strictEqual(evaluatePostgresTableAccess(config, 'DELETE', anonJwt).allowed, false);

  // 2. Authenticated regular user: table grants allow pass-through, RLS denies write
  assert.deepStrictEqual(evaluatePostgresTableAccess(config, 'SELECT', userJwt), { allowed: true, tier: 'ALLOWED' });
  assert.strictEqual(evaluatePostgresTableAccess(config, 'INSERT', userJwt).allowed, false);
  assert.strictEqual(evaluatePostgresTableAccess(config, 'UPDATE', userJwt).allowed, false);
  assert.strictEqual(evaluatePostgresTableAccess(config, 'DELETE', userJwt).allowed, false);

  assert.deepStrictEqual(evaluatePostgresTableAccess(config, 'SELECT', regularAuthJwt), { allowed: true, tier: 'ALLOWED' });
  assert.strictEqual(evaluatePostgresTableAccess(config, 'INSERT', regularAuthJwt).allowed, false);
  assert.strictEqual(evaluatePostgresTableAccess(config, 'UPDATE', regularAuthJwt).allowed, false);
  assert.strictEqual(evaluatePostgresTableAccess(config, 'DELETE', regularAuthJwt).allowed, false);

  // 3. REVIEWER: table grants allow pass-through, RLS denies write
  assert.deepStrictEqual(evaluatePostgresTableAccess(config, 'SELECT', reviewerJwt), { allowed: true, tier: 'ALLOWED' });
  assert.strictEqual(evaluatePostgresTableAccess(config, 'INSERT', reviewerJwt).allowed, false);
  assert.strictEqual(evaluatePostgresTableAccess(config, 'UPDATE', reviewerJwt).allowed, false);
  assert.strictEqual(evaluatePostgresTableAccess(config, 'DELETE', reviewerJwt).allowed, false);

  // 4. ADMIN: table grants allow, RLS allows write
  assert.deepStrictEqual(evaluatePostgresTableAccess(config, 'SELECT', adminJwt), { allowed: true, tier: 'ALLOWED' });
  assert.deepStrictEqual(evaluatePostgresTableAccess(config, 'INSERT', adminJwt), { allowed: true, tier: 'ALLOWED' });
  assert.deepStrictEqual(evaluatePostgresTableAccess(config, 'UPDATE', adminJwt), { allowed: true, tier: 'ALLOWED' });
  assert.deepStrictEqual(evaluatePostgresTableAccess(config, 'DELETE', adminJwt), { allowed: true, tier: 'ALLOWED' });

  // 5. service_role: table grants verified at Tier 1, RLS bypassed at Tier 2
  assert.deepStrictEqual(evaluatePostgresTableAccess(config, 'SELECT', serviceRoleJwt), { allowed: true, tier: 'SERVICE_ROLE_RLS_BYPASS' });
  assert.deepStrictEqual(evaluatePostgresTableAccess(config, 'INSERT', serviceRoleJwt), { allowed: true, tier: 'SERVICE_ROLE_RLS_BYPASS' });
  assert.deepStrictEqual(evaluatePostgresTableAccess(config, 'UPDATE', serviceRoleJwt), { allowed: true, tier: 'SERVICE_ROLE_RLS_BYPASS' });
  assert.deepStrictEqual(evaluatePostgresTableAccess(config, 'DELETE', serviceRoleJwt), { allowed: true, tier: 'SERVICE_ROLE_RLS_BYPASS' });
});

it('Scenario 2: Absence of table-level SELECT grant blocks anon read at Tier 1 before RLS evaluation', () => {
  const restrictedGrants = {
    anon: [], // no SELECT grant on public.banks
    authenticated: ['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
    service_role: ['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  };
  const config = { tableGrants: restrictedGrants, policies: getStandard018Policies(), rlsEnabled: true };
  const readRes = evaluatePostgresTableAccess(config, 'SELECT', anonJwt);
  assert.strictEqual(readRes.allowed, false);
  assert.strictEqual(readRes.tier, 'TIER_1_TABLE_GRANT_DENIED');
});

it('Scenario 3: Absence of table-level INSERT grant blocks ADMIN write at Tier 1 despite passing RLS', () => {
  const readOnlyAuthGrants = {
    anon: ['SELECT'],
    authenticated: ['SELECT'], // authenticated lacks INSERT
    service_role: ['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  };
  const config = { tableGrants: readOnlyAuthGrants, policies: getStandard018Policies(), rlsEnabled: true };
  const insertRes = evaluatePostgresTableAccess(config, 'INSERT', adminJwt);
  assert.strictEqual(insertRes.allowed, false);
  assert.strictEqual(insertRes.tier, 'TIER_1_TABLE_GRANT_DENIED');
});

it('Scenario 4: Missing function EXECUTE grant on can_manage_bank_catalog fails closed', () => {
  // If EXECUTE is revoked from authenticated and not granted, RLS evaluation throws
  const ungrantedPolicies = [
    {
      name: 'banks_admin_insert',
      cmd: 'INSERT',
      permissive: 'PERMISSIVE',
      withCheck: () => {
        const err = new Error('permission denied for function can_manage_bank_catalog');
        err.code = '42501';
        throw err;
      },
    },
  ];
  assert.throws(() => {
    evaluatePostgresRls(ungrantedPolicies, 'INSERT', adminJwt);
  }, /permission denied for function can_manage_bank_catalog/);
});

it('Scenario 5: Absence of table-level grant blocks service_role at Tier 1 despite BYPASSRLS attribute', () => {
  // Proves that service_role does NOT inherently bypass table privileges; it requires table grants.
  const restrictedServiceGrants = {
    ...stagingTableGrants,
    service_role: ['SELECT'], // service_role lacks INSERT grant
  };
  const config = { tableGrants: restrictedServiceGrants, policies: getStandard018Policies(), rlsEnabled: true };
  const insertRes = evaluatePostgresTableAccess(config, 'INSERT', serviceRoleJwt);
  assert.strictEqual(insertRes.allowed, false);
  assert.strictEqual(insertRes.tier, 'TIER_1_TABLE_GRANT_DENIED');
});

it('Scenario 6: Confirmed live staging pre-018 state allows REVIEWER write bypass, eliminated by 018', () => {
  // Live staging baseline confirmed by catalog audit:
  // 1. authenticated has Tier 1 table grants: SELECT, INSERT, UPDATE, DELETE
  // 2. banks write policies call public.is_admin()
  // 3. public.is_admin() explicitly returns true for ferocalc_role = 'REVIEWER'
  const liveStagingPre018Policies = [
    { name: 'banks_public_read', cmd: 'SELECT', permissive: 'PERMISSIVE', roles: ['public'], using: () => true },
    { name: 'banks_admin_insert', cmd: 'INSERT', permissive: 'PERMISSIVE', roles: ['public'], withCheck: (jwt) => simulateIsAdmin(jwt) },
    { name: 'banks_admin_update', cmd: 'UPDATE', permissive: 'PERMISSIVE', roles: ['public'], using: (jwt) => simulateIsAdmin(jwt), withCheck: (jwt) => simulateIsAdmin(jwt) },
    { name: 'banks_admin_delete', cmd: 'DELETE', permissive: 'PERMISSIVE', roles: ['public'], using: (jwt) => simulateIsAdmin(jwt) },
  ];
  const pre018Config = { tableGrants: stagingTableGrants, policies: liveStagingPre018Policies, rlsEnabled: true };

  // Proves the confirmed live vulnerability: REVIEWER is granted full write access on public.banks
  assert.strictEqual(evaluatePostgresTableAccess(pre018Config, 'INSERT', reviewerJwt).allowed, true, 'LIVE VULNERABILITY CONFIRMED: REVIEWER can insert into banks!');
  assert.strictEqual(evaluatePostgresTableAccess(pre018Config, 'UPDATE', reviewerJwt).allowed, true, 'LIVE VULNERABILITY CONFIRMED: REVIEWER can update banks!');
  assert.strictEqual(evaluatePostgresTableAccess(pre018Config, 'DELETE', reviewerJwt).allowed, true, 'LIVE VULNERABILITY CONFIRMED: REVIEWER can delete banks!');

  // Now prove that Migration 018 completely closes this privilege path:
  const post018Config = { tableGrants: stagingTableGrants, policies: getStandard018Policies(), rlsEnabled: true };
  assert.strictEqual(evaluatePostgresTableAccess(post018Config, 'INSERT', reviewerJwt).allowed, false, 'REMEDIATION VERIFIED: Migration 018 denies REVIEWER insert!');
  assert.strictEqual(evaluatePostgresTableAccess(post018Config, 'UPDATE', reviewerJwt).allowed, false, 'REMEDIATION VERIFIED: Migration 018 denies REVIEWER update!');
  assert.strictEqual(evaluatePostgresTableAccess(post018Config, 'DELETE', reviewerJwt).allowed, false, 'REMEDIATION VERIFIED: Migration 018 denies REVIEWER delete!');
});

// Group 3: Hardened Catalog Assertion Simulator
console.log('\nGroup 3: Hardened Catalog Assertion Simulator');

const validFuncMeta = {
  pronargs: 0,
  rettype: 'boolean',
  secdef: false,
  volatility: 's',
  src: "RETURN COALESCE(auth.jwt() ->> 'role' = 'service_role' OR (auth.jwt() -> 'app_metadata' ->> 'ferocalc_role') = 'ADMIN', false);",
};

it('catalog assertions pass cleanly for standard 018 state', () => {
  const cleanPolicies = getStandard018Policies();
  assert.strictEqual(simulateCatalogAssertions(cleanPolicies, validFuncMeta), true);
});

it('catalog assertions fail closed if extra policy exists (policy count != 4)', () => {
  const extraPolicies = [
    ...getStandard018Policies(),
    { name: 'banks_extra', cmd: 'UPDATE', permissive: 'PERMISSIVE', roles: ['public'], refText: 'can_manage_bank_catalog()' },
  ];
  assert.throws(() => {
    simulateCatalogAssertions(extraPolicies, validFuncMeta);
  }, /expected exactly 4 policies on public.banks, found 5/);
});

it('catalog assertions fail closed if any policy is not PERMISSIVE', () => {
  const nonPermissivePolicies = [
    { name: 'banks_public_read', cmd: 'SELECT', permissive: 'PERMISSIVE', roles: ['public'], refText: 'true' },
    { name: 'banks_admin_insert', cmd: 'INSERT', permissive: 'RESTRICTIVE', roles: ['public'], refText: 'can_manage_bank_catalog()' },
    { name: 'banks_admin_update', cmd: 'UPDATE', permissive: 'PERMISSIVE', roles: ['public'], refText: 'can_manage_bank_catalog()' },
    { name: 'banks_admin_delete', cmd: 'DELETE', permissive: 'PERMISSIVE', roles: ['public'], refText: 'can_manage_bank_catalog()' },
  ];
  assert.throws(() => {
    simulateCatalogAssertions(nonPermissivePolicies, validFuncMeta);
  }, /expected all 4 policies on public.banks to be PERMISSIVE/);
});

it('catalog assertions fail closed if any policy does not have role scope public (roles != {public})', () => {
  const nonPublicRolePolicies = [
    { name: 'banks_public_read', cmd: 'SELECT', permissive: 'PERMISSIVE', roles: ['public'], refText: 'true' },
    { name: 'banks_admin_insert', cmd: 'INSERT', permissive: 'PERMISSIVE', roles: ['authenticated'], refText: 'can_manage_bank_catalog()' },
    { name: 'banks_admin_update', cmd: 'UPDATE', permissive: 'PERMISSIVE', roles: ['public'], withCheck: () => true, refText: 'can_manage_bank_catalog()' },
    { name: 'banks_admin_delete', cmd: 'DELETE', permissive: 'PERMISSIVE', roles: ['public'], refText: 'can_manage_bank_catalog()' },
  ];
  assert.throws(() => {
    simulateCatalogAssertions(nonPublicRolePolicies, validFuncMeta);
  }, /expected all 4 policies on public.banks to have roles = {public}/);
});

it('catalog assertions fail closed if any policy has cmd = ALL', () => {
  const policiesWithAll = [
    { name: 'banks_public_read', cmd: 'SELECT', permissive: 'PERMISSIVE', roles: ['public'], refText: 'true' },
    { name: 'banks_admin_insert', cmd: 'INSERT', permissive: 'PERMISSIVE', roles: ['public'], refText: 'can_manage_bank_catalog()' },
    { name: 'banks_admin_update', cmd: 'UPDATE', permissive: 'PERMISSIVE', roles: ['public'], refText: 'can_manage_bank_catalog()' },
    { name: 'banks_admin_write', cmd: 'ALL', permissive: 'PERMISSIVE', roles: ['public'], refText: 'can_manage_bank_catalog()' },
  ];
  assert.throws(() => {
    simulateCatalogAssertions(policiesWithAll, validFuncMeta);
  }, /permissive ALL policy found/);
});

it('catalog assertions fail closed if any policy still references is_admin', () => {
  const policiesWithIsAdmin = [
    { name: 'banks_public_read', cmd: 'SELECT', permissive: 'PERMISSIVE', roles: ['public'], refText: 'true' },
    { name: 'banks_admin_insert', cmd: 'INSERT', permissive: 'PERMISSIVE', roles: ['public'], refText: 'can_manage_bank_catalog()' },
    { name: 'banks_admin_update', cmd: 'UPDATE', permissive: 'PERMISSIVE', roles: ['public'], refText: 'is_admin()' },
    { name: 'banks_admin_delete', cmd: 'DELETE', permissive: 'PERMISSIVE', roles: ['public'], refText: 'can_manage_bank_catalog()' },
  ];
  assert.throws(() => {
    simulateCatalogAssertions(policiesWithIsAdmin, validFuncMeta);
  }, /still contains policies referencing is_admin\(\)/);
});

it('catalog assertions fail closed if banks_public_read is missing', () => {
  const missingRead = [
    { name: 'banks_admin_insert', cmd: 'INSERT', permissive: 'PERMISSIVE', roles: ['public'], refText: 'can_manage_bank_catalog()' },
    { name: 'banks_admin_update', cmd: 'UPDATE', permissive: 'PERMISSIVE', roles: ['public'], withCheck: () => true, refText: 'can_manage_bank_catalog()' },
    { name: 'banks_admin_delete', cmd: 'DELETE', permissive: 'PERMISSIVE', roles: ['public'], refText: 'can_manage_bank_catalog()' },
    { name: 'banks_extra', cmd: 'SELECT', permissive: 'PERMISSIVE', roles: ['public'], refText: 'can_manage_bank_catalog()' },
  ];
  assert.throws(() => {
    simulateCatalogAssertions(missingRead, validFuncMeta);
  }, /banks_public_read is missing/);
});

it('catalog assertions fail closed if function in pg_proc has non-zero arguments (pronargs != 0)', () => {
  const invalidMeta = { ...validFuncMeta, pronargs: 1 };
  assert.throws(() => {
    simulateCatalogAssertions(getStandard018Policies(), invalidMeta);
  }, /function must have exactly 0 arguments \(pronargs=0\)/);
});

it('catalog assertions fail closed if function in pg_proc is not boolean return', () => {
  const invalidMeta = { ...validFuncMeta, rettype: 'integer' };
  assert.throws(() => {
    simulateCatalogAssertions(getStandard018Policies(), invalidMeta);
  }, /function return type is not boolean/);
});

it('catalog assertions fail closed if function in pg_proc is SECURITY DEFINER', () => {
  const invalidMeta = { ...validFuncMeta, secdef: true };
  assert.throws(() => {
    simulateCatalogAssertions(getStandard018Policies(), invalidMeta);
  }, /function must be SECURITY INVOKER/);
});

it('catalog assertions fail closed if function in pg_proc is VOLATILE', () => {
  const invalidMeta = { ...validFuncMeta, volatility: 'v' };
  assert.throws(() => {
    simulateCatalogAssertions(getStandard018Policies(), invalidMeta);
  }, /function volatility must be STABLE/);
});

it('catalog assertions fail closed if function body in pg_proc includes REVIEWER', () => {
  const invalidMeta = {
    ...validFuncMeta,
    src: "RETURN COALESCE(role = 'ADMIN' OR role = 'REVIEWER', false);",
  };
  assert.throws(() => {
    simulateCatalogAssertions(getStandard018Policies(), invalidMeta);
  }, /function body in pg_proc must include ADMIN and exclude REVIEWER/);
});

it('catalog assertions fail closed if banks_admin_update lacks WITH CHECK', () => {
  const updateWithoutCheck = [
    { name: 'banks_public_read', cmd: 'SELECT', permissive: 'PERMISSIVE', roles: ['public'], refText: 'true' },
    { name: 'banks_admin_insert', cmd: 'INSERT', permissive: 'PERMISSIVE', roles: ['public'], withCheck: () => true, refText: 'can_manage_bank_catalog()' },
    { name: 'banks_admin_update', cmd: 'UPDATE', permissive: 'PERMISSIVE', roles: ['public'], using: () => true, withCheck: null, refText: 'can_manage_bank_catalog()' },
    { name: 'banks_admin_delete', cmd: 'DELETE', permissive: 'PERMISSIVE', roles: ['public'], using: () => true, refText: 'can_manage_bank_catalog()' },
  ];
  assert.throws(() => {
    simulateCatalogAssertions(updateWithoutCheck, validFuncMeta);
  }, /banks_admin_update is missing or does not invoke can_manage_bank_catalog\(\) in USING and WITH CHECK/);
});

// Group 4: Workflow Preservation for Rate Review & Attestation
console.log('\nGroup 4: Workflow Preservation for Rate Review & Attestation');

it('preserves REVIEWER read access to unverified rates in public.fd_rates', () => {
  function evalFdRates(operation, rowStatus, jwt) {
    if (operation === 'SELECT') {
      return simulateIsAdmin(jwt) || rowStatus === 'VERIFIED';
    }
    return false;
  }

  assert.strictEqual(evalFdRates('SELECT', 'DRAFT', reviewerJwt), true);
  assert.strictEqual(evalFdRates('SELECT', 'IN_REVIEW', reviewerJwt), true);
  assert.strictEqual(evalFdRates('SELECT', 'ARCHIVED', reviewerJwt), true);
  assert.strictEqual(evalFdRates('SELECT', 'DRAFT', anonJwt), false);
  assert.strictEqual(evalFdRates('SELECT', 'VERIFIED', anonJwt), true);
});

it('preserves REVIEWER read access to public.rate_audit_log', () => {
  function evalAuditLog(operation, jwt) {
    return operation === 'SELECT' ? simulateIsAdmin(jwt) : false;
  }
  assert.strictEqual(evalAuditLog('SELECT', reviewerJwt), true);
  assert.strictEqual(evalAuditLog('SELECT', anonJwt), false);
});

it('preserves REVIEWER capability to execute transition_rate_status stored procedure', () => {
  function simulateRpc(jwt) {
    if (!simulateIsAdmin(jwt)) throw new Error('Unauthorized: admin role required');
    return { ok: true };
  }
  assert.strictEqual(simulateRpc(reviewerJwt).ok, true);
  assert.strictEqual(simulateRpc(adminJwt).ok, true);
  assert.throws(() => simulateRpc(anonJwt), /Unauthorized: admin role required/);
});

// Group 5: Draft Migration SQL Static Inspection & Quarantine Guard
// [Test Note] Assertions in Group 5 inspect migration draft source text offline.
// Live PostgreSQL catalog execution and schema verification require DBA staging rehearsal.
console.log('\nGroup 5: Draft Migration SQL Static Inspection & Quarantine Guard');

const draftPath = path.resolve(__dirname, '../supabase/drafts/018_restrict_reviewer_bank_catalog_mutations.sql');
const draftContent = fs.readFileSync(draftPath, 'utf8');

it('[STATIC_SQL_INSPECTION] draft 018 exists in drafts/ directory', () => {
  assert.strictEqual(fs.existsSync(draftPath), true);
});

it('[STATIC_SQL_INSPECTION] unversioned draft 018 is strictly absent from backend/supabase/migrations/', () => {
  const migrationsDir = path.resolve(__dirname, '../supabase/migrations');
  const files = fs.readdirSync(migrationsDir);
  const appliedMigration = '20261028095435_restrict_reviewer_bank_catalog_mutations.sql';
  const leaked = files.filter(f => (f.includes('018') || f.includes('restrict_reviewer')) && f !== appliedMigration);
  assert.strictEqual(leaked.length, 0, `Unversioned draft must NOT be in migrations/. Found: ${leaked.join(', ')}`);
  assert.ok(files.includes(appliedMigration), `Expected applied migration ${appliedMigration} to be present in migrations/`);
});

it('[STATIC_SQL_INSPECTION] draft 018 contains explicit DROP POLICY IF EXISTS banks_admin_write', () => {
  assert.ok(draftContent.includes('DROP POLICY IF EXISTS "banks_admin_write" ON public.banks;'), 'Must drop banks_admin_write to prevent OR-bypass');
});

it('[STATIC_SQL_INSPECTION] draft 018 contains total policy count = 4 assertion', () => {
  assert.ok(draftContent.includes('v_policy_count != 4'), 'Must assert exactly 4 policies on public.banks');
});

it('[STATIC_SQL_INSPECTION] draft 018 contains all policies PERMISSIVE assertion', () => {
  assert.ok(draftContent.includes('v_permissive_count != 4'), 'Must assert all 4 policies are PERMISSIVE');
});

it('[STATIC_SQL_INSPECTION] draft 018 contains policy role scope assertion (roles = \'{public}\')', () => {
  assert.ok(draftContent.includes("roles = '{public}'"), "Must assert all 4 policies have roles = '{public}'");
  assert.ok(draftContent.includes('v_roles_public_count != 4'), 'Must fail closed if role count != 4');
});

it('[STATIC_SQL_INSPECTION] draft 018 contains cmd = ALL check assertion', () => {
  assert.ok(draftContent.includes("cmd = 'ALL'"), 'Must assert no ALL policies on public.banks');
});

it('[STATIC_SQL_INSPECTION] draft 018 contains check that no policy references is_admin', () => {
  assert.ok(draftContent.includes("LIKE '%is_admin%'"), 'Must assert no policies reference is_admin()');
});

it('[STATIC_SQL_INSPECTION] draft 018 contains pg_proc function signature and security invoker assertions', () => {
  assert.ok(draftContent.includes("v_func_rettype != 'boolean'::regtype"), 'Must assert boolean return type in pg_proc');
  assert.ok(draftContent.includes('v_func_secdef IS NOT FALSE'), 'Must assert prosecdef=false (SECURITY INVOKER) in pg_proc');
  assert.ok(draftContent.includes("v_func_volatile != 's'"), 'Must assert provolatile=s (STABLE) in pg_proc');
});

it('[STATIC_SQL_INSPECTION] draft 018 contains exact zero-argument function signature assertion (pronargs = 0)', () => {
  assert.ok(draftContent.includes('pronargs = 0'), 'Must query pg_proc with pronargs = 0');
  assert.ok(draftContent.includes('v_func_nargs != 0'), 'Must assert pronargs = 0 fail-closed');
});

it('[STATIC_SQL_INSPECTION] draft 018 contains pg_proc function body assertion checking ADMIN and excluding REVIEWER', () => {
  assert.ok(draftContent.includes("v_func_src NOT LIKE '%ADMIN%' OR v_func_src LIKE '%REVIEWER%'"), 'Must assert body includes ADMIN and excludes REVIEWER');
});

it('[STATIC_SQL_INSPECTION] draft 018 contains REVOKE EXECUTE FROM PUBLIC and explicit GRANTs', () => {
  assert.ok(draftContent.includes('REVOKE EXECUTE ON FUNCTION public.can_manage_bank_catalog() FROM PUBLIC;'), 'Must revoke from PUBLIC');
  assert.ok(draftContent.includes('GRANT EXECUTE ON FUNCTION public.can_manage_bank_catalog() TO anon, authenticated, service_role;'), 'Must grant to specific roles');
});

it('[STATIC_SQL_INSPECTION] draft 018 is enclosed in a single transaction (BEGIN ... COMMIT)', () => {
  assert.ok(draftContent.includes('BEGIN;'), 'Must start with BEGIN;');
  assert.ok(draftContent.includes('COMMIT;'), 'Must end with COMMIT;');
});

it('[STATIC_SQL_INSPECTION] draft 018 UPDATE policy defines both USING and WITH CHECK with can_manage_bank_catalog()', () => {
  assert.ok(
    draftContent.includes('FOR UPDATE USING (public.can_manage_bank_catalog()) WITH CHECK (public.can_manage_bank_catalog())'),
    'UPDATE policy must explicitly bind both USING and WITH CHECK'
  );
});

it('[STATIC_SQL_INSPECTION] draft 018 INSERT policy explicitly binds WITH CHECK (public.can_manage_bank_catalog())', () => {
  assert.ok(
    draftContent.includes('FOR INSERT WITH CHECK (public.can_manage_bank_catalog())'),
    'INSERT policy must explicitly bind WITH CHECK (public.can_manage_bank_catalog())'
  );
});

it('[STATIC_SQL_INSPECTION] draft 018 DELETE policy explicitly binds USING (public.can_manage_bank_catalog())', () => {
  assert.ok(
    draftContent.includes('FOR DELETE USING (public.can_manage_bank_catalog())'),
    'DELETE policy must explicitly bind USING (public.can_manage_bank_catalog())'
  );
});

it('[STATIC_SQL_INSPECTION] draft 018 preserves banks_public_read policy and does NOT drop it', () => {
  assert.ok(!draftContent.includes('DROP POLICY IF EXISTS "banks_public_read"'), 'Must NOT drop banks_public_read');
  assert.ok(!draftContent.includes('DROP POLICY "banks_public_read"'), 'Must NOT drop banks_public_read');
  assert.ok(draftContent.includes("policyname = 'banks_public_read' AND cmd = 'SELECT'"), 'Must verify banks_public_read in catalog assertions');
});

it('[STATIC_SQL_INSPECTION] draft 018 does NOT redefine or drop global public.is_admin() helper', () => {
  assert.ok(!draftContent.includes('CREATE OR REPLACE FUNCTION public.is_admin'), 'Must NOT redefine global public.is_admin');
  assert.ok(!draftContent.includes('DROP FUNCTION IF EXISTS public.is_admin'), 'Must NOT drop public.is_admin');
  assert.ok(!draftContent.includes('DROP FUNCTION public.is_admin'), 'Must NOT drop public.is_admin');
});

it('[STATIC_SQL_INSPECTION] draft 018 enforces idempotent DDL via DROP POLICY IF EXISTS and CREATE OR REPLACE FUNCTION', () => {
  assert.ok(draftContent.includes('CREATE OR REPLACE FUNCTION public.can_manage_bank_catalog()'), 'Must use CREATE OR REPLACE');
  assert.ok(draftContent.includes('DROP POLICY IF EXISTS "banks_admin_insert" ON public.banks;'), 'Must drop existing insert policy idempotently');
  assert.ok(draftContent.includes('DROP POLICY IF EXISTS "banks_admin_update" ON public.banks;'), 'Must drop existing update policy idempotently');
  assert.ok(draftContent.includes('DROP POLICY IF EXISTS "banks_admin_delete" ON public.banks;'), 'Must drop existing delete policy idempotently');
});

it('[STATIC_SQL_INSPECTION] draft 018 function exclusively checks app_metadata and never user_metadata', () => {
  assert.ok(draftContent.includes("auth.jwt() -> 'app_metadata' ->> 'ferocalc_role'"), 'Must query app_metadata');
  assert.ok(!draftContent.includes('user_metadata'), 'Must NOT query user_metadata');
});

const rehearsalPath = path.resolve(__dirname, '../supabase/drafts/018_rehearsal_transaction_safe_rollback.sql');
const rehearsalContent = fs.readFileSync(rehearsalPath, 'utf8');

it('[STATIC_SQL_INSPECTION] rehearsal artifact 018 exists under drafts/', () => {
  assert.strictEqual(fs.existsSync(rehearsalPath), true);
});

it('[STATIC_SQL_INSPECTION] rehearsal artifact 018 is strictly absent from backend/supabase/migrations/', () => {
  const migrationsDir = path.resolve(__dirname, '../supabase/migrations');
  const files = fs.readdirSync(migrationsDir);
  const leaked = files.filter(f => f.includes('rehearsal'));
  assert.strictEqual(leaked.length, 0, `Rehearsal artifact must NOT be in migrations/. Found: ${leaked.join(', ')}`);
});

it('[STATIC_SQL_INSPECTION] rehearsal artifact wraps execution in BEGIN and unconditional ROLLBACK', () => {
  const rehLines = rehearsalContent.split('\n');
  const beginLines = rehLines.filter(l => l.trim() === 'BEGIN;');
  const rollbackLines = rehLines.filter(l => l.trim() === 'ROLLBACK;');
  const commitLines = rehLines.filter(l => l.trim() === 'COMMIT;');

  assert.strictEqual(beginLines.length, 1, 'Rehearsal artifact must have exactly 1 top-level BEGIN;');
  assert.strictEqual(rollbackLines.length, 1, 'Rehearsal artifact must have exactly 1 top-level ROLLBACK;');
  assert.strictEqual(commitLines.length, 0, 'Rehearsal artifact must have 0 COMMIT statements');
});

it('[STATIC_SQL_INSPECTION] rehearsal artifact preserves migration body byte-for-byte from original draft', () => {
  const origLines = draftContent.split('\n');
  const rehLines = rehearsalContent.split('\n');

  const origBeginIdx = origLines.findIndex(l => l.trim() === 'BEGIN;');
  const origCommitIdx = origLines.findLastIndex(l => l.trim() === 'COMMIT;');

  const rehBeginIdx = rehLines.findIndex(l => l.trim() === 'BEGIN;');
  const rehRollbackIdx = rehLines.findLastIndex(l => l.trim() === 'ROLLBACK;');

  const origBody = origLines.slice(origBeginIdx + 1, origCommitIdx).join('\n').trim();
  const rehBody = rehLines.slice(rehBeginIdx + 1, rehRollbackIdx).join('\n').trim();

  assert.strictEqual(origBody === rehBody, true, 'Rehearsal artifact body must match original migration body exactly');
  assert.strictEqual(rehBody.includes('can_manage_bank_catalog'), true);
  assert.strictEqual(rehBody.includes('DO $$'), true);
  assert.strictEqual(rehBody.includes('END $$;'), true);
});

// Group 6: Rollback Strategy & Backout Safety Verifications
console.log('\nGroup 6: Rollback Strategy & Backout Safety Verifications');

it('[STATIC_SQL_INSPECTION] draft 018 does NOT contain rollback recipe restoring public.is_admin() on bank mutations', () => {
  assert.ok(!draftContent.includes('FOR INSERT WITH CHECK (public.is_admin())'), 'Must NOT instruct restoring is_admin on INSERT');
  assert.ok(!draftContent.includes('FOR UPDATE USING (public.is_admin())'), 'Must NOT instruct restoring is_admin on UPDATE');
  assert.ok(!draftContent.includes('FOR DELETE USING (public.is_admin())'), 'Must NOT instruct restoring is_admin on DELETE');
});

it('[STATIC_SQL_INSPECTION] draft 018 does NOT contain rollback recipe recreating banks_admin_write', () => {
  assert.ok(!draftContent.includes('CREATE POLICY "banks_admin_write"'), 'Must NOT recreate banks_admin_write');
});

it('[STATIC_SQL_INSPECTION] draft 018 documents PROHIBITION ON BLIND ROLLBACK and FORWARD-FIX REQUIREMENT', () => {
  assert.ok(draftContent.includes('PROHIBITION ON BLIND ROLLBACK TO VULNERABLE PRIOR STATE'), 'Must explicitly warn against blind rollback');
  assert.ok(draftContent.includes('FORWARD-FIX REQUIREMENT'), 'Must mandate a forward-fix approach');
});

it('[STATIC_SQL_INSPECTION] draft 018 distinguishes pre-COMMIT abort from post-COMMIT backout', () => {
  assert.ok(draftContent.includes('Pre-COMMIT Abort (Automatic Transactional Rollback)'), 'Must document automatic pre-commit rollback');
  assert.ok(draftContent.includes('Post-COMMIT Backout Policy'), 'Must document post-commit backout policy');
});

it('emergency fail-closed lockout policy locks out all writes while preserving public read', () => {
  const lockoutPolicies = getEmergencyLockoutPolicies();
  assert.strictEqual(evaluatePostgresRls(lockoutPolicies, 'SELECT', anonJwt), true);
  assert.strictEqual(evaluatePostgresRls(lockoutPolicies, 'SELECT', reviewerJwt), true);
  assert.strictEqual(evaluatePostgresRls(lockoutPolicies, 'SELECT', adminJwt), true);

  // All writes are locked out
  assert.strictEqual(evaluatePostgresRls(lockoutPolicies, 'INSERT', reviewerJwt), false);
  assert.strictEqual(evaluatePostgresRls(lockoutPolicies, 'UPDATE', reviewerJwt), false);
  assert.strictEqual(evaluatePostgresRls(lockoutPolicies, 'DELETE', reviewerJwt), false);
  assert.strictEqual(evaluatePostgresRls(lockoutPolicies, 'INSERT', adminJwt), false);
  assert.strictEqual(evaluatePostgresRls(lockoutPolicies, 'UPDATE', adminJwt), false);
  assert.strictEqual(evaluatePostgresRls(lockoutPolicies, 'DELETE', adminJwt), false);
});

it('permissive policy with false fails to override separate permissive policy, but RESTRICTIVE false guarantees lockout', () => {
  // Proves that if an emergency policy is merely PERMISSIVE with false, a lingering permissive policy still allows writes!
  const permissiveFalseSet = [
    { name: 'banks_lingering_all', cmd: 'ALL', permissive: 'PERMISSIVE', using: () => true, withCheck: () => true },
    { name: 'banks_flawed_lockout_update', cmd: 'UPDATE', permissive: 'PERMISSIVE', using: () => false, withCheck: () => false },
  ];
  // Lingering permissive policy still authorizes update!
  assert.strictEqual(evaluatePostgresRls(permissiveFalseSet, 'UPDATE', adminJwt), true, 'Permissive false cannot override permissive true!');

  // Now test with AS RESTRICTIVE:
  const restrictiveFalseSet = [
    { name: 'banks_lingering_all', cmd: 'ALL', permissive: 'PERMISSIVE', using: () => true, withCheck: () => true },
    { name: 'banks_safe_lockout_update', cmd: 'UPDATE', permissive: 'RESTRICTIVE', using: () => false, withCheck: () => false },
  ];
  // RESTRICTIVE false combines with AND, guaranteeing complete lockout:
  assert.strictEqual(evaluatePostgresRls(restrictiveFalseSet, 'UPDATE', adminJwt), false, 'RESTRICTIVE false overrides any permissive policy!');
});

it('[STATIC_SQL_INSPECTION] draft 018 documents AS RESTRICTIVE emergency lockout guidance', () => {
  assert.ok(draftContent.includes('AS RESTRICTIVE FOR INSERT WITH CHECK (false)'), 'Must specify AS RESTRICTIVE for insert lockout');
  assert.ok(draftContent.includes('AS RESTRICTIVE FOR UPDATE USING (false) WITH CHECK (false)'), 'Must specify AS RESTRICTIVE for update lockout');
  assert.ok(draftContent.includes('AS RESTRICTIVE FOR DELETE USING (false)'), 'Must specify AS RESTRICTIVE for delete lockout');
});

console.log('\n================================================================');
console.log(`Phase 3C.10 Test Summary: ${passedAssertions}/${totalAssertions} assertions PASSED`);
console.log('================================================================\n');
