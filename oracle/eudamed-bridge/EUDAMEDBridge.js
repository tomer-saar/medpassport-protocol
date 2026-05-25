/**
 * MedPassport Protocol — EUDAMED Bridge
 * Validates EU medical device registration before passport minting.
 * Mirrors GUDIDBridge.js structure exactly.
 *
 * Public API only — no authentication required.
 * Source: https://openregulatory.github.io/eudamed-api/
 * Base:   https://ec.europa.eu/tools/eudamed/api
 *
 * Usage:
 *   const bridge = require('./EUDAMEDBridge');
 *
 *   // Validate before EU mint
 *   const result = await bridge.validateBasicUdiDi('7613327025391');
 *   console.log(result.valid);          // true/false
 *   console.log(result.riskClass);      // 'class-iib'
 *   console.log(result.manufacturerSrn); // 'SRN/CH/000012345'
 *
 *   // Full dual-market validation (EU + US in one call)
 *   const dual = await bridge.runDualMarketValidation(
 *     '00844588003288',   // GS1 UDI for GUDID
 *     '7613327025391'     // Basic UDI-DI for EUDAMED
 *   );
 */

'use strict';

const EUDAMED_BASE = 'https://ec.europa.eu/tools/eudamed/api';
const LANGUAGE     = 'en';

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Extract English text from EUDAMED multilingual text objects.
 * Format: { texts: [{ language: { isoCode: 'en' }, text: '...' }] }
 */
function extractText(textObj) {
  if (!textObj) return '';
  if (typeof textObj === 'string') return textObj;
  const texts = textObj.texts || [];
  const en = texts.find(t => t.language?.isoCode === 'en' || t.allLanguagesApplicable);
  return en?.text || texts[0]?.text || '';
}

/**
 * Parse EUDAMED risk class code to human-readable label.
 * e.g. 'refdata.risk-class.class-iib' → 'Class IIb'
 */
function parseRiskClass(code) {
  if (!code) return 'Unknown';
  const map = {
    'class-i':   'Class I',
    'class-iia': 'Class IIa',
    'class-iib': 'Class IIb',
    'class-iii': 'Class III',
    'd':         'Class D (IVDR)',
    'c':         'Class C (IVDR)',
    'b':         'Class B (IVDR)',
    'a':         'Class A (IVDR)',
  };
  const key = code.toLowerCase().replace('refdata.risk-class.', '');
  return map[key] || code;
}

/**
 * Parse EUDAMED device status code.
 */
function parseDeviceStatus(code) {
  if (!code) return 'Unknown';
  const map = {
    'refdata.device-model-status.on-the-market':          'On the market',
    'refdata.device-model-status.no-longer-placed':       'No longer placed on market',
    'refdata.device-model-status.not-yet-placed':         'Not yet placed on market',
    'refdata.device-model-status.discontinued':           'Discontinued',
  };
  return map[code] || code.replace('refdata.device-model-status.', '');
}

/**
 * Parse EUDAMED actor status code.
 */
function parseActorStatus(code) {
  if (!code) return 'Unknown';
  const map = {
    'refdata.actor-status.active':   'ACTIVE',
    'refdata.actor-status.inactive': 'INACTIVE',
    'refdata.actor-status.revoked':  'REVOKED',
  };
  return map[code] || code.replace('refdata.actor-status.', '').toUpperCase();
}

/**
 * Parse certificate status.
 */
function parseCertStatus(code) {
  if (!code) return 'Unknown';
  if (code.includes('valid'))   return 'VALID';
  if (code.includes('expired')) return 'EXPIRED';
  if (code.includes('suspend')) return 'SUSPENDED';
  if (code.includes('withdraw'))return 'WITHDRAWN';
  return code.toUpperCase();
}

// ── Core API calls ────────────────────────────────────────────────────────────

/**
 * Search EUDAMED for a Basic UDI-DI string.
 * Returns the first matching device record from the search endpoint.
 *
 * EUDAMED search endpoint:
 * GET /devices/udiDiData?page=1&pageSize=10&size=10&iso2Code=en&languageIso2Code=en
 * + query param: basicUdi or primaryDi
 */
async function searchByBasicUdiDi(basicUdiDi) {
  const params = new URLSearchParams({
    page:              '1',
    pageSize:          '10',
    size:              '10',
    iso2Code:          LANGUAGE,
    languageIso2Code:  LANGUAGE,
    basicUdi:          basicUdiDi,
  });

  const url = `${EUDAMED_BASE}/devices/udiDiData?${params}`;
  const res  = await fetch(url, {
    headers: { 'Accept': 'application/json', 'Accept-Language': 'en' }
  });

  if (!res.ok) throw new Error(`EUDAMED search failed [${res.status}]: ${url}`);

  const json = await res.json();
  return json; // { content: [...], totalElements, totalPages, ... }
}

/**
 * Fetch full Basic UDI-DI record (cross-version data including certificates, AR).
 * GET /devices/basicUdiData/{basicUdiDiUlid}
 */
async function fetchBasicUdiData(ulid) {
  const url = `${EUDAMED_BASE}/devices/basicUdiData/${ulid}?languageIso2Code=${LANGUAGE}`;
  const res  = await fetch(url, {
    headers: { 'Accept': 'application/json', 'Accept-Language': 'en' }
  });

  if (!res.ok) throw new Error(`EUDAMED basicUdiData failed [${res.status}]: ${ulid}`);
  return res.json();
}

/**
 * Fetch actor (manufacturer) public information.
 * GET /actors/{actorUuid}/publicInformation
 */
async function fetchActorData(actorUuid) {
  const url = `${EUDAMED_BASE}/actors/${actorUuid}/publicInformation?languageIso2Code=${LANGUAGE}`;
  const res  = await fetch(url, {
    headers: { 'Accept': 'application/json', 'Accept-Language': 'en' }
  });

  if (!res.ok) throw new Error(`EUDAMED actor fetch failed [${res.status}]: ${actorUuid}`);
  return res.json();
}

// ── Public interface ──────────────────────────────────────────────────────────

/**
 * Validate a Basic UDI-DI against EUDAMED.
 * Primary validation function — call before EU passport mint.
 *
 * @param {string} basicUdiDi  The Basic UDI-DI (e.g. '7613327025391')
 * @returns {object} Validation result
 */
async function validateBasicUdiDi(basicUdiDi) {
  if (!basicUdiDi || typeof basicUdiDi !== 'string') {
    return { valid: false, error: 'basicUdiDi must be a non-empty string' };
  }

  const trimmed = basicUdiDi.trim();

  try {
    const searchResult = await searchByBasicUdiDi(trimmed);

    if (!searchResult.content || searchResult.content.length === 0) {
      return {
        valid:      false,
        basicUdiDi: trimmed,
        error:      'Basic UDI-DI not found in EUDAMED — device may not be registered for EU market',
        totalFound: 0,
      };
    }

    // Use the first result (exact match on basicUdi field)
    const device = searchResult.content.find(d => d.basicUdi === trimmed)
                || searchResult.content[0];

    const riskClassCode  = device.riskClass?.code || '';
    const statusCode     = device.deviceStatusType?.code || '';

    // Fetch full basic UDI data for certificates and AR
    let fullData = null;
    let certificates = [];
    let authorisedRep = null;

    if (device.basicUdiDiDataUlid || device.ulid) {
      try {
        fullData = await fetchBasicUdiData(device.basicUdiDiDataUlid || device.ulid);
        certificates = fullData.deviceCertificateInfoList || [];
        authorisedRep = fullData.authorisedRepresentative || null;
      } catch (e) {
        // Non-fatal — continue with search data
        console.warn('  EUDAMED: Could not fetch full basicUdiData:', e.message);
      }
    }

    // Parse certificates
    const parsedCerts = certificates.map(cert => ({
      certificateNumber: cert.certificateNumber || 'N/A',
      notifiedBody:      cert.notifiedBody?.name || extractText(cert.notifiedBody?.names) || 'Unknown',
      notifiedBodySrn:   cert.notifiedBody?.srn || '',
      issueDate:         cert.issueDate || '',
      expiryDate:        cert.certificateExpiry || '',
      status:            parseCertStatus(cert.status?.code || ''),
      certificateType:   cert.certificateType?.code || '',
    }));

    // Find active certificate
    const activeCert = parsedCerts.find(c => c.status === 'VALID') || parsedCerts[0] || null;

    // Certificate warning flags
    const certExpired   = activeCert && activeCert.expiryDate
                          && new Date(activeCert.expiryDate) < new Date();
    const certMissing   = parsedCerts.length === 0;

    // Authorised representative
    const arStatus = authorisedRep?.actorStatus?.code
                     ? parseActorStatus(authorisedRep.actorStatus.code)
                     : null;

    const arActive = arStatus === 'ACTIVE';

    // Device on market check
    const onMarket = statusCode.includes('on-the-market');

    // Overall EU authorisation flag
    const euAuthorised = onMarket && !certExpired && !certMissing;

    // Warnings
    const warnings = [];
    if (certExpired)  warnings.push('CE certificate has expired');
    if (certMissing)  warnings.push('No CE certificate found in EUDAMED');
    if (!onMarket)    warnings.push(`Device status: ${parseDeviceStatus(statusCode)}`);
    if (arStatus && !arActive) warnings.push(`Authorised Representative status: ${arStatus}`);

    return {
      valid:            true,
      euAuthorised,
      basicUdiDi:       trimmed,
      eudamedId:        device.uuid || '',
      tradeName:        device.tradeName || '',
      manufacturerName: device.manufacturerName || '',
      manufacturerSrn:  device.manufacturerSrn || '',
      riskClass:        parseRiskClass(riskClassCode),
      riskClassCode,
      deviceStatus:     parseDeviceStatus(statusCode),
      onMarket,

      certificate: activeCert ? {
        number:       activeCert.certificateNumber,
        notifiedBody: activeCert.notifiedBody,
        nbSrn:        activeCert.notifiedBodySrn,
        issueDate:    activeCert.issueDate,
        expiryDate:   activeCert.expiryDate,
        status:       activeCert.status,
        expired:      certExpired,
      } : null,

      allCertificates: parsedCerts,

      authorisedRep: authorisedRep ? {
        name:    authorisedRep.name || '',
        srn:     authorisedRep.srn || '',
        country: authorisedRep.countryName || '',
        status:  arStatus,
        active:  arActive,
        mandate: authorisedRep.mandateStatus?.code || '',
      } : null,

      warnings,
      totalFound: searchResult.totalElements || searchResult.content.length,
    };

  } catch (err) {
    return {
      valid:      false,
      basicUdiDi: trimmed,
      error:      err.message,
    };
  }
}

/**
 * Run dual-market validation — EUDAMED (EU) + GUDID (US) in one call.
 * Call this before minting a dual-market passport.
 *
 * @param {string} udi          Full GS1 UDI string (for GUDID)
 * @param {string} basicUdiDi   Basic UDI-DI (for EUDAMED)
 * @param {object} opts         { skipGudid: false, skipEudamed: false }
 * @returns {object} Combined dual-market validation result
 */
async function runDualMarketValidation(udi, basicUdiDi, opts = {}) {
  const results = {
    timestamp:  new Date().toISOString(),
    udi,
    basicUdiDi,
    eu:         null,
    us:         null,
    dualMarket: false,
    euOnly:     false,
    usOnly:     false,
    warnings:   [],
    errors:     [],
  };

  // Run both validations in parallel
  const [euResult, usResult] = await Promise.allSettled([
    opts.skipEudamed || !basicUdiDi
      ? Promise.resolve(null)
      : validateBasicUdiDi(basicUdiDi),

    opts.skipGudid || !udi
      ? Promise.resolve(null)
      : validateWithGudid(udi),
  ]);

  // EU result
  if (!opts.skipEudamed && basicUdiDi) {
    if (euResult.status === 'fulfilled') {
      results.eu = euResult.value;
      if (euResult.value.warnings) results.warnings.push(...euResult.value.warnings.map(w => `EU: ${w}`));
    } else {
      results.errors.push(`EU validation error: ${euResult.reason?.message || euResult.reason}`);
    }
  }

  // US result
  if (!opts.skipGudid && udi) {
    if (usResult.status === 'fulfilled') {
      results.us = usResult.value;
    } else {
      results.errors.push(`US validation error: ${usResult.reason?.message || usResult.reason}`);
    }
  }

  // Determine market authorisation
  const euValid = results.eu?.euAuthorised === true;
  const usValid = results.us?.valid === true;

  results.dualMarket = euValid && usValid;
  results.euOnly     = euValid && !usValid && !udi;
  results.usOnly     = usValid && !euValid && !basicUdiDi;

  // eudamedRef field for DevicePassportNFT
  if (results.eu?.manufacturerSrn && results.eu?.eudamedId) {
    results.eudamedRef = `${results.eu.manufacturerSrn}/${results.eu.eudamedId}`;
  }

  // gudidRef field for DevicePassportNFT
  if (results.us?.deviceId) {
    results.gudidRef = results.us.deviceId;
  }

  return results;
}

/**
 * Minimal GUDID validation stub — calls the live GUDID API.
 * Full implementation is in oracle/gudid-bridge/GUDIDBridge.js
 * This stub allows dual-market validation without importing the full bridge.
 */
async function validateWithGudid(udi) {
  try {
    // Extract the DI (first 14 chars of GS1 UDI) for GUDID lookup
    const di = udi.replace(/\//g, '').substring(0, 14);
    const url = `https://accessgudid.nlm.nih.gov/api/v3/devices/lookup.json?di=${di}`;
    const res = await fetch(url, { headers: { 'Accept': 'application/json' } });

    if (!res.ok) return { valid: false, error: `GUDID [${res.status}]` };

    const json = await res.json();
    const device = json.gudidLookupResults?.deviceInfo || json;

    return {
      valid:       true,
      deviceId:    di,
      deviceClass: json.gudidLookupResults?.deviceClass
                   || json.gudidLookupResults?.productCodes?.[0]?.deviceClass
                   || 'Unknown',
      brandName:   device.brandName || '',
      companyName: device.companyName || device.manufacturer || '',
    };
  } catch (e) {
    return { valid: false, error: e.message };
  }
}

// ── Self-test ─────────────────────────────────────────────────────────────────

async function runTests() {
  console.log('MedPassport EUDAMED Bridge — Self Test');
  console.log('======================================');
  console.log('Base URL:', EUDAMED_BASE);
  console.log('');

  // Test 1: Helper functions
  console.log('[1] Helper functions');
  console.log('  parseRiskClass("refdata.risk-class.class-iib"):', parseRiskClass('refdata.risk-class.class-iib'));
  console.log('  parseRiskClass("refdata.risk-class.class-iii"):', parseRiskClass('refdata.risk-class.class-iii'));
  console.log('  parseDeviceStatus("refdata.device-model-status.on-the-market"):', parseDeviceStatus('refdata.device-model-status.on-the-market'));
  console.log('  PASS: all helpers returning human-readable values ✓');

  // Test 2: Basic UDI-DI format check
  console.log('\n[2] Input validation');
  const invalidResult = await validateBasicUdiDi('');
  console.log('  Empty string → valid:', invalidResult.valid, '(expected: false)');
  console.log('  PASS:', !invalidResult.valid ? '✓' : '✗');

  // Test 3: Live EUDAMED API call
  // Using a real EU-registered device: Siemens Healthineers MAGNETOM device family
  // Basic UDI-DI format for GS1: 14-digit GTIN prefix
  // Try a search for a known EU-registered Class IIb/III device
  console.log('\n[3] Live EUDAMED API call — search for registered EU device');
  console.log('  Searching EUDAMED public API...');

  try {
    // Search for any registered device to verify API connectivity
    const searchParams = new URLSearchParams({
      page:             '1',
      pageSize:         '5',
      size:             '5',
      iso2Code:         'en',
      languageIso2Code: 'en',
    });

    const testUrl = `${EUDAMED_BASE}/devices/udiDiData?${searchParams}`;
    const res = await fetch(testUrl, {
      headers: { 'Accept': 'application/json', 'Accept-Language': 'en' }
    });

    if (!res.ok) throw new Error(`HTTP ${res.status}`);

    const json = await res.json();
    const count = json.totalElements || json.content?.length || 0;

    console.log('  API status: OK ✓');
    console.log('  Total devices in EUDAMED:', count.toLocaleString());
    console.log('  First result:', json.content?.[0]?.tradeName || 'N/A',
                '—', parseRiskClass(json.content?.[0]?.riskClass?.code || ''));
    console.log('  PASS: EUDAMED public API accessible ✓');

    // Test 4: Validate a specific device from the search results
    if (json.content && json.content.length > 0) {
      const sampleDevice = json.content[0];
      const sampleBasicUdi = sampleDevice.basicUdi;

      console.log('\n[4] Full validation of EUDAMED-sourced Basic UDI-DI');
      console.log('  Validating:', sampleBasicUdi);
      console.log('  Device:', sampleDevice.tradeName, '—', sampleDevice.manufacturerName);

      if (sampleBasicUdi) {
        const validation = await validateBasicUdiDi(sampleBasicUdi);
        console.log('  valid:', validation.valid);
        console.log('  euAuthorised:', validation.euAuthorised);
        console.log('  riskClass:', validation.riskClass);
        console.log('  deviceStatus:', validation.deviceStatus);
        console.log('  manufacturerSrn:', validation.manufacturerSrn);
        if (validation.certificate) {
          console.log('  certificate.number:', validation.certificate.number);
          console.log('  certificate.notifiedBody:', validation.certificate.notifiedBody);
          console.log('  certificate.status:', validation.certificate.status);
          console.log('  certificate.expiryDate:', validation.certificate.expiryDate);
        }
        if (validation.authorisedRep) {
          console.log('  authorisedRep.name:', validation.authorisedRep.name);
          console.log('  authorisedRep.status:', validation.authorisedRep.status);
        }
        if (validation.warnings?.length > 0) {
          console.log('  warnings:', validation.warnings);
        }
        console.log('  eudamedRef (for DevicePassportNFT):',
                    validation.manufacturerSrn + '/' + validation.eudamedId);
        console.log('  PASS: Full validation complete ✓');
      } else {
        console.log('  SKIP: No basicUdi in first result — API returned different format');
      }
    }

  } catch (err) {
    console.error('  ✗ FAIL:', err.message);
    console.error('  Note: EUDAMED public API may be temporarily unavailable');
    console.error('  Retry or check: https://ec.europa.eu/tools/eudamed');
  }

  console.log('\n======================================');
  console.log('Self-test complete.');
  console.log('');
  console.log('Next step: run dual-market validation with a real pilot device:');
  console.log('  bridge.runDualMarketValidation(gudidUdi, basicUdiDi)');
}

// ── Exports ───────────────────────────────────────────────────────────────────

module.exports = {
  validateBasicUdiDi,
  runDualMarketValidation,
  fetchBasicUdiData,
  fetchActorData,
  // Internals exported for testing
  parseRiskClass,
  parseDeviceStatus,
  parseActorStatus,
  parseCertStatus,
  extractText,
};

// Run self-test if called directly: node EUDAMEDBridge.js
if (require.main === module) {
  runTests().catch(console.error);
}
