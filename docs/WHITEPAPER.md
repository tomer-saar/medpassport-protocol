<div align="center">

# MedPassport Protocol
## Whitepaper v1.2

**A Blockchain-Based Digital Product Passport for the Medical Device Industry**

`Version 1.2` &nbsp;·&nbsp; `May 2026` &nbsp;·&nbsp; `MIT License`

[![Regulatory](https://img.shields.io/badge/Regulatory%20Foundation-ISO%2013485%20%7C%20EU%20MDR%20%7C%20FDA%20QMSR%20%7C%2021%20CFR%20Part%2011-blue)]()
[![Status](https://img.shields.io/badge/Status-Community%20Review%20Draft-orange)]()

</div>

---

## Author's Note

**By Tomer Saar, PMP | Medical Device Industry Veteran | Blockchain Practitioner**

After 20 years in the medical device industry — holding leadership roles in R&D, Engineering, and Manufacturing Management for Tier-1 global manufacturers — I came to a conclusion that reshaped how I see the industry I spent my career building:

> *The greatest risk to a medical device isn't always mechanical. It's informational.*

I have led the teams that design, validate, and manufacture high-stakes clinical systems — from diagnostic imaging to invasive surgical devices. In every role, in every audit, in every post-market review, I encountered the same structural weakness: the data that describes a device's history is fragmented, siloed, and frequently lost the moment a device changes hands.

I call this the **Information Gap**. It is not a technology problem. It is an architectural one — and it exists because no shared infrastructure has ever been designed to carry device evidence across organizational boundaries without depending on any single party's goodwill or system uptime.

MedPassport is the synthesis of two decades of operational expertise and the trustless architecture of blockchain. It is not a theoretical exercise. It is the tool I wish had existed every time I sat in an audit room assembling paper records that should have been a single, verifiable chain of evidence.

I am currently deepening my blockchain expertise to build this. The problem is real. The technology is ready. The time is now.

---

## Table of Contents

- [1. Executive Summary](#1-executive-summary)
- [2. The Information Gap — Three Cases That Prove the Problem](#2-the-information-gap--three-cases-that-prove-the-problem)
- [3. The Three Pillars MedPassport Addresses](#3-the-three-pillars-medpassport-addresses)
- [4. How MedPassport Works](#4-how-medpassport-works)
- [5. Data Model and Privacy Principles](#5-data-model-and-privacy-principles)
- [6. Regulatory Framework](#6-regulatory-framework)
- [7. Target Customers and ROI](#7-target-customers-and-roi)
- [8. What MedPassport Is Not](#8-what-medpassport-is-not)
- [9. Business Model](#9-business-model)
- [10. Competitive Positioning](#10-competitive-positioning)
- [11. Use Cases](#11-use-cases)
- [12. Roadmap](#12-roadmap)
- [13. References](#13-references)

---

## 1. Executive Summary

The medical device industry is world-class at building hardware. It has not kept pace on data integrity.

As a device moves from manufacturer to distributor to hospital to service provider to secondary market, its critical records — the Device History Record, calibration certificates, service logs, configuration history, component provenance — are scattered across incompatible systems, stored in local databases, or simply lost. This is not a minor inconvenience. It is a structural vulnerability that has harmed patients, stalled recalls, and suppressed the value of the refurbished device market, estimated at $16.8 billion globally (Grand View Research, 2024).

**MedPassport is an open-source blockchain protocol that assigns every medical device a permanent, tamper-evident Digital Product Passport (DPP).** It creates a shared, tamper-evident source of lifecycle evidence — accessible to authorized stakeholders according to role-based permissions — that travels with the device for its entire operational life.

**Three capabilities, one protocol:**

| Capability | What it addresses |
|---|---|
| **Immutable device identity** | A permanent record anchored to a unique on-chain token — duplicate identity conflicts become detectable and far harder to introduce silently |
| **Verifiable service timeline** | Every service event, calibration, part replacement, and software update recorded and shared across authorized parties |
| **Compliance evidence layer** | Audit-ready records that materially reduce the time and effort required to assemble regulatory evidence |

**The four boundaries where existing systems fail:**
Modern Class IIb and III devices maintain continuous cloud connectivity that works well within its boundary. MedPassport covers the four boundaries where cloud stops: devices older than ~15 years with no cloud interface; devices sold to secondary buyers whose cloud connection is severed at contract expiry; third-party ISO service events that never enter the manufacturer cloud; and cloud data the manufacturer controls that a notified body cannot independently verify.

**The commercial model is straightforward:** MedPassport is free and open as a protocol. Revenue comes from the managed enterprise network — hosted infrastructure, compliance dashboards, integration services, and certification fees — built on top of it.

**The regulatory foundation is ISO 13485:2016**, extended with EU MDR/IVDR for European market access and FDA QMSR with 21 CFR Part 11 for the US market. Designed for multi-jurisdictional deployment from the outset.

---

## 2. The Information Gap — Three Cases That Prove the Problem

These cases are drawn from publicly documented events. They are presented here to illustrate the structural nature of the Information Gap — not as legal or regulatory conclusions. The framing reflects the author's interpretation based on public records and industry experience.

---

### Case 1 — The Duplicate Serial Number Problem
**Philips Respironics, 2023**

In April 2023, the FDA issued a safety alert for Philips respiratory devices that had already completed a repair and rework program following the 2021 recall. The alert is consistent with a failure of device identity management during large-scale rework operations.

**The gap this illustrates:** When devices are reworked at scale, identity records in centralized systems can become inconsistent. The consequence — devices receiving incorrect configuration data — suggests that serial number integrity broke down at some point in the repair workflow.

**What MedPassport addresses:** An on-chain device identity token materially reduces the risk of silent identity conflicts. Each token is unique and non-replicable. Any attempt to register a duplicate identifier against an existing token produces a detectable conflict rather than a silent overwrite. Configuration history is part of the immutable record.

> *This illustrates the Provenance failure mode.*

---

### Case 2 — The Visibility Gap
**Philips Respironics recall, 2021 — approximately 15 million devices**

The 2021 Philips recall became one of the most operationally complex recall events in FDA history. Public reporting and FDA communications suggest that a significant challenge was post-distribution visibility: once devices left the manufacturer's logistics network, tracking their location depended on data held by distributors, DME providers, and hospitals — each in their own systems.

**The gap this illustrates:** Recall effectiveness is constrained by the quality of post-distribution traceability. When that traceability depends on voluntary reporting from a fragmented network of downstream holders, some devices will remain unreached.

**What MedPassport addresses:** A shared ledger with permissioned visibility means authorized parties — manufacturer, distributor, hospital — can each see the current recorded status of a specific device identifier without depending on a single party's database. Recall notifications can be targeted to recorded current holders rather than broadcast into an uncertain network.

> *This illustrates the Compliance failure mode.*

---

### Case 3 — The Component Provenance Gap
**Stryker / Sage Products, 2023 — approximately 174,000 units**

In 2023, Stryker's Sage Products division recalled approximately 174,000 units of a urine management system. Regulatory documentation is consistent with a supplier process change that introduced a latex adhesive not reflected in the device label — a product marked latex-free that contained latex for a subset of production units.

**The gap this illustrates:** When supplier process changes are not systematically reflected in Device History Records at the unit level, labeling can drift from reality. The consequence in this case was patient safety risk for latex-sensitive individuals.

**What MedPassport addresses:** A device passport designed to carry component provenance attestations — supplier identity, material declarations, process change events — provides a mechanism for flagging affected units when a supplier change occurs. The goal is to make labeling drift detectable rather than invisible.

> *This illustrates the Service History and Provenance failure mode.*

---

### The Common Thread

Three cases. Three different companies. Three different failure types. One shared structural cause: **the data trail broke down the moment the device moved beyond the boundary of a single organizational system.**

This is the Information Gap. MedPassport is designed to close it.

---

## 3. The Three Pillars MedPassport Addresses

### Pillar 1 — Provenance

**The pain:** Medical device records are fragmented across manufacturers, hospitals, service providers, and resellers. Verifying authenticity, ownership history, and device condition across the full lifecycle requires manual effort, reliance on third parties, and tolerance for gaps.

**What MedPassport does:** Creates a tamper-evident device passport that stores key lifecycle events — from manufacturing through first sale, servicing, and resale — so authorized stakeholders can verify the same evidence base without depending on any single party's records.

**Who benefits:**

| Stakeholder | Benefit |
|---|---|
| Manufacturer | Materially reduces counterfeit exposure and traceability risk |
| Hospital | Faster equipment verification at receipt and during audit |
| Resale buyer | Verifiable device history supports more confident purchasing decisions |

---

### Pillar 2 — Service History

**The pain:** Maintenance and repair histories are incomplete, siloed, or disputed. Proving whether service was performed, by whom, with which parts, and to which standard requires assembling records from multiple disconnected systems — if those records exist at all.

**What MedPassport does:** Logs service events, replaced parts, certifications, and maintenance intervals against the device's unique on-chain identity. Creates a verifiable service timeline shared across OEMs, hospitals, service organizations, and insurers, subject to role-based access controls.

**Who benefits:**

| Stakeholder | Benefit |
|---|---|
| Hospital | Stronger position in service agreement negotiations based on verified device condition |
| Service provider | Verifiable record of work performed |
| Insurer | Evidence base for warranty and claims decisions; reduced manual back-and-forth |

---

### Pillar 3 — Compliance

**The pain:** Regulatory and audit processes are slowed by fragmented evidence, manual reconciliation, and poor traceability. When authorities or manufacturers need to investigate an incident or execute a recall, they are assembling evidence from a dozen different organizations.

**What MedPassport does:** Provides a compliance evidence layer that links manufacturing records, ownership transfers, service events, and lifecycle milestones into one auditable chain — accessible to all authorized parties simultaneously and structured to support ISO 13485, MDR, and QMSR evidence requirements.

**Who benefits:**

| Stakeholder | Benefit |
|---|---|
| Regulator | More targeted investigations and recall operations |
| Manufacturer | Compliance teams spend less time collecting records from multiple systems |
| Compliance officer | Structured evidence base aligned to regulatory framework requirements |

---

## 4. How MedPassport Works

### The Passport

Every medical device registered on MedPassport receives a **Digital Product Passport (DPP)** — a unique on-chain device identity token tied to the device's physical Unique Device Identifier (UDI). Think of it as a permanent record that cannot be altered, destroyed, or separated from the device it describes.

The passport carries:
- Device identity — manufacturer, model, UDI, regulatory class
- Manufacturing record — date, facility, initial configuration, software version
- Ownership history — every transfer of legal ownership, timestamped and role-verified
- Service timeline — every maintenance event, calibration, repair, and software update
- Certification status — whether the device holds a current verified condition attestation

### The Ledger

The passport is anchored on a blockchain — a distributed ledger that no single party controls and that no party can alter retroactively. Every entry is permanent, timestamped, and records the credentialed identity of who made it.

This is structurally different from a centralized database, where a system migration can corrupt records, an acquisition can make data inaccessible, or an entry can be silently overwritten. On the blockchain, the recorded history is permanent. What the ledger carries is limited by design — see Section 5.

### The Access Model

Not all stakeholders see the same data. MedPassport uses a role-based permission system enforced at the protocol level:

| Role | What they can do |
|---|---|
| Manufacturer | Create the passport token, log software updates, initiate recall flags |
| Certified service org | Log service events, calibration records, part replacement attestations |
| Hospital / owner | View full authorized history, transfer ownership, request certification |
| Reseller | View authorized history, request certification before sale |
| Insurer | Query service history and certification status via premium API |
| Regulator | View all authorized records, set recall flags, access audit trail |
| Public / buyer | View device identity, certification status, and recall flags only |

### The Compliance Score — Decay from 100

MedPassport uses a **decay-from-100 scoring model**. A new CE-marked device starts at 100/100 — the most compliant state possible. Deductions are applied when service is overdue, parts are undocumented, or safety complaints are open. Active recall forces the score to zero immediately.

| Component | Max points | Deduction trigger |
|---|---|---|
| Calibration compliance | 25 pts | Overdue 0-3mo: -5 / 3-6mo: -15 / 6+mo: -25 |
| PM compliance | 25 pts | Overdue 0-3mo: -5 / 3-6mo: -15 / 6+mo: -25 |
| Inspection compliance | 20 pts | Overdue: up to -20 |
| Software currency | 10 pts | Failed update: -10 / Missing 18+mo: -5 |
| Parts integrity | 10 pts | Compatible documented: -3 / Undocumented: -10 |
| Clean complaint record | 10 pts | Open minor: -5 / Open serious: -20 |

**Hard zero conditions:** Active recall / Decommissioned / Certificate expired

Scoring weights are configurable per manufacturer at pilot onboarding — agreed in writing before the pilot starts and locked for the pilot duration.

**Neutral scoring principle:** MedPassport scores compliance — not vendor loyalty. OEM and qualified ISO service both receive full credit for on-time passing events. The OEM advantage is operational (tighter CMMS integration) not algorithmic.

### The Certification Attestation

Before a device enters the secondary market, it can be submitted for a **Certified Device Status** attestation — issued after a physical inspection and verified service history review by an approved OEM or certified service organization. In v1, certification issuance is restricted to these governed roles; the certification governance model will be published separately.

The attestation records:
- Compliance score derived from service history completeness
- Certification level — Bronze, Silver, or Gold
- Issuing organization and reference number
- Expiry date — the attestation is only valid until material lifecycle changes or expiry rules require re-verification

This attestation is non-transferable. It belongs to the device record, not the current owner. A buyer scanning a device QR code sees it immediately alongside recall status and ownership history.

### System Architecture

The diagram below shows how stakeholders, the managed platform layer, and the on-chain ledger relate to one another — and where the boundaries between public and permissioned data sit.

![MedPassport system architecture](assets/architecture.svg)

**Three layers, clear boundaries:**

- **Stakeholders** interact with the platform through role-governed access. What each party can read and write is determined by their credentialed role, not by trust.
- **The managed platform layer** handles enterprise API access, off-chain document storage, dashboards, and integration adapters for CMMS and ERP systems. Sensitive documents — service reports, calibration certificates — live here, not on-chain.
- **The on-chain ledger** holds only what must be immutable and publicly verifiable: device identity tokens, event hashes, timestamps, ownership records, recall flags, and certification attestations. No documents. No patient data. No PII.
- **Read-only consumers** — public buyers, insurers, CMMS systems — access only approved fields through governed interfaces.

---

## 5. Data Model and Privacy Principles

This section defines what MedPassport stores, where, and under what access conditions. These principles are fixed design constraints, not implementation preferences.

**1. No patient data is in scope — in any version.**
MedPassport records device lifecycle events. Patient identity, clinical outcomes, and care workflow data are permanently outside the protocol's scope.

**2. No clinical workflow data is in scope.**
Diagnoses, prescriptions, treatment records, and care decisions are not captured, referenced, or inferred.

**3. Sensitive documents are stored off-chain.**
Service reports, calibration certificates, supplier declarations, and similar documents are stored in IPFS or Arweave. Only their cryptographic hash is anchored on-chain. The document itself is accessible only to authorized parties through the enterprise layer.

**4. On-chain records contain hashes, attestations, timestamps, and role-based event metadata only.**
No document content, no personal identifiers, no free-text clinical notes appear on the public ledger. On-chain data is designed to be safe for public visibility without exposing sensitive information.

**5. Public verification is limited to approved fields.**
Without authentication, any party can verify: device identity, current certification status, active recall flags, and the count of recorded lifecycle events. Full service history, document access, and ownership details require credentialed role access.

---

## 6. Regulatory Framework

MedPassport is designed around a layered regulatory architecture. Each layer builds on the one before, providing multi-jurisdictional coverage from a single protocol implementation.

### Layer 1 — Foundation: ISO 13485:2016

ISO 13485 is the international standard for medical device quality management systems and the logical design anchor for MedPassport. It covers the complete device lifecycle — design, production, distribution, installation, and servicing — which maps directly to the workflows the platform manages.

ISO 13485 is jurisdiction-neutral. A MedPassport implementation aligned to ISO 13485 serves manufacturers in Israel, Europe, the United States, Japan, Brazil, and Australia simultaneously. Both EU MDR and FDA QMSR reference ISO 13485 as their underlying QMS standard — building to ISO 13485 first means compliance with the other frameworks is additive, not duplicative.

| ISO 13485 Clause | Requirement | MedPassport Implementation |
|---|---|---|
| §7.5.8 | Identification and traceability | UDI-anchored passport token provides persistent, non-alterable device traceability |
| §7.5.10 | Customer property | Ownership transfer events recorded with verified role-based identifiers |
| §8.2.1 | Feedback and complaint handling | Incident attestation events captured on-chain; complaint handling workflows remain in the QMS system |
| §8.3 | Control of nonconforming product | Recall flag triggers automatic certification revocation |

---

### Layer 2 — EU Market Access: MDR / IVDR / EUDAMED / ESPR

The EU Medical Device Regulation (2017/745) and In Vitro Diagnostic Regulation (2017/746) drive the strongest current regulatory push for digital traceability in the global device market. Two specific developments in 2025-2026 create immediate commercial urgency for MedPassport.

#### EUDAMED — Mandatory from 28 May 2026

Commission Decision EU 2025/2371, published 27 November 2025, declared the full functionality of the first four EUDAMED modules. From 28 May 2026 — now imminent at the time of this writing — the following are mandatory for all manufacturers placing devices on the EU market:

| EUDAMED Module | Obligation from 28 May 2026 | MedPassport relationship |
|---|---|---|
| **Actor Registration** | All manufacturers must hold a valid Single Registration Number (SRN). Without SRN, placing products on the EU market is not permitted. | MedPassport manufacturer credential onboarding requires EUDAMED SRN as the accreditation reference. The two systems share the same actor identity. |
| **UDI/Device Registration** | New devices must be registered in EUDAMED before first placement on market. UDI data must match technical documentation, labelling, and certificates exactly. | MedPassport passport token anchors to the same UDI registered in EUDAMED. GS1 format validation enforces consistency. The two records are complementary — EUDAMED records what the device is; MedPassport records what happens to it. |
| **Notified Bodies and Certificates** | Certificates must be linked to registered devices in EUDAMED. | MedPassport certification attestation references the notified body certificate number, creating a cross-reference between the two systems. |
| **Market Surveillance** | Competent authorities use this module for monitoring. Recall events and FSCAs flow through here. | MedPassport recall flags and incident attestations provide structured data that supports market surveillance activities. |

**What EUDAMED does not do — and MedPassport does:**
EUDAMED is a registration and static device database. It records that a device exists and is certified. It does not record what happens to a device after it leaves the manufacturer — no service history, no ownership transfers, no calibration records, no second-hand transaction evidence. MedPassport provides exactly this lifecycle continuity layer. The two systems are complementary by design.

**The EUDAMED roadmap beyond 2026:**
The Vigilance module — covering post-market surveillance, incident reports, and periodic safety update reports — is expected to become mandatory around mid-2027. When it does, the structured service event data that MedPassport continuously captures becomes the primary feed for a manufacturer's EUDAMED vigilance submissions. MedPassport is being built now specifically to support this workflow when it becomes mandatory.

#### ESPR — Digital Product Passport: Positioned for Future Alignment

MedPassport is designed to be DPP-ready and compatible with future ESPR-style data requirements. The position on ESPR is stated precisely:

- ESPR entered into force July 2024. Delegated acts defining product-specific DPP requirements are being developed under the ESPR Working Plan 2025-2030.
- Medical devices are not in the first wave of mandatory DPP products. Textiles, batteries, and iron/steel are prioritized first, with electronics and other categories following in 2028-2029.
- The European Commission's Joint Research Centre published its definitive DPP data methodology in March 2026, providing the blueprint regulators will use for all product category delegated acts. MedPassport's data model is aligned with this methodology.
- MedPassport is positioned to align with medical device ESPR obligations as and when they are formalized — not as a claim that those obligations currently apply.

**What ESPR DPP requires that MedPassport already implements:**

| ESPR DPP Requirement | Status in MedPassport |
|---|---|
| Unique product identifier via QR/NFC (ISO/IEC 15459) | ✅ GS1 UDI format is ISO 15459 compliant. QR code passport viewer in roadmap. |
| Manufacturer identity and registration details | ✅ Manufacturer credential with EUDAMED SRN reference |
| Product model, batch, and item information | ✅ `model`, `udi`, `deviceClass` fields in DeviceIdentity |
| Safety information and IFU reference | ✅ `metadataURI` links to IPFS-hosted full DPP JSON |
| Repairability and service information | ✅ Complete service history via ServiceLogRegistry |
| End-of-life declaration | ✅ `DECOMMISSION` event type |
| Material composition and component provenance | 🔄 Supplier attestation events — Phase 2 |
| Carbon footprint and environmental data | ❌ Not in scope for medical device service history pilot |

| EU Requirement | MedPassport Implementation |
|---|---|
| MDR Art. 27 — UDI | UDI is the primary device key; GS1 format validated; consistent with EUDAMED UDI/Device module |
| MDR Art. 83 — Post-Market Surveillance | Service event log provides structured PMS data; designed to feed future EUDAMED Vigilance module |
| MDR Art. 87 — Incident Reporting | Incident attestation event type captures lifecycle context; vigilance reporting remains a QMS function |
| ESPR — Digital Product Passport | DPP-ready architecture aligned with March 2026 JRC methodology; medical device delegated act pending |

---

### Layer 3 — US Market Extension: FDA QMSR + GUDID + 21 CFR Part 11

The FDA Quality Management System Regulation (21 CFR Part 820), effective February 2, 2026, aligns US requirements with ISO 13485:2016 by incorporating it by reference. This means EU compliance through ISO 13485 delivers approximately 80% of US QMSR compliance at no additional cost. The remaining requirements are US-specific additions.

**Why ISO 13485 alignment makes dual-market deployment efficient:**
Because QMSR incorporates ISO 13485:2016 by reference, a manufacturer already compliant with MedPassport's EU workflow satisfies most QMSR obligations automatically. FDA inspectors now use a Total Product Life Cycle approach — tracing UDI data from design through post-market surveillance — which maps directly to MedPassport's continuous lifecycle evidence model.

On Part 11: MedPassport can support Part 11-aligned controls when implemented with validated workflows, governed access management, electronic signature mechanisms, and audited record handling. Blockchain immutability is a necessary but not sufficient condition for Part 11 compliance — the full implementation requires operational and validation controls beyond the protocol itself.

| US Requirement | MedPassport Implementation |
|---|---|
| QMSR §820.10 — UDI system documentation | GS1 UDI format validated at minting; GUDID reference stored in credential |
| QMSR §820.35(b)(2) — Servicing records include UDI | UDI string included in service event metadata and IPFS document schema |
| QMSR §820.35(c) — UDI recorded per batch | Token ID maps to full UDI; batch-level traceability via deviceIdentifier field |
| QMSR §820.65 — Traceability | Full chain of custody from manufacture to current recorded owner |
| QMSR §820.200 — Servicing | Service log registry covers all servicing record requirements |
| 21 CFR Part 11 — Electronic Records | Protocol supports Part 11-aligned controls when deployed with validated workflows and operational governance |

---

### Dual-Market Readiness: EU + US from a Single Deployment

MedPassport is designed so that a manufacturer operating in both the EU and US markets can use a single protocol deployment without maintaining separate systems. This section defines precisely what changes between markets and what does not.

#### The UDI model difference — the only significant technical divergence

The EU introduced a concept that does not exist in the US: the **Basic UDI-DI** — a superordinate identifier that groups a product family in EUDAMED and is never printed on the device label. The US GUDID system uses only the standard UDI-DI.

```
US SYSTEM (GUDID)              EU SYSTEM (EUDAMED)
──────────────────             ──────────────────────────────
UDI-DI                         Basic UDI-DI  ← EU only, in EUDAMED only
  + UDI-PI                       └── UDI-DI
  = Full UDI on label                   + UDI-PI
                                        = Full UDI on label
```

MedPassport accommodates both through dedicated fields in the device identity record:

| Field | EU deployment | US deployment | Dual-market |
|---|---|---|---|
| `udi` | Full UDI string | Full UDI string | Same in both |
| `deviceIdentifier` | UDI-DI component | UDI-DI component | Same in both |
| `basicUdiDi` | EU Basic UDI-DI — populated | Empty string | Populated for EU |
| `eudamedRef` | EUDAMED registration ref | Empty string | Populated for EU |
| `gudidRef` | Empty string | GUDID record ref | Populated for US |

#### Registry bridge architecture — dual validation at mint time

Before a device passport is minted, the protocol verifies the UDI exists in the relevant regulatory database. The bridge used depends on the jurisdiction declared at onboarding:

| Bridge | Market | API | Authentication | What is verified |
|---|---|---|---|---|
| **EUDAMED bridge** | EU | European Commission REST API | Actor SRN required | Basic UDI-DI exists and is active in EUDAMED |
| **GUDID bridge** | US | FDA AccessGUDID public API | None — fully public | UDI-DI exists and device class matches |
| **Both bridges** | Dual market | Both above | EUDAMED auth + public GUDID | Verified in both registries before minting |

The GUDID bridge is live. AccessGUDID requires no authentication and provides a clean REST endpoint. A single GET request to the FDA's public API verifies a device before minting is permitted — implemented and verified against Abbott Vascular XIENCE ALPINE, Class III.

#### What requires no change for dual-market deployment

| Element | Why it is already dual-market ready |
|---|---|
| Smart contract architecture | ISO 13485 foundation satisfies both jurisdictions |
| Service event log | QMSR §820.200 maps directly to existing ServiceLogRegistry |
| Dual-signature governance | Required by both FDA high-risk event policy and EU MDR |
| Correction and amendment model | ISO 13485 §4.2.5 is incorporated by reference in QMSR |
| Zero-PII architecture | GDPR (EU) and HIPAA (US) both require it — same technical solution |
| Certification SBT | Compliance scoring is jurisdiction-neutral |
| Access control model | Role-based permissions satisfy both regulatory frameworks |
| DeviceClass enum | Already contains both EU MDR classes and FDA classes |

#### The dual-market pitch in one sentence

> *"Because FDA's QMSR now incorporates ISO 13485:2016 by reference, EU compliance through MedPassport delivers 80% of US compliance at no additional cost. Three targeted additions — dual UDI fields, a GUDID bridge, and jurisdiction flagging at onboarding — enable a single protocol deployment to serve manufacturers operating in both markets simultaneously."*

---

## 7. Target Customers and ROI

### Wave 1 — The Manufacturer

Manufacturers face the strongest regulatory pressure, carry the greatest recall risk, and have the clearest financial exposure when device identity and history break down. MedPassport gives manufacturers something no internal QMS system can provide: a device identity that survives the boundary of their own organization.

**Wave 1 buyer map:**
The buying decision is driven by regulatory and service leadership, with final approval at COO level. Detailed buyer personas, objection handling scripts, and sales process guidance are available in the Enterprise Addendum (available to qualified enterprise contacts on request).

**Ideal Wave 1 pilot partner:** EU-headquartered Class IIb/III manufacturer, 500-5,000 device fleet, using ServiceMax or Infor EAM, facing EUDAMED legacy device deadline November 2026.

| Pain | MedPassport addresses |
|---|---|
| Recall traceability — manual effort across fragmented downstream holders | Shared ledger materially reduces reliance on downstream voluntary reporting |
| Device identity integrity during large-scale rework | On-chain token conflicts are detectable; silent overwrites are not possible |
| Component provenance gaps in DHR | Supplier attestations logged at unit level; process changes are traceable |
| Audit preparation — 3-10 working days per cycle | Structured evidence layer built continuously, not assembled under pressure |
| 3rd party ISO service events invisible to manufacturer cloud | ISO events captured on same ledger as OEM events |
| PSUR evidence gaps for legacy and lapsed-contract devices | Continuous evidence regardless of contract status |

**Wave 1 pilot success metrics (9-12 months):**

| Metric | Target |
|---|---|
| FSCA identification time | <4 hours for 100% of pilot fleet |
| Audit prep time reduction | >=30% vs baseline |
| Data completeness | >=90% of CMMS work orders + >=40 events |
| Zero workflow addition | 0 new manual tasks for field staff |
| Refurbisher value perception | Positive written assessment |

---

### Wave 2 — The Reseller and Refurbisher

The reseller's value proposition depends on buyer confidence. Today that confidence is purchased with a discount — typically 30 to 50 percent below equivalent new-device pricing for a device whose history cannot be independently verified. MedPassport converts verified history into a negotiating asset.

| Pain | MedPassport addresses |
|---|---|
| Buyers discount devices with unverifiable history | Verified service timeline supports evidence-based pricing discussions |
| Refurbishment work is disputed after sale | On-chain service attestations provide verifiable record of work performed |
| Gray market parts exposure creates liability | Component provenance attestations trackable at unit level |
| Slow transactions due to documentation requests | Buyer scans QR code — public verification fields visible immediately |

---

### Wave 3 — The Insurer

Insurers consume device data rather than create it. Once Wave 1 and Wave 2 establish a critical mass of passports on the network, insurers gain access to structured device condition data that previously did not exist in a form they could consume systematically.

| Pain | MedPassport addresses |
|---|---|
| Warranty claims disputed due to missing service records | On-chain service attestations provide a structured evidence reference |
| Equipment financing risk based on age rather than condition | Compliance score and certification status reflect actual maintenance history |
| Manual back-and-forth with hospitals and OEMs | Premium API access to structured passport data |

---

## 8. What MedPassport Is Not

Clarity of scope protects the product commercially and technically. These boundaries are deliberate design decisions, not provisional limitations.

**MedPassport is not a QMS system.**
It does not replace tools used for quality management, document control, CAPA, design controls, or training workflows. Greenlight Guru, Qualio, and MasterControl solve those problems. MedPassport is the lifecycle evidence layer that sits alongside them.

**MedPassport is not an EHR or clinical system.**
It does not touch patient data, clinical documentation, or care workflows. This boundary is permanent across all versions of the protocol.

**MedPassport is not a replacement for EUDAMED or GUDID.**
EUDAMED is the EU's central database for device registration and regulatory modules. GUDID is the FDA's reference catalog for UDI device identifier data. MedPassport complements these registries by adding lifecycle evidence continuity that neither was designed to provide. It integrates with them — it does not compete.

**MedPassport is not a hospital CMMS or asset management platform.**
CMMS tools — ServiceMax, Nuvolu, Infor EAM — manage work orders, planned maintenance schedules, and operational asset registries. MedPassport integrates with these systems as a structured data destination, not a replacement.

**MedPassport is not a supply chain execution platform.**
It does not manage procurement, logistics, or inventory planning. Supply chain events can be attested against the device passport — but MedPassport does not run the supply chain.

**MedPassport is not an OEM enforcement tool.**
The compliance score reflects actual device condition — not vendor loyalty. An OEM technician and a qualified ISO technician both receive full credit for a passing PM event completed on time. The OEM operational advantage is real but is not baked into the algorithm. Neutrality is the source of MedPassport trust across all parties simultaneously.

---

## 9. Business Model

**Core positioning: Open protocol. Paid enterprise network.**

This model has strong precedent. HashiCorp, Confluent, and Elastic each built category-defining businesses by open-sourcing the protocol and monetizing the operational and enterprise layer built on top. MedPassport follows the same structure.

### The Open Layer — Free Forever

| What is open | Why |
|---|---|
| Smart contracts and schemas | Drives adoption; community can build on and verify the protocol |
| Reference implementation | Shows manufacturers exactly how to integrate |
| Protocol documentation | Reduces friction to first deployment |
| GitHub community | Generates contributions, credibility, and peer review |

### The Commercial Layer — Where Revenue Comes From

| Revenue stream | Who pays | Why they pay |
|---|---|---|
| **Managed SaaS** | Manufacturers, hospitals, resellers, ISOs | Hosted infrastructure, dashboards, audit controls, support — no node operations required |
| **Integration services** | Manufacturers first | Real value arrives when MedPassport connects to existing QMS, CMMS, and ERP systems |
| **Premium API access** | Insurers, enterprise buyers, analytics partners | Governed, scalable access to passport data and structured event history |
| **Verification and certification fees** | Resellers, refurbishers | A verified certification attestation reduces friction and supports evidence-based pricing |

### Revenue Sequence

```
STAGE 1              STAGE 2              STAGE 3              STAGE 4
────────────         ────────────         ────────────         ────────────
Paid pilot           Annual SaaS          Certification        Premium API
+ implementation     subscription         fees for             for insurers
fee                                       resale               and enterprise
                     Recurring base       workflows
First cash in        established          Margin               Ecosystem
                                          expansion            multiplier
```

### Pricing Model — Wave 1

| Tier | Fleet size | Annual fee | Onboarding fee |
|---|---|---|---|
| Pilot | Up to 50 devices | Free (90 days) | $5,000 |
| Starter | Up to 100 devices | $12,000/yr | $5,000 |
| Growth | 101-500 devices | $35,000/yr | $10,000 |
| Enterprise | 501-2,000 devices | $80,000/yr | $20,000 |
| Global | 2,000+ devices | Custom | Custom |

The pilot is free for 90 days to remove adoption risk. The onboarding fee qualifies serious pilot partners and covers integration work. The subscription does not begin unless agreed pilot outcomes are met.

### What Is Deliberately Avoided in v1

**No per-event transaction fees.** Enterprise healthcare buyers prefer predictable subscription or contract pricing over variable metering. Per-event fees are easy to explain in a Web3 context — they are difficult to sell to hospital procurement teams.

**No protocol token.** A governance or utility token adds regulatory complexity, governance overhead, and speculative risk without solving the immediate commercial problem. MedPassport is a tool for the medical device industry, not a financial instrument.

---

## 10. Competitive Positioning

No existing platform solves the cross-organizational medical device lifecycle evidence problem.

| Capability | VeChain DPP | ServiceMax / PTC | MedPassport |
|---|---|---|---|
| Cross-organizational evidence | Partial | No — single org only | Yes — core design |
| MDR PMS / PSUR alignment | No | No | Yes — built-in |
| FSCA execution support | No | Partial | Yes — built-in |
| Neutral scoring (not OEM-biased) | N/A | N/A | Yes — Product A |
| Open source | Partial | No | Yes — MIT |
| Zero-PII on-chain | Yes | N/A | Yes |
| Works without IT integration | No | No | Yes — barcode fallback |

**VeChain** is the closest architectural comparable — consortium blockchain, device-level DPP, B2B SaaS. The critical gap: not built for MDR PMS, PSUR, or FSCA execution. No EUDAMED or QMSR regulatory alignment.

**PTC / ServiceMax** spent $1.46 billion acquiring ServiceMax to own the device lifecycle data layer. Their digital thread works within one organization using the full PTC stack. It breaks at organizational boundaries because competing entities do not share systems. MedPassport is additive to ServiceMax — it makes ServiceMax data independently verifiable and carries it across the boundary ServiceMax cannot cross.

**The defensible moat:** PTC can build a scoring algorithm. They cannot build neutral infrastructure that competing parties trust simultaneously.

---

## 11. Use Cases

### Use Case 1 — The Manufacturer: Closing the Recall Gap

**Scenario:** A mid-sized European medical device manufacturer produces 40,000 units of a Class IIb cardiac monitoring device annually, distributed across 23 countries through a network of distributors and hospitals.

**Without MedPassport:** When a software defect is discovered in a specific firmware version, the manufacturer issues a Field Safety Corrective Action. Identifying which serial numbers are affected requires querying internal ERP records, cross-referencing distributor shipping data, and relying on hospitals to search their own asset management systems. Some devices are never successfully reached.

**With MedPassport:** Each device carries an on-chain passport recording serial number, firmware version, and the last recorded ownership transfer. When the FSCA is issued, affected devices are identified by querying the ledger directly. Recall status is flagged on-chain. Authorized holders receive structured notification. Regulatory authorities can verify recall execution progress against on-chain records rather than manual reports.

**What changes:** Recall traceability no longer depends entirely on downstream voluntary reporting. Evidence of recall execution is structured and accessible.

---

### Use Case 2 — The Refurbisher: Converting History into a Negotiating Asset

**Scenario:** A certified medical equipment refurbisher acquires a fleet of 30 infusion pumps from a decommissioning hospital in Germany. The devices are between four and seven years old.

**Without MedPassport:** The refurbisher receives paper service records — some complete, some partial — and a CMMS export requiring manual interpretation. Prospective buyers apply a significant discount to account for unverifiable history. Post-sale disputes arise when buyers challenge pre-existing condition claims.

**With MedPassport:** Each device's service history is on-chain — PM events, calibration certificates, software versions, and part replacements, logged by the hospital's certified service organization. The refurbisher's technicians perform inspection and remediation, logging each event against the device passport. Devices that meet the compliance score threshold qualify for certification attestation. Buyers scan a QR code before purchase — verification fields are visible immediately. Post-sale history disputes are substantially reduced because the service record is not a claim — it is a structured, timestamped attestation.

**What changes:** The discount applied for unverifiable history is replaced by evidence-based pricing discussions. Transactions move faster. Post-sale disputes decrease.

---

### Use Case 3 — The Insurer: Underwriting on Evidence

**Scenario:** A medical equipment financing company provides lease agreements for high-value imaging and surgical equipment to hospital groups across Europe.

**Without MedPassport:** Equipment condition at lease origination is assessed by a point-in-time inspection report. Residual value projections are based on device age and model, not actual maintenance history. Warranty claims are frequently disputed because neither party can independently verify the service record.

**With MedPassport:** At lease origination, the insurer queries the device passport via the premium API — reviewing the structured service timeline, current certification level, recall status, and compliance score. Residual value projections are anchored to verified maintenance history rather than age-based assumptions. When a warranty claim is filed, the on-chain service attestations serve as a structured evidence reference that both parties can verify independently.

**What changes:** Underwriting relies on structured evidence rather than point-in-time inspection alone. Warranty disputes have a shared evidence base rather than competing paper records.

---

## 12. Roadmap

### Phase 1 — Foundation *(Q2–Q3 2026)*
> Build the core protocol and make it publicly available for review and contribution

- [x] Core smart contracts — 10 contracts · 67 tests passing · CI green
- [x] Device identity token with UDI anchoring and GS1 format validation
- [x] Service log registry — 10 event types · parts and incident integrity flags
- [x] Certification attestation — Bronze/Silver/Gold · ERC-5192 soulbound
- [x] ComplianceScorer v2 — decay-from-100 model · configurable per manufacturer
- [x] GitHub repository — full documentation · whitepaper · MIT license
- [x] Live GUDID bridge — AccessGUDID API verified · real device confirmed
- [x] Landing page — live at tomer-saar.github.io/medpassport-protocol
- [ ] Polygon Amoy testnet deployment — in progress
- [ ] Demo page — device registration flow · compliance score animation
- [ ] QR code passport viewer — public verification without login

### Phase 2 — Integration *(Q4 2026 – Q1 2027)*
> Connect MedPassport to the systems manufacturers and hospitals already use

- [ ] EUDAMED API bridge — verify Basic UDI-DI before EU passport minting
- [ ] IPFS / Arweave document storage for service reports and certificates
- [ ] CMMS adapter — pilot integration with ServiceMax or Infor EAM
- [ ] Polygon Amoy testnet deployment
- [ ] Demo page — live device registration, animated compliance score, Polygonscan link
- [ ] First paid pilot — Class IIb/III device fleet, 2-3 hospitals, 1 refurbisher

### Phase 3 — Dual-Market and Ecosystem *(2027)*
> Expand to US market and build the commercial network

- [ ] Dual-market onboarding — jurisdiction flagging, GUDID + EUDAMED dual validation
- [ ] `basicUdiDi` field deployment — EU Basic UDI-DI support for EUDAMED architecture
- [ ] Managed SaaS platform — hosted infrastructure, dashboards, audit controls
- [ ] GAMP 5 Validation Support Package — IQ/OQ/PQ templates for enterprise onboarding
- [ ] Mobile scanner app for field verification and service event logging
- [ ] Insurer API tier — structured access for warranty and financing workflows
- [ ] EUDAMED Vigilance module bridge — structured PMS data feed (mandatory mid-2027)
- [ ] Automated recall notification via on-chain event monitoring
- [ ] First enterprise SaaS contracts

### Phase 4 — Standardization *(2027–2028)*
> Position MedPassport as a reference implementation for the industry

- [ ] EU ESPR medical device delegated act monitoring and alignment
- [ ] ISO/TC 210 dialogue — quality management for medical devices
- [ ] Notified body engagement for certifier role governance
- [ ] OPC-UA IoT connector — automated device telemetry attestation
- [ ] Academic publication of protocol design and field outcomes

---

## 13. References

1. ISO 13485:2016 — Medical devices — Quality management systems — Requirements for regulatory purposes
2. ISO/IEC 15459:2015 — Information technology — Automatic identification and data capture — Unique identification
3. EU Regulation 2017/745 — Medical Device Regulation (MDR)
4. EU Regulation 2017/746 — In Vitro Diagnostic Medical Devices Regulation (IVDR)
5. EU Regulation 2024/1781 — Ecodesign for Sustainable Products Regulation (ESPR)
6. Commission Decision EU 2025/2371 — EUDAMED four first modules mandatory from 28 May 2026 (November 2025)
7. European Commission JRC — Methodology for defining data requirements for the Digital Product Passport under ESPR, JRC145830 (March 2026)
8. FDA 21 CFR Part 820 — Quality Management System Regulation (QMSR), effective February 2026
9. FDA 21 CFR Part 11 — Electronic Records; Electronic Signatures
10. FDA 21 CFR Part 830 — Unique Device Identification
11. FDA Compliance Program 7382.850 — GUDID formally established as inspectable component, February 2026
12. FDA AccessGUDID — Global Unique Device Identification Database, public API
13. GS1 — Unique Device Identification (UDI) Standard
14. IMDRF — Unique Device Identification System (UDI) — International harmonization framework
15. FDA Safety Communication — Philips Respironics Rework Program Update, April 2023
16. FDA MedWatch — Philips Respironics Sleep and Respiratory Device Recall, June 2021
17. FDA Recall Database — Sage Products Urine Management System, Recall Z-2474-2023 (2023)
18. Grand View Research — Digital Product Passport Market Size & Forecast, 2024-2030 (2024)
19. Grand View Research — Refurbished Medical Equipment Market Analysis (2024)

---

<div align="center">

*MedPassport Protocol — Building the trust layer for medical device lifecycle management*

*Open-source protocol · MIT License · Not legal or regulatory advice*

*Contributions welcome — see [CONTRIBUTING.md](../CONTRIBUTING.md)*

[⬆ Back to top](#medpassport-protocol)

</div>
