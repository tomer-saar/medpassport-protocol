// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DeviceTypes} from "../types/DeviceTypes.sol";
import {CredentialRegistry} from "./CredentialRegistry.sol";

/**
 * @title MigrationGovernance
 * @author Tomer Saar, PMP
 * @notice Manages the multisig approval process for credential
 *         migration — the governed succession mechanism for M&A,
 *         carve-outs, and approved contract transfers.
 *
 *         Migration is the only path by which a MIGRATED credential
 *         produces a successor. It requires a minimum threshold of
 *         governance signatories to approve before execution.
 *
 *         Key guarantees:
 *         - Original authorship on all historical records is preserved
 *         - Migration is permanent and auditable on-chain
 *         - No single signatory can approve a migration unilaterally
 *         - Successor receives a fresh credential with the same role
 *
 * @dev Maps to Decision 2 and ADR-001 migration rules
 *      Axiom 3: Original authorship is preserved permanently
 */
contract MigrationGovernance {

    // ============================================================
    //  STATE VARIABLES
    // ============================================================

    /// @notice Reference to the CredentialRegistry
    CredentialRegistry public immutable credentialRegistry;

    /// @notice Minimum number of signatories required to approve
    ///         a migration proposal. Default is 3 of 5.
    uint256 public requiredApprovals;

    /// @notice Total number of registered governance signatories
    uint256 public signatoryCount;

    /// @dev address => is registered signatory
    mapping(address => bool) public isSignatory;

    /// @dev proposalId => MigrationProposal
    mapping(bytes32 => MigrationProposal) public proposals;

    /// @dev proposalId => signatory => has approved
    mapping(bytes32 => mapping(address => bool)) public hasApproved;

    /// @dev proposalId => exists
    mapping(bytes32 => bool) public proposalExists;

    /// @notice Total proposals ever created
    uint256 public proposalCount;

    // ============================================================
    //  STRUCTS
    // ============================================================

    /**
     * @notice A migration proposal waiting for multisig approval.
     *         Created by a signatory, approved by the required
     *         threshold, then executed to trigger the migration.
     */
    struct MigrationProposal {
        bytes32  proposalId;           // Unique proposal identifier
        bytes32  originalCredentialId; // Credential being migrated
        address  successorWallet;      // Wallet of the successor entity
        string   successorOrgName;     // Legal name of successor
        string   successorAccredRef;   // Accreditation ref of successor
        string   migrationRef;         // External approval reference
        address  proposedBy;           // Signatory who created proposal
        uint256  proposedAt;           // Timestamp of proposal creation
        uint256  approvalCount;        // Number of approvals received
        bool     executed;             // True once migration is complete
        bool     cancelled;            // True if proposal was cancelled
    }

    // ============================================================
    //  EVENTS
    // ============================================================

    event SignatoryAdded(address indexed signatory, uint256 timestamp);

    event SignatoryRemoved(address indexed signatory, uint256 timestamp);

    event MigrationProposed(
        bytes32 indexed proposalId,
        bytes32 indexed originalCredentialId,
        address indexed successorWallet,
        address proposedBy,
        uint256 timestamp
    );

    event MigrationApproved(
        bytes32 indexed proposalId,
        address indexed approvedBy,
        uint256 approvalCount,
        uint256 timestamp
    );

    event MigrationExecuted(
        bytes32 indexed proposalId,
        bytes32 indexed originalCredentialId,
        bytes32 indexed successorCredentialId,
        uint256 timestamp
    );

    event MigrationCancelled(
        bytes32 indexed proposalId,
        address cancelledBy,
        uint256 timestamp
    );

    // ============================================================
    //  ERRORS
    // ============================================================

    error NotSignatory(address caller);
    error ProposalNotFound(bytes32 proposalId);
    error AlreadyApproved(bytes32 proposalId, address signatory);
    error AlreadyExecuted(bytes32 proposalId);
    error AlreadyCancelled(bytes32 proposalId);
    error InsufficientApprovals(uint256 required, uint256 actual);
    error NotProposer(address caller);

    // ============================================================
    //  MODIFIERS
    // ============================================================

    modifier onlySignatory() {
        if (!isSignatory[msg.sender]) revert NotSignatory(msg.sender);
        _;
    }

    modifier proposalMustExist(bytes32 proposalId) {
        if (!proposalExists[proposalId])
            revert ProposalNotFound(proposalId);
        _;
    }

    modifier notExecuted(bytes32 proposalId) {
        if (proposals[proposalId].executed)
            revert AlreadyExecuted(proposalId);
        _;
    }

    modifier notCancelled(bytes32 proposalId) {
        if (proposals[proposalId].cancelled)
            revert AlreadyCancelled(proposalId);
        _;
    }

    // ============================================================
    //  CONSTRUCTOR
    // ============================================================

    /**
     * @param _credentialRegistry Address of the CredentialRegistry
     * @param _signatories        Initial list of governance signatories
     * @param _requiredApprovals  Minimum approvals needed — default 3
     */
    constructor(
        address _credentialRegistry,
        address[] memory _signatories,
        uint256 _requiredApprovals
    ) {
        require(
            _credentialRegistry != address(0),
            "CredentialRegistry cannot be zero address"
        );
        require(
            _signatories.length >= _requiredApprovals,
            "Not enough signatories for required approvals"
        );
        require(
            _requiredApprovals >= 2,
            "Minimum 2 approvals required"
        );

        credentialRegistry = CredentialRegistry(_credentialRegistry);
        requiredApprovals  = _requiredApprovals;

        for (uint256 i = 0; i < _signatories.length; i++) {
            require(
                _signatories[i] != address(0),
                "Signatory cannot be zero address"
            );
            isSignatory[_signatories[i]] = true;
            signatoryCount++;
            emit SignatoryAdded(_signatories[i], block.timestamp);
        }
    }

    // ============================================================
    //  PROPOSAL LIFECYCLE
    // ============================================================

    /**
     * @notice Propose a credential migration for multisig approval.
     * @dev Any signatory can propose. The proposer's approval is
     *      counted automatically at proposal time.
     *
     * @param originalCredentialId  Credential being migrated
     * @param successorWallet       Wallet of the successor entity
     * @param successorOrgName      Legal name of successor organization
     * @param successorAccredRef    Accreditation reference of successor
     * @param migrationRef          External approval document reference
     */
    function proposeMigration(
        bytes32 originalCredentialId,
        address successorWallet,
        string calldata successorOrgName,
        string calldata successorAccredRef,
        string calldata migrationRef
    ) external onlySignatory returns (bytes32 proposalId) {
        require(
            successorWallet != address(0),
            "Successor wallet cannot be zero address"
        );

        proposalId = keccak256(
            abi.encodePacked(
                originalCredentialId,
                successorWallet,
                block.timestamp,
                proposalCount
            )
        );

        proposals[proposalId] = MigrationProposal({
            proposalId:           proposalId,
            originalCredentialId: originalCredentialId,
            successorWallet:      successorWallet,
            successorOrgName:     successorOrgName,
            successorAccredRef:   successorAccredRef,
            migrationRef:         migrationRef,
            proposedBy:           msg.sender,
            proposedAt:           block.timestamp,
            approvalCount:        1,  // Proposer auto-approves
            executed:             false,
            cancelled:            false
        });

        hasApproved[proposalId][msg.sender] = true;
        proposalExists[proposalId] = true;
        proposalCount++;

        emit MigrationProposed(
            proposalId,
            originalCredentialId,
            successorWallet,
            msg.sender,
            block.timestamp
        );

        emit MigrationApproved(
            proposalId,
            msg.sender,
            1,
            block.timestamp
        );
    }

    /**
     * @notice Approve a pending migration proposal.
     * @dev Each signatory can approve only once.
     *      Once the required threshold is reached, the proposal
     *      is ready to execute — but execution is a separate step.
     *
     * @param proposalId The proposal to approve
     */
    function approveMigration(bytes32 proposalId)
        external
        onlySignatory
        proposalMustExist(proposalId)
        notExecuted(proposalId)
        notCancelled(proposalId)
    {
        if (hasApproved[proposalId][msg.sender])
            revert AlreadyApproved(proposalId, msg.sender);

        hasApproved[proposalId][msg.sender] = true;
        proposals[proposalId].approvalCount++;

        emit MigrationApproved(
            proposalId,
            msg.sender,
            proposals[proposalId].approvalCount,
            block.timestamp
        );
    }

    /**
     * @notice Execute an approved migration proposal.
     * @dev Callable by any signatory once the approval threshold
     *      is reached. Triggers the actual credential migration
     *      in the CredentialRegistry.
     *
     *      After execution:
     *      - Original credential is marked MIGRATED — terminal
     *      - Successor receives a new ACTIVE credential
     *      - Original authorship on all historical records preserved
     *      - Migration event permanently recorded on-chain
     *
     * @param proposalId The approved proposal to execute
     */
    function executeMigration(bytes32 proposalId)
        external
        onlySignatory
        proposalMustExist(proposalId)
        notExecuted(proposalId)
        notCancelled(proposalId)
    {
        MigrationProposal storage proposal = proposals[proposalId];

        if (proposal.approvalCount < requiredApprovals)
            revert InsufficientApprovals(
                requiredApprovals,
                proposal.approvalCount
            );

        proposal.executed = true;

        // Execute the migration in CredentialRegistry
        bytes32 successorCredentialId = credentialRegistry.migrateCredential(
            proposal.originalCredentialId,
            proposal.successorWallet,
            proposal.successorOrgName,
            proposal.successorAccredRef,
            proposal.migrationRef
        );

        emit MigrationExecuted(
            proposalId,
            proposal.originalCredentialId,
            successorCredentialId,
            block.timestamp
        );
    }

    /**
     * @notice Cancel a pending migration proposal.
     * @dev Only the original proposer can cancel.
     *      Cannot cancel an already executed proposal.
     *
     * @param proposalId The proposal to cancel
     */
    function cancelMigration(bytes32 proposalId)
        external
        proposalMustExist(proposalId)
        notExecuted(proposalId)
        notCancelled(proposalId)
    {
        if (proposals[proposalId].proposedBy != msg.sender)
            revert NotProposer(msg.sender);

        proposals[proposalId].cancelled = true;

        emit MigrationCancelled(
            proposalId,
            msg.sender,
            block.timestamp
        );
    }

    // ============================================================
    //  VIEW FUNCTIONS
    // ============================================================

    /**
     * @notice Get the full details of a migration proposal.
     * @param proposalId The proposal to query
     */
    function getProposal(bytes32 proposalId)
        external view
        proposalMustExist(proposalId)
        returns (MigrationProposal memory)
    {
        return proposals[proposalId];
    }

    /**
     * @notice Check if a proposal has enough approvals to execute.
     * @param proposalId The proposal to check
     * @return True if approval threshold is met
     */
    function isReadyToExecute(bytes32 proposalId)
        external view
        returns (bool)
    {
        if (!proposalExists[proposalId]) return false;
        MigrationProposal storage p = proposals[proposalId];
        return (
            !p.executed &&
            !p.cancelled &&
            p.approvalCount >= requiredApprovals
        );
    }
}