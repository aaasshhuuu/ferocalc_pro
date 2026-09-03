-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 001: Enums
-- ============================================================
-- Run this FIRST before any table migrations.

-- Rate verification lifecycle states
CREATE TYPE rate_status AS ENUM (
  'DRAFT',
  'IN_REVIEW',
  'VERIFIED',
  'REJECTED',
  'ARCHIVED'
);

-- Customer category (determines rate tier at bank)
CREATE TYPE customer_type AS ENUM (
  'REGULAR',
  'SENIOR_CITIZEN',
  'SUPER_SENIOR_CITIZEN',
  'STAFF',
  'NRE',
  'NRO'
);

-- Compounding frequency for maturity calculation
CREATE TYPE compounding_frequency AS ENUM (
  'MONTHLY',
  'QUARTERLY',
  'HALF_YEARLY',
  'ANNUALLY',
  'AT_MATURITY'
);

-- Bank operational status
CREATE TYPE bank_status AS ENUM (
  'ACTIVE',
  'MERGED',
  'ACQUIRED',
  'INACTIVE',
  'ARCHIVED'
);

-- Bank category (RBI classification)
CREATE TYPE bank_type AS ENUM (
  'PUBLIC',
  'PRIVATE',
  'SMALL_FINANCE',
  'FOREIGN',
  'COOPERATIVE',
  'PAYMENT'
);

-- Audit action types
CREATE TYPE audit_action AS ENUM (
  'CREATE',
  'EDIT',
  'SUBMIT_FOR_REVIEW',
  'VERIFY',
  'REJECT',
  'ARCHIVE',
  'UNARCHIVE'
);
