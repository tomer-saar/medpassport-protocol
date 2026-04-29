# ADR-000 — MedPassport Protocol Axioms

**Status:** Accepted  
**Date:** April 2026  
**Author:** Tomer Saar, PMP  

---

## Context

Before any contract is written, the protocol's constitutional rules must be
stated explicitly. Every contract, every test, and every deployment decision
either upholds these axioms or it does not. They are not implementation
preferences — they are non-negotiable design constraints.

---

## The Five Axioms

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

---

## Consequences

Every contract in the MedPassport protocol must be evaluated against
these five axioms before deployment. Any contract function that would
violate any axiom must be redesigned, not deployed.

These axioms map directly to:
- ISO 13485:2016 §4.2.4 — Control of records
- ISO 13485:2016 §4.2.5 — Amendment of records  
- 21 CFR Part 11 — Electronic records and signatures
- GDPR Article 25 — Data protection by design
- EU MDR Article 83 — Post-market surveillance

---

## Review

These axioms may not be amended without a full governance review
and a new ADR superseding this one. They are the foundation on
which all other architectural decisions rest.
