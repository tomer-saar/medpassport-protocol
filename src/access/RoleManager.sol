// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DeviceTypes} from "../types/DeviceTypes.sol";
import {CredentialRegistry} from "./CredentialRegistry.sol";

/**
 * @title RoleManager
 * @author Tomer Saar, PMP
 * @notice Enforces role-based permissions for every write path
 *         in the MedPassport protocol.
 *
 *         Every contract that accepts writes imports this contract
 *         and calls the appropriate permission check before executing.
 *         If the check fails, the transaction reverts immediately.
 *
 *         No write path may bypass these checks.
 *         This rule is enforced as a Foundry invariant test.
 *
 * @dev Maps to ADR-001 — Role Matrix
 *      Axiom 1: Every write is a signed attestation by a
 *               credentialed actor
 */
contract RoleManager {

    // ============================================================
    //  STATE VARIABLES
    // ============================================================

    /// @notice Reference to the CredentialRegistry
    CredentialRegistry public immutable credentialRegistry;

    // ============================================================
    //  ERRORS
    // ============================================================

    error NotCredentialed(address caller);
    error WrongRole(
        address caller,
        DeviceTypes.ActorRole required,
        DeviceTypes.ActorRole actual
    );
    error InsufficientRole(address caller, string requiredRole);
    error CredentialNotActive(address caller);

    // ============================================================
    //  CONSTRUCTOR
    // ============================================================

    /**
     * @param _credentialRegistry Address of the deployed
     *        CredentialRegistry contract.
     */
    constructor(address _credentialRegistry) {
        require(
            _credentialRegistry != address(0),
            "CredentialRegistry cannot be zero address"
        );
        credentialRegistry = CredentialRegistry(_credentialRegistry);
    }

    // ============================================================
    //  PERMISSION CHECKS
    //  These functions are called by every write-path contract
    //  before accepting any action. They revert if the caller
    //  does not have the required role and active credential.
    // ============================================================

    /**
     * @notice Verify caller is a credentialed actor with an
     *         active credential. Reverts if not.
     * @param caller The address to check
     */
    function requireActive(address caller) public view {
        if (!credentialRegistry.isActive(caller))
            revert CredentialNotActive(caller);
    }

    /**
     * @notice Verify caller holds the MANUFACTURER role.
     * @dev Required for: minting passports, software updates,
     *      decommission events.
     * @param caller The address to check
     */
    function requireManufacturer(address caller) external view {
        requireActive(caller);
        DeviceTypes.ActorRole role = credentialRegistry.getRole(caller);
        if (role != DeviceTypes.ActorRole.MANUFACTURER)
            revert InsufficientRole(caller, "MANUFACTURER");
    }

    /**
     * @notice Verify caller holds the CERTIFIED_SERVICE_ORG role.
     * @dev Required for: PM events, calibration, corrective
     *      maintenance, inspection, incident reports.
     * @param caller The address to check
     */
    function requireServiceOrg(address caller) external view {
        requireActive(caller);
        DeviceTypes.ActorRole role = credentialRegistry.getRole(caller);
        if (role != DeviceTypes.ActorRole.CERTIFIED_SERVICE_ORG)
            revert InsufficientRole(caller, "CERTIFIED_SERVICE_ORG");
    }

    /**
     * @notice Verify caller holds the CERTIFIER role.
     * @dev Required for: certification issuance and revocation.
     * @param caller The address to check
     */
    function requireCertifier(address caller) external view {
        requireActive(caller);
        DeviceTypes.ActorRole role = credentialRegistry.getRole(caller);
        if (role != DeviceTypes.ActorRole.CERTIFIER)
            revert InsufficientRole(caller, "CERTIFIER");
    }

    /**
     * @notice Verify caller holds the REGULATOR role.
     * @dev Required for: recall flags, incident reports,
     *      certification revocation.
     * @param caller The address to check
     */
    function requireRegulator(address caller) external view {
        requireActive(caller);
        DeviceTypes.ActorRole role = credentialRegistry.getRole(caller);
        if (role != DeviceTypes.ActorRole.REGULATOR)
            revert InsufficientRole(caller, "REGULATOR");
    }

    /**
     * @notice Verify caller holds the GOVERNANCE role.
     * @dev Required for: credential management operations.
     * @param caller The address to check
     */
    function requireGovernance(address caller) external view {
        requireActive(caller);
        DeviceTypes.ActorRole role = credentialRegistry.getRole(caller);
        if (role != DeviceTypes.ActorRole.GOVERNANCE)
            revert InsufficientRole(caller, "GOVERNANCE");
    }

    /**
     * @notice Verify caller can write a specific event type.
     * @dev Enforces the full event-type permission matrix
     *      from ADR-001 and EVENT-TAXONOMY.md.
     *      Every event type has exactly one permitted writer role.
     *
     * @param caller    The address attempting to write
     * @param eventType The type of event being written
     */
    function requireEventPermission(
        address caller,
        DeviceTypes.EventType eventType
    ) external view {
        requireActive(caller);
        DeviceTypes.ActorRole role = credentialRegistry.getRole(caller);

        if (eventType == DeviceTypes.EventType.SOFTWARE_UPDATE) {
            // Software updates: manufacturer only
            if (role != DeviceTypes.ActorRole.MANUFACTURER)
                revert InsufficientRole(caller, "MANUFACTURER");

        } else if (
            eventType == DeviceTypes.EventType.PREVENTIVE_MAINTENANCE ||
            eventType == DeviceTypes.EventType.CORRECTIVE_MAINTENANCE ||
            eventType == DeviceTypes.EventType.CALIBRATION ||
            eventType == DeviceTypes.EventType.INSPECTION
        ) {
            // Standard service events: certified service org only
            if (role != DeviceTypes.ActorRole.CERTIFIED_SERVICE_ORG)
                revert InsufficientRole(caller, "CERTIFIED_SERVICE_ORG");

        } else if (
            eventType == DeviceTypes.EventType.INCIDENT_REPORT
        ) {
            // Incident reports: service org or regulator
            if (
                role != DeviceTypes.ActorRole.CERTIFIED_SERVICE_ORG &&
                role != DeviceTypes.ActorRole.REGULATOR
            ) revert InsufficientRole(
                caller,
                "CERTIFIED_SERVICE_ORG or REGULATOR"
            );

        } else if (
            eventType == DeviceTypes.EventType.DECOMMISSION
        ) {
            // Decommission: device owner or manufacturer
            if (
                role != DeviceTypes.ActorRole.DEVICE_OWNER &&
                role != DeviceTypes.ActorRole.MANUFACTURER
            ) revert InsufficientRole(
                caller,
                "DEVICE_OWNER or MANUFACTURER"
            );

        } else if (
            eventType == DeviceTypes.EventType.OWNERSHIP_TRANSFER
        ) {
            // Ownership transfer: device owner only
            // Dual-signature enforced in TransferManager
            if (role != DeviceTypes.ActorRole.DEVICE_OWNER)
                revert InsufficientRole(caller, "DEVICE_OWNER");

        } else if (
            eventType == DeviceTypes.EventType.CERTIFICATION_ISSUED ||
            eventType == DeviceTypes.EventType.CERTIFICATION_REVOKED
        ) {
            // Certification: certifier or regulator
            if (
                role != DeviceTypes.ActorRole.CERTIFIER &&
                role != DeviceTypes.ActorRole.REGULATOR
            ) revert InsufficientRole(
                caller,
                "CERTIFIER or REGULATOR"
            );
        }
    }

    /**
     * @notice Verify caller can append a correction record.
     * @dev Corrections may be written by:
     *      - The original event writer
     *      - The device owner
     *      - A regulator
     *      All must hold active credentials.
     *
     * @param caller          The address attempting the correction
     * @param originalWriter  The address that wrote the original event
     */
    function requireCorrectionPermission(
        address caller,
        address originalWriter
    ) external view {
        requireActive(caller);
        DeviceTypes.ActorRole role = credentialRegistry.getRole(caller);

        bool isOriginalWriter = (caller == originalWriter);
        bool isOwnerOrRegulator = (
            role == DeviceTypes.ActorRole.DEVICE_OWNER ||
            role == DeviceTypes.ActorRole.REGULATOR
        );

        if (!isOriginalWriter && !isOwnerOrRegulator)
            revert InsufficientRole(
                caller,
                "original writer, DEVICE_OWNER, or REGULATOR"
            );
    }

    // ============================================================
    //  VIEW HELPERS
    // ============================================================

    /**
     * @notice Check if a caller has a specific role without reverting.
     * @dev Use this for conditional logic — use requireX for enforcement.
     *
     * @param caller The address to check
     * @param role   The role to check against
     * @return True if caller has the role and an active credential
     */
    function hasRole(
        address caller,
        DeviceTypes.ActorRole role
    ) external view returns (bool) {
        if (!credentialRegistry.isActive(caller)) return false;
        return credentialRegistry.getRole(caller) == role;
    }

    /**
     * @notice Get the role of a caller without reverting.
     * @param caller The address to query
     * @return The ActorRole of the caller
     * @return True if the caller has an active credential
     */
    function getRoleOf(address caller)
        external view
        returns (DeviceTypes.ActorRole, bool)
    {
        bool active = credentialRegistry.isActive(caller);
        if (!active) return (DeviceTypes.ActorRole.GOVERNANCE, false);
        return (credentialRegistry.getRole(caller), true);
    }
}