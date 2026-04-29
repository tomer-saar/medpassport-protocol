// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DeviceTypes
 * @author Tomer Saar, PMP
 * @notice Shared data types for the MedPassport Protocol.
 *         This library is the dictionary of the entire protocol.
 *         Every other contract imports from here.
 *         No logic lives here — only definitions.
 *
 * @dev Regulatory alignment:
 *      ISO 13485:2016 §7.5.8 — Identification and traceability
 *      EU MDR 2017/745 Art. 27 — Unique Device Identification
 *      FDA 21 CFR Part 820.60 — Identification
 */
library DeviceTypes {

    // ============================================================
    //  ENUMERATIONS
    // ============================================================

    enum DeviceClass {
        CLASS_I,
        CLASS_IIA,
        CLASS_IIB,
        CLASS_III,
        IVD_A,
        IVD_B,
        IVD_C,
        IVD_D
    }

    enum EventType {
        PREVENTIVE_MAINTENANCE,
        CORRECTIVE_MAINTENANCE,
        CALIBRATION,
        SOFTWARE_UPDATE,
        INSPECTION,
        INCIDENT_REPORT,
        DECOMMISSION,
        OWNERSHIP_TRANSFER,
        CERTIFICATION_ISSUED,
        CERTIFICATION_REVOKED
    }

    enum CorrectionType {
        SUPERSEDES,
        DISPUTES,
        AMENDS
    }

    enum CertLevel {
        BRONZE,
        SILVER,
        GOLD
    }

    enum CredentialState {
        ACTIVE,
        REVOKED,
        INACTIVE,
        MIGRATED
    }

    enum ActorRole {
        MANUFACTURER,
        CERTIFIED_SERVICE_ORG,
        CERTIFIER,
        REGULATOR,
        DEVICE_OWNER,
        GOVERNANCE
    }

    // ============================================================
    //  STRUCTS
    // ============================================================

    struct DeviceIdentity {
        string      udi;
        string      deviceIdentifier;
        DeviceClass deviceClass;
        string      model;
        address     manufacturerWallet;
        uint256     manufactureDate;
        string      metadataURI;
        bool        recallActive;
        bool        decommissioned;
        uint256     lastServiceBlock;
        uint256     eventCount;
    }

    struct ServiceEvent {
        uint256    tokenId;
        EventType  eventType;
        uint256    timestamp;
        uint256    blockNumber;
        address    reportedBy;
        bytes32    credentialId;
        bytes32    documentHash;
        string     ipfsCID;
        bool       passedInspection;
        string     softwareVersion;
        string     notes;
    }

    struct CorrectionRecord {
        CorrectionType correctionType;
        bytes32    originalEventHash;
        uint256    originalTokenId;
        uint256    originalEventIndex;
        address    correctedBy;
        bytes32    credentialId;
        bytes32    documentHash;
        string     ipfsCID;
        string     correctionNote;
        uint256    timestamp;
        bool       supersedes;
    }

    struct Credential {
        bytes32         credentialId;
        address         wallet;
        ActorRole       role;
        CredentialState state;
        string          organizationName;
        string          accreditationRef;
        uint256         grantedAt;
        uint256         updatedAt;
        address         grantedBy;
        bytes32         successorId;
    }

    struct PendingAction {
        bytes32  actionId;
        uint256  tokenId;
        address  proposer;
        address  confirmer;
        bytes32  documentHash;
        uint256  proposedAt;
        uint256  expiresAt;
        bool     confirmed;
        bool     cancelled;
    }

    struct Certification {
        uint256   deviceTokenId;
        uint8     complianceScore;
        uint256   issuedAt;
        uint256   validUntil;
        address   certifierAddress;
        bytes32   certifierCredId;
        string    certifierOrg;
        string    certificationRef;
        CertLevel level;
        bool      active;
    }
}