// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DeviceTypes} from "../types/DeviceTypes.sol";

/**
 * @title CredentialRegistry
 * @author Tomer Saar, PMP
 * @notice Tracks every credentialed actor in the MedPassport network
 *         and enforces credential state transitions.
 *
 *         Every organization that writes to MedPassport holds exactly
 *         one credential record. The state of that credential determines
 *         whether the actor can write to the protocol.
 *
 *         Four states exist: ACTIVE, REVOKED, INACTIVE, MIGRATED.
 *         State transitions are governed by the protocol multisig.
 *         Revocation and migration are terminal — they cannot be undone.
 *
 * @dev Maps to ADR-001 — Credential States and Role Matrix
 *      Axiom 3: Original authorship is preserved permanently
 *      ISO 13485:2016 §4.2.4 — Control of records
 */
contract CredentialRegistry {

    using DeviceTypes for DeviceTypes.Credential;

    // ============================================================
    //  STATE VARIABLES
    // ============================================================

    /// @notice The governance multisig address
    /// Only this address can grant, revoke, and migrate credentials
    address public governance;

    /// @notice Total number of credentials ever granted
    uint256 public credentialCount;

    /// @dev credentialId => Credential record
    mapping(bytes32 => DeviceTypes.Credential) private _credentials;

    /// @dev wallet address => credentialId
    /// One wallet can only hold one active credential at a time
    mapping(address => bytes32) private _walletToCredential;

    /// @dev credentialId => exists flag
    mapping(bytes32 => bool) private _credentialExists;

    // ============================================================
    //  EVENTS
    //  Every state change emits an event — permanent on-chain record
    // ============================================================

    event CredentialGranted(
        bytes32 indexed credentialId,
        address indexed wallet,
        DeviceTypes.ActorRole role,
        string organizationName,
        uint256 timestamp
    );

    event CredentialRevoked(
        bytes32 indexed credentialId,
        address indexed wallet,
        string reason,
        uint256 timestamp
    );

    event CredentialInactivated(
        bytes32 indexed credentialId,
        address indexed wallet,
        string reason,
        uint256 timestamp
    );

    event CredentialReactivated(
        bytes32 indexed credentialId,
        address indexed wallet,
        uint256 timestamp
    );

    event CredentialMigrated(
        bytes32 indexed originalCredentialId,
        bytes32 indexed successorCredentialId,
        address indexed originalWallet,
        address successorWallet,
        string migrationRef,
        uint256 timestamp
    );

    // ============================================================
    //  ERRORS
    //  Custom errors are cheaper than string reverts in Solidity
    // ============================================================

    error NotGovernance();
    error CredentialNotFound(bytes32 credentialId);
    error CredentialAlreadyExists(address wallet);
    error InvalidStateTransition(
        DeviceTypes.CredentialState current,
        DeviceTypes.CredentialState attempted
    );
    error TerminalState(bytes32 credentialId);
    error WalletAlreadyCredentialed(address wallet);
    error SuccessorAlreadyCredentialed(address successor);

    // ============================================================
    //  MODIFIERS
    // ============================================================

    modifier onlyGovernance() {
        if (msg.sender != governance) revert NotGovernance();
        _;
    }

    modifier credentialMustExist(bytes32 credentialId) {
        if (!_credentialExists[credentialId])
            revert CredentialNotFound(credentialId);
        _;
    }

    modifier notTerminal(bytes32 credentialId) {
        DeviceTypes.CredentialState state =
            _credentials[credentialId].state;
        if (
            state == DeviceTypes.CredentialState.REVOKED ||
            state == DeviceTypes.CredentialState.MIGRATED
        ) revert TerminalState(credentialId);
        _;
    }

    // ============================================================
    //  CONSTRUCTOR
    // ============================================================

    /**
     * @param _governance The governance multisig address.
     *        This is the only address that can manage credentials.
     *        In production this should be a Gnosis Safe multisig.
     */
    constructor(address _governance) {
        require(_governance != address(0), "Governance cannot be zero address");
        governance = _governance;
    }

    // ============================================================
    //  CREDENTIAL MANAGEMENT
    // ============================================================

    /**
     * @notice Grant a new credential to an organization.
     * @dev Only callable by governance.
     *      One wallet can only hold one credential at a time.
     *      The credentialId is derived from the wallet and timestamp
     *      to ensure uniqueness.
     *
     * @param wallet          The wallet address of the organization
     * @param role            The role being granted
     * @param organizationName Legal name of the organization
     * @param accreditationRef External accreditation reference number
     */
    function grantCredential(
        address wallet,
        DeviceTypes.ActorRole role,
        string calldata organizationName,
        string calldata accreditationRef
    ) external onlyGovernance returns (bytes32 credentialId) {
        if (_walletToCredential[wallet] != bytes32(0)) {
            bytes32 existingId = _walletToCredential[wallet];
            if (_credentials[existingId].state ==
                DeviceTypes.CredentialState.ACTIVE) {
                revert WalletAlreadyCredentialed(wallet);
            }
        }

        // Generate unique credential ID from wallet and timestamp
        credentialId = keccak256(
            abi.encodePacked(wallet, block.timestamp, credentialCount)
        );

        _credentials[credentialId] = DeviceTypes.Credential({
            credentialId:     credentialId,
            wallet:           wallet,
            role:             role,
            state:            DeviceTypes.CredentialState.ACTIVE,
            organizationName: organizationName,
            accreditationRef: accreditationRef,
            grantedAt:        block.timestamp,
            updatedAt:        block.timestamp,
            grantedBy:        msg.sender,
            successorId:      bytes32(0)
        });

        _walletToCredential[wallet] = credentialId;
        _credentialExists[credentialId] = true;
        credentialCount++;

        emit CredentialGranted(
            credentialId,
            wallet,
            role,
            organizationName,
            block.timestamp
        );
    }

    /**
     * @notice Revoke a credential immediately.
     * @dev Revocation is terminal — it cannot be undone.
     *      The credential moves to REVOKED state permanently.
     *      Historical records written by this credential are
     *      preserved but flagged with REVOKED status.
     *      Maps to ADR-001 state transition rules.
     *
     * @param credentialId The credential to revoke
     * @param reason       Plain language reason for revocation
     */
    function revokeCredential(
        bytes32 credentialId,
        string calldata reason
    )
        external
        onlyGovernance
        credentialMustExist(credentialId)
        notTerminal(credentialId)
    {
        DeviceTypes.Credential storage cred = _credentials[credentialId];
        cred.state     = DeviceTypes.CredentialState.REVOKED;
        cred.updatedAt = block.timestamp;

        emit CredentialRevoked(
            credentialId,
            cred.wallet,
            reason,
            block.timestamp
        );
    }

    /**
     * @notice Set a credential to INACTIVE — suspended pending review.
     * @dev INACTIVE credentials cannot write but may be reactivated.
     *      This is not a terminal state — unlike REVOKED.
     *
     * @param credentialId The credential to inactivate
     * @param reason       Plain language reason for suspension
     */
    function inactivateCredential(
        bytes32 credentialId,
        string calldata reason
    )
        external
        onlyGovernance
        credentialMustExist(credentialId)
        notTerminal(credentialId)
    {
        DeviceTypes.Credential storage cred = _credentials[credentialId];
        require(
            cred.state == DeviceTypes.CredentialState.ACTIVE,
            "Only ACTIVE credentials can be inactivated"
        );
        cred.state     = DeviceTypes.CredentialState.INACTIVE;
        cred.updatedAt = block.timestamp;

        emit CredentialInactivated(
            credentialId,
            cred.wallet,
            reason,
            block.timestamp
        );
    }

    /**
     * @notice Reactivate an INACTIVE credential after review clears.
     * @dev Only INACTIVE credentials can be reactivated.
     *      REVOKED and MIGRATED are terminal — they cannot be reactivated.
     *
     * @param credentialId The credential to reactivate
     */
    function reactivateCredential(
        bytes32 credentialId
    )
        external
        onlyGovernance
        credentialMustExist(credentialId)
    {
        DeviceTypes.Credential storage cred = _credentials[credentialId];
        require(
            cred.state == DeviceTypes.CredentialState.INACTIVE,
            "Only INACTIVE credentials can be reactivated"
        );
        cred.state     = DeviceTypes.CredentialState.ACTIVE;
        cred.updatedAt = block.timestamp;

        emit CredentialReactivated(
            credentialId,
            cred.wallet,
            block.timestamp
        );
    }

    /**
     * @notice Migrate a credential to a successor entity.
     * @dev Used for legitimate succession — acquisition, carve-out,
     *      approved contract transfer. Migration is terminal for the
     *      original credential. The successor receives a new credential.
     *      Original authorship on all historical records is preserved.
     *      Maps to Decision 2 and ADR-001 migration rules.
     *
     * @param originalCredentialId  The credential being migrated
     * @param successorWallet       Wallet address of the successor entity
     * @param successorOrgName      Legal name of the successor organization
     * @param successorAccredRef    Accreditation reference of the successor
     * @param migrationRef          External migration approval reference
     */
    function migrateCredential(
        bytes32 originalCredentialId,
        address successorWallet,
        string calldata successorOrgName,
        string calldata successorAccredRef,
        string calldata migrationRef
    )
        external
        onlyGovernance
        credentialMustExist(originalCredentialId)
        notTerminal(originalCredentialId)
        returns (bytes32 successorCredentialId)
    {
        if (_walletToCredential[successorWallet] != bytes32(0)) {
            bytes32 existingId = _walletToCredential[successorWallet];
            if (_credentials[existingId].state ==
                DeviceTypes.CredentialState.ACTIVE) {
                revert SuccessorAlreadyCredentialed(successorWallet);
            }
        }

        DeviceTypes.Credential storage original =
            _credentials[originalCredentialId];

        // Grant new credential to successor with same role
        successorCredentialId = keccak256(
            abi.encodePacked(
                successorWallet,
                block.timestamp,
                credentialCount
            )
        );

        _credentials[successorCredentialId] = DeviceTypes.Credential({
            credentialId:     successorCredentialId,
            wallet:           successorWallet,
            role:             original.role,
            state:            DeviceTypes.CredentialState.ACTIVE,
            organizationName: successorOrgName,
            accreditationRef: successorAccredRef,
            grantedAt:        block.timestamp,
            updatedAt:        block.timestamp,
            grantedBy:        msg.sender,
            successorId:      bytes32(0)
        });

        _walletToCredential[successorWallet] = successorCredentialId;
        _credentialExists[successorCredentialId] = true;
        credentialCount++;

        // Mark original as MIGRATED — terminal state
        original.state       = DeviceTypes.CredentialState.MIGRATED;
        original.successorId = successorCredentialId;
        original.updatedAt   = block.timestamp;

        emit CredentialMigrated(
            originalCredentialId,
            successorCredentialId,
            original.wallet,
            successorWallet,
            migrationRef,
            block.timestamp
        );
    }

    // ============================================================
    //  VIEW FUNCTIONS — read-only, no gas cost for external callers
    // ============================================================

    /**
     * @notice Check if a wallet address holds an active credential.
     * @dev This is the primary check used by all write-path contracts.
     *      Any contract that accepts writes must call this first.
     *
     * @param wallet The wallet address to check
     * @return True if the wallet holds an ACTIVE credential
     */
    function isActive(address wallet) external view returns (bool) {
        bytes32 credId = _walletToCredential[wallet];
        if (credId == bytes32(0)) return false;
        return _credentials[credId].state ==
            DeviceTypes.CredentialState.ACTIVE;
    }

    /**
     * @notice Get the role of a credentialed actor.
     * @param wallet The wallet address to query
     * @return The ActorRole of the wallet
     */
    function getRole(address wallet)
        external view
        returns (DeviceTypes.ActorRole)
    {
        bytes32 credId = _walletToCredential[wallet];
        require(credId != bytes32(0), "Wallet has no credential");
        return _credentials[credId].role;
    }

    /**
     * @notice Get the full credential record for a wallet.
     * @param wallet The wallet address to query
     * @return The full Credential struct
     */
    function getCredentialByWallet(address wallet)
        external view
        returns (DeviceTypes.Credential memory)
    {
        bytes32 credId = _walletToCredential[wallet];
        require(credId != bytes32(0), "Wallet has no credential");
        return _credentials[credId];
    }

    /**
     * @notice Get a credential record by its ID.
     * @param credentialId The credential ID to query
     * @return The full Credential struct
     */
    function getCredentialById(bytes32 credentialId)
        external view
        credentialMustExist(credentialId)
        returns (DeviceTypes.Credential memory)
    {
        return _credentials[credentialId];
    }

    /**
     * @notice Get the credential ID for a wallet address.
     * @param wallet The wallet address to query
     * @return The credential ID
     */
    function getCredentialId(address wallet)
        external view
        returns (bytes32)
    {
        return _walletToCredential[wallet];
    }

    /**
     * @notice Get the current state of a credential.
     * @param credentialId The credential ID to query
     * @return The current CredentialState
     */
    function getCredentialState(bytes32 credentialId)
        external view
        credentialMustExist(credentialId)
        returns (DeviceTypes.CredentialState)
    {
        return _credentials[credentialId].state;
    }
}