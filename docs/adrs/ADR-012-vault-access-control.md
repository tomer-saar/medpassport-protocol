# ADR-012 — Vault Access Control: Envelope Encryption Model

**Status:** Proposed — Design complete · Implementation Phase 3
**Date:** May 2026 (updated from session review)
**Author:** Tomer Saar
**Category:** Security / Privacy / Protocol Architecture

---

## Context

MedPassport uses a three-layer architecture for document storage:

- **Layer 1 (private):** Your systems — CMMS, QMS, ERP. No external access ever.
- **Layer 2 (encrypted vault):** IPFS/Arweave — calibration certificates, service reports. Role-gated access.
- **Layer 3 (public ledger):** Polygon — 64-char hash + CID + timestamp only. No document content.

Layer 3 is already implemented. Layer 2 requires an access control model that allows different stakeholders to read only the documents relevant to their role, without any single party controlling the encryption keys.

**The problem:** IPFS is public by default. Any CID stored on-chain can be fetched by anyone. For the testnet pilot this is acceptable — no real commercial data, no real patient data. For production, documents must be encrypted before upload and decryptable only by authorized parties.

**Known design tension:** The on-chain layer (Layer 3) is inherently public. Anyone who knows a device tokenId can query `ComplianceScorer.getScore(tokenId)` directly on Polygon. The access control defined in this ADR applies to the **vault layer (Layer 2)** — document content, detailed event records, and calibration certificates. The compliance score and recall flag visible on-chain are by design queryable, but are not exposed at the application layer without a granted viewer role. This is a deliberate trade-off: operator-free architecture requires public ledger transparency at Layer 3. Commercially sensitive document content is protected at Layer 2 through envelope encryption.

---

## Decision: Envelope Encryption

### The model

Each document is encrypted with a unique symmetric key (AES-256-GCM). That symmetric key is then encrypted separately for each role that should have access — using the public key of each authorized party. The encrypted key envelopes are stored alongside the encrypted document in IPFS.

```
Document (plaintext)
      │
      ▼ AES-256-GCM encrypt with random DEK
Encrypted document → stored in IPFS as Layer 2
      │
      ├── DEK encrypted with OEM public key           → stored in IPFS alongside document
      ├── DEK encrypted with Device Owner key         → stored in IPFS alongside document
      ├── DEK encrypted with Notified Body key        → stored in IPFS alongside document (per grant)
      ├── DEK encrypted with ISO Actor key            → stored in IPFS alongside document
      └── DEK encrypted with Granted Viewer key       → stored in IPFS alongside document (per grant)

On-chain (Layer 3): document CID + keccak256(encrypted document)
```

Each authorized party decrypts their envelope with their private key to get the DEK, then decrypts the document. No single party holds all keys. MedPassport never holds any private key.

### Why envelope encryption

- Standard pattern: AWS KMS, HashiCorp Vault, Signal Protocol all use this approach
- No trusted intermediary: MedPassport does not hold any private key
- Selective disclosure: new roles can be granted access by adding a new encrypted envelope without re-encrypting the document
- Revocation: remove the envelope for a revoked party — they can no longer decrypt future documents
- GDPR compliance: right to erasure applies to the envelopes in the vault. On-chain records show an event occurred — not document content.

---

## Access Tier Matrix

### Write access (enforced on-chain in RoleManager.sol — already implemented)

| Actor | Can write to vault | Event types |
|---|---|---|
| OEM / Manufacturer | ✅ | SW_UPDATE, FSCA, COMPLAINT, mint |
| ISO technician (credentialed) | ✅ | PM, CALIBRATION, INSPECTION, INCIDENT |
| Hospital | ✅ | INSTALLATION only |
| Regulator | ✅ | FSCA activation/clearance |
| Refurbisher | ✅ | REFURBISHMENT, transfer initiation |

**Note on CAPA traceability:** MedPassport does not replace the OEM's complaint management system (QMS, CAPA module). When a corrective action involves an ISO technician, MedPassport independently verifies the corrective service event — logged by the credentialed actor with timestamp and outcome. The OEM's QMS remains the system of record for the complaint lifecycle. MedPassport provides the cross-organizational evidence that the corrective action was executed by a verified actor.

### Read access (vault decryption — Phase 3, ADR-012)

| Actor | Documents they can decrypt | Notes |
|---|---|---|
| **OEM / Manufacturer** | All documents for devices they manufactured. All SW_UPDATE records including SBOM. | Manufacturer has lifetime PMS obligation regardless of ownership or contract status |
| **Device current owner (hospital/user)** | All documents for devices they currently own | Ownership transfers automatically transfer read access |
| **ISO technician** | Documents for events they personally wrote | Credentialed actor — can verify their own work |
| **Notified Body (per-audit grant)** | Full audit evidence for assigned device scope — events, calibration certs, FSCA records, ownership chain | Granted by device owner (hospital or OEM) per audit engagement. Configurable time-limited access. Read-only. See grant flow below. |
| **Insurer (paid API)** | Compliance score, event count, cert status, event types and outcomes | Commercial API tier — no service notes, no PII. Paid subscription. |
| **Refurbisher (at transfer)** | Full history for devices they are purchasing | Unlocked at point of ownership transfer. Access scoped to transferred devices only. |
| **Granted viewer (per-transaction)** | Compliance score, certification status, event count | Granted by device owner per transaction — buyer evaluating a device, hospital procurement, insurance underwriter. Does not include document content or service notes. |
| **Public (no grant required)** | Active recall flag only | Safety-critical. Always visible without any grant. No score, no history, no certification status. |

### What is NEVER decryptable by any party

- Patient data — architecturally impossible. Not in vault, not on-chain.
- Another OEM's device records
- Internal service notes of a competing ISO technician
- Commercial pricing and contract terms — Layer 1 only, never uploaded

### Distinction: Granted viewer vs Public

This is a critical design decision clarified in May 2026:

**Public (no grant):** Only the active recall flag. A device under active recall must be publicly visible — this is a safety requirement equivalent to EUDAMED FSCA publication. No commercial data, no compliance score, no history.

**Granted viewer (device owner grants):** Compliance score, certification level, and event count. Granted per transaction by the device owner. Typical use cases: prospective buyer evaluating a refurbished device, hospital procurement evaluating a fleet purchase, insurance underwriter assessing portfolio risk. The grant is initiated by the seller or owner — not by MedPassport.

**Why scores are not public by default:** A compliance score of 72/100 is commercially sensitive. A competitor, a plaintiff's attorney, or a regulator could use it in ways the device owner did not intend. The OEM or device owner must actively choose to disclose the score to a specific party. This preserves the commercial relationship while enabling trust-based transactions.

---

## Notified Body Access Grant Flow

Access is initiated by the regulated party — not by the Notified Body.

1. Device owner (hospital or OEM) receives audit notification from Notified Body
2. Device owner initiates an access grant in VaultService specifying:
   - Notified Body SRN (registered identifier)
   - Device scope (list of tokenIds or device class)
   - Grant duration (configurable — default 90 days, extendable)
3. VaultService generates encrypted envelope for the NB's registered public key
4. Envelope is added to each relevant document in the vault for the granted scope
5. Notified Body downloads documents using their private key to decrypt
6. Grant expires at configured duration — NB cannot decrypt new documents after expiry
7. Documents already decrypted during the grant window remain in NB's possession — their responsibility

**Who controls the grant:** The device owner. MedPassport cannot grant NB access without device owner authorization. This preserves the manufacturer's control over audit scope while enabling independent verification.

---

## Regulatory Alignment Note

MedPassport is relevant to the **post-registration PMS evidence layer** of EUDAMED — not to device registration itself.

| EUDAMED activity | MedPassport relevance |
|---|---|
| Device registration (modules 1-3) | Not relevant — registration is between manufacturer and competent authority |
| PMS / PSUR evidence (module 4) | ✅ Direct — on-chain service history is structured PSUR evidence |
| Vigilance reporting / VGL (~Q2 2027) | ✅ Direct — FSCA events, complaint records, and corrective action chains feed VGL |
| Notified Body certificate verification | ✅ Indirect — NB can independently verify service evidence via access grant |

The regulatory urgency for MedPassport is MDR Art. 83 (lifetime PMS obligation, currently in force), FDA QMSR (service traceability, currently in force), and EUDAMED VGL (~Q2 2027) — not the EUDAMED registration deadlines.

---

## Pilot Implementation (Phase 2 — current)

**Wave 1 testnet pilot: no encryption**

Documents are stored as plaintext on IPFS. The CID and keccak256 hash are stored on-chain. Anyone with the CID can fetch the document.

This is acceptable for the Wave 1 testnet pilot because:
- No real patient data is stored
- No real commercial data is stored
- Test documents are synthetic
- The hash integrity proof still works correctly
- The architecture is in place — encryption is additive

**Before first enterprise production deployment:**
- Implement AES-256-GCM document encryption in VaultService.js
- Implement envelope generation per authorized role
- Add public key storage to CredentialRegistry.sol (on-chain)
- Add envelope storage structure to IPFS document format
- Implement Granted viewer grant flow (per-transaction, initiated by device owner)
- Implement Notified Body grant flow (per-audit, configurable duration)

---

## Document Format (Phase 3 — encrypted)

```json
{
  "medpassport": "1.0",
  "encrypted": true,
  "algorithm": "AES-256-GCM",
  "iv": "<base64 initialization vector>",
  "ciphertext": "<base64 encrypted document>",
  "envelopes": {
    "oem:<manufacturerSrn>":      "<base64 DEK encrypted with OEM public key>",
    "owner:<credentialId>":       "<base64 DEK encrypted with owner public key>",
    "nb:<notifiedBodySrn>":       "<base64 DEK encrypted with NB public key — per grant>",
    "iso:<credentialId>":         "<base64 DEK encrypted with ISO public key>",
    "viewer:<credentialId>":      "<base64 DEK encrypted with granted viewer public key>"
  },
  "grants": {
    "nb:<notifiedBodySrn>": {
      "scope": ["tokenId1", "tokenId2"],
      "expiresAt": "<ISO 8601 timestamp>",
      "grantedBy": "<device owner credentialId>"
    },
    "viewer:<credentialId>": {
      "scope": ["tokenId1"],
      "expiresAt": "<ISO 8601 timestamp>",
      "grantedBy": "<device owner credentialId>"
    }
  },
  "documentHash": "<keccak256 of plaintext — matches on-chain>",
  "metadata": {
    "eventType":  "CALIBRATION",
    "tokenId":    "1",
    "timestamp":  "2026-05-26T...",
    "protocol":   "MedPassport"
  }
}
```

---

## Consequences

**Positive:**
- No trusted intermediary for document access
- GDPR compliant by design — right to erasure applies to vault documents
- Notified Body can verify independently without requesting documents from manufacturer
- Competitive data (service notes, pricing) never exposed cross-organizationally
- Granted viewer model protects OEM commercial interests while enabling trust-based transactions
- Public recall flag preserves patient safety without exposing commercial data

**Risks and mitigations:**
- Key loss: actor loses private key → cannot decrypt their envelopes. Mitigation: actors manage own key backup. MedPassport cannot recover — by design.
- Envelope size: many roles = larger IPFS document. Mitigation: only generate envelopes for roles with active access needs.
- On-chain score queryability: ComplianceScorer.getScore() is publicly queryable at contract level. Mitigation: application layer does not expose scores without Granted viewer authorization. Document this tension explicitly — see Known Design Tension above.
- Granted viewer grant management complexity: device owners must actively manage grants. Mitigation: VaultService automates grant generation at point of transaction.

---

## Implementation Checklist (Phase 3)

- [ ] Add `publicKey` field to CredentialRegistry.sol (Ed25519 public key, bytes)
- [ ] Implement AES-256-GCM encryption in VaultService.js
- [ ] Implement envelope generation per authorized role
- [ ] Implement envelope decryption for each actor type
- [ ] Implement Notified Body access grant flow (configurable duration, device owner initiated)
- [ ] Implement Granted viewer grant flow (per-transaction, device owner initiated)
- [ ] Update IPFS document format to encrypted envelope structure with grants metadata
- [ ] Update application layer to require Granted viewer role before exposing score/cert
- [ ] Security audit — Certora or equivalent — before production

---

## Change Log

| Date | Change | Reason |
|---|---|---|
| May 2026 (initial) | ADR created — envelope encryption model, 90-day NB expiry | Initial design |
| May 2026 (updated) | Split Public into Granted viewer + Public (recall only). NB grant duration made configurable. On-chain score tension documented. CAPA traceability scope clarified. EUDAMED regulatory note added. Granted viewer envelope and grants metadata added to document format. | Session review — gaps analysis against one-pager and market conversations |

---

## References

- ADR-000 Protocol Axioms — Zero PII on-chain (Axiom 2)
- ADR-001 Credential States — credential lifecycle
- ADR-011 Access Tier Framework — monetization with neutrality
- GDPR Article 17 — Right to erasure
- EU MDR Art. 83 — Lifetime PMS obligation
- NIST SP 800-175B — Guideline for Using Cryptographic Standards
- AWS KMS envelope encryption documentation

---

*Not legal or regulatory advice. MIT License.*
*MedPassport Protocol · Tomer Saar · May 2026*
