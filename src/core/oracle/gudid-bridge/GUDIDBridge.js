cat > oracle/gudid-bridge/GUDIDBridge.js << 'EOF'
const axios = require('axios');

const GUDID_BASE_URL = 'https://accessgudid.nlm.nih.gov/api/v3';
const REQUEST_TIMEOUT_MS = 10000;

const FDA_CLASS_MAP = {
  '1': 'CLASS_I',
  '2': 'CLASS_II',
  '3': 'CLASS_III',
  'U': 'UNCLASSIFIED'
};

class GUDIDBridge {

  constructor(options = {}) {
    this.baseUrl        = options.baseUrl        || GUDID_BASE_URL;
    this.timeout        = options.timeout        || REQUEST_TIMEOUT_MS;
    this.simulationMode = options.simulationMode || false;
  }

  async verifyUDI(udiDi) {
    if (!udiDi || udiDi.trim() === '') {
      return this._error('UDI-DI cannot be empty', 'EMPTY_UDI');
    }

    if (this.simulationMode) {
      console.log(`[GUDID Bridge] Simulation mode for: ${udiDi}`);
      return this._simulatedResponse(udiDi);
    }

    try {
      console.log(`[GUDID Bridge] Verifying UDI-DI: ${udiDi}`);
      const url = `${this.baseUrl}/devices/lookup.json`;
      const response = await axios.get(url, {
        params: { di: udiDi },
        timeout: this.timeout,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'MedPassport-Protocol/1.0'
        }
      });
      return this._parseResponse(response.data, udiDi);
    } catch (error) {
      if (error.response && error.response.status === 404) {
        return this._error(`UDI-DI not found in GUDID: ${udiDi}`, 'UDI_NOT_FOUND');
      }
      if (error.code === 'ECONNABORTED') {
        return this._error('GUDID API request timed out', 'TIMEOUT');
      }
      return this._error(`GUDID API error: ${error.message}`, 'API_ERROR');
    }
  }

  async verifyUDIWithClass(udiDi, expectedClass) {
    const result = await this.verifyUDI(udiDi);
    if (!result.verified) return result;
    const gudidClass = FDA_CLASS_MAP[result.deviceClass] || 'UNKNOWN';
    if (gudidClass !== expectedClass) {
      return {
        ...result,
        verified: false,
        classMatch: false,
        error: `Class mismatch: GUDID=${gudidClass}, expected=${expectedClass}`,
        errorCode: 'CLASS_MISMATCH'
      };
    }
    return { ...result, classMatch: true };
  }

  _parseResponse(data, udiDi) {
    const device = (data.gudid || {}).device || {};
    const productCodes = data.productCodes || [];

    // Extract deviceId from identifiers array
    const identifiers = device.identifiers || {};
    const identifierArr = identifiers.identifier || [];
    const primaryIdentifier = Array.isArray(identifierArr)
      ? identifierArr[0]
      : identifierArr;
    const deviceId = (primaryIdentifier || {}).deviceId || '';

    // Extract deviceClass from productCodes array
    const firstProduct = Array.isArray(productCodes)
      ? productCodes[0]
      : productCodes;
    const deviceClass = (firstProduct || {}).deviceClass || '';
    const deviceName  = (firstProduct || {}).deviceName  || '';

    if (!device.brandName && !deviceId) {
      return this._error(`No device data for UDI-DI: ${udiDi}`, 'NO_DATA');
    }

    console.log(`[GUDID Bridge] Verified: ${deviceId}`);
    console.log(`[GUDID Bridge] Device:   ${device.brandName || 'Unknown'}`);
    console.log(`[GUDID Bridge] Class:    ${deviceClass}`);
    console.log(`[GUDID Bridge] Company:  ${device.companyName || 'Unknown'}`);

    return {
      verified:             true,
      udiDi:                deviceId || udiDi,
      brandName:            device.brandName            || '',
      versionModelNumber:   device.versionModelNumber   || '',
      catalogNumber:        device.catalogNumber        || '',
      companyName:          device.companyName          || '',
      deviceClass:          deviceClass,
      deviceName:           deviceName,
      deviceDescription:    device.deviceDescription    || '',
      inCommercialDistribution:
        device.deviceCommDistributionStatus === 'In Commercial Distribution',
      rx:  device.rx  || false,
      otc: device.otc || false,
      source:     'FDA_GUDID',
      verifiedAt: new Date().toISOString()
    };
  }

  _simulatedResponse(udiDi) {
    return {
      verified:            true,
      udiDi:               udiDi,
      brandName:           'CardioScan Pro 3000 (Simulated)',
      versionModelNumber:  'CSP3000-SIM',
      companyName:         'MedDevice GmbH (Simulated)',
      deviceClass:         '2',
      deviceName:          'CT Scanner - Simulated',
      deviceDescription:   'CT Scanner Class IIb - MedPassport demo',
      inCommercialDistribution: true,
      rx:  true,
      otc: false,
      source:          'SIMULATION',
      verifiedAt:      new Date().toISOString(),
      simulationMode:  true
    };
  }

  _error(message, errorCode = 'UNKNOWN') {
    console.error(`[GUDID Bridge] Error: ${message}`);
    return {
      verified:   false,
      error:      message,
      errorCode:  errorCode,
      source:     'FDA_GUDID',
      verifiedAt: new Date().toISOString()
    };
  }
}

module.exports = GUDIDBridge;
EOF