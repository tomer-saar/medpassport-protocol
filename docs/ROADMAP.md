# MedPassport Protocol — Public Roadmap

> Public roadmap. Detailed sprint plans, partner targets, pricing, pilot negotiations, and private architecture ADRs are maintained outside the public repository.

## Current Status — June 2026

MedPassport is at TRL 5 with a live testnet protocol on Polygon Amoy.

Completed public milestones:

- 10 smart contracts implemented and deployed on Polygon Amoy testnet
- 80 automated tests passing
- FDA GUDID bridge live and verified
- EU EUDAMED bridge live and verified against public data
- IPFS upload layer operational
- Website and interactive demo available
- Protocol axioms documented

## Phase 1 — Protocol Foundation

Status: Complete

- Define protocol axioms
- Implement credential registry and role permissions
- Implement device passport NFT
- Implement append-only service event log
- Implement correction registry
- Implement dual-signature ownership transfer
- Implement compliance scoring
- Implement soulbound certification token
- Add automated Foundry test suite

## Phase 2 — Testnet Evidence Layer

Status: In progress

Goals:

- Complete VaultService validation on Polygon Amoy
- Connect off-chain evidence upload to on-chain hash anchoring
- Improve public demo flows
- Build production-grade barcode/PWA fallback workflow
- Prepare CMMS integration interfaces
- Improve technical documentation for external review
- Complete preliminary smart-contract security review

## Phase 3 — Pilot Readiness

Status: Planned

Goals:

- Run live lifecycle events on testnet with real-world workflow assumptions
- Validate service-event capture through CMMS or barcode/PWA fallback
- Measure event submission latency and evidence completeness
- Validate ownership-transfer and certification workflows
- Calibrate compliance scoring against field data
- Prepare pilot reporting dashboards

## Phase 4 — Production Hardening

Status: Planned

Goals:

- Enterprise-grade identity and access management
- Encrypted evidence vault
- Formal key custody and operational security controls
- Mainnet deployment after audit and pilot milestones
- Expanded CMMS integrations
- Regulator / notified-body audit views
- Insurer and procurement-facing read APIs

## Roadmap Principles

- Patient data and PII remain out of scope.
- Public ledger data remains limited to hashes, attestations, timestamps, device identity, and credential metadata.
- Detailed commercial strategy and partner-specific pilot scope are not public roadmap items.
- Architecture decisions are published only when they are stable and safe for public disclosure.
