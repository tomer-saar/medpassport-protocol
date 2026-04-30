// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DeviceTypes} from "../types/DeviceTypes.sol";
import {CredentialRegistry} from "../access/CredentialRegistry.sol";
import {RoleManager} from "../access/RoleManager.sol";
import {DevicePassportNFT} from "./DevicePassportNFT.sol";

/**
 * @title TransferManager
 * @author Tomer Saar, PMP
 * @notice Manages dual-signature ownership transfer of device passports.
 *
 *         Ownership transfer is a high-risk event — it changes who is
 *         legally responsible for a medical device. Two independent
 *         credentialed actors must sign before the transfer is final.
 *
 *         The flow has two steps:
 *         1. Current owner proposes the transfer — first signature
 *         2. New owner confirms the transfer — second signature
 *         3. Transfer is written on-chain only after both sign
 *
 *         A 72-hour expiry window applies to all pending transfers.
 *         If the confirmer does not sign within 72 hours, the
 *         proposal expires and must be reinitiated.
 *
 *         Failure conditions — transfer is rejected if:
 *         - Proposer credential is not ACTIVE
 *         - Confirmer credential is not ACTIVE
 *         - Confirmer is the same address as proposer
 *         - Confirmer is not the declared new owner
 *         - Device has an active recall flag
 *         - Device is decommissioned
 *         - Transfer window has expired
 *
 * @dev Maps to Axiom 5 in ADR-000 — high-risk dual-signature
 *      SEQUENCE-DIAGRAMS.md — Diagram 1: Ownership Transfer
 *      ISO 13485:2016 §7.5.10 — Customer property
 */
contract TransferManager {

    // ============================================================
    //  CONSTANTS
    // ============================================================

    /// @notice Transfer proposal expiry — 72 hours in seconds
    uint256 public constant EXPIRY_WINDOW = 72 hours;

    // ============================================================
    //  STATE VARIABLES
    // ============================================================

    /// @notice Reference to the CredentialRegistry
    CredentialRegistry public immutable credentialRegistry;

    /// @notice Reference to the RoleManager
    RoleManager public immutable roleManager;

    /// @notice Reference to the DevicePassportNFT
    DevicePassportNFT public immutable passportNFT;

    /// @dev proposalId => PendingAction
    mapping(bytes32 => DeviceTypes.PendingAction) private _proposals;

    /// @dev proposalId => exists
    mapping(bytes32 => bool) private _proposalExists;

    /// @dev tokenId => active proposalId
    /// Only one active proposal per device at a time
    mapping(uint256 => bytes32) private _activeProposal;

    /// @notice Total proposals ever created
    uint256 public proposalCount;

    // ============================================================
    //  EVENTS
    // ============================================================

    event TransferProposed(
        bytes32 indexed proposalId,
        uint256 indexed tokenId,
        address indexed proposer,
        address confirmer,
        uint256 expiresAt,
        uint256 timestamp
    );

    event TransferConfirmed(
        bytes32 indexed proposalId,
        uint256 indexed tokenId,
        address indexed newOwner,
        uint256 timestamp
    );

    event TransferCancelled(
        bytes32 indexed proposalId,
        uint256 indexed tokenId,
        address cancelledBy,
        string  reason,
        uint256 timestamp
    );

    event TransferExpired(
        bytes32 indexed proposalId,
        uint256 indexed tokenId,
        uint256 timestamp
    );

    // ============================================================
    //  ERRORS
    // ============================================================

    error NotDeviceOwner(address caller, uint256 tokenId);
    error DeviceHasActiveRecall(uint256 tokenId);
    error DeviceIsDecommissioned(uint256 tokenId);
    error ActiveProposalExists(uint256 tokenId, bytes32 proposalId);
    error ProposalNotFound(bytes32 proposalId);
    error ProposalExpired(bytes32 proposalId);
    error ProposalAlreadyConfirmed(bytes32 proposalId);
    error ProposalAlreadyCancelled(bytes32 proposalId);
    error ConfirmerMustBeDifferentFromProposer();
    error ConfirmerMustBeNewOwner(address caller, address expectedConfirmer);
    error NotProposer(address caller);

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
    //  STEP 1 — PROPOSE TRANSFER
    // ============================================================

    /**
     * @notice Propose an ownership transfer — first signature.
     * @dev Caller must be the current NFT owner with an active credential.
     *      Device must not have an active recall or be decommissioned.
     *      Only one active proposal per device at a time.
     *      The proposal expires after 72 hours if not confirmed.
     *
     * @param tokenId      The device passport token to transfer
     * @param newOwner     The address of the intended new owner
     * @param documentHash Hash of the transfer agreement document
     * @return proposalId  The unique ID of this transfer proposal
     */
    function proposeTransfer(
        uint256 tokenId,
        address newOwner,
        bytes32 documentHash
    ) external returns (bytes32 proposalId) {

        // Check caller is the current device owner
        if (passportNFT.ownerOf(tokenId) != msg.sender)
            revert NotDeviceOwner(msg.sender, tokenId);

        // Check caller has active credential
        roleManager.requireActive(msg.sender);

        // Check device is operational
        DeviceTypes.DeviceIdentity memory device =
            passportNFT.getDevice(tokenId);

        if (device.recallActive)
            revert DeviceHasActiveRecall(tokenId);
        if (device.decommissioned)
            revert DeviceIsDecommissioned(tokenId);

        // Check no active proposal exists for this device
        bytes32 existingProposal = _activeProposal[tokenId];
        if (existingProposal != bytes32(0)) {
            // Check if existing proposal has expired
            if (!_isExpired(existingProposal)) {
                revert ActiveProposalExists(tokenId, existingProposal);
            }
            // Expired — emit expiry event and clear it
            emit TransferExpired(
                existingProposal,
                tokenId,
                block.timestamp
            );
            _proposals[existingProposal].cancelled = true;
        }

        require(newOwner != address(0), "New owner cannot be zero address");
        require(newOwner != msg.sender, "Cannot transfer to yourself");
        require(documentHash != bytes32(0), "Document hash required");

        // Generate unique proposal ID
        proposalId = keccak256(
            abi.encodePacked(
                tokenId,
                msg.sender,
                newOwner,
                block.timestamp,
                proposalCount
            )
        );

        uint256 expiresAt = block.timestamp + EXPIRY_WINDOW;

        _proposals[proposalId] = DeviceTypes.PendingAction({
            actionId:     proposalId,
            tokenId:      tokenId,
            proposer:     msg.sender,
            confirmer:    newOwner,
            documentHash: documentHash,
            proposedAt:   block.timestamp,
            expiresAt:    expiresAt,
            confirmed:    false,
            cancelled:    false
        });

        _proposalExists[proposalId] = true;
        _activeProposal[tokenId]    = proposalId;
        proposalCount++;

        emit TransferProposed(
            proposalId,
            tokenId,
            msg.sender,
            newOwner,
            expiresAt,
            block.timestamp
        );
    }

    // ============================================================
    //  STEP 2 — CONFIRM TRANSFER
    // ============================================================

    /**
     * @notice Confirm a transfer proposal — second signature.
     * @dev Caller must be the declared new owner (confirmer).
     *      Caller must have an active credential.
     *      Caller must be different from the proposer.
     *      Proposal must not be expired, confirmed, or cancelled.
     *      On success — NFT is transferred to the confirmer.
     *
     * @param proposalId The proposal ID to confirm
     */
    function confirmTransfer(bytes32 proposalId) external {

        if (!_proposalExists[proposalId])
            revert ProposalNotFound(proposalId);

        DeviceTypes.PendingAction storage proposal =
            _proposals[proposalId];

        // Check proposal state
        if (proposal.confirmed)
            revert ProposalAlreadyConfirmed(proposalId);
        if (proposal.cancelled)
            revert ProposalAlreadyCancelled(proposalId);
        if (_isExpired(proposalId)) {
            proposal.cancelled = true;
            _activeProposal[proposal.tokenId] = bytes32(0);
            emit TransferExpired(
                proposalId,
                proposal.tokenId,
                block.timestamp
            );
            revert ProposalExpired(proposalId);
        }

        // Check confirmer is the declared new owner
        if (msg.sender != proposal.confirmer)
            revert ConfirmerMustBeNewOwner(msg.sender, proposal.confirmer);

        // Check confirmer is not the proposer — Axiom 5
        if (msg.sender == proposal.proposer)
            revert ConfirmerMustBeDifferentFromProposer();

        // Check confirmer has active credential
        roleManager.requireActive(msg.sender);

        // Mark as confirmed
        proposal.confirmed = true;
        _activeProposal[proposal.tokenId] = bytes32(0);

        // Execute the NFT transfer
        // The current owner (proposer) must have approved this contract
        // to transfer the token — handled via ERC721 approve flow
        passportNFT.safeTransferFrom(
            proposal.proposer,
            proposal.confirmer,
            proposal.tokenId
        );

        emit TransferConfirmed(
            proposalId,
            proposal.tokenId,
            proposal.confirmer,
            block.timestamp
        );
    }

    // ============================================================
    //  CANCEL TRANSFER
    // ============================================================

    /**
     * @notice Cancel a pending transfer proposal.
     * @dev Only the original proposer can cancel.
     *      Cannot cancel an already confirmed or cancelled proposal.
     *
     * @param proposalId The proposal to cancel
     * @param reason     Plain language reason for cancellation
     */
    function cancelTransfer(
        bytes32 proposalId,
        string calldata reason
    ) external {
        if (!_proposalExists[proposalId])
            revert ProposalNotFound(proposalId);

        DeviceTypes.PendingAction storage proposal =
            _proposals[proposalId];

        if (proposal.confirmed)
            revert ProposalAlreadyConfirmed(proposalId);
        if (proposal.cancelled)
            revert ProposalAlreadyCancelled(proposalId);
        if (msg.sender != proposal.proposer)
            revert NotProposer(msg.sender);

        proposal.cancelled = true;
        _activeProposal[proposal.tokenId] = bytes32(0);

        emit TransferCancelled(
            proposalId,
            proposal.tokenId,
            msg.sender,
            reason,
            block.timestamp
        );
    }

    // ============================================================
    //  VIEW FUNCTIONS
    // ============================================================

    /**
     * @notice Get the details of a transfer proposal.
     * @param proposalId The proposal to query
     */
    function getProposal(bytes32 proposalId)
        external view
        returns (DeviceTypes.PendingAction memory)
    {
        if (!_proposalExists[proposalId])
            revert ProposalNotFound(proposalId);
        return _proposals[proposalId];
    }

    /**
     * @notice Get the active proposal ID for a device token.
     * @param tokenId The device passport token to query
     * @return The active proposal ID — bytes32(0) if none
     */
    function getActiveProposal(uint256 tokenId)
        external view
        returns (bytes32)
    {
        return _activeProposal[tokenId];
    }

    /**
     * @notice Check if a proposal is still within its expiry window.
     * @param proposalId The proposal to check
     * @return True if the proposal has NOT expired
     */
    function isProposalValid(bytes32 proposalId)
        external view
        returns (bool)
    {
        if (!_proposalExists[proposalId]) return false;
        DeviceTypes.PendingAction storage p = _proposals[proposalId];
        return !p.confirmed && !p.cancelled && !_isExpired(proposalId);
    }

    // ============================================================
    //  INTERNAL HELPERS
    // ============================================================

    function _isExpired(bytes32 proposalId)
        internal view
        returns (bool)
    {
        return block.timestamp > _proposals[proposalId].expiresAt;
    }
}