# Security and Privacy

MedPassport is designed as a zero-PII, tamper-evident evidence protocol for regulated medical devices.

## Security Principles

### Zero PII on-chain

No patient data, protected health information, customer names, engineer names, pricing, service notes, or clinical workflow data is written to the blockchain.

The public ledger stores only:

- Device identifiers such as UDI where required
- Cryptographic hashes
- Event timestamps
- Event metadata
- Credential identifiers
- Attestation records

### Append-only evidence

Events are not deleted or overwritten. Corrections are added as new records that reference the original event. This preserves the full audit trail while allowing mistakes or disputes to be handled transparently.

### Signed attestations

Every lifecycle event is written by a credentialed actor. Anonymous writes do not exist in the protocol model.

### Role-based access

Write access is controlled by credentialed roles. Read access is purpose-limited and depends on actor type, ownership, and explicit grants.

Public access is intentionally limited. Public users can verify device identity and active recall status. More detailed evidence is available only to authorized actors or through owner-authorized grants.

### Dual-signature governance for high-risk actions

Ownership transfer and certification issuance require two independent credentialed actors. No single actor can complete either action unilaterally.

## Evidence Storage Model

MedPassport separates public proof from private evidence.

| Layer | Purpose |
|---|---|
| Private systems | CMMS, QMS, ERP, customer records, contracts, pricing |
| Evidence vault | Supporting documents such as calibration certificates and service reports |
| Public ledger | Hashes, timestamps, attestations, credential IDs, device identity |
| Application layer | Role-based dashboards, audit views, and owner-authorized grants |

## Current Testnet Scope

The current public protocol is a testnet implementation. Testnet deployments must not contain real patient data or confidential commercial data.

## Production Security Direction

Production hardening is expected to include:

- Encrypted evidence vault
- Enterprise identity integration
- Strong operational key management
- Audit logging
- Formal incident response procedures
- Independent smart-contract review before production deployment

Implementation details for production custody, grants, and enterprise security are intentionally not published in this public repository until they are finalized and appropriate for disclosure.

## Reporting Security Issues

Please do not open public GitHub issues for suspected vulnerabilities.

Contact the maintainer privately through the contact method listed on the GitHub profile or project website. Include:

- A clear description of the issue
- Steps to reproduce, if applicable
- Potential impact
- Any suggested mitigation

## Disclaimer

This repository is not legal, medical, regulatory, or cybersecurity advice. Production use in regulated environments requires appropriate legal, security, validation, and regulatory review.
