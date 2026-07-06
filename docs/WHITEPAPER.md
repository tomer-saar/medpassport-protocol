<div align="center">

# MedPassport Protocol Whitepaper v2.0

## Verifiable Lifecycle Evidence for Regulated Physical Assets
### Medical Devices as the First Market

`Public Review Draft` · `June 2026` · `MIT License`

</div>

---

## Important Notice

This document is a public technical and market-positioning whitepaper for MedPassport Protocol. It is not legal, medical, regulatory, financial, or investment advice. MedPassport does not make clinical decisions, replace regulated quality systems, or determine regulatory compliance outcomes. The protocol provides an evidence infrastructure layer: signed lifecycle attestations, tamper-evident records, and controlled access to device evidence.

MedPassport does not require an application token for pilot adoption. The protocol uses public blockchain infrastructure for verifiable attestations while enterprise users interact through conventional SaaS, CMMS, QMS, and identity workflows.

Detailed implementation annexes, partner-specific pilot documents, security architecture, and enterprise integration designs are available only under appropriate confidentiality terms for qualified partners, auditors, and institutional collaborators.

This document covers the market, regulatory, and architectural thesis. To verify the protocol's current build status, test results, and to run it yourself, see the [project README](https://github.com/tomer-saar/medpassport-protocol#readme).

---

## 1. Executive Summary

Regulated physical assets depend on evidence. A high-risk medical device is not only a physical machine; it is a chain of identity records, service events, calibration certificates, software updates, ownership transfers, corrective actions, and regulatory obligations. Today that evidence is fragmented across manufacturer systems, hospital CMMS platforms, independent service organizations, paper records, PDF archives, and regulator databases.

MedPassport Protocol creates a neutral evidence layer for this fragmented lifecycle. It assigns each medical device a permanent Digital Product Passport anchored to its Unique Device Identifier (UDI), and records lifecycle events as signed, tamper-evident attestations from credentialed actors. Sensitive documents remain off-chain. The public ledger stores only hashes, timestamps, device identifiers, credential references, and event metadata needed for independent verification.

The first market is high-risk medical devices: Class IIb and Class III equipment such as imaging, cardiology, and other regulated capital equipment. This market is ideal for the first deployment because devices already have regulatory identity systems, strict post-market surveillance obligations, complex service networks, and high consequences when records are incomplete.

The broader thesis is larger: MedPassport is infrastructure for verifiable lifecycle evidence of regulated physical assets. Medical devices are the first wedge because the pain is immediate, the identity layer exists, and the regulatory timing is strong.

As of June 2026, MedPassport is at TRL 5: ten smart contracts are live on Polygon Amoy testnet, 100 Foundry tests are passing, CI is green, FDA GUDID and EU EUDAMED bridge services are live, the IPFS document uploader is operational, VaultService is functionally built with its on-chain write path pending a scheduled contract redeployment, and a public website and interactive demo are live. Current test count and build status are maintained in the project README, which reflects live CI results.

---

## 2. The Problem: Evidence Breaks at Organizational Boundaries

Medical device regulation assumes records are complete. Real-world device operations are not organized that way.

A device may be manufactured by one company, distributed by another, owned by a hospital, serviced by an OEM team for several years, maintained later by an independent ISO, transferred to another site, refurbished, resold, and eventually decommissioned. Each organization records part of the story. No single system carries the full record across the full lifecycle.

This creates four structural evidence gaps.

### 2.1 Legacy and Offline Devices

Many high-risk devices remain in clinical use long after the first generation of OEM cloud systems. Some devices are intentionally disconnected for cybersecurity reasons. Others are old enough that continuous cloud integration was never part of the design. Their service evidence is often stored in local files, PDFs, spreadsheets, or site-specific CMMS records.

### 2.2 Ownership Transfer

When a device changes owner, the service and compliance chain often breaks. The manufacturer may retain regulatory obligations, but the operational record moves to a new owner, distributor, refurbisher, or hospital. The new owner may not inherit a complete evidence set, and the previous owner may not retain an accurate operational history.

### 2.3 Independent Service

Independent service organizations perform legitimate maintenance, calibration, inspection, and repair. But their records often do not enter the manufacturer's QMS or the hospital's long-term evidence package in a structured, verifiable way. The result is not necessarily poor service; the result is poor cross-organizational evidence.

### 2.4 Non-Independent Evidence

Evidence held only inside an OEM database, a hospital CMMS, or an ISO's internal system is controlled by a commercially interested party. Even if accurate, it may not have the same evidentiary weight as a tamper-evident record that can be independently verified across organizational boundaries.

The core problem is not data entry. It is neutral evidence continuity.

---

## 3. Why Existing Systems Cannot Solve This Alone

Medical device companies already use sophisticated systems: QMS platforms, ERP systems, CMMS systems, field-service platforms, and regulatory databases. These systems are necessary. They are not sufficient.

A QMS is authoritative inside one manufacturer. A CMMS is authoritative inside one hospital or service organization. EUDAMED and GUDID identify devices in regulatory registries. OEM cloud platforms may record telemetry for connected devices. None of these systems is designed to be a neutral, cross-organizational evidence ledger that survives every handoff.

The limitation is architectural:

| System type | Works well for | Structural limitation |
|---|---|---|
| OEM cloud | Connected devices under OEM service control | Stops at contract, connectivity, or ownership boundaries |
| CMMS / field service platform | Work orders inside one organization | Does not create neutral evidence across organizations |
| QMS / CAPA system | Manufacturer regulatory workflows | Does not automatically ingest independent service evidence across the full installed base |
| EUDAMED / GUDID | Device identity and regulatory registration | Does not record complete operational service history across decades |
| Paper / PDF records | Local evidence retention | Difficult to verify, reconcile, search, or trust independently |

MedPassport does not replace these systems. It anchors the critical lifecycle attestations that must survive across them.

---

## 4. Why Web3 Is the Correct Architecture

Blockchain is not used here because medical devices need cryptocurrency. They do not.

Blockchain is used because the evidence problem has four properties that match public ledger architecture:

1. **No single party can be the trusted operator.** Manufacturers, hospitals, ISOs, refurbishers, insurers, and regulators have different incentives.
2. **History must be append-only.** Service and transfer records should not be silently overwritten after a dispute, incident, audit, acquisition, or system migration.
3. **Every write must be attributable.** A record is useful only if the responsible credentialed actor is known.
4. **Verification must outlive platforms.** The evidence chain should remain verifiable even if an OEM portal, CMMS instance, or local archive is unavailable.

MedPassport uses the blockchain as a neutral settlement layer for attestations. Documents remain off-chain. Sensitive data remains in private systems or encrypted vault storage. The ledger carries proof that an event occurred, who signed it, when it was recorded, and which document hash corresponds to the evidence.

This is a Web3 infrastructure use case, not a speculative token use case.

---

## 5. Protocol Overview

MedPassport has three public-facing architectural layers.

```text
Layer 1 — Private enterprise systems
CMMS · QMS · ERP · OEM service platforms · hospital records

Layer 2 — Controlled evidence vault
Encrypted or controlled-access documents: service reports, calibration certificates,
software release notes, SBOM references, refurbishment evidence

Layer 3 — Public attestation ledger
Device identity token, event hash, document hash, timestamp, credential reference,
active recall state, certification attestation
```

The protocol creates a device passport and attaches lifecycle events to that passport. Each event is a signed attestation by a credentialed actor. The on-chain layer is intentionally minimal: it proves integrity and authorship without exposing sensitive business, clinical, or personal information.

### 5.1 Device Passport

Each registered device receives a unique on-chain passport tied to its physical UDI and regulatory identity. The passport becomes the permanent anchor for lifecycle records.

### 5.2 Lifecycle Events

Lifecycle events include preventive maintenance, calibration, inspection, software update, incident reporting, ownership transfer, refurbishment, certification, and other regulated service milestones.

### 5.3 Evidence Documents

Documents such as calibration certificates and service reports are stored off-chain. Their cryptographic hashes are anchored on-chain, allowing later verification that the document presented during an audit is the same document that was attached at the time of the event.

### 5.4 Credentialed Actors

Actors write to the protocol only through credentials. The public whitepaper does not expose the full enterprise credential architecture, but the principle is simple: write authority is based on role and credential validity, not on commercial control by any single party.

---

## 6. Access and Privacy Model

MedPassport separates safety visibility from commercial evidence disclosure.

### 6.1 Public Access

Public users may verify basic device identity and active recall status. This supports safety and transparency without exposing commercial service history.

### 6.2 Owner-Authorized Access

Expanded evidence views are controlled by the device owner or authorized party. A prospective buyer, insurer, notified body, or other reviewer may receive a limited grant that exposes only the evidence appropriate to that transaction or audit.

### 6.3 Regulator and Notified Body Access

Regulators and notified bodies need audit evidence, not uncontrolled write authority. MedPassport supports structured, time-bound, role-based evidence access while preserving the responsibility chain for formal regulatory actions.

### 6.4 No Patient Data

Patient data is out of scope. No protected health information, clinical treatment data, or patient identifiers belong on-chain or in the MedPassport evidence model.

### 6.5 No Commercial Leakage

Pricing, contracts, full internal service notes, customer lists, and proprietary operational data remain inside the relevant enterprise systems. The protocol anchors the evidence needed for verification, not the entire business record.

---

## 7. Credentialed Attestations and Mutual Attestation

MedPassport is built around signed accountability.

Every write is a signed attestation. The actor's credential is permanently associated with the event. Nothing is deleted or overwritten. Corrections are appended as new records that reference the previous record.

High-risk workflows require independent confirmation. Ownership transfer and certification issuance are examples where one actor should not be able to complete the action unilaterally. Mutual attestation creates a stronger evidence chain because more than one party must confirm a high-impact state change.

This model is important for regulated physical assets because real-world events often have multiple stakeholders: the current owner, the receiving owner, the service organization, the certifier, and the manufacturer may all have legitimate roles in the evidence chain.

---

## 8. Medical Devices as the First Market

MedPassport starts with medical devices because the sector has a rare combination of urgent need and strong implementation primitives.

| Market condition | Why it matters |
|---|---|
| UDI already exists | Devices have a regulatory identity layer suitable for passport anchoring |
| Service evidence is regulated | Calibration, maintenance, software, and incident records matter for compliance |
| Lifecycle is long | Devices often remain in use across ownership and service-provider changes |
| Evidence is fragmented | OEMs, hospitals, ISOs, refurbishers, and distributors hold different parts of the record |
| Regulatory timing is active | MDR, EUDAMED, QMSR, and digital product passport trends all increase evidence pressure |
| Liability exposure is real | Incomplete records complicate attribution after incidents and recalls |

The first deployments are focused on high-risk medical devices where evidence quality has the highest operational, regulatory, and financial value.

### 8.1 The Secondary Market Opportunity

Medical devices do not lose value only because they age. They lose value when their history becomes unverifiable.

The refurbished medical equipment market is already a large and expanding global category. Grand View Research estimated the market at **USD 21.30 billion in 2025** and projected it to reach **USD 50.03 billion by 2033**, growing at an **11.32% CAGR from 2026 to 2033**. The same market summary identifies medical imaging equipment as the largest product segment in 2025.

The limiting factor is trust. A CT scanner, ultrasound system, anesthesia platform, surgical imaging system, or patient-monitoring device with a complete, verifiable service history is commercially different from the same device with fragmented PDFs, missing calibration records, unclear software state, or unverifiable parts provenance.

MedPassport gives the secondary market a neutral verification layer. Device identity, ownership chain, service events, calibration evidence, software updates, recall status, and certification attestations can travel with the device across resale, refurbishment, and redeployment. This turns device history from a negotiation risk into a pricing signal.

For refurbishers, the value is faster buyer confidence. For hospitals, it is defensible procurement and resale. For OEMs, it is post-transfer visibility without operating the secondary marketplace. For Web3 investors, it is a direct real-world asset thesis: regulated physical assets need verifiable lifecycle evidence before they can be priced, insured, financed, or traded efficiently.

Important boundary: MedPassport does not decide whether a refurbished or remanufactured device may be placed on the market. Regulatory obligations remain with the relevant manufacturer, refurbisher, remanufacturer, importer, distributor, hospital, or other economic operator. MedPassport provides the evidence layer: identity, history, attestations, document integrity, and controlled disclosure.

---

## 9. Regulatory Path

MedPassport is not a regulatory database and does not replace regulatory submissions, notified body review, clinical evaluation, complaint handling, CAPA, or benefit-risk judgment. Its role is narrower and more defensible: it provides structured, independently verifiable lifecycle evidence that regulated actors can use inside their existing regulatory workflows.

The public regulatory thesis is:

> Registration tells the regulator what the device is. MedPassport records what happens to the device after registration — across ownership, service, software, calibration, incident, refurbishment, and decommissioning boundaries.

### 9.1 EU MDR: Post-Market Evidence, Not Device Registration

The strongest EU hook is MDR post-market surveillance and field safety execution, not initial registration. Manufacturers already have formal obligations for post-market surveillance, periodic safety update reporting, vigilance, and field safety corrective actions. MedPassport supports these obligations by creating a durable evidence layer for service events, calibration, software updates, incident attestations, ownership status, and affected-fleet discovery.

MedPassport should not be positioned as replacing EUDAMED registration. It is the post-registration evidence layer that helps close the gap between a device being registered and a device having a complete, retrievable lifecycle record.

### 9.2 EUDAMED: Mandatory Modules Create the Baseline; Vigilance/PMS Creates the Forward Hook

As of 28 May 2026, the first four EUDAMED modules became mandatory: Actor registration, UDI/Device registration, Notified Bodies & Certificates, and Market Surveillance. These modules establish the EU registry baseline for actors, devices, certificates, and market surveillance.

The remaining EUDAMED modules — Vigilance and Post-Market Surveillance, and Clinical Investigations/Performance Studies — remain under development. The European Commission states that the remaining modules will be released when mandatory, with no voluntary-use period. This is the forward-looking MedPassport hook: manufacturers need structured evidence before digital vigilance and PMS workflows become mandatory, because the evidence record must already exist when the reporting obligation arrives.

Public-safe positioning:

> EUDAMED registration confirms that a device exists. MedPassport creates the cross-organizational lifecycle evidence needed after that registration — the evidence that supports PMS, PSUR preparation, FSCA execution, and future digital vigilance workflows.

### 9.3 FDA QMSR: ISO 13485 Alignment Makes Traceability More Strategic

The FDA Quality Management System Regulation amendments are effective February 2, 2026. The rule modernizes 21 CFR Part 820 and incorporates ISO 13485:2016 by reference. For MedPassport, the strategic implication is that traceability, control of records, servicing evidence, complaint investigation support, and CAPA trend completeness become stronger US-market arguments.

The US argument should remain more nuanced than the EU argument. The EU has the clearest lifetime PMS/PSUR driver. In the US, MedPassport is best framed around service traceability, complaint investigation completeness, CAPA trend data, UDI-linked records, and software/SBOM currency across devices that may be serviced or transferred outside the OEM's direct control.

### 9.4 FDA Cybersecurity and SBOM Continuity

For software-enabled medical devices, cybersecurity evidence is increasingly lifecycle-based. MedPassport's software update event model can anchor software version, SBOM hash, SBOM CID, technician credential, timestamp, and device UDI. This creates a cross-organizational proof point for software currency after resale, off-contract service, or independent ISO maintenance.

Public-safe positioning:

> A software bill of materials is only useful if the manufacturer can prove which software version is installed on which device. MedPassport provides a UDI-linked, timestamped, credentialed evidence trail for software updates across organizational boundaries.

### 9.5 ESPR and Digital Product Passport Direction

ESPR is not yet a direct medical-device compliance obligation, and MedPassport should not imply that a medical-device DPP delegated act is already in force. The correct claim is architectural alignment.

The ESPR digital product passport framework points toward persistent product identifiers, differentiated access rights, interoperable structured data, availability after business failure, data authentication and integrity, and independent digital product passport service providers. These principles strongly resemble the infrastructure MedPassport is building for medical devices: UDI-anchored identity, role-based access, signed lifecycle records, off-chain evidence, and long-term verifiability.

This matters to Web3 investors because ESPR validates the broader market direction: regulated physical products are moving toward persistent, interoperable, access-controlled digital evidence. MedPassport is applying that architecture first to one of the highest-value regulated asset classes: high-risk medical devices.

### 9.6 Regulatory Boundaries

MedPassport does not claim to automate or replace:

- device registration in EUDAMED,
- clinical evaluation or PMCF,
- QMS complaint handling and CAPA ownership,
- benefit-risk assessment,
- formal vigilance submission responsibility,
- notified body conformity assessment, or
- FDA-specific submission formats.

Its contribution is the evidence layer beneath those workflows: signed service records, software update proof, calibration evidence, ownership traceability, incident context, document integrity, and cross-organizational record continuity.

---

## 10. Compliance Evidence and Scoring

MedPassport includes an evidence-based compliance scoring model. The score is not a medical decision, not a regulatory decision, and not a substitute for professional judgment. It is a structured summary of device evidence.

A new compliant device starts at 100/100. Deductions occur when evidence indicates overdue maintenance, missing calibration, failed inspection, undocumented parts, software currency gaps, or unresolved safety events. Active recall or decommissioned state can force a hard-zero condition until corrective action is completed and verified.

Certification levels summarize the evidence state:

| Level | Score range | Meaning |
|---|---:|---|
| Gold | 90-100 | Strong evidence of current service and compliance state |
| Silver | 75-89 | Generally strong evidence with some deductions |
| Bronze | 60-74 | Evidence exists, but material gaps or delays are present |
| Not certifiable | Below 60 | Significant gaps require correction before certification |

The score is designed to be explainable. A device owner, auditor, insurer, or buyer should be able to understand which evidence components affected the score.

---

## 11. Insurance and Liability: Turning Maintenance History into Risk Data

Medical device risk is not limited to whether a device was originally designed correctly. For high-risk capital equipment, liability often depends on what happened after the device left the manufacturer: whether it was maintained on schedule, calibrated correctly, serviced by a qualified actor, updated to the required software version, transferred between owners, or operated under an active recall.

Today, that evidence is fragmented across OEM systems, hospital CMMS records, ISO service notes, PDFs, spreadsheets, and local archives. When an incident occurs, insurers, manufacturers, hospitals, and service organizations may spend significant time reconstructing the service chain before the technical cause can even be evaluated.

This is an attribution problem. A device incident may raise multiple competing questions: was the root cause design-related, service-related, calibration-related, software-related, parts-related, or use-related? Without a shared evidence trail, each party may hold a partial record and each record may require manual reconciliation.

MedPassport converts fragmented maintenance history into structured, verifiable risk data. Each service event is tied to a device identity, timestamp, credentialed actor, document hash, and outcome. The result is not a medical conclusion or a legal determination; it is an independently verifiable evidence layer that can help insurers and risk managers distinguish between a well-documented device lifecycle and an undocumented one.

For insurers, this creates a potential new underwriting signal: service documentation quality. For hospitals and refurbishers, it creates a defensible record of care. For manufacturers, it improves visibility into off-contract and independently serviced devices without turning the manufacturer into the operator of every downstream record system.

The commercial relevance is material. Medical-device liability, complaint handling, product quality, and recall issues can generate significant financial and reputational exposure. Public reporting has documented large medical-device product-liability settlements and ongoing FDA enforcement attention around complaint handling, safety reports, and quality-system failures. MedPassport does not claim to prevent such events. Its contribution is narrower and more defensible: reducing evidentiary uncertainty by making the device lifecycle record complete, attributable, and independently verifiable.

Public-safe positioning:

> MedPassport creates a new class of machine-readable risk data: verified lifecycle evidence for regulated physical assets.

---

## 12. Current Technical Status

As of June 2026, MedPassport is at Technology Readiness Level 5: ten smart contracts live on Polygon Amoy testnet, FDA GUDID and EU EUDAMED bridges live and tested, an IPFS document uploader operational with Pinata, VaultService built with its on-chain write path pending a scheduled contract redeployment, and a public site live with demo and stakeholder flows, under an MIT open-source license.

This whitepaper describes the qualitative state of the protocol and does not track exact test counts or build numbers, since those change between whitepaper revisions. For current test results, contract counts, and CI status, see the [project README](https://github.com/tomer-saar/medpassport-protocol#readme), which reflects live CI status via its test badge.

The current testnet implementation proves the core architecture: device identity, event logging, compliance scoring, certification, ownership transfer, oracle bridges, document hashing, and public verification.

Production deployment requires additional security hardening, audit work, encrypted vault implementation, enterprise onboarding workflows, and a mainnet deployment after pilot and audit readiness criteria are met.

---

## 13. Business Model

MedPassport follows an open protocol plus paid enterprise network model.

A second commercial layer is risk-data infrastructure: turning verified lifecycle evidence into structured signals for audit, underwriting, procurement, resale, and asset-quality review.

The base protocol is open-source. Revenue opportunities are built around the managed network and enterprise services required for regulated adoption:

- hosted infrastructure,
- enterprise dashboards,
- CMMS and QMS integrations,
- audit evidence exports,
- verification APIs,
- secondary-market evidence summaries for authorized buyers, refurbishers, and asset-finance workflows,
- certification workflows,
- pilot onboarding and support,
- production compliance and validation packages.

This approach is designed to make the protocol credible as neutral infrastructure while allowing commercial value capture through enterprise operations and integrations.

No token is required for pilot adoption. Any future network-governance or incentive mechanism would need to be evaluated separately against medical-device regulation, enterprise adoption requirements, securities considerations, and partner trust.

---

## 14. Web3 Category Fit

MedPassport sits at the intersection of several Web3 infrastructure categories.

| Category | MedPassport fit |
|---|---|
| Real-world asset infrastructure | Not tokenized ownership; verifiable evidence surrounding regulated physical assets |
| Decentralized identity | Credentialed actors and attributable lifecycle attestations |
| Verifiable credentials | Role-based authority, signed evidence, and controlled disclosure |
| Compliance infrastructure | Tamper-evident audit records for regulated workflows |
| DePIN-adjacent systems | Physical-asset lifecycle network without relying on consumer hardware incentives |
| Enterprise blockchain | Walletless user experience, SaaS integration, and public proof layer |

The distinction from many RWA projects is important. MedPassport does not claim to make medical devices liquid financial assets. Instead, it makes their lifecycle evidence verifiable. That evidence can support resale, insurance, audit, recall, service accountability, and asset valuation without transforming the device itself into a tradable token.

This is a more conservative and enterprise-compatible Web3 thesis: public infrastructure for trust, not speculative tokenization.

---

## 15. Network Effects

MedPassport becomes more valuable as more actors and devices join the evidence network.

The same network effect also improves risk-data quality: every additional verified service event makes device condition, maintenance behavior, and evidence completeness easier to evaluate across a fleet.

- Each registered device increases the searchable evidence base.
- Each credentialed service actor increases the scope of trustworthy service events.
- Each ownership transfer strengthens the continuity of the device history.
- Each uploaded evidence document improves audit readiness.
- Each integration with CMMS, QMS, or regulatory registries reduces manual reconciliation.

The protocol's network effect is not social media virality. It is institutional evidence density.

As the number of devices and credentialed actors increases, the network becomes more useful to manufacturers, hospitals, refurbishers, insurers, and regulators because the evidence graph becomes more complete.

---

## 16. Roadmap

### Completed: Testnet Evidence Protocol

- Protocol axioms and event model
- Ten-contract smart contract stack
- Polygon Amoy testnet deployment
- FDA GUDID bridge
- EU EUDAMED bridge
- IPFS document upload and hash anchoring
- Compliance scoring and certification logic
- Public website and interactive demo

### Near Term: Pilot Readiness

- Execute the scheduled VaultService contract redeployment
- Build production-grade Path B mobile PWA
- Prepare security audit scope
- Prepare pilot evidence dashboards
- Define public-safe pilot materials and legal templates

### Pilot Phase

- Onboard limited Class IIb/III device fleet
- Capture lifecycle events through CMMS integration or barcode fallback
- Measure event capture rate, workflow time, audit readiness, and evidence completeness
- Calibrate scoring model against real field data

### Production Hardening

- Security audit completion
- Encrypted evidence vault
- Enterprise credential onboarding
- Production key custody model
- Mainnet deployment after audit and pilot readiness gates
- Expanded API access for insurers, buyers, and audit stakeholders

---

## 17. What MedPassport Is Not

MedPassport is not an electronic health record. It stores no patient data.

MedPassport is not a QMS replacement. OEMs and regulated organizations remain responsible for their own quality systems, CAPA processes, complaint handling, and regulatory submissions.

MedPassport is not a CMMS replacement. It integrates with systems such as field-service and maintenance platforms where possible.

MedPassport is not a regulator. It does not decide whether a device is compliant, safe, or marketable.

MedPassport is not an OEM enforcement tool. The protocol's neutrality depends on allowing credentialed service events to be written based on valid authority, not based on commercial preference.

MedPassport is not a speculative token project. Pilot adoption does not require a network token, user wallets, or crypto payments by enterprise users.

---

## 18. Team

**Tomer Saar, PMP** — Founder. 20+ years in the medical device industry across R&D, engineering, and manufacturing management for tier-1 global manufacturers. Co-inventor on granted patents in implantable cardiac devices and motion systems.

**Dr. Shlomo Gilat** — Research Lead and Industry Advisor. DSc Biomedical Engineering, Technion. 35+ years in Class IIb/III medical devices, two US patents, and 22 publications.

MedPassport combines medical-device operating experience, regulatory evidence awareness, and blockchain engineering into one focused protocol.

---

## 19. References

1. European Commission, EUDAMED Overview — mandatory first four modules from 28 May 2026 and development status of remaining modules: https://health.ec.europa.eu/medical-devices-eudamed/overview_en
2. Federal Register, FDA Medical Devices; Quality System Regulation Amendments, final rule effective February 2, 2026: https://www.federalregister.gov/documents/2024/02/02/2024-01709/medical-devices-quality-system-regulation-amendments
3. Regulation (EU) 2024/1781 establishing a framework for ecodesign requirements for sustainable products: https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32024R1781
4. a16z crypto, State of Crypto 2025: https://a16zcrypto.com/posts/article/state-of-crypto-report-2025/
5. Reuters, Becton Dickinson agrees to settle about 38,000 hernia mesh suits: https://www.reuters.com/legal/litigation/becton-dickinson-agrees-settle-about-38000-hernia-mesh-suits-2024-10-03/
6. Reuters, U.S. FDA warning to Medline over defective heart-procedure syringes and complaint-handling issues: https://www.reuters.com/legal/litigation/us-fda-warns-medline-over-defective-heart-procedure-syringes-2026-04-08/
7. Reuters, additional FDA warning to Medline over quality lapses: https://www.reuters.com/legal/litigation/medline-draws-another-us-fda-warning-two-months-over-quality-lapses-2026-06-03/
8. Grand View Research, Refurbished Medical Equipment Market Size Report, 2033: https://www.grandviewresearch.com/industry-analysis/refurbished-medical-equipment-market
9. FDA, Remanufacturing of Medical Devices Guidance for Industry, Entities That Perform Servicing or Remanufacturing, and FDA Staff, May 2024: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/remanufacturing-medical-devices
10. Regulation (EU) 2017/745 Medical Device Regulation: https://eur-lex.europa.eu/eli/reg/2017/745/oj
11. MedPassport Protocol repository and public materials: https://github.com/tomer-saar/medpassport-protocol

---

<div align="center">

**MedPassport Protocol**  
Verifiable lifecycle evidence for regulated physical assets.  
Medical devices first.

</div>
