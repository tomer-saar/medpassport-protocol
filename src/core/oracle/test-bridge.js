cat > oracle/gudid-bridge/test-bridge.js << 'EOF'
const GUDIDBridge = require('./GUDIDBridge');

async function runTests() {
  console.log('==========================================');
  console.log('MedPassport GUDID Bridge - Test Suite');
  console.log('==========================================\n');

  console.log('TEST 1: Simulation mode');
  console.log('------------------------');
  const simBridge = new GUDIDBridge({ simulationMode: true });
  const simResult = await simBridge.verifyUDI('00844588003288');
  console.log('Result:', simResult.verified ? 'PASS' : 'FAIL');
  console.log('Source:', simResult.source);
  console.log('Device:', simResult.brandName);
  console.log();

  console.log('TEST 2: Live GUDID API - Abbott XIENCE ALPINE stent');
  console.log('------------------------------------------------------');
  const liveBridge = new GUDIDBridge({ simulationMode: false });
  const liveResult = await liveBridge.verifyUDI('08717648200274');
  console.log('Result:', liveResult.verified ? 'PASS' : 'FAIL');
  if (liveResult.verified) {
    console.log('UDI-DI:', liveResult.udiDi);
    console.log('Device:', liveResult.brandName);
    console.log('Company:', liveResult.companyName);
    console.log('Class:', liveResult.deviceClass);
    console.log('Commercial:', liveResult.inCommercialDistribution);
  } else {
    console.log('Error:', liveResult.error);
  }
  console.log();

  console.log('TEST 3: Invalid UDI rejection');
  console.log('------------------------------');
  const invalidResult = await liveBridge.verifyUDI('INVALID-UDI-123');
  console.log('Result:', !invalidResult.verified ? 'PASS' : 'FAIL');
  console.log('Error code:', invalidResult.errorCode);
  console.log();

  console.log('TEST 4: Empty UDI rejection');
  console.log('----------------------------');
  const emptyResult = await liveBridge.verifyUDI('');
  console.log('Result:', !emptyResult.verified ? 'PASS' : 'FAIL');
  console.log('Error code:', emptyResult.errorCode);
  console.log();

  console.log('TEST 5: Class verification - correct class');
  console.log('------------------------------------------');
  const classResult = await liveBridge.verifyUDIWithClass('08717648200274', 'CLASS_III');
  console.log('Result:', classResult.verified ? 'PASS' : 'FAIL');
  console.log('Class match:', classResult.classMatch);
  console.log();

  console.log('==========================================');
  console.log('Test suite complete');
  console.log('==========================================');
}

runTests().catch(console.error);
EOFsa