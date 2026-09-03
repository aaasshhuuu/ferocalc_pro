// FeroCalc Verified FD Rate Engine
// Supabase client (server-side, uses service role key — NEVER sent to browser)
// All privileged operations (admin writes) use this client.
// Public reads use the anon key via supabasePublic.

'use strict';

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL          = process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY     = process.env.SUPABASE_ANON_KEY;
const SUPABASE_SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  // Non-fatal at startup: the app can still serve legacy JSON rates.
  console.warn('[Supabase] WARNING: SUPABASE_URL or SUPABASE_ANON_KEY not set. ' +
               'Verified rate endpoints will return 503.');
}

/**
 * Public client — uses the anon key.
 * RLS enforces that only VERIFIED rates are visible.
 * Safe to use for public /api/verified-rates queries.
 */
const supabasePublic = SUPABASE_URL && SUPABASE_ANON_KEY
  ? createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: { persistSession: false },
    })
  : null;

/**
 * Admin client — uses the service-role key.
 * Bypasses RLS. MUST NEVER be used in Flutter or exposed to the browser.
 * Used exclusively in admin API routes on the server.
 */
const supabaseAdmin = SUPABASE_URL && SUPABASE_SERVICE_KEY
  ? createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { persistSession: false },
    })
  : null;

/**
 * Returns true if Supabase is configured and available.
 */
const isSupabaseAvailable = () => supabasePublic !== null;

/**
 * Verify an inbound Supabase JWT (for admin dashboard auth).
 * Returns the user or throws on invalid token.
 */
async function verifySupabaseUser(token) {
  if (!supabaseAdmin) throw new Error('Supabase not configured');
  const { data, error } = await supabaseAdmin.auth.getUser(token);
  if (error || !data.user) throw new Error('Invalid or expired token');
  return data.user;
}

/**
 * Check if a verified Supabase user has FeroCalc admin role.
 */
function isFeroCalcAdmin(user) {
  const role = user?.app_metadata?.ferocalc_role;
  return role === 'ADMIN' || role === 'REVIEWER';
}

module.exports = { supabasePublic, supabaseAdmin, isSupabaseAvailable, verifySupabaseUser, isFeroCalcAdmin };
