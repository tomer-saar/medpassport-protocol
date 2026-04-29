# ADR-001 — Credential States and Role Matrix

**Status:** Accepted  
**Date:** April 2026  
**Author:** Tomer Saar, PMP  

---

## Context

Every actor who writes to the MedPassport ledger holds a credentialed
role. This document defines every role, every credential state, and
every permitted action. It is the authoritative reference for the
CredentialRegistry and RoleManager contracts.

---

## Credential States

Every credential exists in exactly one of four states at any time:

| State | Meaning | Can write | Historical records |
|---|---|---|---|
| ACTIVE | Valid and in good standing | Yes | Visible, no flag |
| REVOKED | Cancelled — bad actor or decertification | No | Visible, flagged REVOKED |
| INACTIVE | Suspended — pending review or voluntary exit | No | Visible, flagged INACTIVE |
| MIGRATED | Transferred to successor entity | No | Visible, flagged MIGRATED |

---

## State Transition Rules

ACTIVE → REVOKED — governance multisig, immediate, no appeal
ACTIVE → INACTIVE — governance multisig, pending review
ACTIVE → MIGRATED — governance multisig, legitimate succession only
INACTIVE → ACTIVE — governance multisig, after review clears
INACTIVE → REVOKED — governance multisig, if review finds cause
REVOKED → nothing — revocation is terminal
MIGRATED → nothing — migration is terminal

---

## Role Matrix

### MANUFACTURER
- Mint device passport token — YES
- Log SOFTWARE_UPDATE event — YES
- Log DECOMMISSION event — YES
- Log service events — NO
- Issue certification — NO
- Set recall flags — NO
- Transfer ownership as current owner — YES

### CERTIFIED_SERVICE_ORG
- Log PREVENTIVE_MAINTENANCE — YES
- Log CORRECTIVE_MAINTENANCE — YES
- Log CALIBRATION — YES
- Log INSPECTION — YES
- Log INCIDENT_REPORT — YES
- Log SOFTWARE_UPDATE — NO, manufacturer only
- Mint device passport — NO
- Issue certification — NO

### CERTIFIER
- Issue CERTIFICATION_ISSUED — YES, dual-sig required
- Revoke CERTIFICATION_REVOKED — YES
- Log service events — NO
- Mint device passport — NO

### REGULATOR
- Set RECALL_FLAGGED — YES
- Clear RECALL_CLEARED — YES
- Log INCIDENT_REPORT — YES
- Revoke certification — YES
- View all records — YES
- Mint device passport — NO

### DEVICE_OWNER
- Initiate OWNERSHIP_TRANSFER — YES, dual-sig required
- Request certification — YES
- View full device history — YES
- Append DISPUTES correction — YES
- Log service events — NO

### PUBLIC — no credential required
- View device identity — YES
- View certification status — YES
- View recall flags — YES
- View full service history — NO
- Write any event — NO

---

## Migration Rules

Permitted only for legitimate succession:
- Company acquisition
- Approved carve-out
- Authorized contract transfer

Requires minimum 3-of-5 governance multisig approval.
Original authorship on all historical records is always preserved.
Migration is not permitted for bankruptcy without approved successor.

---

## Consequences

The CredentialRegistry contract must enforce these state transitions.
The RoleManager contract must enforce these permission boundaries.
No write path may bypass credential state checks.
This is enforced as a Foundry invariant test.