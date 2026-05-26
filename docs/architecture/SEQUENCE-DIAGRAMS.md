# MedPassport — Sequence Diagrams v2.0

**Status:** Accepted
**Date:** May 2026 (rebuilt from contracts — v1.0 was truncated)
**Author:** Tomer Saar, PMP

---

## Overview

These diagrams define the exact step-by-step flows for the two
highest-risk workflows in the MedPassport protocol. Both require
dual-signature and are enforced by TransferManager.sol and
CertificationSBT.sol respectively.

Both flows share the same governance principle:
**No single party can complete a high-risk action unilaterally.**

---

## Diagram 1 — Ownership Transfer

Covers transfer of a device from any current owner (refurbisher,
distributor, hospital) to a new owner. Both parties must sign
independently within a 72-hour window. An active recall blocks
the transfer entirely.

```mermaid
sequenceDiagram
    participant Proposer as Proposer<br/>(current owner)
    participant TM as TransferManager.sol
    participant NFT as DevicePassportNFT.sol
    participant CS as ComplianceScorer.sol
    participant Confirmer as Confirmer<br/>(new owner)

    Note over Proposer,Confirmer: PRE-CONDITIONS
    Proposer->>NFT: owns device (tokenId)?
    NFT-->>Proposer: confirmed owner

    Proposer->>NFT: recallActive?
    NFT-->>Proposer: false (transfer blocked if true)

    Note over Proposer,TM: STEP 1 — PROPOSE
    Proposer->>TM: proposeTransfer(tokenId, newOwner)
    TM->>TM: verify caller owns token
    TM->>TM: verify no active recall
    TM->>TM: verify no pending proposal exists
    TM->>TM: store proposal + expiresAt (now + 72h)
    TM-->>Proposer: proposalId

    Note over TM,Confirmer: 72-HOUR WINDOW
    Note over TM: proposal sits pending

    alt Confirmer signs within 72h
        Confirmer->>TM: confirmTransfer(proposalId)
        TM->>TM: verify caller == proposed newOwner
        TM->>TM: verify proposal not expired
        TM->>TM: verify proposer != confirmer
        TM->>NFT: transferFrom(currentOwner, newOwner, tokenId)
        NFT-->>TM: ownership updated
        TM->>CS: ownership transfer noted
        TM-->>Confirmer: transfer complete
        Note over Proposer,Confirmer: Full history preserved<br/>Read access transfers to new owner<br/>Compliance score unchanged

    else Proposal expires after 72h
        Note over TM: proposal marked expired
        Proposer->>TM: proposeTransfer(...) again if still needed
    end

    alt Active recall discovered after proposal
        Note over TM: recall activated by regulator
        Confirmer->>TM: confirmTransfer(proposalId)
        TM->>NFT: recallActive?
        NFT-->>TM: true
        TM-->>Confirmer: revert — TransferBlockedByRecall
    end
```

### Key rules enforced on-chain

| Rule | Enforced by | Consequence if violated |
|---|---|---|
| Only current owner can propose | TransferManager | revert — not owner |
| Active recall blocks transfer | TransferManager → DevicePassportNFT | revert — TransferBlockedByRecall |
| Proposer cannot be confirmer | TransferManager | revert — SameActorForbidden |
| 72-hour expiry | TransferManager | revert — ProposalExpired |
| One pending proposal at a time | TransferManager | revert — ProposalAlreadyPending |

### What transfers automatically

- Device ownership (ERC-721 token)
- Full read access to vault documents
- Compliance score and full service history
- Certification SBT remains on device (non-transferable to new owner but stays on device record)

### What does NOT transfer

- OEM service contract (commercial relationship — off-chain)
- Warranty status (manufacturer determines independently)
- Credentials of previous actors (remain with those actors)

---

## Diagram 2 — Certification (Bronze / Silver / Gold)

Covers the issuance of an ERC-5192 soulbound certification token.
Requires: compliance score above minimum threshold, two independent
credentialed actors, no active recall.

```mermaid
sequenceDiagram
    participant Certifier as Certifier<br/>(credentialed actor)
    participant SBT as CertificationSBT.sol
    participant CS as ComplianceScorer.sol
    participant NFT as DevicePassportNFT.sol
    participant Owner as Device Owner<br/>(confirmer)

    Note over Certifier,Owner: PRE-CONDITIONS
    Certifier->>CS: getScore(tokenId)
    CS-->>Certifier: score (must be ≥ 60 for Bronze,<br/>≥ 75 for Silver, ≥ 90 for Gold)

    Certifier->>NFT: recallActive(tokenId)?
    NFT-->>Certifier: false (certification blocked if true)

    Note over Certifier,SBT: STEP 1 — PROPOSE CERTIFICATION
    Certifier->>SBT: proposeCertification(tokenId, level, certRef)
    SBT->>CS: getScore(tokenId)
    CS-->>SBT: current score
    SBT->>SBT: score >= minimum for requested level?
    SBT->>NFT: recallActive(tokenId)?
    SBT->>SBT: store proposal + expiresAt (now + 72h)
    SBT-->>Certifier: proposalId

    Note over SBT,Owner: 72-HOUR WINDOW

    alt Owner confirms within 72h
        Owner->>SBT: confirmCertification(proposalId)
        SBT->>SBT: verify caller == device owner
        SBT->>SBT: verify proposal not expired
        SBT->>SBT: verify certifier != owner
        SBT->>CS: getScore(tokenId) — re-check at confirmation time
        CS-->>SBT: score still above threshold?

        alt Score still valid at confirmation
            SBT->>NFT: recallActive? — final check
            NFT-->>SBT: false
            SBT->>SBT: mint ERC-5192 soulbound token
            SBT->>SBT: lock token (non-transferable)
            SBT-->>Owner: certification issued (Bronze/Silver/Gold)
            Note over Certifier,Owner: Token is non-transferable<br/>Tied to device, not owner<br/>Visible on QR scan immediately

        else Score dropped below threshold during window
            SBT-->>Owner: revert — ScoreBelowMinimum
            Note over Certifier,Owner: Re-certify after service events<br/>bring score back above threshold
        end

    else Proposal expires after 72h
        Note over SBT: proposal marked expired
        Certifier->>SBT: proposeCertification(...) again if still needed
    end

    alt Recall activated after proposal, before confirmation
        Owner->>SBT: confirmCertification(proposalId)
        SBT->>NFT: recallActive?
        NFT-->>SBT: true
        SBT-->>Owner: revert — DeviceUnderRecall
    end
```

### Certification levels and thresholds

| Level | Min score | Typical state |
|---|---|---|
| GOLD | 90-100 | All service on schedule, no incidents, software current |
| SILVER | 75-89 | Minor deductions — one overdue PM or compatible parts used |
| BRONZE | 60-74 | Multiple deductions — device still serviceable, below optimal |
| Not certifiable | < 60 | Significant compliance gaps — address before certifying |
| Hard zero | 0 | Active recall or decommissioned — certification impossible |

### Key rules enforced on-chain

| Rule | Enforced by | Consequence if violated |
|---|---|---|
| Score must meet level threshold | CertificationSBT → ComplianceScorer | revert — ScoreBelowMinimum |
| Active recall blocks certification | CertificationSBT → DevicePassportNFT | revert — DeviceUnderRecall |
| Certifier cannot be owner | CertificationSBT | revert — SameActorForbidden |
| Score re-checked at confirmation | CertificationSBT | revert if score dropped |
| 72-hour expiry | CertificationSBT | revert — ProposalExpired |
| Token is non-transferable | ERC-5192 locked() = true | transfer reverts |

### Certification revocation

```mermaid
sequenceDiagram
    participant Actor as Certifier or Regulator
    participant SBT as CertificationSBT.sol

    Actor->>SBT: revokeCertification(tokenId)
    SBT->>SBT: verify caller is certifier or REGULATOR role
    SBT->>SBT: mark certification revoked
    SBT->>SBT: burn soulbound token
    SBT-->>Actor: certification revoked
    Note over Actor,SBT: Score not changed by revocation<br/>New certification possible after<br/>service events bring score up
```

---

## Diagram 3 — Vault Service Event (Sprint 8)

Covers the full flow of a service event with document upload —
from technician action to on-chain attestation. Added Sprint 8
with VaultService.js operational.

```mermaid
sequenceDiagram
    participant Tech as Technician<br/>(OEM or ISO)
    participant PathB as Path B Form<br/>(mobile)
    participant VS as VaultService.js
    participant Pinata as Pinata IPFS
    participant SLR as ServiceLogRegistry.sol
    participant CS as ComplianceScorer.sol

    Note over Tech,CS: PATH B — MANUAL (current)
    Tech->>PathB: scan device barcode
    PathB->>PathB: pre-fill form from ?scan= URL params
    Tech->>PathB: select event type + outcome
    Tech->>PathB: attach calibration certificate PDF
    Tech->>PathB: submit

    PathB->>VS: logEventWithDocument(tokenId, eventType, buffer, metadata)

    Note over VS,Pinata: STEP 1 — IPFS UPLOAD
    VS->>Pinata: uploadToIPFS(documentBuffer, filename)
    Pinata-->>VS: { cid, keccak256Hash, size }

    alt SOFTWARE_UPDATE with SBOM
        VS->>Pinata: uploadJSONToIPFS(sbomObject, sbomName)
        Pinata-->>VS: { sbomCid, sha256Hash }
    end

    Note over VS,SLR: STEP 2 — ON-CHAIN WRITE
    VS->>VS: build 12-param logEvent() call
    VS->>SLR: logEvent(tokenId, eventType, documentHash,<br/>ipfsCID, passedInspection, softwareVersion,<br/>notes, hasCompatibleParts, hasUndocumentedParts,<br/>isSeriousIncident, sbomHash, sbomCid)
    SLR->>SLR: verify credential is ACTIVE
    SLR->>SLR: verify role has permission for eventType
    SLR->>SLR: verify device not decommissioned
    SLR->>SLR: append event to immutable log
    SLR->>CS: trigger score recalculation
    CS-->>SLR: updated compliance score
    SLR-->>VS: eventIndex

    VS-->>PathB: receipt { txHash, cid, keccak256,<br/>sbomCid, blockNumber, timestamp }

    PathB-->>Tech: success — event logged on-chain

    Note over Tech,CS: VERIFICATION (any authorized party)
    Note over Pinata,SLR: Fetch CID from chain → compute hash<br/>→ compare to stored keccak256<br/>→ tamper-evident proof
```

---

## Diagram 4 — Dual-Market Passport Mint

Covers the mint flow for a device placed on both EU and US markets.
Both GUDID and EUDAMED validation run in parallel before minting.

```mermaid
sequenceDiagram
    participant MFG as Manufacturer
    participant GUDID as GUDIDBridge.js<br/>(FDA)
    participant EUDAMED as EUDAMEDBridge.js<br/>(EU Commission)
    participant NFT as DevicePassportNFT.sol
    participant CS as ComplianceScorer.sol

    MFG->>GUDID: validateUdi(udi)
    MFG->>EUDAMED: validateBasicUdiDi(basicUdiDi)
    Note over GUDID,EUDAMED: Run in parallel

    GUDID-->>MFG: { valid, deviceClass, gudidRef }
    EUDAMED-->>MFG: { valid, euAuthorised, riskClass,<br/>certificate, authorisedRep, eudamedRef }

    alt Both valid
        MFG->>NFT: mintDevicePassport(owner, udi, deviceClass,<br/>model, metadata, basicUdiDi,<br/>gudidRef, eudamedRef, false)
        NFT->>NFT: validate GS1 UDI format
        NFT->>NFT: check UDI not already registered
        NFT->>NFT: mint ERC-721 token
        NFT->>CS: initialise score at 100/100
        CS-->>NFT: confirmed
        NFT-->>MFG: tokenId
        Note over MFG,CS: Passport live on Polygon Amoy<br/>Score: 100/100 GOLD eligible<br/>Dual-market: EU + US fields populated

    else EU validation fails
        EUDAMED-->>MFG: { valid: false, error, warnings }
        Note over MFG: Check EUDAMED registration<br/>Verify certificate status<br/>Confirm AR is active

    else US validation fails
        GUDID-->>MFG: { valid: false, error }
        Note over MFG: Check GUDID registration<br/>Verify UDI-DI format
    end
```

---

## Update Log

| Version | Date | Changes |
|---|---|---|
| v1.0 | April 2026 | Initial — Diagrams 1-2 (truncated, diagrams missing) |
| v2.0 | May 2026 | Rebuilt complete — all Mermaid diagrams added · Diagrams 3-4 added for VaultService and dual-market mint |

---

*MedPassport Protocol · MIT License · Not legal or regulatory advice*
*Author: Tomer Saar, PMP · Last updated: May 2026 · Sprint 8*
