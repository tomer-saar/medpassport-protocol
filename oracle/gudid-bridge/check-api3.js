const axios = require('axios');
axios.get('https://accessgudid.nlm.nih.gov/api/v3/devices/lookup.json', {
  params: { di: '08717648200274' }
}).then(r => {
  const device = r.data.gudid.device;
  const identifiers = device.identifiers || {};
  const identifier = Array.isArray(identifiers.identifier)
    ? identifiers.identifier[0]
    : identifiers.identifier;
  console.log('identifier object:', JSON.stringify(identifier));
  console.log('productCodes:', JSON.stringify(r.data.productCodes));
}).catch(e => console.log(e.message));
