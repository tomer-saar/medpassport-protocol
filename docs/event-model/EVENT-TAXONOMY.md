# MedPassport — Event Taxonomy v1.0

**Status:** Accepted
**Date:** April 2026
**Author:** Tomer Saar, PMP

---

## Overview

Every lifecycle event recorded on the MedPassport ledger belongs to
one of the categories defined in this document. This taxonomy is the
authoritative reference for the ServiceLogRegistry and
CorrectionRegistry contracts. No event type may be added or removed
without a new ADR superseding this document.

---

## Primary Event Types

### SERVICE events

| Event type | Who can write | Dual-sig | Description |
|---|---|---|---|
| PREVENTIVE_MAINTENANCE | Certified service org | No | Scheduled PM per maintenance plan |
| CORRECTIVE_MAINTENANCE | Certified service org | No | Unscheduled repair or breakdown |
| CALIBRATION | Certified service org | No | Metrology calibration with certificate |
| SOFTWARE_UPDATE | Manufacturer only | No | Firmware or software version change |
| INSPECTION | Certified service org or regulator | No | Quality or regulatory inspection |
| INCIDENT_REPORT | Certified service org or regulator | No | Adverse event reference |
| DECOMMISSION | Device owner or manufacturer | No | End of operational life |

### TRANSFER events

| Event type | Who can write | Dual-sig | Description |
|---|---|---|---|
| OWNERSHIP_TRANSFER | Current owner + receiver | YES | Change of legal owner or operator |

### CERTIFICATION events

| Event type | Who can write | Dual-sig | Description |
|---|---|---|---|
| CERTIFICATION_ISSUED | Certifier + quality lead | YES | Bronze, Silver, or Gold stamp issued |
| CERTIFICATION_REVOKED | Certifier or regulator | No | Certification revoked with reason |

### CORRECTION events

| Event type | Who can write | References | Description |
|---|---|---|---|
| SUPERSEDES | Original writer or device owner | Original event hash | Replaces prior event for operational use |
| DISPUTES | Device owner, manufacturer, or regulator | Original event hash | Flags event as contested |
| AMENDS | Original writer | Original event hash | Adds missing information to prior event |

### GOVERNANCE events

| Event type | Who can write | Description |
|---|---|---|
| CREDENTIAL_REVOKED | Governance multisig | Actor credential revoked |
| CREDENTIAL_MIGRATED | Governance multisig | Credential transferred to successor |
| RECALL_FLAGGED | Regulator role | Device subject to field safety corrective action |
| RECALL_CLEARED | Regulator role | Recall resolved and cleared |

---

## Event Record Structure

Every event contains these fields:
tokenId          - Device passport token this event belongs to
eventType        - One of the types defined above
timestamp        - Block timestamp at time of writing
blockNumber      - Block number for sequencing
reportedBy       - Wallet address of the credentialed actor
credentialId     - On-chain credential identifier
documentHash     - keccak256 hash of the supporting document
ipfsCID          - IPFS content identifier of the full document
passedInspection - Boolean outcome where applicable
softwareVersion  - Populated for SOFTWARE_UPDATE events only
notes            - Brief on-chain note, max 200 characters
---

## Correction Chain Rules

1. A correction must reference the original event by its on-chain hash
2. SUPERSEDES makes the original inactive for operational queries
   but permanently visible in audit view
3. DISPUTES does not supersede — both records remain active
4. A correction may itself be corrected — chains are allowed
5. No correction may alter the original author field of any record

---

## Edge Cases Resolved

| Scenario | Resolution |
|---|---|
| Correction writer credential revoked after writing | Correction stands — status at time of writing is recorded |
| Original writer credential revoked before correction | Device owner or governance may correct |
| Dual-sig transfer initiated but second signer revoked | Transfer cancelled — proposer must reinitiate |
| Device decommissioned — new service event attempted | Rejected at contract level |
| Recall active — certification issuance attempted | Rejected at contract level |