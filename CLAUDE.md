# MedPassport Protocol — Claude Code Context

> Technical context only. Business strategy is in a separate private document.
> This file is PUBLIC — lives in the GitHub repository.

## What This Project Is

MedPassport is an open-source protocol creating permanent, independently verifiable
lifecycle records for high-risk medical devices.
Live site: https://tomer-saar.github.io/medpassport-protocol/
License: MIT · Author: Tomer Saar, PMP

## Technology Stack

Solidity 0.8.20 · Foundry · Polygon/Ethereum EVM
ERC-721 device passport · ERC-5192 soulbound cert
Node.js GUDID bridge live · OpenZeppelin v5.6.1
via_ir = true in foundry.toml — required, do not remove

## Contract Architecture — 10 Contracts in Dependency Order

src/types/DeviceTypes.sol           Start here. Shared enums and structs.
src/access/CredentialRegistry.sol   ACTIVE/REVOKED/INACTIVE/MIGRATED states
src/access/RoleManager.sol          Role-based permission for every write path
src/access/MigrationGovernance.sol  3-of-5 multisig for credential succession
src/core/DevicePassportNFT.sol      ERC-721 device identity. UDI-anchored.
src/core/ServiceLogRegistry.sol     Append-only log. 10 event types. 3 flags.
src/core/CorrectionRegistry.sol     SUPERSEDES / DISPUTES / AMENDS
src/core/TransferManager.sol        Dual-signature transfer. 72h expiry.
src/compliance/ComplianceScorer.sol Decay-from-100. Configurable per manufacturer.
src/compliance/CertificationSBT.sol ERC-5192 soulbound. Bronze/Silver/Gold.

## Critical Design Decisions

1. simulatedDevice flag
   false = production, GS1 + GUDID API enforced
   true  = simulation, bypasses validation, use for all tests
   All 67 tests use simulatedDevice = true

2. Zero PII on-chain — permanent architectural constraint
   On-chain: hash, timestamp, credential ID, UDI, event type only
   Never: customer names, pricing, notes, patient data

3. Decay-from-100 scoring
   New device = 100. Deductions on overdue service, undocumented parts,
   open complaints. Active recall forces zero. Configurable via setScoringConfig()

4. Neutral scoring — not OEM-biased
   OEM and ISO service get equal credit for on-time passing events

5. Dual-signature for ownership transfer and certification
   Two independent credentialed actors required. Neither acts unilaterally.

6. Append-only integrity
   Nothing deleted or overwritten. Corrections append a superseding record.

7. GS1 UDI validation
   _isValidGS1UDI() validates first 14 chars. Do not simplify or remove.

## Dual-Market Fields

Field         EU deployment              US deployment
udi           Full UDI string            Full UDI string
basicUdiDi    EU Basic UDI-DI populated  Empty string
gudidRef      Empty string               GUDID record reference
eudamedRef    EUDAMED SRN + device ref   Empty string

GUDID bridge: oracle/gudid-bridge/GUDIDBridge.js
Verified: XIENCE ALPINE, Abbott Vascular, Class III
Device class: productCodes[0].deviceClass
Device ID: identifiers.identifier[0].deviceId

## Regulatory Alignment

ISO 13485:2016  Global  §7.5.8 Traceability · §8.2.1 Feedback
EU MDR 2017/745 EU      Art. 27 UDI · Art. 83 PMS · Art. 87 FSCA
EUDAMED         EU      4 modules mandatory 28 May 2026
FDA QMSR        US      §820.10 UDI · §820.65 Traceability
FDA GUDID       US      UDI-DI validation bridge — live

## Test Suite

forge build
forge test
forge test --summary

Status: 80 tests — 80 passing — 0 failing
  CredentialRegistryTest: 22
  DevicePassportTest: 24
  ComplianceTest: 21

Convention: all mintDevicePassport calls use simulatedDevice = true

## GUDID Bridge

cd oracle/gudid-bridge && node test-bridge.js
Expected: 4 tests passing including live FDA API call

## Deployment

Local:
  anvil
  forge script script/foundry/DeployAll.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key <key>

Demo:
  forge script script/foundry/LiveDemo.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key <key>

Polygon Amoy testnet (pending, do from home computer):
  Wallet: 0xA9d53cCfbc80fd13D91F2e46bB6Eca388295745f
  Faucet: faucet.polygon.technology

## Landing Page

Live: https://tomer-saar.github.io/medpassport-protocol/
File: docs/index.html (keep in sync with docs/site/index.html)

Demo UDIs:
  CT Scanner:    00844588003288/LOT2026-001/SN00432  GOLD   100
  Infusion Pump: 00384109500023/LOT2025-012/SN01891  SILVER 82
  Recall:        00729483610044/LOT2023-008/SN00234  recall 0

## ServiceEvent struct — Sprint 6 additions

bool hasCompatibleParts     non-OEM documented parts used
bool hasUndocumentedParts   parts used with no documentation
bool isSeriousIncident      for INCIDENT_REPORT serious vs minor
logEvent() now takes 10 parameters. All tests updated.

## Pending Build Items

Sprint 7 — COMPLETE:
  Polygon Amoy testnet — DEPLOYED ✅ block 38,793,859
  batchLog() — DONE ✅ 80 tests passing
  SBOM hash field — DONE ✅

Phase 2:
  MTT batch events — multiple events in one transaction
  EUDAMED bridge — verify Basic UDI-DI before EU minting
  CMMS adapter — ServiceMax / Infor EAM API integration
  IPFS storage — calibration certs and service reports
  MedPassport Studio — low-code CMMS field mapper
    BUILD ONLY after first real field mapping session with pilot partner

Phase 3:
  DiscrepancyRegistry.sol — unauthorized intervention detection
  Notified body audit portal
  Authorized Service Partner credential tier

## Git Workflow

git add .
git commit -m "descriptive message"
git push origin main

CI runs forge test on every push. Always run forge test before committing.
Never push broken tests.

Last updated: May 2026 · 80 tests passing · MIT License

## EUDAMED Bridge

oracle/eudamed-bridge/EUDAMEDBridge.js
Test: cd oracle/eudamed-bridge && node EUDAMEDBridge.js
Note: requires normal network (ec.europa.eu blocked in Codespace egress)
Functions:
  validateBasicUdiDi(basicUdiDi) — validates EU device registration
  runDualMarketValidation(udi, basicUdiDi) — EU + US in one call
Returns: euAuthorised, riskClass, certificate, authorisedRep, eudamedRef