<div align="center">

# MedPassport Protocol — Whitepaper

`Version 1.3` &nbsp;·&nbsp; `May 2026` &nbsp;·&nbsp; `MIT License`

[![Status](https://img.shields.io/badge/Status-Community%20Review%20Draft-orange)]()
[![TRL](https://img.shields.io/badge/TRL-4%20%E2%86%92%206%20(Phase%202)-informational)]()

</div>

---

## Request the Full Whitepaper

The full MedPassport Protocol Whitepaper v1.3 covers:

- Complete protocol architecture and design rationale
- Regulatory framework — EU MDR, EUDAMED, FDA QMSR, ESPR alignment
- Dual-market readiness (EU + US) — single deployment, dual validation
- Security and privacy model — Zero-PII three-layer architecture
- Compliance scoring model — Decay-from-100, component weights, calibration methodology
- Wave 1 pilot definition — success metrics, data collection paths, KPIs
- Use cases — OEM, hospital, refurbisher, insurer, regulator
- Competitive landscape analysis
- Business model and go-to-market strategy

**To request the full whitepaper:**

→ Connect on [LinkedIn](https://www.linkedin.com/in/tomer-saar/) and send a message

→ Email via the GitHub profile contact

---

## Protocol Summary

MedPassport is an open-source protocol (MIT) that assigns every medical device a
permanent, tamper-evident Digital Product Passport — carrying lifecycle evidence
across the organizational handoffs where today's systems go silent.

**The core innovation:** A cross-organizational evidence layer that allows manufacturers,
hospitals, independent service organizations, refurbishers, and regulators to write and
read device lifecycle attestations without depending on a single trusted operator or
exposing commercially sensitive data.

**The regulatory driver:** EU MDR Art. 83 PMS, PSUR obligations, FSCA execution (Art. 87), and EUDAMED mandatory registration (May 2026, EU Decision 2025/2371) all require device-level evidence that current systems cannot provide across organizational boundaries. The EUDAMED Vigilance & PMS module (expected mandatory ~Q2 2027) will require digital PSUR and serious incident submissions — MedPassport is the evidence infrastructure that feeds this submission.

---

## Key Protocol Properties

**Zero-PII on-chain** — only cryptographic hashes, attestations, and UDI identifiers
reach the public ledger. No customer names, pricing, service notes, or personal data
is architecturally possible on-chain.

**Append-only integrity** — events are signed attestations. Nothing is deleted or
overwritten. Corrections append a superseding record — the full audit trail is always
preserved.

**Headless integration** — field technicians take zero additional steps. The protocol
reads from existing CMMS work order closures automatically. Barcode scan fallback for
non-integrated environments, with Offline-to-Online sync.

**Neutral scoring** — compliance scores reflect actual device condition, not vendor
loyalty. OEM and qualified ISO service both receive full credit for on-time, passing
events.

**Mutual Attestation** — cross-organizational events require cryptographic consent
from all parties involved. No single actor can write to another's device record
unilaterally.

**Gasless enterprise UX** — ERC-4337 account abstraction means no enterprise
participant manages crypto wallets or native tokens.

---

## Compliance Scoring Model

A new CE-marked device starts at **100/100**. Deductions are applied automatically
when service is overdue, parts are undocumented, software is out of date, or
complaints are open. A device that has gone through an active recall holds **0/100**
(hard zero) until corrective action is completed and verified.

**Certification thresholds:**
- GOLD: 90–100
- SILVER: 75–89
- BRONZE: 60–74
- Below 60: Not certifiable

---

## Regulatory Alignment Summary

| Framework | Jurisdiction | Coverage |
|---|---|---|
| ISO 13485:2016 | Global | §7.5.8 Traceability · §8.2.1 Feedback |
| EU MDR 2017/745 | EU | Art. 27 UDI · Art. 83 PMS · Art. 87 FSCA |
| EUDAMED | EU | 4 modules mandatory 28 May 2026 · Legacy device deadline 28 Nov 2026 · Vigilance & PMS module mandatory ~Q2 2027 (indicative — EU timelines typically slip 6-12 months) |
| EU ESPR 2024/1781 | EU | DPP-ready architecture |
| FDA QMSR 21 CFR 820 | US | UDI · Records · Traceability · Servicing |
| FDA GUDID | US | Live UDI-DI validation bridge |
| 21 CFR Part 11 | US | Audit trail · unique identification |

---

## Current Status — TRL 4

The protocol is at Technology Readiness Level 4 (lab prototype):

- 10 smart contracts · 74 automated tests · GitHub Actions CI green
- Live FDA GUDID bridge · AccessGUDID API verified
- Interactive 5-scenario demo — [tomer-saar.github.io/medpassport-protocol](https://tomer-saar.github.io/medpassport-protocol)
- Role-based demo v2 (manufacturer / hospital / ISO / refurbisher / regulator) —
  [tomer-saar.github.io/medpassport-protocol/demo-v2.html](https://tomer-saar.github.io/medpassport-protocol/demo-v2.html)

Phase 2 (Sprint 7, active) targets TRL 5: Polygon Amoy testnet deployment,
IPFS vault, preliminary security audit, Path B barcode UI.

---

## Author

**Tomer Saar, PMP** — 20+ years Medical Device Industry
Co-inventor on multiple granted patents in implantable cardiac devices and motion systems

**Research Lead & Industry Advisor: Dr. Shlomo Gilat**
DSc Biomedical Engineering, Technion · 35+ years Class IIb/III · 2 US patents · 22 publications

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue?logo=linkedin)](https://www.linkedin.com/in/tomer-saar/)

---

*Not legal, medical, or regulatory advice. MIT License.*
