const axios = require('axios');
axios.get('https://accessgudid.nlm.nih.gov/api/v3/devices/lookup.json', {
  params: { di: '08717648200274' }
}).then(r => {
  const device = r.data.gudid.device;
  console.log('deviceIdentifier:', device.deviceIdentifier);
  console.log('brandName:', device.brandName);
  console.log('companyName:', device.companyName);
  console.log('deviceClass:', device.deviceClass);
}).catch(e => console.log(e.message));
