// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DeviceTypes} from "../types/DeviceTypes.sol";
import {CredentialRegistry} from "../access/CredentialRegistry.sol";
import {RoleManager} from "../access/RoleManager.sol";
import {ServiceLogRegistry} from "./ServiceLogRegistry.sol";

/**
 * @title CorrectionRegistry
 * @author Tomer Saar, PMP
 * @notice Manages corrections, disputes, and amendments to
 *         service events recorded in the ServiceLogRegistry.
 *
 *         Original events are never deleted or overwritten.
 *         Corrections are appended — each correction references
 *         the original event by its document hash and index.
 *
 *         Three correction types exist:
 *         - SUPERSEDES: replaces the original for operational use
 *         - DISPUTES:   flags the event as contested
 *         - AMENDS:     adds missing information
 *
 *         Correction chains are allowed — a correction may itself
 *         be corrected. The full chain is always queryable.
 *
 * @dev Maps to Axiom 2 in ADR-000
 *      ISO 13485:2016 §4.2.5 — Amendment of quality records
 *      FDA 21 CFR Part 11 — Audit trail integrity
 */
contract CorrectionRegistry {

    // ============================================================
    //  STATE VARIABLES
    // ============================================================

    /// @notice Reference to the CredentialRegistry
    CredentialRegistry public immutable credentialRegistry;

    /// @notice Reference to the RoleManager
    RoleManager public immutable roleManager;

    /// @notice Reference to the ServiceLogRegistry
    ServiceLogRegistry public immutable serviceLog;

    /// @dev tokenId => array of correction records
    mapping(uint256 => DeviceTypes.CorrectionRecord[]) private _corrections;

    /// @dev originalEventHash => correction index in the array
    /// Allows fast lookup of corrections by original event hash
    mapping(bytes32 => uint256[]) private _correctionsByHash;

    /// @dev originalEventHash => is superseded
    /// True if a SUPERSEDES correction exists for this event
    mapping(bytes32 => bool) public isSuperseded;

    /// @dev originalEventHash => is disputed
    /// True if a DISPUTES correction exists for this event
    mapping(bytes32 => bool) public isDisputed;

    // ============================================================
    //  EVENTS
    // ============================================================

    event CorrectionAppended(
        uint256 indexed tokenId,
        uint256         correctionIndex,
        DeviceTypes.CorrectionType correctionType,
        bytes32 indexed originalEventHash,
        address indexed correctedBy,
        uint256         timestamp
    );

    // ============================================================
    //  ERRORS
    // ============================================================

    error DocumentHashRequired();
    error IPFSCIDRequired();
    error OriginalEventHashRequired();
    error CorrectionNoteRequired();
    error OriginalEventNotFound(bytes32 originalEventHash);
    error AlreadySuperseded(bytes32 originalEventHash);
    error IndexOutOfBounds(uint256 tokenId, uint256 index);

    // ============================================================
    //  CONSTRUCTOR
    // ============================================================

    constructor(
        address _credentialRegistry,
        address _roleManager,
        address _serviceLog
    ) {
        require(
            _credentialRegistry != address(0),
            "CredentialRegistry cannot be zero address"
        );
        require(
            _roleManager != address(0),
            "RoleManager cannot be zero address"
        );
        require(
            _serviceLog != address(0),
            "ServiceLog cannot be zero address"
        );

        credentialRegistry = CredentialRegistry(_credentialRegistry);
        roleManager        = RoleManager(_roleManager);
        serviceLog         = ServiceLogRegistry(_serviceLog);
    }

    // ============================================================
    //  CORE FUNCTION — APPEND CORRECTION
    // ============================================================

    /**
     * @notice Append a correction record to a prior service event.
     * @dev The original event is identified by its token ID, index,
     *      and document hash — all three must match.
     *      The caller must have permission to correct this event:
     *      - The original writer
     *      - The device owner
     *      - A regulator
     *
     *      A SUPERSEDES correction marks the original as inactive
     *      for operational queries but keeps it in the audit trail.
     *      Only one SUPERSEDES correction is allowed per event.
     *
     * @param tokenId            Device passport token ID
     * @param originalEventIndex Index of the event being corrected
     * @param originalEventHash  Document hash of the original event
     * @param correctionType     SUPERSEDES, DISPUTES, or AMENDS
     * @param documentHash       Hash of the correction document
     * @param ipfsCID            IPFS CID of the correction document
     * @param correctionNote     Plain language description
     * @return correctionIndex   Index of this correction in the array
     */
    function appendCorrection(
        uint256                    tokenId,
        uint256                    originalEventIndex,
        bytes32                    originalEventHash,
        DeviceTypes.CorrectionType correctionType,
        bytes32                    documentHash,
        string  calldata           ipfsCID,
        string  calldata           correctionNote
    ) external returns (uint256 correctionIndex) {

        // Validate inputs
        if (originalEventHash == bytes32(0))
            revert OriginalEventHashRequired();
        if (documentHash == bytes32(0))
            revert DocumentHashRequired();
        if (bytes(ipfsCID).length == 0)
            revert IPFSCIDRequired();
        if (bytes(correctionNote).length == 0)
            revert CorrectionNoteRequired();

        // Verify original event exists and hash matches
        bool hashVerified = serviceLog.verifyDocument(
            tokenId,
            originalEventIndex,
            originalEventHash
        );
        if (!hashVerified)
            revert OriginalEventNotFound(originalEventHash);

        // Check SUPERSEDES — only one allowed per event
        if (
            correctionType == DeviceTypes.CorrectionType.SUPERSEDES &&
            isSuperseded[originalEventHash]
        ) revert AlreadySuperseded(originalEventHash);

        // Get original event to check authorship
        DeviceTypes.ServiceEvent memory original =
            serviceLog.getEvent(tokenId, originalEventIndex);

        // Check caller has permission to correct
        roleManager.requireCorrectionPermission(
            msg.sender,
            original.reportedBy
        );

        // Get caller credential ID
        bytes32 credentialId =
            credentialRegistry.getCredentialId(msg.sender);

        // Build correction record
        bool supersedes =
            correctionType == DeviceTypes.CorrectionType.SUPERSEDES;

        DeviceTypes.CorrectionRecord memory correction =
            DeviceTypes.CorrectionRecord({
                correctionType:     correctionType,
                originalEventHash:  originalEventHash,
                originalTokenId:    tokenId,
                originalEventIndex: originalEventIndex,
                correctedBy:        msg.sender,
                credentialId:       credentialId,
                documentHash:       documentHash,
                ipfsCID:            ipfsCID,
                correctionNote:     correctionNote,
                timestamp:          block.timestamp,
                supersedes:         supersedes
            });

        _corrections[tokenId].push(correction);
        correctionIndex = _corrections[tokenId].length - 1;

        // Track by original hash for fast lookup
        _correctionsByHash[originalEventHash].push(correctionIndex);

        // Update flags
        if (supersedes) {
            isSuperseded[originalEventHash] = true;
        }
        if (correctionType == DeviceTypes.CorrectionType.DISPUTES) {
            isDisputed[originalEventHash] = true;
        }

        emit CorrectionAppended(
            tokenId,
            correctionIndex,
            correctionType,
            originalEventHash,
            msg.sender,
            block.timestamp
        );
    }

    // ============================================================
    //  VIEW FUNCTIONS
    // ============================================================

    /**
     * @notice Get all corrections for a device token.
     * @param tokenId The device passport token to query
     */
    function getCorrections(uint256 tokenId)
        external view
        returns (DeviceTypes.CorrectionRecord[] memory)
    {
        return _corrections[tokenId];
    }

    /**
     * @notice Get a single correction by token ID and index.
     * @param tokenId The device passport token
     * @param index   The correction index
     */
    function getCorrection(uint256 tokenId, uint256 index)
        external view
        returns (DeviceTypes.CorrectionRecord memory)
    {
        if (index >= _corrections[tokenId].length)
            revert IndexOutOfBounds(tokenId, index);
        return _corrections[tokenId][index];
    }

    /**
     * @notice Get all correction indices for a specific original event.
     * @param originalEventHash The document hash of the original event
     */
    function getCorrectionsByOriginalHash(bytes32 originalEventHash)
        external view
        returns (uint256[] memory)
    {
        return _correctionsByHash[originalEventHash];
    }

    /**
     * @notice Get the total number of corrections for a device.
     * @param tokenId The device passport token to query
     */
    function getCorrectionCount(uint256 tokenId)
        external view
        returns (uint256)
    {
        return _corrections[tokenId].length;
    }

    /**
     * @notice Check if an event is operationally active.
     * @dev An event is inactive for operational use if it has been
     *      superseded by a correction. It remains visible in audit view.
     *
     * @param originalEventHash The document hash of the event to check
     * @return True if the event is active — not superseded
     */
    function isEventActive(bytes32 originalEventHash)
        external view
        returns (bool)
    {
        return !isSuperseded[originalEventHash];
    }
}