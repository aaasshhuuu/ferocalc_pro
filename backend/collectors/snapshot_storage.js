// FeroCalc Verified FD Rate Engine — Snapshot Storage Interface
//
// Pluggable snapshot storage abstraction.
// Phase 1 provides in-memory / metadata-only storage, designed so Supabase Storage
// (or S3/Cloud Storage) can be attached seamlessly in later phases.
//
// Rules:
// - Never fakes a public or remote URL.
// - Persists content metadata, hash, and payload length.

'use strict';

class SnapshotStorage {
  /**
   * Save a snapshot of collected content.
   *
   * @param {Object} params
   * @param {string} params.sourceId
   * @param {string} params.contentHash
   * @param {Buffer} params.buffer
   * @param {string} params.contentType
   * @returns {Promise<SnapshotRecord>}
   */
  async saveSnapshot(params) {
    throw new Error('saveSnapshot() must be implemented by subclass');
  }

  /**
   * Retrieve snapshot metadata by hash.
   *
   * @param {string} contentHash
   * @returns {Promise<SnapshotRecord|null>}
   */
  async getSnapshotMetadata(contentHash) {
    throw new Error('getSnapshotMetadata() must be implemented by subclass');
  }
}

/**
 * Metadata-only implementation for Phase 1.
 * Stores hash, byte count, and timestamp without writing full blobs to persistent disk.
 */
class MetadataOnlySnapshotStorage extends SnapshotStorage {
  constructor() {
    super();
    this._snapshots = new Map();
  }

  async saveSnapshot({ sourceId, contentHash, buffer, contentType }) {
    const record = {
      sourceId,
      contentHash,
      byteLength: buffer ? buffer.length : 0,
      contentType: contentType || 'application/octet-stream',
      storedAt: new Date().toISOString(),
      storageType: 'metadata_only',
      storageUri: null, // Explicitly null: no fake URL
    };
    this._snapshots.set(contentHash, record);
    return record;
  }

  async getSnapshotMetadata(contentHash) {
    return this._snapshots.get(contentHash) || null;
  }
}

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

/**
 * Content-addressed, verifiable snapshot storage for future collections.
 * Stores normalized content bytes, optional raw responses, and provenance metadata.
 * Validates that normalized bytes cryptographically reproduce the contentHash.
 */
class ContentAddressedSnapshotStorage extends SnapshotStorage {
  /**
   * @param {Object} options
   * @param {string} [options.storageDir] Local filesystem directory for storing snapshots
   * @param {boolean} [options.inMemoryOnly=false] For isolated unit testing
   */
  constructor(options = {}) {
    super();
    this.inMemoryOnly = Boolean(options.inMemoryOnly);
    this.storageDir = options.storageDir || path.join(__dirname, '../data/snapshots');
    this._inMemorySnapshots = new Map();

    if (!this.inMemoryOnly) {
      if (!fs.existsSync(this.storageDir)) {
        fs.mkdirSync(this.storageDir, { recursive: true });
      }
      // Ensure private/ignored storage location by creating a .gitignore if absent
      const gitignorePath = path.join(this.storageDir, '.gitignore');
      if (!fs.existsSync(gitignorePath)) {
        fs.writeFileSync(gitignorePath, '*\n!.gitignore\n', 'utf8');
      }
    }
  }

  /**
   * Saves a content-addressed snapshot of collected and normalized content.
   * Verifies that the normalized buffer produces the expected contentHash.
   *
   * @param {Object} params
   * @param {string} params.sourceId
   * @param {string} params.contentHash
   * @param {Buffer|string} params.normalizedContent - The exact bytes hashed
   * @param {Buffer|string} [params.rawContent] - Optional raw response bytes
   * @param {string} [params.contentType='text/html; charset=utf-8']
   * @param {string} [params.sourceUrl]
   * @param {string} [params.bankCode]
   * @param {string} [params.effectiveFrom]
   * @param {string} [params.fetchedAt]
   * @param {string} [params.normalizerVersion='1.0.0']
   * @param {string} [params.parserVersion='1.0.0']
   * @returns {Promise<Object>}
   */
  async saveSnapshot(params) {
    const {
      sourceId,
      contentHash,
      normalizedContent,
      rawContent,
      contentType = 'text/html; charset=utf-8',
      sourceUrl,
      bankCode,
      effectiveFrom,
      fetchedAt = new Date().toISOString(),
      normalizerVersion = '1.0.0',
      parserVersion = '1.0.0',
    } = params;

    if (!sourceId || !contentHash || !normalizedContent) {
      throw new Error('sourceId, contentHash, and normalizedContent are required to save snapshot');
    }

    const normBuffer = Buffer.isBuffer(normalizedContent)
      ? normalizedContent
      : Buffer.from(normalizedContent, 'utf8');

    // Cryptographic verification: Assert that normalized bytes reproduce the contentHash
    const computedHash = crypto.createHash('sha256').update(normBuffer).digest('hex');
    if (computedHash.toLowerCase() !== contentHash.toLowerCase()) {
      throw new Error(`Snapshot integrity verification failed: Computed hash "${computedHash}" does not match declared contentHash "${contentHash}"`);
    }

    const metadata = {
      sourceId,
      bankCode: bankCode || null,
      sourceUrl: sourceUrl || null,
      contentHash,
      byteLength: normBuffer.length,
      rawByteLength: rawContent ? (Buffer.isBuffer(rawContent) ? rawContent.length : Buffer.from(rawContent).length) : null,
      contentType,
      storedAt: new Date().toISOString(),
      fetchedAt,
      effectiveFrom: effectiveFrom || null,
      normalizerVersion,
      parserVersion,
      storageType: this.inMemoryOnly ? 'in_memory' : 'file_immutable',
      immutableFilename: `snapshot_${sourceId}_${contentHash}.normalized.txt`,
      hasRawSupplement: Boolean(rawContent),
    };

    if (this.inMemoryOnly) {
      this._inMemorySnapshots.set(contentHash, {
        metadata,
        normalizedBuffer: normBuffer,
        rawBuffer: rawContent ? Buffer.from(rawContent) : null,
      });
      return metadata;
    }

    // Write normalized snapshot file (immutable, content-addressed)
    const normFilePath = path.join(this.storageDir, metadata.immutableFilename);
    const metaFilePath = path.join(this.storageDir, `snapshot_${sourceId}_${contentHash}.meta.json`);

    if (!fs.existsSync(normFilePath)) {
      fs.writeFileSync(normFilePath, normBuffer);
    }
    if (!fs.existsSync(metaFilePath)) {
      fs.writeFileSync(metaFilePath, JSON.stringify(metadata, null, 2), 'utf8');
    }

    if (rawContent) {
      const rawFilePath = path.join(this.storageDir, `snapshot_${sourceId}_${contentHash}.raw.bin`);
      if (!fs.existsSync(rawFilePath)) {
        fs.writeFileSync(rawFilePath, Buffer.isBuffer(rawContent) ? rawContent : Buffer.from(rawContent));
      }
    }

    return metadata;
  }

  /**
   * Verifies that the stored snapshot on disk or in memory reproduces the contentHash.
   *
   * @param {string} contentHash
   * @returns {Promise<{ verified: boolean, reproducedHash?: string, byteLength?: number, error?: string }>}
   */
  async verifySnapshot(contentHash) {
    if (!contentHash) throw new Error('contentHash is required to verify snapshot');

    if (this.inMemoryOnly) {
      const record = this._inMemorySnapshots.get(contentHash);
      if (!record) {
        return {
          verified: false,
          error: `Snapshot not found for hash "${contentHash}". (Historical snapshots from Phase 1 were not retained).`,
        };
      }
      const recomputed = crypto.createHash('sha256').update(record.normalizedBuffer).digest('hex');
      return {
        verified: recomputed.toLowerCase() === contentHash.toLowerCase(),
        reproducedHash: recomputed,
        byteLength: record.normalizedBuffer.length,
      };
    }

    if (!fs.existsSync(this.storageDir)) {
      return {
        verified: false,
        error: `Snapshot storage directory does not exist: "${this.storageDir}"`,
      };
    }

    const files = fs.readdirSync(this.storageDir);
    const matchingFile = files.find(f => f.includes(contentHash) && f.endsWith('.normalized.txt'));
    if (!matchingFile) {
      return {
        verified: false,
        error: `No stored snapshot file found matching hash "${contentHash}". (Historical snapshots from Phase 1 were not retained on disk).`,
      };
    }

    const contentBuffer = fs.readFileSync(path.join(this.storageDir, matchingFile));
    const recomputed = crypto.createHash('sha256').update(contentBuffer).digest('hex');

    return {
      verified: recomputed.toLowerCase() === contentHash.toLowerCase(),
      reproducedHash: recomputed,
      byteLength: contentBuffer.length,
      filename: matchingFile,
    };
  }

  /**
   * Retrieves snapshot metadata by content hash.
   */
  async getSnapshotMetadata(contentHash) {
    if (this.inMemoryOnly) {
      return this._inMemorySnapshots.get(contentHash)?.metadata || null;
    }
    if (!fs.existsSync(this.storageDir)) return null;
    const metaFilename = fs.readdirSync(this.storageDir).find(f => f.includes(contentHash) && f.endsWith('.meta.json'));
    if (!metaFilename) return null;
    const content = fs.readFileSync(path.join(this.storageDir, metaFilename), 'utf8');
    return JSON.parse(content);
  }
}

module.exports = {
  SnapshotStorage,
  MetadataOnlySnapshotStorage,
  ContentAddressedSnapshotStorage,
};
