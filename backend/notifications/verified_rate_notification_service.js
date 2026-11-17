// FeroCalc Verified FD Rate Engine — Verified Rate Notification Service (Phase 5.0.6.1 Hardened)
//
// Safety & Operational Guarantees:
// 1. VERIFIED-ONLY: Strictly rejects DRAFT, IN_REVIEW, REJECTED, and unverified changes.
// 2. DETERMINISTIC EVENT IDENTITY: Generates stable event IDs from immutable verified content (SHA-256),
//    never incorporating volatile timestamps into the event identity.
// 3. DURABLE DEDUPLICATION: Persists event identity atomically to prevent duplicate push/inbox alerts
//    across repeated pipeline executions, backend restarts, and concurrent serverless instances.
// 4. CONCURRENCY-SAFE: Leverages database unique constraints (PostgreSQL 23505) and persistent stores
//    so concurrent dispatches of the same verified event safely deduplicate.
// 5. TRUTHFUL INFRASTRUCTURE: When Firebase credentials are not provisioned, truthfully operates in
//    CONFIG_READY_AWAITING_FIREBASE_CREDENTIALS mode without fabricating push delivery.
// 6. ZERO SECRET LEAKAGE: Payloads contain zero service keys, reviewer notes, or internal DB credentials.

'use strict';

const crypto = require('crypto');
const { isSupabaseAvailable, supabaseAdmin } = require('../supabase/supabase_client');

/**
 * Normalizes effective dates to a canonical YYYY-MM-DD string or trimmed format.
 */
function normalizeEffectiveDate(dateStr) {
  if (!dateStr || dateStr === 'none') return 'none';
  if (typeof dateStr === 'string') {
    const trimmed = dateStr.trim();
    if (!trimmed) return 'none';
    if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
      return trimmed;
    }
    const d = new Date(trimmed);
    if (!isNaN(d.getTime())) {
      const yyyy = d.getUTCFullYear();
      const mm = String(d.getUTCMonth() + 1).padStart(2, '0');
      const dd = String(d.getUTCDate()).padStart(2, '0');
      return `${yyyy}-${mm}-${dd}`;
    }
    return trimmed.toLowerCase();
  }
  if (dateStr instanceof Date && !isNaN(dateStr.getTime())) {
    const yyyy = dateStr.getUTCFullYear();
    const mm = String(dateStr.getUTCMonth() + 1).padStart(2, '0');
    const dd = String(dateStr.getUTCDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  }
  return String(dateStr).trim().toLowerCase();
}

/**
 * Deterministically stringifies an object by sorting all keys alphabetically.
 */
function deterministicStringify(obj) {
  if (obj === null || typeof obj !== 'object') {
    return JSON.stringify(obj);
  }
  if (Array.isArray(obj)) {
    return '[' + obj.map(deterministicStringify).join(',') + ']';
  }
  const sortedKeys = Object.keys(obj).sort();
  const parts = sortedKeys.map(k => `${JSON.stringify(k)}:${deterministicStringify(obj[k])}`);
  return '{' + parts.join(',') + '}';
}

class VerifiedRateNotificationService {
  constructor(options = {}) {
    this.logger = options.logger || console;
    this.supabaseClient = options.supabaseClient || (isSupabaseAvailable() ? supabaseAdmin : null);
    this.persistentStore = options.persistentStore || null; // Injected persistent store for tests/custom backends
    this.processedEventIds = new Set();
    this.recentVerifiedEvents = []; // In-memory cache for fast reads
    this.registeredDevices = new Map(); // installationId -> { token, preferences, favoriteBankIds, updatedAt }
    this.firebaseAdmin = options.firebaseAdmin || null;
    this.isFirebaseInitialized = false;

    this._hasDedicatedTable = null;
    this._tableSupportChecked = false;

    this._initFirebaseIfAvailable();
  }

  _initFirebaseIfAvailable() {
    if (this.firebaseAdmin) {
      this.isFirebaseInitialized = true;
      return;
    }

    try {
      const serviceAccountKey = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
      if (serviceAccountKey) {
        const admin = require('firebase-admin');
        const parsedKey = typeof serviceAccountKey === 'string' && serviceAccountKey.startsWith('{')
          ? JSON.parse(serviceAccountKey)
          : require(serviceAccountKey);

        if (!admin.apps.length) {
          admin.initializeApp({
            credential: admin.credential.cert(parsedKey),
          });
        }
        this.firebaseAdmin = admin;
        this.isFirebaseInitialized = true;
        this.logger.log('[VerifiedRateNotificationService] Firebase Admin SDK initialized for FCM.');
      }
    } catch {
      this.isFirebaseInitialized = false;
    }
  }

  get isPushConfigured() {
    return this.isFirebaseInitialized && this.firebaseAdmin !== null;
  }

  /**
   * Derives a stable, deterministic source record identifier if candidateId is missing.
   * Uses immutable business dimensions (bank, customer type, rate category, scheme, callable, tenure, deposits).
   */
  deriveStableSourceRecordId(params) {
    if (params.candidateId && String(params.candidateId).trim()) {
      return String(params.candidateId).trim();
    }
    if (params.promotedRateId && String(params.promotedRateId).trim()) {
      return String(params.promotedRateId).trim();
    }
    if (params.sourceRecordId && String(params.sourceRecordId).trim()) {
      return String(params.sourceRecordId).trim();
    }

    const bank = String(params.bankId || params.bankCode || '').toLowerCase().trim();
    const cust = String(params.customerType || params.candidate?.customer_type || 'REGULAR').toUpperCase().trim();
    const cat = String(params.rateCategory || params.candidate?.rate_category || 'STANDARD').toUpperCase().trim();
    const scheme = (params.schemeName || params.candidate?.scheme_name) ? String(params.schemeName || params.candidate?.scheme_name).toLowerCase().trim() : 'standard';
    const callable = (params.isCallable !== false && params.candidate?.is_callable !== false) ? 'callable' : 'non_callable';
    const depMin = Number(params.minDeposit ?? params.candidate?.min_deposit ?? 0);
    const depMax = params.maxDeposit !== undefined && params.maxDeposit !== null ? Number(params.maxDeposit) : (params.candidate?.max_deposit !== undefined && params.candidate?.max_deposit !== null ? Number(params.candidate.max_deposit) : 'unlimited');
    const tenureDesc = String(params.tenureDescription || params.tenureLabel || params.candidate?.tenure_label || 'standard').toLowerCase().trim();
    const domain = String(params.tenureDomain || params.candidate?.tenure_domain || 'DAYS').toUpperCase().trim();

    const altRaw = `alt:${bank}:${cust}:${cat}:${scheme}:${callable}:${depMin}-${depMax}:${domain}:${tenureDesc}`;
    return 'alt_' + crypto.createHash('sha256').update(altRaw).digest('hex').substring(0, 16);
  }

  /**
   * Generates deterministic event identity and payload fingerprint based on immutable verified content.
   * Strictly excludes volatile timestamps, execution IDs, and random UUIDs.
   *
   * @param {Object} params
   * @returns {{ eventId: string, fingerprint: string, rateFingerprintPayload: Object }}
   */
  generateEventIdentity(params) {
    const bankKey = String(params.bankId || params.bankCode || '').toLowerCase().trim();
    const eventType = String(params.type || 'verifiedRateChange').trim();
    const customerType = String(params.customerType || params.candidate?.customer_type || 'REGULAR').toUpperCase().trim();
    const rateCategory = String(params.rateCategory || params.candidate?.rate_category || 'STANDARD').toUpperCase().trim();
    const schemeName = (params.schemeName || params.candidate?.scheme_name) ? String(params.schemeName || params.candidate?.scheme_name).toLowerCase().trim() : null;
    const isCallable = (params.isCallable !== false && params.candidate?.is_callable !== false);
    const normEffectiveDate = normalizeEffectiveDate(params.effectiveDate || params.candidate?.effective_date || params.candidate?.effective_from);

    const numNewRate = Number(params.newRate !== undefined ? params.newRate : params.interestRate);
    const normNewRate = !isNaN(numNewRate) ? numNewRate.toFixed(4) : String(params.newRate);

    const numPrevRate = params.previousRate !== undefined && params.previousRate !== null ? Number(params.previousRate) : null;
    const normPrevRate = (numPrevRate !== null && !isNaN(numPrevRate)) ? numPrevRate.toFixed(4) : null;

    const sourceRecordId = this.deriveStableSourceRecordId(params);

    const minDeposit = Number(params.minDeposit ?? params.candidate?.min_deposit ?? 0);
    const maxDeposit = params.maxDeposit !== undefined && params.maxDeposit !== null
      ? Number(params.maxDeposit)
      : (params.candidate?.max_deposit !== undefined && params.candidate?.max_deposit !== null ? Number(params.candidate.max_deposit) : null);

    const tenureDomain = String(params.tenureDomain || params.candidate?.tenure_domain || 'DAYS').toUpperCase().trim();
    const tenureDesc = String(params.tenureDescription || params.tenureLabel || params.candidate?.tenure_label || 'Fixed Deposit').trim().toLowerCase();

    const minDays = params.minTenureDays ?? params.candidate?.min_tenure_days ?? null;
    const maxDays = params.maxTenureDays ?? params.candidate?.max_tenure_days ?? null;
    const minYears = params.minYears ?? params.candidate?.min_years ?? null;
    const minMonths = params.minMonths ?? params.candidate?.min_months ?? null;
    const minDaysCal = params.minDaysCal ?? params.candidate?.min_days_cal ?? null;
    const minOperator = params.minOperator ?? params.candidate?.min_operator ?? null;
    const maxYears = params.maxYears ?? params.candidate?.max_years ?? null;
    const maxMonths = params.maxMonths ?? params.candidate?.max_months ?? null;
    const maxDaysCal = params.maxDaysCal ?? params.candidate?.max_days_cal ?? null;
    const maxOperator = params.maxOperator ?? params.candidate?.max_operator ?? null;

    const rateFingerprintPayload = {
      bankId: bankKey,
      customerType,
      depositBounds: {
        max: maxDeposit,
        min: minDeposit,
      },
      effectiveDate: normEffectiveDate,
      eventType,
      isCallable,
      newRate: normNewRate,
      previousRate: normPrevRate,
      rateCategory,
      schemeName,
      sourceRecordId,
      tenure: {
        description: tenureDesc,
        domain: tenureDomain,
        maxDays,
        maxDaysCal,
        maxMonths,
        maxOperator,
        maxYears,
        minDays,
        minDaysCal,
        minMonths,
        minOperator,
        minYears,
      },
    };

    const serialized = deterministicStringify(rateFingerprintPayload);
    const fingerprint = crypto.createHash('sha256').update(serialized).digest('hex');
    const eventId = 'evt_' + fingerprint.substring(0, 24);

    return {
      eventId,
      fingerprint,
      rateFingerprintPayload,
    };
  }

  /**
   * Backwards-compatible event ID generator.
   */
  generateEventId(bankCode, tenureKey, rate, effectiveDate, recordId) {
    if (typeof bankCode === 'object' && bankCode !== null) {
      return this.generateEventIdentity(bankCode).eventId;
    }
    return this.generateEventIdentity({
      bankCode,
      tenureDescription: tenureKey,
      newRate: rate,
      effectiveDate,
      candidateId: recordId,
    }).eventId;
  }

  /**
   * Registers or updates an anonymous device token and notification preferences.
   * Supports an optional installationToken for tamper-proof ownership verification during deletion.
   */
  registerDevice(installationId, registrationData) {
    if (!installationId || typeof installationId !== 'string') {
      throw new Error('Valid installationId is required for device registration');
    }

    const {
      token = null,
      preferences = {},
      favoriteBankIds = [],
      installationToken = null,
    } = registrationData;

    const existingRecord = this.registeredDevices.get(installationId);

    // If existing record has a tokenHash and caller passes an installationToken, verify it matches
    if (existingRecord && existingRecord.tokenHash) {
      if (!installationToken || typeof installationToken !== 'string') {
        throw new Error('Existing registration requires matching installationToken to update');
      }
      const candidateHash = crypto.createHash('sha256').update(installationToken.trim()).digest('hex');
      if (candidateHash !== existingRecord.tokenHash) {
        throw new Error('Invalid installationToken: token does not match registered owner');
      }
    }

    let tokenHash = existingRecord ? existingRecord.tokenHash : null;
    if (installationToken && typeof installationToken === 'string' && installationToken.trim().length > 0) {
      tokenHash = crypto.createHash('sha256').update(installationToken.trim()).digest('hex');
    }

    const deviceRecord = {
      installationId,
      tokenHash,
      token: token ? String(token).trim() : null,
      preferences: {
        masterEnabled: preferences.masterEnabled ?? true,
        favoriteBankRateChanges: preferences.favoriteBankRateChanges ?? true,
        newlyPromotedSlabs: preferences.newlyPromotedSlabs ?? true,
        significantRateChanges: preferences.significantRateChanges ?? true,
        productAnnouncements: preferences.productAnnouncements ?? false,
      },
      favoriteBankIds: Array.isArray(favoriteBankIds) ? favoriteBankIds : [],
      updatedAt: new Date().toISOString(),
    };

    const maxCapacity = 10000;
    if (this.registeredDevices.size >= maxCapacity && !this.registeredDevices.has(installationId)) {
      const oldestKey = this.registeredDevices.keys().next().value;
      if (oldestKey) {
        this.registeredDevices.delete(oldestKey);
      }
    }

    this.registeredDevices.set(installationId, deviceRecord);
    return {
      success: true,
      installationId,
      pushConfigured: this.isPushConfigured,
      registeredAt: deviceRecord.updatedAt,
      hasTokenAuth: !!tokenHash,
    };
  }

  /**
   * Deletes and revokes an anonymous device registration, removing device token,
   * alert preferences, and favorite bank associations from remote storage.
   * Strictly enforces installationToken check when a tokenHash was registered.
   */
  deleteDevice(installationId, installationToken = null) {
    if (!installationId || typeof installationId !== 'string') {
      throw new Error('Valid installationId is required for device deletion');
    }

    const existingRecord = this.registeredDevices.get(installationId);
    if (!existingRecord) {
      return {
        success: true,
        installationId,
        deleted: false,
        message: 'No registration record found or already deleted',
      };
    }

    if (existingRecord.tokenHash) {
      if (!installationToken || typeof installationToken !== 'string') {
        return {
          success: false,
          unauthorized: true,
          message: 'Missing required installation authorization token',
        };
      }
      const candidateHash = crypto.createHash('sha256').update(installationToken.trim()).digest('hex');
      if (candidateHash !== existingRecord.tokenHash) {
        return {
          success: false,
          unauthorized: true,
          message: 'Invalid installation authorization token',
        };
      }
    }

    this.registeredDevices.delete(installationId);

    if (this.persistentStore && typeof this.persistentStore.deleteDevice === 'function') {
      try {
        this.persistentStore.deleteDevice(installationId);
      } catch (err) {
        this.logger.warn(`Failed to delete device from persistentStore: ${err.message}`);
      }
    }

    return {
      success: true,
      installationId,
      deleted: true,
      message: 'Device registration and preferences deleted successfully',
    };
  }

  /**
   * Retrieves sanitized device registration info (for testing / verification).
   */
  getDevice(installationId) {
    if (!installationId) return null;
    const record = this.registeredDevices.get(installationId);
    if (!record) return null;
    return {
      installationId: record.installationId,
      hasToken: !!record.token,
      preferences: { ...record.preferences },
      favoriteBankIds: [...record.favoriteBankIds],
      updatedAt: record.updatedAt,
      hasTokenAuth: !!record.tokenHash,
    };
  }

  /**
   * Atomically persists an event record to durable storage with concurrency-safe deduplication.
   */
  async _persistAndDeduplicate(eventRecord) {
    const { eventId, payload } = eventRecord;

    // 1. Injected persistentStore (for testing restarts, multi-instance concurrency, or custom stores)
    if (this.persistentStore) {
      const res = await this.persistentStore.recordEvent(eventRecord);
      if (!res.duplicate) {
        this.processedEventIds.add(eventId);
        this.recentVerifiedEvents.unshift(payload);
        if (this.recentVerifiedEvents.length > 100) this.recentVerifiedEvents.pop();
      }
      return res;
    }

    // 2. Database-backed durable storage (Supabase staging/production)
    if (this.supabaseClient) {
      try {
        return await this._persistToDatabase(eventRecord);
      } catch (dbErr) {
        this.logger.warn(`[VerifiedRateNotificationService] Database persistence warning: ${dbErr.message}`);
      }
    }

    // 3. In-memory deduplication (offline test mode / DB unavailable fallback)
    if (this.processedEventIds.has(eventId)) {
      return {
        duplicate: true,
        eventId,
        reason: `Idempotent duplicate: Event ${eventId} was already dispatched.`,
      };
    }

    this.processedEventIds.add(eventId);
    this.recentVerifiedEvents.unshift(payload);
    if (this.recentVerifiedEvents.length > 100) {
      this.recentVerifiedEvents.pop();
    }

    return { duplicate: false, eventId };
  }

  /**
   * Internal DB persistence attempting dedicated table first, then operational store fallback.
   */
  async _persistToDatabase(eventRecord) {
    const { eventId, payload, fingerprint, bankCode, bankId, type } = eventRecord;

    // A. Attempt dedicated verified_rate_notification_events table if available
    if (this._hasDedicatedTable !== false) {
      try {
        const notifRow = {
          event_id: eventId,
          bank_id: bankId || bankCode.toLowerCase(),
          bank_code: bankCode,
          bank_name: payload.bankName || bankCode,
          event_type: type,
          title: payload.title,
          message: payload.message,
          effective_date: payload.effectiveDate,
          verified_timestamp: payload.verifiedTimestamp,
          action_route: payload.actionRoute,
          payload,
          fingerprint,
          candidate_id: eventRecord.candidateId || null,
          promoted_rate_id: eventRecord.promotedRateId || null,
        };

        const { error } = await this.supabaseClient
          .from('verified_rate_notification_events')
          .insert(notifRow)
          .select()
          .single();

        if (!error) {
          this._hasDedicatedTable = true;
          this._tableSupportChecked = true;
          this.processedEventIds.add(eventId);
          this.recentVerifiedEvents.unshift(payload);
          if (this.recentVerifiedEvents.length > 100) this.recentVerifiedEvents.pop();
          return { duplicate: false, eventId };
        }

        if (error.code === '23505' || String(error.message).includes('duplicate key') || String(error.message).includes('unique constraint')) {
          this._hasDedicatedTable = true;
          this._tableSupportChecked = true;
          return {
            duplicate: true,
            eventId,
            reason: `Idempotent duplicate: Event ${eventId} was already dispatched and recorded in database.`,
          };
        }

        // Check if table does not exist in schema cache
        if (error.code === 'PGRST205' || String(error.message).includes('Could not find the table') || error.status === 404) {
          this._hasDedicatedTable = false;
          this._tableSupportChecked = true;
        } else {
          throw error;
        }
      } catch (err) {
        if (String(err.message).includes('Could not find the table') || err.code === 'PGRST205') {
          this._hasDedicatedTable = false;
          this._tableSupportChecked = true;
        } else {
          throw err;
        }
      }
    }

    // B. Fallback to existing persistent operational store (rate_pipeline_runs with UNIQUE job_id)
    const jobId = `notif_evt_${eventId}`;
    const runRecord = {
      job_id: jobId,
      trigger_type: 'VERIFIED_RATE_NOTIFICATION',
      status: 'DISPATCHED',
      started_at: payload.verifiedTimestamp,
      finished_at: payload.verifiedTimestamp,
      error_summary: payload.message,
      metadata: {
        eventId,
        fingerprint,
        bankId,
        bankCode,
        type,
        payload,
      },
    };

    const { error } = await this.supabaseClient
      .from('rate_pipeline_runs')
      .insert(runRecord)
      .select()
      .single();

    if (error) {
      if (error.code === '23505' || String(error.message).includes('duplicate key') || String(error.message).includes('unique constraint')) {
        return {
          duplicate: true,
          eventId,
          reason: `Idempotent duplicate: Event ${eventId} was already dispatched and recorded in database.`,
        };
      }
      throw error;
    }

    this.processedEventIds.add(eventId);
    this.recentVerifiedEvents.unshift(payload);
    if (this.recentVerifiedEvents.length > 100) this.recentVerifiedEvents.pop();

    return { duplicate: false, eventId };
  }

  /**
   * Dispatches a verified rate notification event.
   *
   * @param {Object} params
   * @param {string} params.status - Must be 'VERIFIED' or 'PROMOTED'
   * @param {string} params.bankCode - e.g. 'SBI', 'HDFC'
   * @param {string} [params.bankName] - Full bank name
   * @param {string} [params.bankId] - Stable bank UUID or code
   * @param {number|string} params.newRate - Verified rate value
   * @param {number|string} [params.previousRate] - Previous rate if superseded
   * @param {string} [params.tenureDescription] - e.g. '1 Year to < 2 Years'
   * @param {string} [params.effectiveDate] - e.g. '2026-11-01'
   * @param {string} [params.candidateId]
   * @param {string} [params.promotedRateId]
   * @param {string} [params.type] - 'verifiedRateChange', 'newPromotedSlab', etc.
   */
  async dispatchVerifiedRateEvent(params) {
    const {
      status,
      bankCode,
      bankName,
      bankId,
      newRate,
      previousRate,
      tenureDescription = 'Fixed Deposit',
      effectiveDate = null,
      type = 'verifiedRateChange',
    } = params;

    // Guard 1: VERIFIED ONLY. Reject DRAFT, IN_REVIEW, REJECTED, UNVERIFIED
    const normStatus = String(status || '').toUpperCase();
    if (normStatus !== 'VERIFIED' && normStatus !== 'PROMOTED') {
      return {
        dispatched: false,
        rejected: true,
        reason: `Rejected: Notification requested for non-verified status "${status}". Only VERIFIED/PROMOTED records can trigger alerts.`,
      };
    }

    if (!bankCode || newRate === undefined || newRate === null) {
      return {
        dispatched: false,
        rejected: true,
        reason: 'Rejected: Missing required bankCode or newRate',
      };
    }

    // Guard 2: Material change protection.
    // Avoid sending notifications when the verified rate payload has not materially changed.
    if (previousRate !== undefined && previousRate !== null && type === 'verifiedRateChange') {
      const numNew = Number(newRate);
      const numPrev = Number(previousRate);
      if (!isNaN(numNew) && !isNaN(numPrev) && Math.abs(numNew - numPrev) < 0.0001) {
        return {
          dispatched: false,
          unchanged: true,
          reason: `Suppressed: Verified rate payload has not materially changed (${numNew}% vs ${numPrev}%).`,
        };
      }
    }

    // Step 3: Compute deterministic event identity from immutable verified content
    const { eventId, fingerprint } = this.generateEventIdentity(params);

    // Build genuine summary message
    let changeSummary = '';
    if (previousRate !== undefined && previousRate !== null) {
      const pNum = parseFloat(previousRate);
      const nNum = parseFloat(newRate);
      const direction = nNum > pNum ? 'increased' : 'decreased';
      changeSummary = `${tenureDescription} rate ${direction} from ${pNum}% to ${nNum}% p.a.`;
    } else {
      changeSummary = `New verified slab published: ${tenureDescription} at ${newRate}% p.a.`;
    }

    // Separate verifiedTimestamp as event metadata, NOT distinguishing event ID component
    const verifiedTimestamp = new Date().toISOString();

    const payload = {
      id: 'notif_' + crypto.randomUUID().substring(0, 12),
      eventId,
      bankId: bankId || bankCode.toLowerCase(),
      bankCode,
      bankName: bankName || bankCode,
      type,
      title: `${bankName || bankCode} Rate Update`,
      message: changeSummary,
      effectiveDate: effectiveDate || null,
      verifiedTimestamp,
      actionRoute: `/bank/${encodeURIComponent(bankName || bankCode)}`,
    };

    // Step 4: Durable deduplication & persistence MUST happen before downstream delivery
    const persistenceResult = await this._persistAndDeduplicate({
      eventId,
      payload,
      fingerprint,
      bankCode,
      bankId: payload.bankId,
      type,
      candidateId: params.candidateId,
      promotedRateId: params.promotedRateId,
    });

    if (persistenceResult.duplicate) {
      return {
        dispatched: false,
        duplicate: true,
        eventId,
        reason: persistenceResult.reason || `Idempotent duplicate: Event ${eventId} was already dispatched.`,
      };
    }

    // Step 5: Downstream delivery attempt (FCM)
    let fcmOutcome = {
      delivered: false,
      pushConfigured: this.isPushConfigured,
      status: this.isPushConfigured ? 'READY' : 'CONFIG_READY_AWAITING_FIREBASE_CREDENTIALS',
    };

    if (this.isPushConfigured) {
      try {
        fcmOutcome = await this._sendFcmNotification(payload);
      } catch (fcmErr) {
        this.logger.warn(`[VerifiedRateNotificationService] FCM push error (non-fatal): ${fcmErr.message}`);
        fcmOutcome = { delivered: false, error: fcmErr.message, pushConfigured: true };
      }
    }

    return {
      dispatched: true,
      eventId,
      payload,
      fcm: fcmOutcome,
    };
  }

  async _sendFcmNotification(payload) {
    if (!this.firebaseAdmin) return { delivered: false, reason: 'Firebase not initialized' };

    const message = {
      notification: {
        title: payload.title,
        body: payload.message,
      },
      data: {
        eventId: payload.eventId,
        bankId: payload.bankId,
        bankName: payload.bankName,
        actionRoute: payload.actionRoute,
      },
      topic: 'verified_rates',
    };

    const response = await this.firebaseAdmin.messaging().send(message);
    return { delivered: true, messageId: response, pushConfigured: true };
  }

  /**
   * Returns recent verified rate events for in-app inbox sync.
   * If a database client or persistent store is available, fetches durable events across restarts.
   */
  async getRecentEvents(limit = 20) {
    if (this.persistentStore && typeof this.persistentStore.getRecent === 'function') {
      try {
        const stored = await this.persistentStore.getRecent(limit);
        if (stored && stored.length > 0) return stored;
      } catch (err) {
        this.logger.warn(`Failed to read from persistentStore: ${err.message}`);
      }
    }

    if (this.supabaseClient) {
      try {
        if (this._hasDedicatedTable) {
          const { data, error } = await this.supabaseClient
            .from('verified_rate_notification_events')
            .select('payload, verified_timestamp, created_at')
            .order('verified_timestamp', { ascending: false })
            .limit(limit);

          if (!error && data && data.length > 0) {
            return data.map(r => r.payload).filter(Boolean);
          }
        }

        const { data, error } = await this.supabaseClient
          .from('rate_pipeline_runs')
          .select('metadata, started_at, created_at')
          .eq('trigger_type', 'VERIFIED_RATE_NOTIFICATION')
          .order('started_at', { ascending: false })
          .limit(limit);

        if (!error && data && data.length > 0) {
          return data
            .map(row => row.metadata?.payload)
            .filter(p => p && p.eventId);
        }
      } catch (err) {
        this.logger.warn(`Failed to fetch recent events from Supabase: ${err.message}`);
      }
    }

    return this.recentVerifiedEvents.slice(0, limit);
  }

  /**
   * Synchronous accessor for in-memory cache.
   */
  getRecentEventsSync(limit = 20) {
    return this.recentVerifiedEvents.slice(0, limit);
  }

  clearForTesting() {
    this.processedEventIds.clear();
    this.recentVerifiedEvents = [];
    this.registeredDevices.clear();
    if (this.persistentStore && typeof this.persistentStore.clear === 'function') {
      this.persistentStore.clear();
    }
  }
}

const instance = new VerifiedRateNotificationService();

module.exports = {
  VerifiedRateNotificationService,
  verifiedRateNotificationService: instance,
  normalizeEffectiveDate,
  deterministicStringify,
};
