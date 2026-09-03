# FeroCalc — Verified FD Rate Engine: Admin Setup Guide

## Prerequisites

- A Supabase project created at [supabase.com](https://supabase.com)
- Access to the Supabase SQL Editor
- Access to the Vercel dashboard (for backend env vars)

---

## Step 1: Run Migrations

In the Supabase SQL Editor, run these files **in order**:

```
backend/supabase/migrations/001_create_enums.sql
backend/supabase/migrations/002_create_banks.sql
backend/supabase/migrations/003_create_fd_rates.sql
backend/supabase/migrations/004_create_audit_log.sql
backend/supabase/migrations/005_create_rls_policies.sql
backend/supabase/migrations/006_create_views_and_functions.sql
```

> **Verify**: After 002, run `SELECT * FROM banks;` — you should see 5 rows (SBI, HDFC, ICICI, Axis, Unity SFB).

---

## Step 2: Create the First Admin User

1. Go to **Supabase Dashboard → Authentication → Users → Add user**
2. Create a user with the admin's email and a strong password
3. After creating the user, click the user and go to **User Metadata**
4. Add the following to **App Metadata** (NOT User Metadata):

```json
{
  "ferocalc_role": "ADMIN"
}
```

> **Important**: `app_metadata` is server-controlled. Users cannot modify it. This is what `is_admin()` checks.

---

## Step 3: Configure Backend Environment Variables

In **Vercel Dashboard → Backend project → Settings → Environment Variables**, add:

| Variable                   | Value                                          | Notes                                   |
|---------------------------|------------------------------------------------|-----------------------------------------|
| `SUPABASE_URL`            | `https://your-ref.supabase.co`                | From Project Settings → API             |
| `SUPABASE_ANON_KEY`       | `eyJ...`                                       | From Project Settings → API (anon/public) |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJ...`                                     | **NEVER expose in Flutter** — server-only |

> **Redeploy** the backend after adding these variables.

---

## Step 4: Verify the Public API

After deployment, call:

```
GET /api/verified-rates
```

Expected response when no rates exist yet:
```json
{
  "status": "ok",
  "data": [],
  "meta": {
    "count": 0,
    "source": "verified",
    "note": "All rates are manually verified against official bank sources."
  }
}
```

> This is the correct honest empty state. Do not seed fake rates.

---

## Step 5: Test Admin Authentication

Use a tool like Postman or curl:

```bash
# 1. Get a Supabase JWT (replace with your credentials)
curl -X POST 'https://your-ref.supabase.co/auth/v1/token?grant_type=password' \
  -H 'apikey: YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@ferocalc.in","password":"YOUR_PASSWORD"}'

# 2. Use the access_token to call the admin API
curl -H 'Authorization: Bearer YOUR_ACCESS_TOKEN' \
  https://your-backend.vercel.app/api/admin/rates?status=DRAFT
```

Expected: `{"status":"ok","data":[],"count":0}`

---

## Step 6: Create the First Draft Rate (Maker)

> ⚠️ Do NOT verify any rate until you have manually confirmed it against the official bank source.

```bash
curl -X POST 'https://your-backend.vercel.app/api/admin/rates/draft' \
  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "bank_id": "<UUID from SELECT id FROM banks WHERE short_name='\''SBI'\''>",
    "customer_type": "REGULAR",
    "min_tenure_days": 365,
    "max_tenure_days": 730,
    "min_deposit": 1000,
    "interest_rate": 6.80,
    "is_callable": true,
    "compounding_frequency": "QUARTERLY",
    "effective_from": "2026-01-01T00:00:00.000Z",
    "source_url": "https://sbi.co.in/web/interest-rates/deposit-rates",
    "review_notes": "Rate for 1-2 year regular FD. Verified against sbi.co.in on 2026-09-02."
  }'
```

---

## Step 7: Verify a Rate (Checker)

> ⚠️ Before clicking Verify, confirm the rate on the official source URL.
> Open `source_url` in a browser. Confirm the rate matches exactly.

```bash
# Submit for review first
curl -X PATCH 'https://your-backend.vercel.app/api/admin/rates/{RATE_ID}/transition' \
  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"new_status":"IN_REVIEW","notes":"Ready for checker review"}'

# After review, verify
curl -X PATCH 'https://your-backend.vercel.app/api/admin/rates/{RATE_ID}/transition' \
  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"new_status":"VERIFIED","notes":"Confirmed against sbi.co.in on 2026-09-02"}'
```

The rate will now appear in `GET /api/verified-rates`.

---

## Workflow Reference

```
DRAFT → IN_REVIEW → VERIFIED → ARCHIVED
DRAFT → REJECTED  → DRAFT (correct and resubmit)
IN_REVIEW → DRAFT (send back for correction)
```

**Allowed official source domains** (enforced server-side before VERIFY):
- `sbi.co.in`
- `hdfcbank.com`
- `icicibank.com`
- `axisbank.com`
- `theunitybank.com`

---

## Security Reminders

| Rule | Enforcement |
|------|-------------|
| Service role key never in Flutter | Architecture: only server-side |
| DRAFT/IN_REVIEW never in public API | Supabase RLS + `verified_fd_rates` view |
| Rates can never be deleted | No DELETE RLS policy |
| Audit log is append-only | No UPDATE/DELETE RLS policy |
| Official domain required for VERIFY | `isOfficialDomain()` check in admin router |
