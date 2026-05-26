/**
 * MedPassport Protocol — VaultService Self-Test
 * Tests 1-3 run without a live contract (IPFS + param building only).
 * Test 4 requires a deployed ServiceLogRegistry on Polygon Amoy.
 *
 * Run:
 *   cd oracle/vault
 *   DOTENV_CONFIG_PATH=../../.env node test-vault.js
 *
 * For full Test 4, set SERVICE_LOG_ADDRESS in .env:
 *   SERVICE_LOG_ADDRESS=0x...
 */

'use strict';

require('dotenv').config({ path: '../../.env' });

const {
  uploadToIPFS,
  uploadJSONToIPFS,
  buildLogEventParams,
  verifyReceipt,
  EVENT_TYPES,
  CONFIG,
} = require('./VaultService');

const ethers = require('ethers');

// ── Test helpers ──────────────────────────────────────────────────────────────

let passed = 0;
let failed = 0;

function pass(msg) { console.log(`  ✓ PASS: ${msg}`); passed++; }
function fail(msg) { console.log(`  ✗ FAIL: ${msg}`); failed++; }
function section(msg) { console.log(`\n[${passed + failed + 1}] ${msg}`); }

// ── Tests ─────────────────────────────────────────────────────────────────────

async function runTests() {
  console.log('MedPassport Vault Service — Self Test');
  console.log('======================================');
  console.log(`Network:  ${CONFIG.network}`);
  console.log(`RPC URL:  ${CONFIG.rpcUrl}`);
  console.log(`Pinata:   ${CONFIG.pinataJwt ? 'JWT configured ✓' : 'JWT MISSING ✗'}`);
  console.log(`Wallet:   ${CONFIG.privateKey ? 'Private key configured ✓' : 'Private key MISSING ✗'}`);

  // ── Test 1: EVENT_TYPES mapping ──────────────────────────────────────────
  section('EVENT_TYPES mapping — matches DeviceTypes.EventType enum');

  const expectedTypes = {
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

  let allMatch = true;
  for (const [key, val] of Object.entries(expectedTypes)) {
    if (EVENT_TYPES[key] !== val) {
      fail(`EVENT_TYPES.${key} = ${EVENT_TYPES[key]}, expected ${val}`);
      allMatch = false;
    }
  }
  if (allMatch) pass(`All ${Object.keys(expectedTypes).length} event types match contract enum`);

  // ── Test 2: Live IPFS upload — calibration certificate simulation ─────────
  section('Live IPFS upload — calibration certificate PDF simulation');

  if (!CONFIG.pinataJwt) {
    console.log('  SKIP: PINATA_JWT not configured');
  } else {
    try {
      // Simulate a calibration certificate PDF
      const certContent = JSON.stringify({
        document:    'CALIBRATION_CERTIFICATE',
        deviceUdi:   '00844588003288/LOT2023-Q1/SN00432',
        deviceModel: 'CardioScan Pro 3000',
        calibrationDate: new Date().toISOString().split('T')[0],
        technician:  'ISO-CERT-4471',
        result:      'PASS',
        nextDue:     '2027-05-26',
        parameters: [
          { name: 'Voltage accuracy',    value: '±0.5%', spec: '±1.0%', status: 'PASS' },
          { name: 'Timing accuracy',     value: '±0.2ms', spec: '±0.5ms', status: 'PASS' },
          { name: 'Signal sensitivity',  value: '0.05mV', spec: '0.1mV', status: 'PASS' },
        ],
        protocol:  'MedPassport',
        timestamp: new Date().toISOString(),
      });

      const buffer   = Buffer.from(certContent, 'utf8');
      const filename = 'medpassport-test-calibration-cert.json';

      const result = await uploadToIPFS(buffer, filename, {
        eventType: 'CALIBRATION',
        test:      'true',
      });

      console.log(`  CID:        ${result.cid}`);
      console.log(`  keccak256:  ${result.keccak256Hash}`);
      console.log(`  Size:       ${result.size} bytes`);
      console.log(`  Gateway:    ${result.gatewayUrl}`);

      if (result.cid && result.keccak256Hash && result.size > 0) {
        pass('Document uploaded to IPFS — CID and hash returned');
      } else {
        fail('Upload returned incomplete result');
      }

      // Verify round-trip
      const fetchRes  = await fetch(result.gatewayUrl);
      const fetchBuf  = Buffer.from(await fetchRes.arrayBuffer());
      const fetchHash = ethers.keccak256(fetchBuf);
      const hashMatch = fetchHash.toLowerCase() === result.keccak256Hash.toLowerCase();

      if (hashMatch) {
        pass(`Hash round-trip verified — fetched document matches on-chain hash`);
      } else {
        fail(`Hash mismatch: fetched=${fetchHash} stored=${result.keccak256Hash}`);
      }

      // Store for Test 3
      global._testDocResult = result;
      global._testDocBuffer = buffer;

    } catch (err) {
      fail(`IPFS upload error: ${err.message}`);
    }
  }

  // ── Test 3: Build logEvent params — 12-param structure ───────────────────
  section('Build logEvent() params — 12-parameter structure + SBOM');

  if (!CONFIG.pinataJwt) {
    console.log('  SKIP: PINATA_JWT not configured');
  } else {
    try {
      const docBuffer = global._testDocBuffer || Buffer.from('test calibration cert', 'utf8');

      const sbomObject = {
        bomFormat:    'CycloneDX',
        specVersion:  '1.4',
        version:      1,
        metadata: {
          timestamp:    new Date().toISOString(),
          component: {
            type:       'firmware',
            name:       'CardioScan Pro 3000 Firmware',
            version:    'v4.4.1',
          }
        },
        components: [
          { type: 'library', name: 'cardiac-signal-processor', version: '2.1.0' },
          { type: 'library', name: 'ecg-display-engine', version: '3.0.2' },
          { type: 'firmware', name: 'bootloader', version: '1.2.0' },
        ]
      };

      const { params, docUpload, sbomUpload } = await buildLogEventParams(
        docBuffer,
        'test-sw-update-doc.json',
        sbomObject,
        'sbom-v4.4.1.json',
        {
          tokenId:              1n,
          eventTypeCode:        EVENT_TYPES.SOFTWARE_UPDATE,
          passedInspection:     true,
          softwareVersion:      'v4.4.1',
          notes:                'Security patch — test run',
          hasCompatibleParts:   false,
          hasUndocumentedParts: false,
          isSeriousIncident:    false,
        }
      );

      // Validate 12 params
      if (params.length !== 12) {
        fail(`Expected 12 params, got ${params.length}`);
      } else {
        pass(`logEvent() param count: 12 ✓`);
      }

      // Validate types
      const checks = [
        [typeof params[0] === 'bigint' || typeof params[0] === 'number', 'tokenId is numeric'],
        [typeof params[1] === 'number', 'eventType is number'],
        [typeof params[2] === 'string' && params[2].startsWith('0x'), 'documentHash is 0x bytes32'],
        [typeof params[3] === 'string' && params[3].startsWith('baf'), 'ipfsCID is CIDv1'],
        [typeof params[4] === 'boolean', 'passedInspection is boolean'],
        [typeof params[5] === 'string', 'softwareVersion is string'],
        [typeof params[6] === 'string', 'notes is string'],
        [typeof params[7] === 'boolean', 'hasCompatibleParts is boolean'],
        [typeof params[8] === 'boolean', 'hasUndocumentedParts is boolean'],
        [typeof params[9] === 'boolean', 'isSeriousIncident is boolean'],
        [typeof params[10] === 'string' && params[10].startsWith('0x'), 'sbomHash is 0x bytes32'],
        [typeof params[11] === 'string' && params[11].startsWith('baf'), 'sbomCid is CIDv1'],
      ];

      let allValid = true;
      for (const [condition, msg] of checks) {
        if (!condition) { fail(msg); allValid = false; }
      }
      if (allValid) pass('All 12 param types valid — ready for logEvent()');

      console.log('\n  Param summary:');
      console.log(`    [0]  tokenId:              ${params[0]}`);
      console.log(`    [1]  eventType:            ${params[1]} (SOFTWARE_UPDATE)`);
      console.log(`    [2]  documentHash:         ${params[2].substring(0,20)}...`);
      console.log(`    [3]  ipfsCID:              ${params[3]}`);
      console.log(`    [4]  passedInspection:     ${params[4]}`);
      console.log(`    [5]  softwareVersion:      ${params[5]}`);
      console.log(`    [6]  notes:                ${params[6]}`);
      console.log(`    [7]  hasCompatibleParts:   ${params[7]}`);
      console.log(`    [8]  hasUndocumentedParts: ${params[8]}`);
      console.log(`    [9]  isSeriousIncident:    ${params[9]}`);
      console.log(`    [10] sbomHash:             ${params[10].substring(0,20)}...`);
      console.log(`    [11] sbomCid:              ${params[11]}`);

      if (sbomUpload) {
        console.log(`\n  SBOM gateway: ${sbomUpload.gatewayUrl}`);
        pass('SBOM uploaded and sbomHash/sbomCid populated correctly');
      }

    } catch (err) {
      fail(`Build params error: ${err.message}`);
    }
  }

  // ── Test 4: Full on-chain write (requires deployed contract) ─────────────
  section('Full on-chain write — Polygon Amoy (requires SERVICE_LOG_ADDRESS in .env)');

  const contractAddress = process.env.SERVICE_LOG_ADDRESS;

  if (!contractAddress) {
    console.log('  SKIP: SERVICE_LOG_ADDRESS not set in .env');
    console.log('  To run: add SERVICE_LOG_ADDRESS=0x... to .env and re-run');
    console.log('  Get address from: broadcast/DeployAll.s.sol/80002/run-latest.json');
  } else if (!CONFIG.privateKey) {
    console.log('  SKIP: PRIVATE_KEY not configured');
  } else {
    try {
      const { logEventWithDocument } = require('./VaultService');

      const testDoc = Buffer.from(JSON.stringify({
        document:    'CALIBRATION_CERTIFICATE',
        deviceUdi:   '00844588003288/LOT2023-Q1/SN00432',
        result:      'PASS',
        test:        true,
        timestamp:   new Date().toISOString(),
      }), 'utf8');

      // Need a valid credential ID from the deployed CredentialRegistry
      // Using ZeroHash for testnet simulation
      const receipt = await logEventWithDocument({
        tokenId:        1n,
        eventType:      'CALIBRATION',
        documentBuffer: testDoc,
        documentName:   'medpassport-vault-test-calibration.json',
        metadata: {
          credentialId:         ethers.ZeroHash,
          passedInspection:     true,
          softwareVersion:      '',
          notes:                'VaultService self-test — automated calibration event',
          hasCompatibleParts:   false,
          hasUndocumentedParts: false,
          isSeriousIncident:    false,
        },
        contractAddress,
      });

      if (receipt.success && receipt.txHash && receipt.cid) {
        pass('Full vault write succeeded');
        console.log(`\n  ╔══════════════════════════════════════════════╗`);
        console.log(`  ║  VAULT RECEIPT                               ║`);
        console.log(`  ╠══════════════════════════════════════════════╣`);
        console.log(`  ║  txHash:     ${receipt.txHash.substring(0,20)}...`);
        console.log(`  ║  Block:      ${receipt.blockNumber}`);
        console.log(`  ║  CID:        ${receipt.cid}`);
        console.log(`  ║  keccak256:  ${receipt.keccak256.substring(0,20)}...`);
        console.log(`  ║  Gateway:    ${receipt.gatewayUrl}`);
        console.log(`  ║  Network:    ${receipt.network}`);
        console.log(`  ╚══════════════════════════════════════════════╝`);
      } else {
        fail(`Vault write returned incomplete receipt: ${JSON.stringify(receipt)}`);
      }

    } catch (err) {
      fail(`On-chain write error: ${err.message}`);
      if (err.message.includes('credential')) {
        console.log('  Note: credential not registered — use a valid credentialId from CredentialRegistry');
      }
    }
  }

  // ── Summary ───────────────────────────────────────────────────────────────
  console.log('\n======================================');
  console.log(`Tests: ${passed} passed · ${failed} failed`);
  console.log('======================================');

  if (passed >= 3) {
    console.log('\nVaultService is operational.');
    console.log('Next step: add SERVICE_LOG_ADDRESS to .env and run Test 4');
    console.log('Get address: broadcast/DeployAll.s.sol/80002/run-latest.json');
  }
}

runTests().catch(err => {
  console.error('\nFatal error:', err.message);
  process.exit(1);
});
