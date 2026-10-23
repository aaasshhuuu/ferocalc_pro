// FeroCalc Verified FD Rate Engine — Distributed Job Lock Manager
//
// Prevents concurrent scheduled/manual pipeline runs and recovers from stale locks.
//
// Safety Guarantees:
// 1. Mutual exclusion: Only one active pipeline runner can hold the lock at a given time.
// 2. Lease-based expiration: Crashed processes do not deadlock future runs (default lease: 15m).
// 3. Fallback support: Uses Supabase rate_pipeline_locks when available, with in-memory fallback.

'use strict';

const { supabaseAdmin, isSupabaseAvailable } = require('../supabase/supabase_client');

const DEFAULT_LOCK_NAME = 'rate_pipeline_global';
const DEFAULT_LEASE_DURATION_MS = 15 * 60 * 1000; // 15 minutes

class JobLockManager {
  constructor(options = {}) {
    this.lockName = options.lockName || DEFAULT_LOCK_NAME;
    this.leaseDurationMs = options.leaseDurationMs || DEFAULT_LEASE_DURATION_MS;
    this.logger = options.logger || console;
    this.allowInMemoryFallback = options.allowInMemoryFallback !== undefined
      ? Boolean(options.allowInMemoryFallback)
      : (!isSupabaseAvailable() && !options.supabaseClient);
    this.useInMemoryOnly = Boolean(options.useInMemoryOnly);
    this.supabaseClient = options.supabaseClient || (isSupabaseAvailable() ? supabaseAdmin : null);

    // In-memory fallback store
    this._inMemoryLock = null;
  }

  /**
   * Attempts to acquire an exclusive lock for the specified jobId.
   *
   * @param {string} jobId - Unique identifier for the executing job
   * @returns {Promise<{ acquired: boolean, isReentrant?: boolean, reclaimedStaleLock?: boolean, reason?: string, existingLock?: Object }>}
   */
  async acquireLock(jobId) {
    if (!jobId) {
      throw new Error('jobId is required to acquire a lock');
    }

    const now = new Date();
    const expiresAt = new Date(now.getTime() + this.leaseDurationMs);

    if (this.useInMemoryOnly || (!this.supabaseClient && this.allowInMemoryFallback)) {
      return this._acquireInMemory(jobId, now, expiresAt);
    }

    if (!this.supabaseClient) {
      return {
        acquired: false,
        reason: 'Database is unavailable and in-memory fallback is disabled (fail-closed)',
      };
    }

    try {
      // 1. Check existing lock in DB
      const { data: existingLock, error: selectError } = await this.supabaseClient
        .from('rate_pipeline_locks')
        .select('*')
        .eq('lock_name', this.lockName)
        .maybeSingle();

      if (selectError) {
        this.logger.warn(`Failed to query rate_pipeline_locks: ${selectError.message}`);
        return {
          acquired: false,
          reason: `Failed to query rate_pipeline_locks: ${selectError.message}`,
        };
      }

      if (existingLock) {
        const lockExpiry = new Date(existingLock.expires_at);
        const isStale = lockExpiry.getTime() <= now.getTime();

        if (!isStale) {
          // Re-entrant acquisition: caller already holds the active lease
          if (existingLock.locked_by_job_id === jobId) {
            return {
              acquired: true,
              isReentrant: true,
              existingLock,
            };
          }

          // Lock is actively held by another process
          return {
            acquired: false,
            reason: `Pipeline is currently running by job "${existingLock.locked_by_job_id}" (acquired at ${existingLock.acquired_at}, expires at ${existingLock.expires_at})`,
            existingLock,
          };
        }

        // Stale lock detected -> atomic conditional reclaim
        this.logger.warn(`Stale pipeline lock detected for job "${existingLock.locked_by_job_id}" (expired at ${existingLock.expires_at}). Reclaiming lock for job "${jobId}".`);

        const { data: updatedRows, error: updateError } = await this.supabaseClient
          .from('rate_pipeline_locks')
          .update({
            locked_by_job_id: jobId,
            acquired_at: now.toISOString(),
            expires_at: expiresAt.toISOString(),
          })
          .eq('lock_name', this.lockName)
          .lte('expires_at', now.toISOString()) // Atomic compare-and-swap predicate
          .select();

        if (updateError) {
          return {
            acquired: false,
            reason: `Failed to reclaim stale lock: ${updateError.message}`,
          };
        }

        if (!updatedRows || updatedRows.length === 0) {
          return {
            acquired: false,
            reason: `Stale lock reclaim race lost: Lock "${this.lockName}" was updated, renewed, or reclaimed concurrently by another process.`,
          };
        }

        return { acquired: true, reclaimedStaleLock: true, previousJobId: existingLock.locked_by_job_id };
      }

      // No lock row exists yet -> insert new lock
      const { data: insertedRows, error: insertError } = await this.supabaseClient
        .from('rate_pipeline_locks')
        .insert([{
          lock_name: this.lockName,
          locked_by_job_id: jobId,
          acquired_at: now.toISOString(),
          expires_at: expiresAt.toISOString(),
        }])
        .select();

      if (insertError) {
        return {
          acquired: false,
          reason: `Lock acquisition race condition: ${insertError.message}`,
        };
      }

      return { acquired: true };
    } catch (err) {
      this.logger.warn(`Lock error: ${err.message}`);
      return {
        acquired: false,
        reason: `Lock acquisition exception: ${err.message}`,
      };
    }
  }

  /**
   * Releases the held lock if locked by the specified jobId.
   * Guarded so an old owner cannot delete a newer owner's lease.
   *
   * @param {string} jobId
   * @returns {Promise<{ released: boolean, reason?: string }>}
   */
  async releaseLock(jobId) {
    if (!jobId) {
      throw new Error('jobId is required to release a lock');
    }

    if (this.useInMemoryOnly || (!this.supabaseClient && this.allowInMemoryFallback)) {
      return this._releaseInMemory(jobId);
    }

    if (!this.supabaseClient) {
      return { released: false, reason: 'Database is unavailable' };
    }

    try {
      // Guarded delete: ONLY delete if lock_name matches AND locked_by_job_id matches jobId.
      const { data: deletedRows, error: deleteError } = await this.supabaseClient
        .from('rate_pipeline_locks')
        .delete()
        .eq('lock_name', this.lockName)
        .eq('locked_by_job_id', jobId)
        .select();

      if (deleteError) {
        this.logger.warn(`Failed to delete lock from DB: ${deleteError.message}`);
        return { released: false, reason: deleteError.message };
      }

      if (!deletedRows || deletedRows.length === 0) {
        this.logger.warn(`Guarded lock release: No lock held by "${jobId}" for "${this.lockName}" (lease may have expired or been reclaimed)`);
        return {
          released: false,
          reason: `Lock not held by "${jobId}" or lease was already expired/reclaimed by another process.`,
        };
      }

      return { released: true };
    } catch (err) {
      this.logger.warn(`DB release error: ${err.message}`);
      return { released: false, reason: `DB release error: ${err.message}` };
    }
  }

  /**
   * Verifies that the lock is currently held by the specified jobId and has not expired.
   *
   * @param {string} jobId
   * @returns {Promise<{ valid: boolean, reason?: string, remainingMs?: number }>}
   */
  async verifyLock(jobId) {
    if (!jobId) {
      throw new Error('jobId is required to verify lock');
    }
    const now = new Date();

    if (this.useInMemoryOnly || (!this.supabaseClient && this.allowInMemoryFallback)) {
      if (!this._inMemoryLock) {
        return { valid: false, reason: 'No active in-memory lock found' };
      }
      if (this._inMemoryLock.jobId !== jobId) {
        return { valid: false, reason: `Lock is held by "${this._inMemoryLock.jobId}", not "${jobId}"` };
      }
      if (this._inMemoryLock.expiresAt.getTime() <= now.getTime()) {
        return { valid: false, reason: 'In-memory lock lease has expired' };
      }
      return { valid: true, remainingMs: this._inMemoryLock.expiresAt.getTime() - now.getTime() };
    }

    if (!this.supabaseClient) {
      return { valid: false, reason: 'Database is unavailable' };
    }

    try {
      const { data: existingLock, error } = await this.supabaseClient
        .from('rate_pipeline_locks')
        .select('*')
        .eq('lock_name', this.lockName)
        .maybeSingle();

      if (error) {
        return { valid: false, reason: `Failed to query lock: ${error.message}` };
      }
      if (!existingLock) {
        return { valid: false, reason: 'No active lock row found in database' };
      }
      if (existingLock.locked_by_job_id !== jobId) {
        return { valid: false, reason: `Lock held by "${existingLock.locked_by_job_id}", not "${jobId}"` };
      }
      const expiry = new Date(existingLock.expires_at);
      if (expiry.getTime() <= now.getTime()) {
        return { valid: false, reason: `Lock lease expired at ${existingLock.expires_at}` };
      }
      return { valid: true, remainingMs: expiry.getTime() - now.getTime() };
    } catch (err) {
      return { valid: false, reason: `Error verifying lock: ${err.message}` };
    }
  }

  /**
   * Safely renews/extends an actively held lock lease.
   *
   * @param {string} jobId
   * @param {number} [extensionMs]
   * @returns {Promise<{ renewed: boolean, expiresAt?: Date, reason?: string }>}
   */
  async renewLock(jobId, extensionMs = this.leaseDurationMs) {
    if (!jobId) throw new Error('jobId is required to renew lock');
    const now = new Date();
    const newExpiresAt = new Date(now.getTime() + extensionMs);

    if (this.useInMemoryOnly || (!this.supabaseClient && this.allowInMemoryFallback)) {
      if (!this._inMemoryLock || this._inMemoryLock.jobId !== jobId) {
        return { renewed: false, reason: 'Lock not held by this jobId' };
      }
      if (this._inMemoryLock.expiresAt.getTime() <= now.getTime()) {
        return { renewed: false, reason: 'Cannot renew expired lock' };
      }
      this._inMemoryLock.expiresAt = newExpiresAt;
      return { renewed: true, expiresAt: newExpiresAt };
    }

    if (!this.supabaseClient) {
      return { renewed: false, reason: 'Database is unavailable' };
    }

    try {
      const { data, error } = await this.supabaseClient
        .from('rate_pipeline_locks')
        .update({
          expires_at: newExpiresAt.toISOString(),
        })
        .eq('lock_name', this.lockName)
        .eq('locked_by_job_id', jobId)
        .gt('expires_at', now.toISOString())
        .select();

      if (error) {
        return { renewed: false, reason: error.message };
      }
      if (!data || data.length === 0) {
        return { renewed: false, reason: 'Lock expired or lost to another process' };
      }
      return { renewed: true, expiresAt: newExpiresAt };
    } catch (err) {
      return { renewed: false, reason: err.message };
    }
  }

  // ----------------------------------------------------------------
  // In-memory fallback implementation (Test / Offline only)
  // ----------------------------------------------------------------

  _acquireInMemory(jobId, now, expiresAt) {
    if (this._inMemoryLock) {
      const isStale = this._inMemoryLock.expiresAt.getTime() <= now.getTime();
      if (!isStale) {
        if (this._inMemoryLock.jobId === jobId) {
          return { acquired: true, isReentrant: true };
        }
        return {
          acquired: false,
          reason: `Pipeline is currently running by job "${this._inMemoryLock.jobId}" (expires at ${this._inMemoryLock.expiresAt.toISOString()})`,
          existingLock: {
            lock_name: this.lockName,
            locked_by_job_id: this._inMemoryLock.jobId,
            acquired_at: this._inMemoryLock.acquiredAt.toISOString(),
            expires_at: this._inMemoryLock.expiresAt.toISOString(),
          },
        };
      }
      this.logger.warn(`Reclaiming stale in-memory lock previously held by "${this._inMemoryLock.jobId}"`);
    }

    this._inMemoryLock = {
      jobId,
      acquiredAt: now,
      expiresAt,
    };

    return { acquired: true };
  }

  _releaseInMemory(jobId) {
    if (!this._inMemoryLock) {
      return { released: true };
    }
    if (this._inMemoryLock.jobId !== jobId) {
      return { released: false, reason: `Lock held by "${this._inMemoryLock.jobId}"` };
    }
    this._inMemoryLock = null;
    return { released: true };
  }

  // Helper for testing: force state
  _setInMemoryLock(jobId, acquiredAt, expiresAt) {
    this._inMemoryLock = { jobId, acquiredAt, expiresAt };
  }
}

module.exports = {
  JobLockManager,
  DEFAULT_LOCK_NAME,
  DEFAULT_LEASE_DURATION_MS,
};
