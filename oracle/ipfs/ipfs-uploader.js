/**
 * MedPassport Protocol — IPFS Uploader
 * Pins documents to Pinata and returns CID + hashes for on-chain storage.
 *
 * Usage:
 *   const { uploadDocument, uploadJSON } = require('./ipfs-uploader');
 *
 *   // Upload a file buffer (PDF, image, etc.)
 *   const result = await uploadDocument(buffer, 'calibration-cert-SN00432.pdf', {
 *     deviceUdi: '00844588003288/LOT2023-Q1/SN00432',
 *     eventType: 'CALIBRATION',
 *     credentialId: 'ISO-CERT-4471',
 *   });
 *   console.log(result.cid);          // store in ServiceLogRegistry as documentCid
 *   console.log(result.keccak256);    // store in ServiceLogRegistry as documentHash
 *
 *   // Upload a JSON object (SBOM, event summary)
 *   const result = await uploadJSON(sbomObject, 'sbom-v4.4.1.json', metadata);
 *   console.log(result.sha256);       // store in ServiceLogRegistry as sbomHash
 */

'use strict';

const crypto  = require('crypto');
const fs      = require('fs');
const path    = require('path');
const { ethers } = require('ethers');

// ── Config ────────────────────────────────────────────────────────────────────

const PINATA_JWT = process.env.PINATA_JWT;
const PINATA_GATEWAY = process.env.PINATA_GATEWAY || 'https://gateway.pinata.cloud';
const PINATA_PIN_URL = 'https://api.pinata.cloud/pinning/pinFileToIPFS';
const PINATA_JSON_URL = 'https://api.pinata.cloud/pinning/pinJSONToIPFS';

if (!PINATA_JWT) {
  throw new Error(
    'PINATA_JWT environment variable not set.\n' +
    'Add it to your .env file: PINATA_JWT=eyJ...'
  );
}

// ── Hash utilities ────────────────────────────────────────────────────────────

/**
 * Compute keccak256 of a buffer — matches Solidity's keccak256().
 * Used for documentHash field in ServiceLogRegistry.
 */
function keccak256Hash(buffer) {
  return ethers.keccak256(buffer);
}

/**
 * Compute sha256 of a buffer.
 * Used for sbomHash field in ServiceLogRegistry.
 */
function sha256Hash(buffer) {
  return '0x' + crypto.createHash('sha256').update(buffer).digest('hex');
}

// ── Core upload ───────────────────────────────────────────────────────────────

/**
 * Upload a file buffer to Pinata IPFS.
 * Returns CID, keccak256 hash, and sha256 hash.
 *
 * @param {Buffer} buffer        - File contents
 * @param {string} filename      - Display name for the file
 * @param {object} metadata      - Key-value pairs stored as Pinata metadata (NOT on-chain)
 * @returns {{ cid, keccak256, sha256, size, gateway }}
 */
async function uploadDocument(buffer, filename, metadata = {}) {
  if (!Buffer.isBuffer(buffer)) {
    throw new Error('uploadDocument: first argument must be a Buffer');
  }

  // Build multipart form data
  const boundary = '----MedPassportBoundary' + Date.now();
  const CRLF = '\r\n';

  // File part
  const fileHeader = [
    `--${boundary}`,
    `Content-Disposition: form-data; name="file"; filename="${filename}"`,
    `Content-Type: application/octet-stream`,
    '',
    '',
  ].join(CRLF);

  // Pinata metadata part (not stored on-chain — stays in Pinata dashboard only)
  const pinataMetadata = JSON.stringify({
    name: filename,
    keyvalues: {
      protocol: 'MedPassport',
      version:  '1.0',
      ...metadata,
    },
  });

  const metadataHeader = [
    `--${boundary}`,
    `Content-Disposition: form-data; name="pinataMetadata"`,
    '',
    '',
  ].join(CRLF);

  const pinataOptions = JSON.stringify({ cidVersion: 1 });
  const optionsHeader = [
    `--${boundary}`,
    `Content-Disposition: form-data; name="pinataOptions"`,
    '',
    '',
  ].join(CRLF);

  const closing = `${CRLF}--${boundary}--${CRLF}`;

  const body = Buffer.concat([
    Buffer.from(fileHeader, 'utf8'),
    buffer,
    Buffer.from(CRLF + metadataHeader + pinataMetadata, 'utf8'),
    Buffer.from(CRLF + optionsHeader + pinataOptions, 'utf8'),
    Buffer.from(closing, 'utf8'),
  ]);

  const response = await fetch(PINATA_PIN_URL, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${PINATA_JWT}`,
      'Content-Type': `multipart/form-data; boundary=${boundary}`,
    },
    body,
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Pinata upload failed [${response.status}]: ${text}`);
  }

  const json = await response.json();
  const cid  = json.IpfsHash;

  return {
    cid,
    keccak256: keccak256Hash(buffer),
    sha256:    sha256Hash(buffer),
    size:      json.PinSize,
    gateway:   `${PINATA_GATEWAY}/ipfs/${cid}`,
  };
}

/**
 * Upload a JSON object (e.g. SBOM) to Pinata IPFS.
 * Serialises to Buffer first so hashes are deterministic.
 *
 * @param {object} jsonObject    - The object to pin
 * @param {string} filename      - Display name (e.g. 'sbom-v4.4.1.json')
 * @param {object} metadata      - Pinata metadata key-values
 * @returns {{ cid, keccak256, sha256, size, gateway }}
 */
async function uploadJSON(jsonObject, filename, metadata = {}) {
  // Deterministic serialisation — sorted keys, no extra whitespace
  const serialised = JSON.stringify(jsonObject, Object.keys(jsonObject).sort());
  const buffer     = Buffer.from(serialised, 'utf8');
  return uploadDocument(buffer, filename, metadata);
}

/**
 * Upload a file from disk by path.
 * Convenience wrapper around uploadDocument.
 */
async function uploadFile(filePath, metadata = {}) {
  const buffer   = fs.readFileSync(filePath);
  const filename = path.basename(filePath);
  return uploadDocument(buffer, filename, metadata);
}

/**
 * Verify a document against its on-chain hash.
 * Fetches the document from IPFS and confirms the hash matches.
 *
 * @param {string} cid           - IPFS CID stored on-chain
 * @param {string} onChainHash   - keccak256 hash stored on-chain (0x...)
 * @returns {{ verified: boolean, fetchedHash: string }}
 */
async function verifyDocument(cid, onChainHash) {
  const url      = `${PINATA_GATEWAY}/ipfs/${cid}`;
  const response = await fetch(url);

  if (!response.ok) {
    throw new Error(`Failed to fetch from IPFS [${response.status}]: ${url}`);
  }

  const arrayBuffer = await response.arrayBuffer();
  const buffer      = Buffer.from(arrayBuffer);
  const fetchedHash = keccak256Hash(buffer);
  const verified    = fetchedHash.toLowerCase() === onChainHash.toLowerCase();

  return { verified, fetchedHash, cid, url };
}

// ── Self-test ─────────────────────────────────────────────────────────────────

async function runTests() {
  console.log('MedPassport IPFS Uploader — Self Test');
  console.log('======================================');

  // Test 1: Hash utilities
  console.log('\n[1] Hash utilities');
  const testBuffer = Buffer.from('MedPassport test payload 2026', 'utf8');
  const k = keccak256Hash(testBuffer);
  const s = sha256Hash(testBuffer);
  console.log('  keccak256:', k);
  console.log('  sha256:   ', s);
  console.log('  PASS: both hashes are 66 chars (0x + 64 hex)', k.length === 66 && s.length === 66 ? '✓' : '✗');

  // Test 2: JSON serialisation is deterministic
  console.log('\n[2] JSON determinism');
  const obj1 = { version: 'v4.4.1', components: ['kernel', 'ui'], date: '2026-05-23' };
  const obj2 = { date: '2026-05-23', components: ['kernel', 'ui'], version: 'v4.4.1' };
  const b1   = Buffer.from(JSON.stringify(obj1, Object.keys(obj1).sort()), 'utf8');
  const b2   = Buffer.from(JSON.stringify(obj2, Object.keys(obj2).sort()), 'utf8');
  const match = keccak256Hash(b1) === keccak256Hash(b2);
  console.log('  PASS: same content, different key order → same hash', match ? '✓' : '✗');

  // Test 3: Live Pinata upload
  console.log('\n[3] Live Pinata upload');
  const testDoc = Buffer.from(
    JSON.stringify({
      test:      true,
      protocol:  'MedPassport',
      timestamp: new Date().toISOString(),
      device:    '00844588003288/LOT2023-Q1/SN00432',
    }),
    'utf8'
  );

  try {
    const result = await uploadDocument(testDoc, 'medpassport-test.json', {
      eventType: 'TEST',
      deviceUdi: '00844588003288/LOT2023-Q1/SN00432',
    });

    console.log('  CID:      ', result.cid);
    console.log('  keccak256:', result.keccak256);
    console.log('  sha256:   ', result.sha256);
    console.log('  Size:     ', result.size, 'bytes');
    console.log('  Gateway:  ', result.gateway);

    // Test 4: Verify round-trip
    console.log('\n[4] Verify round-trip (fetch from IPFS + hash match)');
    const verification = await verifyDocument(result.cid, result.keccak256);
    console.log('  Verified: ', verification.verified ? '✓ PASS' : '✗ FAIL');
    console.log('  Fetched hash matches on-chain hash:', verification.verified);

  } catch (err) {
    console.error('  ✗ FAIL:', err.message);
    console.error('  Check your PINATA_JWT in .env');
  }

  console.log('\n======================================');
  console.log('Self-test complete.');
}

// ── Exports ───────────────────────────────────────────────────────────────────

module.exports = { uploadDocument, uploadJSON, uploadFile, verifyDocument, keccak256Hash, sha256Hash };

// Run self-test if called directly: node ipfs-uploader.js
if (require.main === module) {
  runTests().catch(console.error);
}
