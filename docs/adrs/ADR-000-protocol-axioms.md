# ADR-000 — MedPassport Protocol Axioms

**Status:** Accepted  
**Date:** April 2026  
**Revised:** June 2026 — Axiom 6 added (open write authority — was referenced in
ARCHITECTURE.md §6 and Strategy v2 §7 but not formally written into this document)  
**Author:** Tomer Saar, PMP  

---

## Context

Before any contract is written, the protocol's constitutional rules must be
stated explicitly. Every contract, every test, and every deployment decision
either upholds these axioms or it does not. They are not implementation
preferences — they are non-negotiable design constraints.

---

## The Six Axioms

### Axiom 1 — Every write is a signed attestation
Every lifecycle event recorded on the MedPassport ledger is a signed
attestation by a credentialed actor. Anonymous writes do not exist.
The credential of the writing actor is permanently recorded alongside
every event.

### Axiom 2 — Nothing is ever deleted or overwritten
No event, record, or attestation is ever deleted or overwritten.
Corrections are additions — a superseding record is appended that
references the original by its on-chain hash. The original remains
permanently visible as part of the audit trail.

### Axiom 3 — Original authorship is preserved permanently
Regardless of credential migration, revocation, or organizational
succession, every historical record permanently shows who originally
wrote it, under which credential, and at which point in time.
Migration transfers write authority forward. It does not rewrite
the past.

### Axiom 4 — Patient data and PII never reach the ledger
No Personally Identifiable Information (PII) or Protected Health
Information (PHI) is ever written to the on-chain ledger. This is
a protocol-level technical constraint, not a policy position. Only
device identifiers (UDI), document hashes, organizational credentials,
and event metadata are recorded on-chain.

### Axiom 5 — High-risk events require two independent signatures
Ownership transfer and certification issuance require two independent
credentialed actors to sign before the event is written as final.
No single actor can complete either of these events unilaterally.
Both signing credentials are permanently recorded.

### Axiom 6 — Write access is determined by credential, not by commercial relationship
Any credentialed actor holding a valid MedPassport credential may write
service events to any device record within their role permissions.
No commercial relationship — including OEM service contracts, warranty
terms, or pricing agreements — can prevent a credentialed actor from
logging an event on a device they have serviced.
An OEM may flag warranty implications of non-OEM service. They may not
prevent the record from being written.
This is enforced in RoleManager.sol — it is an architectural constraint,
not a policy. It is the property that makes MedPassport neutral
infrastructure rather than a vendor enforcement tool.

---

## Consequences

Every contract in the MedPassport protocol must be evaluated against
these six axioms before deployment. Any contract function that would
violate any axiom must be redesigned, not deployed.

These axioms map directly to:
- ISO 13485:2016 §4.2.4 — Control of records
- ISO 13485:2016 §4.2.5 — Amendment of records
- 21 CFR Part 11 — Electronic records and signatures
- GDPR Article 25 — Data protection by design
- EU MDR Article 83 — Post-market surveillance
- EU MDR Article 83 — OEM PMS obligation covers all devices regardless
  of service provider, requiring that ISO service events are recordable
  (Axiom 6)
- FDA QMSR 21 CFR §820.100 — CAPA trend analysis requires a complete
  dataset including ISO-serviced devices; blocking ISO writes would
  structurally corrupt trend analysis (Axiom 6)

---

## Review

These axioms may not be amended without a full governance review
and a new ADR superseding this one. They are the foundation on
which all other architectural decisions rest.

**Revision note (June 2026):** Axiom 6 was present by intent from protocol
inception — it is referenced as "Protocol Axiom 6" in ARCHITECTURE.md §6,
Strategy v2 §7, and the Sprint Plan v3 ADR tracker. This revision formally
writes it into ADR-000 to close the gap between intent and the written record.
The existing five axioms are unchanged.
