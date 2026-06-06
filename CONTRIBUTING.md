# Contributing to MedPassport Protocol

Thank you for your interest in contributing.

MedPassport is an open-source protocol for tamper-evident medical-device lifecycle evidence. Contributions are welcome from Solidity developers, medical-device professionals, healthcare IT specialists, security researchers, and regulatory experts.

## Project Principles

Before contributing, please read the protocol axioms in:

`docs/adrs/ADR-000-protocol-axioms.md`

Every contribution must preserve these principles:

- Every write is a signed attestation
- Nothing is deleted or overwritten
- Original authorship is preserved
- Patient data and PII never reach the ledger
- High-risk events require two independent signatures
- Write access is based on credential, not commercial relationship

## Development Setup

```bash
git clone https://github.com/tomer-saar/medpassport-protocol.git
cd medpassport-protocol
forge install
forge build
forge test
```

## Pull Request Guidelines

Before opening a pull request:

1. Run the full test suite.
2. Do not commit `.env` files or private keys.
3. Do not include patient data, personal data, or real commercial data in tests.
4. Keep test data synthetic.
5. Document any architecture-impacting change.
6. Explain how the change preserves the protocol axioms.

## Smart Contract Changes

Smart contract changes require special care.

- Run `forge test` before submitting.
- Preserve append-only behavior.
- Do not introduce any path that allows event deletion or silent overwrite.
- Do not introduce anonymous writes.
- Do not add PII/PHI fields to on-chain structs or events.
- Do not weaken dual-signature requirements for ownership transfer or certification.

## Documentation Changes

Public documentation should explain the protocol clearly without exposing private commercial strategy, partner-specific material, or sensitive security implementation details.

Do not add private strategy, pilot, pricing, investor, LOI, insurance, or partner documents to the public repository.

## Security Issues

Do not disclose security vulnerabilities in public issues.

Report suspected vulnerabilities privately using the contact method listed on the GitHub profile or project website.

## Code of Conduct

Contributors are expected to communicate respectfully and constructively. This project operates at the intersection of healthcare, regulation, and public safety, so clarity and professionalism matter.

## License

By contributing, you agree that your contribution will be licensed under the MIT License used by this repository.
