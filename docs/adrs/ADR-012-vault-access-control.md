# ADR-012 — Vault Access Control: Envelope Encryption Model

**Status:** Proposed — Design complete · Implementation Phase 3
**Date:** May 2026
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
      ├── DEK encrypted with OEM public key      → stored in IPFS alongside document
      ├── DEK encrypted with Device Owner key    → stored in IPFS alongside document
      ├── DEK encrypted with Notified Body key   → stored in IPFS alongside document
      └── DEK encrypted with ISO Actor key       → stored in IPFS alongside document

On-chain (Layer 3): document CID + keccak256(encrypted document)
```

Each authorized party decrypts their envelope with their private key to get the DEK, then decrypts the document. No single party holds all keys. MedPassport never holds any private key.

### Why envelope encryption

- Standard pattern: AWS KMS, HashiCorp Vault, Signal Protocol all use this approach
- No trusted intermediary: MedPassport does not hold any private key
- Selective disclosure: new roles can be granted access by adding a new encrypted envelope without re-encrypting the document
- Revocation: remove the envelope for a revoked party — they can no longer decrypt future documents (past documents remain accessible to them — same as any encrypted storage system)
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

### Read access (vault decryption — implemented in Phase 3)

| Actor | Documents they can decrypt | Rationale |
|---|---|---|
| **OEM / Manufacturer** | All documents for devices they manufactured. All SW_UPDATE records. | Manufacturer has lifetime PMS obligation |
| **Device current owner (hospital/user)** | All documents for devices they currently own | Ownership transfers automatically transfer read access |
| **ISO technician** | Documents for events they personally wrote | Credentialed actor — can verify their own work |
| **Notified Body (granted)** | Full RA layer: all events, calibration certs, FSCA records, ownership chain for specific device | Granted per-audit by device owner. Read-only. |
| **Insurer (paid API)** | Compliance score, event count, cert status, event types and outcomes | Commercial API tier — no service notes, no PII |
| **Refurbisher (at transfer)** | Full history for devices they are purchasing | Unlocked at point of ownership transfer |
| **Public (QR scan)** | Nothing encrypted. Score, cert status, event count, recall flag — all from on-chain, not vault | Always free, always available |

### What is NEVER decryptable by any party

- Patient data — architecturally impossible on-chain. Not in vault either.
- Another OEM's device records
- Internal service notes of a competing ISO technician
- Commercial pricing and contract terms — Layer 1 only, never uploaded

---

## Key Management

### Key hierarchy

```
Root Authority: MedPassport Protocol (open source — no single controller)
      │
      ├── Organizational Keys (Ed25519 keypairs)
      │     Each credentialed actor in CredentialRegistry has a keypair
      │     Public key stored in CredentialRegistry on-chain
      │     Private key held by the actor — MedPassport never holds it
      │
      └── Document Encryption Keys (DEK)
            Random AES-256-GCM key per document
            Wrapped in envelopes for each authorized role
            Stored in IPFS alongside the encrypted document
```

### Key rotation

When a credential is revoked in CredentialRegistry:
- New documents: no envelope generated for the revoked party
- Existing documents: envelopes remain. Revoked party retains access to historical documents they were authorized for. This is intentional — retroactive revocation of read access to signed attestations would undermine the audit trail.

### Notified Body access grants

Notified Body read access is granted per-audit, per-device-scope, with expiry:
1. Device owner (hospital or OEM) grants read access to a specific Notified Body SRN
2. VaultService generates encrypted envelope for the NB's public key
3. Envelope is added to each relevant document in the vault
4. Grant expires after 90 days (configurable)
5. After expiry, NB cannot decrypt new documents — existing access to already-decrypted documents is their responsibility

---

## Pilot Implementation (Phase 2 — current)

**Testnet pilot: no encryption**

Documents are stored as plaintext on IPFS. The CID and keccak256 hash are stored on-chain. Anyone with the CID can fetch the document.

This is acceptable for the Wave 1 testnet pilot because:
- No real patient data is stored
- No real commercial data is stored
- Test documents are synthetic
- The hash integrity proof still works correctly
- The architecture is in place — encryption is additive

**Before first enterprise production deployment:**
- Implement AES-256-GCM document encryption in VaultService
- Implement envelope generation per authorized role
- Add public key storage to CredentialRegistry (on-chain)
- Add envelope storage structure to IPFS document format

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
    "oem:<manufacturerSrn>":    "<base64 DEK encrypted with OEM public key>",
    "owner:<credentialId>":     "<base64 DEK encrypted with owner public key>",
    "nb:<notifiedBodySrn>":     "<base64 DEK encrypted with NB public key>",
    "iso:<credentialId>":       "<base64 DEK encrypted with ISO public key>"
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
- Selective disclosure — roles can be added without re-encryption

**Risks and mitigations:**
- Key loss: actor loses private key → cannot decrypt their envelopes. Mitigation: actors must manage their own key backup. MedPassport cannot recover — this is by design for neutrality.
- Envelope size: many roles = larger IPFS document. Mitigation: only generate envelopes for roles that actually need access. Insurers and public get on-chain data only.
- Complexity: Phase 3 adds significant implementation complexity. Mitigation: plaintext pilot first, encrypt before first LOI is signed.

---

## Implementation Checklist (Phase 3)

- [ ] Add `publicKey` field to CredentialRegistry.sol (Ed25519 public key, bytes)
- [ ] Implement AES-256-GCM encryption in VaultService.js
- [ ] Implement envelope generation per authorized role
- [ ] Implement envelope decryption for each actor type
- [ ] Add Notified Body access grant flow (90-day expiry)
- [ ] Update IPFS document format to encrypted envelope structure
- [ ] Security audit — Certora or equivalent — before production

---

## References

- ADR-000 Protocol Axioms — Zero PII on-chain (Axiom 2)
- ADR-001 Credential States — credential lifecycle
- ADR-011 Access Tier Framework — monetization with neutrality
- GDPR Article 17 — Right to erasure
- NIST SP 800-175B — Guideline for Using Cryptographic Standards
- AWS KMS envelope encryption documentation

---

*Not legal or regulatory advice. MIT License.*
*MedPassport Protocol · Tomer Saar, PMP · May 2026*
