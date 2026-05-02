const axios = require('axios');
axios.get('https://accessgudid.nlm.nih.gov/api/v3/devices/lookup.json', {
  params: { di: '08717648200274' }
}).then(r => {
  console.log('KEYS:', Object.keys(r.data));
  console.log('START:', JSON.stringify(r.data).substring(0, 400));
}).catch(e => console.log(e.message));
