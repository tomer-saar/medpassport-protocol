<div align="center">

# 🏥 MedPassport Protocol

### Cross-organizational trust infrastructure for regulated medical device lifecycles

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-363636?logo=solidity)](https://soliditylang.org/)
[![Network](https://img.shields.io/badge/Network-Polygon%20%7C%20Ethereum-8247E5?logo=ethereum)](https://polygon.technology/)
[![Privacy](https://img.shields.io/badge/Privacy-Zero--PII%20Architecture-brightgreen)]()
[![Validation](https://img.shields.io/badge/Validation-GAMP%205%20Aligned-blue)]()
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Tests](https://github.com/tomer-saar/medpassport-protocol/actions/workflows/test.yml/badge.svg)](https://github.com/tomer-saar/medpassport-protocol/actions/workflows/test.yml)
[![Status](https://img.shields.io/badge/Status-Alpha%20%2F%20Community%20Review-orange)]()

<br/>

**MedPassport is an open-source protocol that assigns every medical device
a permanent, tamper-evident Digital Product Passport — carrying lifecycle
evidence across the organizational handoffs where today's systems go silent.**

<br/>

[📄 Whitepaper](docs/WHITEPAPER.md) &nbsp;·&nbsp;
[🏗️ Architecture](#️-architecture) &nbsp;·&nbsp;
[🔐 Security & Privacy](#-security--privacy) &nbsp;·&nbsp;
[🚀 Quick Start](#-quick-start) &nbsp;·&nbsp;
[🤝 Contributing](CONTRIBUTING.md)

</div>

---

## The Problem This Solves

Medical device lifecycle data crosses six organizational boundaries —
manufacturer, distributor, hospital, ISO service organization,
refurbisher, and secondary buyer. At every handoff, existing systems
go silent.

The consequence is structural:

- Recalls take weeks to reach affected devices because post-distribution
  visibility depends on voluntary reporting from downstream holders
- Audit preparation takes days because evidence is assembled from
  3–8 disconnected systems under time pressure
- Refurbished devices sell at 30–50% discount because buyers cannot
  independently verify service history
- Warranty disputes take 30–90 days because both parties work from
  competing paper records

**This is not a software problem. It is an architectural one.**
No existing platform carries device evidence across organizational
boundaries without depending on a single trusted operator.
MedPassport removes the need for that operator.

---

## Protocol Design Principles

| Principle | Implementation |
|---|---|
| **Zero-PII on-chain** | Only hashes, attestations, UDI identifiers, and organizational credentials reach the ledger. No PII or PHI is architecturally possible on-chain. |
| **Append-only integrity** | Events are signed attestations. Nothing is deleted or overwritten. Corrections append a superseding record — the full audit trail is always preserved. |
| **Headless integration** | Field technicians take zero additional steps. The protocol reads from ServiceMax / Infor EAM work order closures automatically. |
| **Gasless enterprise UX** | ERC-4337 account abstraction. No enterprise participant manages crypto wallets or native tokens. Costs settle via standard SaaS billing. |
| **Open protocol, paid network** | Smart contracts and schemas are MIT-licensed. Revenue comes from managed SaaS, integration services, and certification fees built on top. |

---

## Architecture
┌─────────────────────────────────────────────────────────────┐
│                      STAKEHOLDER TIER                       │
│  Manufacturer · Hospital · ISO Service Org · Refurbisher    │
│  Regulator · Insurer (read-only) · Public (read-only)       │
└───────────────────────┬─────────────────────────────────────┘
│  Role-based permissioned access
┌───────────────────────▼─────────────────────────────────────┐
│                    ENTERPRISE API LAYER                     │
│  Role-based access · Dashboards · Audit views               │
│  ERC-4337 Paymaster · SSO / SAML integration                │
├─────────────────────────────────────────────────────────────┤
│                  OFF-CHAIN DOCUMENT VAULT                   │
│  IPFS + Arweave · Service reports · Calibration certs       │
│  No PII · No PHI · Hash-anchored on-chain                   │
└───────────────────────┬─────────────────────────────────────┘
│  Hashes · attestations · metadata only
┌───────────────────────▼─────────────────────────────────────┐
│              ON-CHAIN LEDGER  (Polygon / Ethereum)          │
│                                                             │
│  ┌──────────────┐  ┌─────────────────┐  ┌───────────────┐  │
│  │Device identity│  │ Service event  │  │  Cert token   │  │
│  │token (ERC-721)│  │ log (append-   │  │  (ERC-5192    │  │
│  │UDI · ownership│  │ only hashes)   │  │  soulbound)   │  │
│  │recall flag   │  │                 │  │  Bronze/Ag/Au │  │
│  └──────────────┘  └─────────────────┘  └───────────────┘  │
└─────────────────────────────────────────────────────────────┘
│  Read-only · approved fields only
┌───────────────────────▼─────────────────────────────────────┐
│                    READ-ONLY CONSUMERS                      │
│  Public buyer (QR scan) · Insurer API · CMMS / ERP sync     │
└─────────────────────────────────────────────────────────────┘

---

## Smart Contract Stack
src/
├── types/
│   └── DeviceTypes.sol          # Shared structs and enums
├── access/
│   ├── CredentialRegistry.sol   # Credential states and transitions
│   ├── RoleManager.sol          # Role-based permissions
│   └── MigrationGovernance.sol  # M&A and succession handling
├── core/
│   ├── DevicePassportNFT.sol    # ERC-721 device identity token
│   ├── ServiceLogRegistry.sol   # Append-only event log
│   ├── CorrectionRegistry.sol   # Dispute and correction chain
│   └── TransferManager.sol      # Dual-signature ownership transfer
├── compliance/
│   ├── ComplianceScorer.sol     # Weighted scoring algorithm
│   └── CertificationSBT.sol     # ERC-5192 soulbound cert token
└── account-abstraction/
└── MedPassportPaymasterStub.sol  # Gasless UX layer
---

## 🔐 Security & Privacy

### Zero-PII architecture

No PII or PHI is ever written to the ledger. Enforced at three
independent levels — protocol, API gateway, and tenant configuration.
No override exists.

### Append-only integrity

Events are signed attestations. Corrections append a superseding
record referencing the original hash. The original is permanently
preserved. Nothing is deleted.

### Dual-signature for high-risk events

Ownership transfer and certification require two independent
credentialed actors. Neither can complete the action unilaterally.

### GAMP 5 aligned

Managed SaaS classified as GAMP 5 Category 4. Full Validation
Support Package provided at enterprise onboarding — IQ/OQ/PQ
templates, traceability matrix, risk assessment.

---

## Regulatory Alignment

| Framework | Key coverage |
|---|---|
| **ISO 13485:2016** | §7.5.8 Traceability · §8.2.1 Feedback · §8.3 Nonconforming product |
| **EU MDR 2017/745** | Art. 27 UDI · Art. 83 PMS · Art. 87 Incident reporting |
| **EU ESPR 2024/1781** | DPP-ready architecture |
| **FDA QMSR 21 CFR 820** | §820.60 · §820.65 · §820.200 |
| **21 CFR Part 11** | Audit trail · unique identification · record retrieval |

---

## Sprint 0 — Protocol Design Documents

The protocol design documents are published before any contract code.
This is intentional — every architectural decision is documented,
justified, and traceable to a regulatory requirement.

| Document | Description |
|---|---|
| [ADR-000 Protocol Axioms](docs/adrs/ADR-000-protocol-axioms.md) | The five constitutional rules every contract must uphold |
| [ADR-001 Credential States](docs/adrs/ADR-001-credential-states.md) | Role matrix and credential state transitions |
| [Event Taxonomy](docs/event-model/EVENT-TAXONOMY.md) | All event types, write authority, and edge cases |
| [Sequence Diagrams](docs/architecture/SEQUENCE-DIAGRAMS.md) | Step-by-step flows for ownership transfer and certification |

---

## 🚀 Quick Start

```bash
git clone https://github.com/tomer-saar/medpassport-protocol.git
cd medpassport-protocol
forge install
forge build
forge test
```

---

## 🗺️ Roadmap

- [x] **Sprint 0** — Protocol design documents · axioms · event taxonomy · sequence diagrams
- [x] **Sprint 1** — Identity and governance · CredentialRegistry · RoleManager · MigrationGovernance
- [x] **Sprint 2** — Core lifecycle · DevicePassportNFT · ServiceLogRegistry · CorrectionRegistry · TransferManager
- [x] **Sprint 3** — Compliance layer · ComplianceScorer · CertificationSBT
- [x] **Sprint 4** — Deployment scripts · live demo · CT scanner pilot verified on-chain

## ✅ Live Demo Results

The complete CT scanner pilot workflow was executed on a local blockchain:
PASSPORT STATUS - CardioScan Pro 3000
Token ID:         1
UDI:              00844588003288/LOT2026-001/SN00432
Service events:   4 (PM, Calibration, Inspection, SW Update)
Compliance score: 100 / 100
Certified:        true
Cert level:       GOLD
Recall active:    false

Full workflow verified:
- Device passport minted by manufacturer
- Dual-signature ownership transfer to hospital
- 4 service events logged on-chain
- Compliance score calculated automatically
- Gold certification issued via dual-signature
- Full history preserved across all transfers
---

## Enterprise Inquiries

MedPassport maintains a separate Enterprise Addendum covering
deployment architecture, governance model, GAMP 5 validation,
integration priority, pilot definition, and ROI benchmarks.

Shared directly with qualified enterprise contacts on request.

**Contact:** [(https://www.linkedin.com/in/tomer-saar/)]

---

## 👤 Author

**Tomer Saar, PMP**
20+ years in Medical Device Industry
R&D · Engineering · Manufacturing Management at Tier-1 Global Leaders
Currently deepening blockchain expertise to build the trust
infrastructure this industry is missing.



---

## 🤝 Contributing

Contributions welcome from Solidity developers, medical device
professionals, healthcare IT specialists, and security researchers.

See [CONTRIBUTING.md](CONTRIBUTING.md) to get started.

---

## ⚖️ License

MIT License · Not legal, medical, or regulatory advice.

---

<div align="center">

**If this project is useful to you, please ⭐ star the repo**

</div>