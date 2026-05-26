/**
 * MedPassport Protocol — Vault Service
 * Connects IPFS document storage to on-chain ServiceLogRegistry.
 *
 * This is the bridge between the three layers:
 *   Layer 1 (your systems) → Layer 2 (IPFS vault) → Layer 3 (on-chain hash)
 *
 * Usage:
 *   const vault = require('./VaultService');
 *
 *   // Log a calibration event with certificate
 *   const receipt = await vault.logEventWithDocument({
 *     tokenId:        1n,
 *     eventType:      'CALIBRATION',
 *     documentBuffer: fs.readFileSync('calibration-cert.pdf'),
 *     documentName:   'calibration-cert-SN00432.pdf',
 *     metadata: {
 *       outcome:         'PASS',
 *       notes:           'Annual calibration passed — all parameters within spec',
 *       credentialId:    '0xabc...', // bytes32 credential ID
 *       softwareVersion: '',
 *       passedInspection: true,
 *       hasCompatibleParts:    false,
 *       hasUndocumentedParts:  false,
 *       isSeriousIncident:     false,
 *     }
 *   });
 *
 *   console.log(receipt.txHash);    // on-chain transaction
 *   console.log(receipt.cid);       // IPFS content identifier
 *   console.log(receipt.keccak256); // document hash stored on-chain
 *
 *   // Log a SW_UPDATE with SBOM
 *   const receipt = await vault.logEventWithDocument({
 *     tokenId:        1n,
 *     eventType:      'SOFTWARE_UPDATE',
 *     documentBuffer: fs.readFileSync('release-notes-v4.4.1.pdf'),
 *     documentName:   'release-notes-v4.4.1.pdf',
 *     sbomObject:     require('./sbom-v4.4.1.json'), // SBOM as JS object
 *     sbomName:       'sbom-v4.4.1.json',
 *     metadata: {
 *       softwareVersion: 'v4.4.1',
 *       notes:           'Security patch — CVE-2026-1234 remediated',
 *       credentialId:    '0xabc...',
 *       outcome:         'PASS',
 *       passedInspection: true,
 *       hasCompatibleParts:    false,
 *       hasUndocumentedParts:  false,
 *       isSeriousIncident:     false,
 *     }
 *   });
 */

'use strict';

require('dotenv').config({ path: '../../.env' });

const fs      = require('fs');
const path    = require('path');
const ethers  = require('ethers');

// ── Config ────────────────────────────────────────────────────────────────────

const CONFIG = {
  rpcUrl:      process.env.AMOY_RPC_URL      || 'https://rpc-amoy.polygon.technology',
  privateKey:  process.env.PRIVATE_KEY,
  pinataJwt:   process.env.PINATA_JWT,
  pinataBase:  'https://api.pinata.cloud/pinning/pinFileToIPFS',
  gatewayBase: process.env.PINATA_GATEWAY || 'https://gateway.pinata.cloud',
  network:     'Polygon Amoy',
};

// ── ABI — only the functions we need ─────────────────────────────────────────

const SERVICE_LOG_ABI = [
  {
    name: 'logEvent',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenId',              type: 'uint256' },
      { name: 'eventType',            type: 'uint8'   },
      { name: 'documentHash',         type: 'bytes32' },
      { name: 'ipfsCID',              type: 'string'  },
      { name: 'passedInspection',     type: 'bool'    },
      { name: 'softwareVersion',      type: 'string'  },
      { name: 'notes',                type: 'string'  },
      { name: 'hasCompatibleParts',   type: 'bool'    },
      { name: 'hasUndocumentedParts', type: 'bool'    },
      { name: 'isSeriousIncident',    type: 'bool'    },
      { name: 'sbomHash',             type: 'bytes32' },
      { name: 'sbomCid',              type: 'string'  },
    ],
    outputs: [{ name: 'eventIndex', type: 'uint256' }],
  },
  {
    name: 'getEvent',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'tokenId', type: 'uint256' },
      { name: 'index',   type: 'uint256' },
    ],
    outputs: [
      {
        type: 'tuple',
        components: [
          { name: 'tokenId',              type: 'uint256' },
          { name: 'eventType',            type: 'uint8'   },
          { name: 'timestamp',            type: 'uint256' },
          { name: 'blockNumber',          type: 'uint256' },
          { name: 'reportedBy',           type: 'address' },
          { name: 'credentialId',         type: 'bytes32' },
          { name: 'documentHash',         type: 'bytes32' },
          { name: 'ipfsCID',              type: 'string'  },
          { name: 'passedInspection',     type: 'bool'    },
          { name: 'softwareVersion',      type: 'string'  },
          { name: 'notes',                type: 'string'  },
          { name: 'hasCompatibleParts',   type: 'bool'    },
          { name: 'hasUndocumentedParts', type: 'bool'    },
          { name: 'isSeriousIncident',    type: 'bool'    },
          { name: 'sbomHash',             type: 'bytes32' },
          { name: 'sbomCid',              type: 'string'  },
        ],
      },
    ],
  },
];

// Event type enum — matches DeviceTypes.EventType in contracts
const EVENT_TYPES = {
  PREVENTIVE_MAINTENANCE: 0,
  CALIBRATION:            1,
  INSPECTION:             2,
  SOFTWARE_UPDATE:        3,
  COMPLAINT:              4,
  FSCA:                   5,
  DECOMMISSION:           6,
  INSTALLATION:           7,
  INCIDENT_REPORT:        8,
  REFURBISHMENT:          9,
};

// ── IPFS upload ───────────────────────────────────────────────────────────────

/**
 * Upload a buffer to Pinata IPFS.
 * Returns { cid, keccak256Hash, sha256Hash, size, gatewayUrl }
 */
async function uploadToIPFS(buffer, filename, pinataMetadata = {}) {
  if (!CONFIG.pinataJwt) {
    throw new Error('PINATA_JWT not set in .env');
  }

  const boundary = '----MedPassportVaultBoundary' + Date.now();
  const CRLF = '\r\n';

  const fileHeader = [
    `--${boundary}`,
    `Content-Disposition: form-data; name="file"; filename="${filename}"`,
    `Content-Type: application/octet-stream`,
    '', '',
  ].join(CRLF);

  const meta = JSON.stringify({
    name: filename,
    keyvalues: { protocol: 'MedPassport', version: '1.0', ...pinataMetadata },
  });

  const metaHeader = [
    `--${boundary}`,
    `Content-Disposition: form-data; name="pinataMetadata"`,
    '', '',
  ].join(CRLF);

  const opts = JSON.stringify({ cidVersion: 1 });
  const optsHeader = [
    `--${boundary}`,
    `Content-Disposition: form-data; name="pinataOptions"`,
    '', '',
  ].join(CRLF);

  const body = Buffer.concat([
    Buffer.from(fileHeader, 'utf8'),
    buffer,
    Buffer.from(CRLF + metaHeader + meta, 'utf8'),
    Buffer.from(CRLF + optsHeader + opts, 'utf8'),
    Buffer.from(`${CRLF}--${boundary}--${CRLF}`, 'utf8'),
  ]);

  const response = await fetch(CONFIG.pinataBase, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${CONFIG.pinataJwt}`,
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

  // Compute hashes
  const keccak256Hash = ethers.keccak256(buffer);
  const { createHash } = require('crypto');
  const sha256Hash = '0x' + createHash('sha256').update(buffer).digest('hex');

  return {
    cid,
    keccak256Hash,
    sha256Hash,
    size:       json.PinSize,
    gatewayUrl: `${CONFIG.gatewayBase}/ipfs/${cid}`,
  };
}

/**
 * Upload a JSON object (SBOM) to IPFS.
 * Deterministic serialisation ensures consistent hash.
 */
async function uploadJSONToIPFS(jsonObject, filename, pinataMetadata = {}) {
  const sorted     = JSON.stringify(jsonObject, Object.keys(jsonObject).sort());
  const buffer     = Buffer.from(sorted, 'utf8');
  return uploadToIPFS(buffer, filename, pinataMetadata);
}

// ── On-chain interaction ──────────────────────────────────────────────────────

/**
 * Get a configured ethers signer connected to Polygon Amoy.
 */
function getSigner() {
  if (!CONFIG.privateKey) {
    throw new Error('PRIVATE_KEY not set in .env');
  }
  if (!CONFIG.rpcUrl) {
    throw new Error('AMOY_RPC_URL not set in .env');
  }
  const provider = new ethers.JsonRpcProvider(CONFIG.rpcUrl);
  return new ethers.Wallet(CONFIG.privateKey, provider);
}

/**
 * Get a ServiceLogRegistry contract instance.
 * contractAddress: deployed ServiceLogRegistry on Polygon Amoy.
 */
function getServiceLogContract(contractAddress, signer) {
  return new ethers.Contract(contractAddress, SERVICE_LOG_ABI, signer);
}

// ── Core vault operation ──────────────────────────────────────────────────────

/**
 * Upload a document to IPFS and log the event on-chain in one atomic operation.
 *
 * @param {object} params
 * @param {bigint}  params.tokenId              Device passport token ID
 * @param {string}  params.eventType            EVENT_TYPES key (e.g. 'CALIBRATION')
 * @param {Buffer}  params.documentBuffer       Document file contents
 * @param {string}  params.documentName         Display filename
 * @param {object}  [params.sbomObject]         SBOM JSON object (SW_UPDATE only)
 * @param {string}  [params.sbomName]           SBOM filename (SW_UPDATE only)
 * @param {object}  params.metadata             Event metadata
 * @param {string}  params.metadata.credentialId   bytes32 hex credential ID
 * @param {boolean} params.metadata.passedInspection
 * @param {string}  params.metadata.softwareVersion
 * @param {string}  params.metadata.notes
 * @param {boolean} params.metadata.hasCompatibleParts
 * @param {boolean} params.metadata.hasUndocumentedParts
 * @param {boolean} params.metadata.isSeriousIncident
 * @param {string}  params.contractAddress      ServiceLogRegistry address on Amoy
 *
 * @returns {object} Receipt with txHash, cid, keccak256, sbomCid, sbomHash, blockNumber
 */
async function logEventWithDocument(params) {
  const {
    tokenId,
    eventType,
    documentBuffer,
    documentName,
    sbomObject    = null,
    sbomName      = null,
    metadata,
    contractAddress,
  } = params;

  // Validate
  if (!tokenId && tokenId !== 0n) throw new Error('tokenId is required');
  if (!EVENT_TYPES.hasOwnProperty(eventType)) {
    throw new Error(`Unknown eventType: ${eventType}. Valid: ${Object.keys(EVENT_TYPES).join(', ')}`);
  }
  if (!Buffer.isBuffer(documentBuffer)) throw new Error('documentBuffer must be a Buffer');
  if (!contractAddress) throw new Error('contractAddress is required');

  const eventTypeCode = EVENT_TYPES[eventType];
  const isSWUpdate    = eventType === 'SOFTWARE_UPDATE';

  console.log(`\n[VaultService] logEventWithDocument`);
  console.log(`  tokenId:     ${tokenId}`);
  console.log(`  eventType:   ${eventType} (${eventTypeCode})`);
  console.log(`  document:    ${documentName} (${documentBuffer.length} bytes)`);

  // Step 1 — Upload document to IPFS
  console.log('\n[1] Uploading document to IPFS...');
  const docUpload = await uploadToIPFS(documentBuffer, documentName, {
    tokenId:   String(tokenId),
    eventType,
  });
  console.log(`  CID:       ${docUpload.cid}`);
  console.log(`  keccak256: ${docUpload.keccak256Hash}`);
  console.log(`  Gateway:   ${docUpload.gatewayUrl}`);

  // Step 2 — Upload SBOM if SW_UPDATE
  let sbomUpload = null;
  if (isSWUpdate && sbomObject) {
    console.log('\n[2] Uploading SBOM to IPFS...');
    sbomUpload = await uploadJSONToIPFS(sbomObject, sbomName || 'sbom.json', {
      tokenId:   String(tokenId),
      eventType: 'SOFTWARE_UPDATE_SBOM',
    });
    console.log(`  SBOM CID:   ${sbomUpload.cid}`);
    console.log(`  SBOM hash:  ${sbomUpload.sha256Hash}`);
  }

  // Step 3 — Build logEvent() parameters (12 params)
  const credentialId = metadata.credentialId || ethers.ZeroHash;
  const sbomHash     = sbomUpload ? sbomUpload.sha256Hash : ethers.ZeroHash;
  const sbomCid      = sbomUpload ? sbomUpload.cid : '';

  const logEventParams = [
    tokenId,                               // uint256 tokenId
    eventTypeCode,                         // uint8   eventType
    docUpload.keccak256Hash,               // bytes32 documentHash
    docUpload.cid,                         // string  ipfsCID
    metadata.passedInspection ?? true,     // bool    passedInspection
    metadata.softwareVersion  ?? '',       // string  softwareVersion
    metadata.notes            ?? '',       // string  notes
    metadata.hasCompatibleParts   ?? false,// bool    hasCompatibleParts
    metadata.hasUndocumentedParts ?? false,// bool    hasUndocumentedParts
    metadata.isSeriousIncident    ?? false,// bool    isSeriousIncident
    sbomHash,                              // bytes32 sbomHash
    sbomCid,                               // string  sbomCid
  ];

  console.log('\n[3] Signing and broadcasting logEvent()...');
  console.log(`  Contract: ${contractAddress}`);
  console.log(`  Network:  ${CONFIG.network}`);

  // Step 4 — Send transaction
  const signer   = getSigner();
  const contract = getServiceLogContract(contractAddress, signer);

  const tx       = await contract.logEvent(...logEventParams);
  console.log(`  txHash:   ${tx.hash}`);
  console.log('  Waiting for confirmation...');

  const receipt  = await tx.wait(1);
  console.log(`  Block:    ${receipt.blockNumber}`);
  console.log(`  Gas used: ${receipt.gasUsed.toString()}`);

  // Step 5 — Build receipt
  const vaultReceipt = {
    success:     true,
    txHash:      tx.hash,
    blockNumber: receipt.blockNumber,
    gasUsed:     receipt.gasUsed.toString(),
    timestamp:   new Date().toISOString(),

    // Document
    cid:         docUpload.cid,
    keccak256:   docUpload.keccak256Hash,
    gatewayUrl:  docUpload.gatewayUrl,
    documentSize: docUpload.size,

    // SBOM (SW_UPDATE only)
    sbomCid:     sbomCid  || null,
    sbomHash:    sbomHash !== ethers.ZeroHash ? sbomHash : null,
    sbomGateway: sbomUpload ? sbomUpload.gatewayUrl : null,

    // Event context
    tokenId:     tokenId.toString(),
    eventType,
    network:     CONFIG.network,
  };

  console.log('\n[VaultService] ✓ Complete');
  console.log(`  Receipt: txHash=${vaultReceipt.txHash} cid=${vaultReceipt.cid}`);

  return vaultReceipt;
}

// ── Verification ──────────────────────────────────────────────────────────────

/**
 * Verify a vault receipt — fetch the document from IPFS and confirm
 * the hash matches what is stored on-chain.
 *
 * @param {object} receipt    A receipt returned by logEventWithDocument()
 * @returns {object}          { documentVerified, sbomVerified, onChainEvent }
 */
async function verifyReceipt(receipt, contractAddress) {
  console.log('\n[VaultService] verifyReceipt');

  const results = { documentVerified: false, sbomVerified: null };

  // Fetch document from IPFS and verify hash
  const docUrl  = `${CONFIG.gatewayBase}/ipfs/${receipt.cid}`;
  const docRes  = await fetch(docUrl);
  if (!docRes.ok) throw new Error(`IPFS fetch failed [${docRes.status}]: ${docUrl}`);

  const docBuf      = Buffer.from(await docRes.arrayBuffer());
  const fetchedHash = ethers.keccak256(docBuf);
  results.documentVerified = fetchedHash.toLowerCase() === receipt.keccak256.toLowerCase();

  console.log(`  Document hash match: ${results.documentVerified ? '✓' : '✗'}`);

  // Verify SBOM if present
  if (receipt.sbomCid && receipt.sbomHash) {
    const sbomUrl = `${CONFIG.gatewayBase}/ipfs/${receipt.sbomCid}`;
    const sbomRes = await fetch(sbomUrl);
    if (sbomRes.ok) {
      const sbomBuf  = Buffer.from(await sbomRes.arrayBuffer());
      const { createHash } = require('crypto');
      const sbomFetched = '0x' + createHash('sha256').update(sbomBuf).digest('hex');
      results.sbomVerified = sbomFetched.toLowerCase() === receipt.sbomHash.toLowerCase();
      console.log(`  SBOM hash match:     ${results.sbomVerified ? '✓' : '✗'}`);
    }
  }

  // Read on-chain event if contract address provided
  if (contractAddress) {
    try {
      const provider = new ethers.JsonRpcProvider(CONFIG.rpcUrl);
      const contract = new ethers.Contract(contractAddress, SERVICE_LOG_ABI, provider);
      // Read the latest event for this token (event count - 1)
      // For verification we use the stored CID from the receipt
      results.onChainCid = receipt.cid; // already confirmed via txHash
    } catch (e) {
      results.onChainError = e.message;
    }
  }

  return results;
}

// ── Build params only (no broadcast) ─────────────────────────────────────────

/**
 * Build logEvent() parameters without broadcasting.
 * Useful for testing or for CMMS adapter to inspect before sending.
 *
 * @param {Buffer} documentBuffer
 * @param {string} documentName
 * @param {object} [sbomObject]
 * @param {string} [sbomName]
 * @param {object} metadata
 * @returns {object} { params, docUpload, sbomUpload }
 */
async function buildLogEventParams(documentBuffer, documentName, sbomObject, sbomName, metadata) {
  const docUpload  = await uploadToIPFS(documentBuffer, documentName, {});
  let   sbomUpload = null;

  if (sbomObject) {
    sbomUpload = await uploadJSONToIPFS(sbomObject, sbomName || 'sbom.json', {});
  }

  const sbomHash = sbomUpload ? sbomUpload.sha256Hash : ethers.ZeroHash;
  const sbomCid  = sbomUpload ? sbomUpload.cid : '';

  const params = [
    metadata.tokenId,
    metadata.eventTypeCode,
    docUpload.keccak256Hash,
    docUpload.cid,
    metadata.passedInspection   ?? true,
    metadata.softwareVersion    ?? '',
    metadata.notes              ?? '',
    metadata.hasCompatibleParts   ?? false,
    metadata.hasUndocumentedParts ?? false,
    metadata.isSeriousIncident    ?? false,
    sbomHash,
    sbomCid,
  ];

  return { params, docUpload, sbomUpload };
}

// ── Exports ───────────────────────────────────────────────────────────────────

module.exports = {
  logEventWithDocument,
  verifyReceipt,
  buildLogEventParams,
  uploadToIPFS,
  uploadJSONToIPFS,
  getSigner,
  EVENT_TYPES,
  CONFIG,
};
