// FeroCalc Verified FD Rate Engine — Collection Orchestration Service
//
// Responsibilities:
// - Coordinates collection across registered sources
// - Resilient execution: one failed source does not abort the batch
// - Updates rate_sources state in Supabase if DB is reachable
// - Appends collection audit records to source_collection_logs if DB is reachable
// - Structured non-secret logging

'use strict';

const { defaultRegistry } = require('./source_registry');
const { createCollector } = require('./pilot_collectors');
const { MetadataOnlySnapshotStorage } = require('./snapshot_storage');
const { supabaseAdmin, isSupabaseAvailable } = require('../supabase/supabase_client');

class RateCollectionService {
  constructor(options = {}) {
    this.registry = options.registry || defaultRegistry;
    this.storage = options.storage || new MetadataOnlySnapshotStorage();
    this.logger = options.logger || console;
    this.collectorFactory = options.collectorFactory || createCollector;
    this.skipDbPersist = options.skipDbPersist !== undefined ? Boolean(options.skipDbPersist) : false;
    this.supabaseAdmin = options.supabaseAdmin || null;
  }

  /**
   * Log structured telemetry safely (stripping any credentials/tokens).
   */
  _log(level, event, data = {}) {
    const safeData = { ...data };
    delete safeData.token;
    delete safeData.jwt;
    delete safeData.key;
    delete safeData.bodyBuffer;

    const logEntry = JSON.stringify({
      timestamp: new Date().toISOString(),
      service: 'RateCollectionService',
      level,
      event,
      ...safeData,
    });

    if (level === 'error') {
      this.logger.error(logEntry);
    } else {
      this.logger.log(logEntry);
    }
  }

  /**
   * Fetch previous content hash from Supabase or memory.
   */
  async _getPreviousHash(sourceId) {
    if (this.skipDbPersist) {
      return null;
    }
    if (!isSupabaseAvailable() || !supabaseAdmin) {
      return null;
    }
    try {
      const { data, error } = await supabaseAdmin
        .from('rate_sources')
        .select('last_content_hash')
        .eq('id', sourceId)
        .maybeSingle();

      if (error || !data) return null;
      return data.last_content_hash || null;
    } catch {
      return null;
    }
  }

  /**
   * Persist collection result to Supabase if available.
   */
  async _persistResult(result, options = {}) {
    const shouldSkip = this.skipDbPersist ||
      (options.skipDbPersist !== undefined ? Boolean(options.skipDbPersist) : false) ||
      (options.persistResult === false);

    if (shouldSkip) {
      return null;
    }
    const db = options.supabaseAdmin || this.supabaseAdmin || supabaseAdmin;
    const isAvailable = (options.supabaseAdmin || this.supabaseAdmin) ? true : (isSupabaseAvailable() && Boolean(supabaseAdmin));
    if (!isAvailable || !db) {
      return null;
    }

    const parserId = result.parserId || `${result.bankCode.toLowerCase()}_parser`;

    // 1. Update source state in rate_sources
    const { error: upsertErr } = await db
      .from('rate_sources')
      .upsert({
        id: result.sourceId,
        bank_code: result.bankCode,
        source_url: result.sourceUrl,
        source_type: result.sourceType,
        parser_id: parserId,
        parser_version: result.parserVersion,
        last_checked_at: result.fetchedAt,
        last_success_at: result.httpStatus === 200 ? result.fetchedAt : undefined,
        last_content_hash: result.contentHash || undefined,
        last_status: result.status,
        last_error: result.error || null,
        updated_at: new Date().toISOString(),
      }, { onConflict: 'id' });

    if (upsertErr) {
      this._log('error', 'rate_source_upsert_failed', { error: upsertErr.message, sourceId: result.sourceId });
      throw new Error(`Failed to persist rate_source [${result.sourceId}]: ${upsertErr.message}`);
    }

    // 2. Append audit log in source_collection_logs
    const { data: logData, error: logErr } = await db
      .from('source_collection_logs')
      .insert({
        source_id: result.sourceId,
        bank_code: result.bankCode,
        source_url: result.sourceUrl,
        fetched_at: result.fetchedAt,
        http_status: result.httpStatus,
        content_type: result.contentType,
        content_hash: result.contentHash,
        status: result.status,
        changed: result.changed,
        fetch_duration_ms: result.fetchDurationMs,
        byte_size: result.byteLength,
        error_message: result.error,
        parser_version: result.parserVersion,
      })
      .select('id');

    if (logErr) {
      this._log('error', 'source_collection_log_insert_failed', { error: logErr.message, sourceId: result.sourceId });
      throw new Error(`Failed to insert source_collection_log [${result.sourceId}]: ${logErr.message}`);
    }

    return {
      success: true,
      logId: logData && logData[0] ? logData[0].id : null,
    };
  }

  /**
   * Collect a single registered source.
   */
  async collectSource(sourceConfig, options = {}) {
    const collector = this.collectorFactory(sourceConfig);
    const readOnly = options.readOnly === true || this.skipDbPersist ||
      (options.skipDbPersist !== undefined ? Boolean(options.skipDbPersist) : false) ||
      (options.persistResult === false);

    this._log('info', 'collection_started', {
      sourceId: collector.id,
      bankCode: collector.bankCode,
      url: collector.sourceUrl,
    });

    const previousHash = options.previousHash !== undefined
      ? options.previousHash
      : (readOnly ? null : await this._getPreviousHash(collector.id));

    const result = await collector.collect({
      previousHash,
      fetchFunc: options.fetchFunc,
      timeoutMs: options.timeoutMs,
      maxRetries: options.maxRetries,
    });

    // Save snapshot metadata if successful (skipped in read-only / skipDbPersist mode)
    if (!readOnly && result.bodyBuffer && result.contentHash) {
      await this.storage.saveSnapshot({
        sourceId: result.sourceId,
        contentHash: result.contentHash,
        buffer: result.bodyBuffer,
        contentType: result.contentType,
      });
    }

    if (result.status === 'FETCH_FAILED') {
      this._log('error', 'fetch_failed', {
        sourceId: result.sourceId,
        error: result.error,
        durationMs: result.fetchDurationMs,
      });
    } else {
      this._log('info', 'fetch_succeeded', {
        sourceId: result.sourceId,
        status: result.status,
        changed: result.changed,
        hash: result.contentHash,
        bytes: result.byteLength,
        durationMs: result.fetchDurationMs,
      });
    }

    if (!readOnly) {
      const persistResult = await this._persistResult(result, { skipDbPersist: readOnly });
      if (persistResult && persistResult.logId) {
        result.collectionLogId = persistResult.logId;
      }
    }
    return result;
  }

  /**
   * Collect all enabled sources in the registry.
   * Guarantees that failure in one source does not halt the overall run.
   */
  async collectAllEnabledSources(options = {}) {
    const sources = this.registry.getEnabledSources();
    this._log('info', 'batch_collection_started', { totalSources: sources.length });

    const results = [];
    for (const source of sources) {
      try {
        const res = await this.collectSource(source, options);
        results.push(res);
      } catch (err) {
        // Absolute fail-safe: collector itself should not throw, but catch anyway
        this._log('error', 'unexpected_collector_crash', {
          sourceId: source.id,
          error: err.message,
        });
        results.push({
          sourceId: source.id,
          bankCode: source.bankCode,
          sourceUrl: source.sourceUrl,
          sourceType: source.sourceType,
          fetchedAt: new Date().toISOString(),
          httpStatus: null,
          contentHash: null,
          status: 'FETCH_FAILED',
          changed: false,
          error: err.message,
          parserVersion: source.parserVersion,
        });
      }
    }

    const summary = {
      total: results.length,
      firstSeen: results.filter(r => r.status === 'FIRST_SEEN').length,
      unchanged: results.filter(r => r.status === 'UNCHANGED').length,
      changed: results.filter(r => r.status === 'CHANGED').length,
      failed: results.filter(r => r.status === 'FETCH_FAILED').length,
    };

    this._log('info', 'batch_collection_completed', summary);

    return {
      results,
      summary,
    };
  }
}

module.exports = {
  RateCollectionService,
};
