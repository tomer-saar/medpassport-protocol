// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DeviceTypes} from "../types/DeviceTypes.sol";
import {CredentialRegistry} from "../access/CredentialRegistry.sol";
import {RoleManager} from "../access/RoleManager.sol";
import {DevicePassportNFT} from "./DevicePassportNFT.sol";

/**
 * @title ServiceLogRegistry
 * @author Tomer Saar, PMP
 * @notice Immutable, append-only registry of all lifecycle events
 *         recorded against medical device passports.
 *
 *         Every event is a signed attestation by a credentialed actor.
 *         Events are never deleted or overwritten — only appended.
 *         Corrections are handled by the CorrectionRegistry contract.
 *
 *         Full service reports are stored off-chain on IPFS.
 *         Only the keccak256 hash of each document is stored on-chain.
 *         Any tampering with the off-chain document breaks the hash match.
 *
 * @dev Maps to Axiom 1 and Axiom 2 in ADR-000
 *      ISO 13485:2016 §8.2.1 — Feedback and complaint handling
 *      EU MDR 2017/745 Art. 83 — Post-market surveillance
 *      FDA 21 CFR Part 820.200 — Servicing records
 */
contract ServiceLogRegistry {

    // ============================================================
    //  STATE VARIABLES
    // ============================================================

    /// @notice Reference to the CredentialRegistry
    CredentialRegistry public immutable credentialRegistry;

    /// @notice Reference to the RoleManager
    RoleManager public immutable roleManager;

    /// @notice Reference to the DevicePassportNFT
    DevicePassportNFT public immutable passportNFT;

    /// @dev tokenId => array of service events (append-only)
    mapping(uint256 => DeviceTypes.ServiceEvent[]) private _history;

    // ============================================================
    //  STRUCTS
    // ============================================================

    /// @notice Parameters for a single event within a batchLog() call.
    struct BatchEventParams {
        DeviceTypes.EventType eventType;
        bytes32               documentHash;
        string                ipfsCID;
        bool                  passedInspection;
        string                softwareVersion;
        string                notes;
        bool                  hasCompatibleParts;
        bool                  hasUndocumentedParts;
        bool                  isSeriousIncident;
        bytes32               sbomHash;
    }

    // ============================================================
    //  EVENTS
    // ============================================================

    event ServiceEventLogged(
        uint256 indexed tokenId,
        uint256         eventIndex,
        DeviceTypes.EventType indexed eventType,
        address indexed reportedBy,
        bytes32         documentHash,
        uint256         timestamp
    );

    event BatchLogged(
        uint256 indexed tokenId,
        uint256         count,
        uint256         timestamp
    );

    // ============================================================
    //  ERRORS
    // ============================================================

    error DocumentHashRequired();
    error IPFSCIDRequired();
    error DeviceIsDecommissioned(uint256 tokenId);
    error DeviceHasActiveRecall(uint256 tokenId);
    error EventIndexOutOfBounds(uint256 tokenId, uint256 index);
    error DocumentHashMismatch();
    error BatchSizeOutOfBounds(uint256 count);

    // ============================================================
    //  CONSTRUCTOR
    // ============================================================

    constructor(
        address _credentialRegistry,
        address _roleManager,
        address _passportNFT
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
            _passportNFT != address(0),
            "PassportNFT cannot be zero address"
        );

        credentialRegistry = CredentialRegistry(_credentialRegistry);
        roleManager        = RoleManager(_roleManager);
        passportNFT        = DevicePassportNFT(_passportNFT);
    }

    // ============================================================
    //  CORE FUNCTIONS — LOG EVENT
    // ============================================================

    /**
     * @notice Record a lifecycle event against a device passport.
     * @dev Caller must hold the appropriate role for the event type.
     *      Enforced by RoleManager.requireEventPermission().
     *      Device must not be decommissioned.
     *      Document hash is required — no hash, no event.
     *      Full document stored on IPFS — only hash stored on-chain.
     *
     * @param tokenId          Device passport token ID
     * @param eventType        The type of lifecycle event
     * @param documentHash     keccak256 hash of the full service report
     * @param ipfsCID          IPFS content identifier of the document
     * @param passedInspection Pass or fail outcome where applicable
     * @param softwareVersion  New version string for SOFTWARE_UPDATE events
     * @param notes            Brief on-chain note — max 200 characters
     * @param sbomHash         keccak256 hash of the SBOM for SOFTWARE_UPDATE events; bytes32(0) otherwise
     * @return eventIndex      Index of this event in the device history
     */
    function logEvent(
        uint256                tokenId,
        DeviceTypes.EventType  eventType,
        bytes32                documentHash,
        string  calldata       ipfsCID,
        bool                   passedInspection,
        string  calldata       softwareVersion,
        string  calldata       notes,
        bool                   hasCompatibleParts,
        bool                   hasUndocumentedParts,
        bool                   isSeriousIncident,
        bytes32                sbomHash
    ) external returns (uint256 eventIndex) {
        DeviceTypes.DeviceIdentity memory device = passportNFT.getDevice(tokenId);
        if (device.decommissioned) revert DeviceIsDecommissioned(tokenId);
        bytes32 credentialId = credentialRegistry.getCredentialId(msg.sender);
        return _logEvent(
            tokenId, eventType, documentHash, ipfsCID, passedInspection,
            softwareVersion, notes, hasCompatibleParts, hasUndocumentedParts,
            isSeriousIncident, sbomHash, credentialId
        );
    }

    /**
     * @notice Record multiple lifecycle events in a single atomic transaction.
     * @dev Device state and credential ID are fetched once for the entire batch.
     *      Any single failure reverts all events. Each event still enforces its
     *      own role permission and document validation rules.
     *
     * @param tokenId  Device passport token ID (shared across all events)
     * @param events   Ordered array of event parameters; min 1, max 10
     */
    function batchLog(
        uint256 tokenId,
        BatchEventParams[] calldata events
    ) external {
        uint256 count = events.length;
        if (count == 0 || count > 10) revert BatchSizeOutOfBounds(count);

        // Pre-fetch once — device check and credential lookup are shared
        // across all events, avoiding N redundant external calls.
        DeviceTypes.DeviceIdentity memory device = passportNFT.getDevice(tokenId);
        if (device.decommissioned) revert DeviceIsDecommissioned(tokenId);

        bytes32 credentialId = credentialRegistry.getCredentialId(msg.sender);

        for (uint256 i = 0; i < count; i++) {
            BatchEventParams calldata p = events[i];
            _logEvent(
                tokenId,
                p.eventType,
                p.documentHash,
                p.ipfsCID,
                p.passedInspection,
                p.softwareVersion,
                p.notes,
                p.hasCompatibleParts,
                p.hasUndocumentedParts,
                p.isSeriousIncident,
                p.sbomHash,
                credentialId
            );
        }

        emit BatchLogged(tokenId, count, block.timestamp);
    }

    // ============================================================
    //  INTERNAL
    // ============================================================

    function _logEvent(
        uint256                tokenId,
        DeviceTypes.EventType  eventType,
        bytes32                documentHash,
        string  calldata       ipfsCID,
        bool                   passedInspection,
        string  calldata       softwareVersion,
        string  calldata       notes,
        bool                   hasCompatibleParts,
        bool                   hasUndocumentedParts,
        bool                   isSeriousIncident,
        bytes32                sbomHash,
        bytes32                credentialId
    ) internal returns (uint256 eventIndex) {
        roleManager.requireEventPermission(msg.sender, eventType);

        if (documentHash == bytes32(0)) revert DocumentHashRequired();
        if (bytes(ipfsCID).length == 0) revert IPFSCIDRequired();

        DeviceTypes.ServiceEvent memory newEvent = DeviceTypes.ServiceEvent({
            tokenId:              tokenId,
            eventType:            eventType,
            timestamp:            block.timestamp,
            blockNumber:          block.number,
            reportedBy:           msg.sender,
            credentialId:         credentialId,
            documentHash:         documentHash,
            ipfsCID:              ipfsCID,
            passedInspection:     passedInspection,
            softwareVersion:      softwareVersion,
            notes:                notes,
            hasCompatibleParts:   hasCompatibleParts,
            hasUndocumentedParts: hasUndocumentedParts,
            isSeriousIncident:    isSeriousIncident,
            sbomHash:             sbomHash
        });

        _history[tokenId].push(newEvent);
        eventIndex = _history[tokenId].length - 1;

        passportNFT.incrementEventCount(tokenId);

        emit ServiceEventLogged(
            tokenId,
            eventIndex,
            eventType,
            msg.sender,
            documentHash,
            block.timestamp
        );
    }

    // ============================================================
    //  VIEW FUNCTIONS
    // ============================================================

    /**
     * @notice Get the complete service history for a device.
     * @param tokenId The device passport token to query
     */
    function getHistory(uint256 tokenId)
        external view
        returns (DeviceTypes.ServiceEvent[] memory)
    {
        return _history[tokenId];
    }

    /**
     * @notice Get a single event by token ID and index.
     * @param tokenId The device passport token to query
     * @param index   The index of the event in the history array
     */
    function getEvent(uint256 tokenId, uint256 index)
        external view
        returns (DeviceTypes.ServiceEvent memory)
    {
        if (index >= _history[tokenId].length)
            revert EventIndexOutOfBounds(tokenId, index);
        return _history[tokenId][index];
    }

    /**
     * @notice Get the total number of events for a device.
     * @param tokenId The device passport token to query
     */
    function getEventCount(uint256 tokenId)
        external view
        returns (uint256)
    {
        return _history[tokenId].length;
    }

    /**
     * @notice Verify a document hash matches the on-chain record.
     * @dev Used to verify that an IPFS document has not been tampered with.
     *      If the document is modified, its keccak256 hash changes
     *      and will no longer match the on-chain record.
     *
     * @param tokenId      The device passport token
     * @param index        The event index to verify against
     * @param documentHash The hash to verify
     * @return True if the hash matches the on-chain record
     */
    function verifyDocument(
        uint256 tokenId,
        uint256 index,
        bytes32 documentHash
    ) external view returns (bool) {
        if (index >= _history[tokenId].length)
            revert EventIndexOutOfBounds(tokenId, index);
        return _history[tokenId][index].documentHash == documentHash;
    }

    /**
     * @notice Get all events of a specific type for a device.
     * @dev Useful for filtering calibration history or PM records.
     * @param tokenId   The device passport token to query
     * @param eventType The event type to filter by
     */
    function getEventsByType(
        uint256 tokenId,
        DeviceTypes.EventType eventType
    ) external view returns (DeviceTypes.ServiceEvent[] memory filtered) {
        DeviceTypes.ServiceEvent[] storage history = _history[tokenId];
        uint256 count;

        for (uint256 i = 0; i < history.length; i++) {
            if (history[i].eventType == eventType) count++;
        }

        filtered = new DeviceTypes.ServiceEvent[](count);
        uint256 idx;
        for (uint256 i = 0; i < history.length; i++) {
            if (history[i].eventType == eventType) {
                filtered[idx++] = history[i];
            }
        }
    }
}
