// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {DeviceTypes} from "../types/DeviceTypes.sol";
import {CredentialRegistry} from "../access/CredentialRegistry.sol";
import {RoleManager} from "../access/RoleManager.sol";
import {ComplianceScorer} from "./ComplianceScorer.sol";
import {DevicePassportNFT} from "../core/DevicePassportNFT.sol";
import {ServiceLogRegistry} from "../core/ServiceLogRegistry.sol";

/**
 * @title CertificationSBT
 * @author Tomer Saar, PMP
 * @notice Issues non-transferable Soulbound Tokens representing
 *         certified device status — the trust stamp that converts
 *         verified service history into a resale price premium.
 *
 *         Certification levels:
 *         GOLD   (score 90-100): 15-20% service agreement discount
 *         SILVER (score 75-89):  Standard market pricing
 *         BRONZE (score 60-74):  Baseline negotiating position
 *
 *         Key properties:
 *         - Non-transferable (Soulbound per ERC-5192)
 *         - Time-limited — default validity 365 days
 *         - Tied to device passport token — not to the owner wallet
 *         - Dual-signature required for issuance (Axiom 5)
 *         - Automatically revocable on recall activation
 *         - Score must meet minimum threshold (60) to certify
 *
 * @dev Implements ERC-5192 minimal soulbound interface
 *      Maps to Axiom 5 in ADR-000
 *      SEQUENCE-DIAGRAMS.md Diagram 2: Certification Issuance
 */
contract CertificationSBT is ERC721 {

    // ============================================================
    //  CONSTANTS
    // ============================================================

    uint256 public constant DEFAULT_VALIDITY_DAYS = 365;
    uint256 public constant CONFIRMATION_WINDOW   = 72 hours;
    uint8   public constant MIN_SCORE             = 60;

    // ============================================================
    //  STATE VARIABLES
    // ============================================================

    CredentialRegistry public immutable credentialRegistry;
    RoleManager        public immutable roleManager;
    ComplianceScorer   public immutable scorer;
    DevicePassportNFT     public immutable passportNFT;
    ServiceLogRegistry    public immutable serviceLog;

    /// @notice Total certifications ever issued
    uint256 public totalCertifications;

    /// @dev cert token ID => Certification record
    mapping(uint256 => DeviceTypes.Certification) private _certifications;

    /// @dev device token ID => active cert token ID (0 = none)
    mapping(uint256 => uint256) public activeCertification;

    /// @dev proposalId => PendingAction (dual-sig)
    mapping(bytes32 => DeviceTypes.PendingAction) private _proposals;

    /// @dev proposalId => exists
    mapping(bytes32 => bool) private _proposalExists;

    /// @dev device token ID => active proposal ID
    mapping(uint256 => bytes32) private _activeProposal;

    /// @notice Total proposals ever created
    uint256 public proposalCount;

    // ============================================================
    //  EVENTS
    // ============================================================

    event CertificationProposed(
        bytes32 indexed proposalId,
        uint256 indexed deviceTokenId,
        address indexed proposer,
        address confirmer,
        uint8   score,
        uint256 expiresAt,
        uint256 timestamp
    );

    event CertificationIssued(
        uint256 indexed certTokenId,
        uint256 indexed deviceTokenId,
        DeviceTypes.CertLevel level,
        uint8   score,
        uint256 validUntil,
        address certifier,
        uint256 timestamp
    );

    event CertificationRevoked(
        uint256 indexed certTokenId,
        uint256 indexed deviceTokenId,
        string  reason,
        address revokedBy,
        uint256 timestamp
    );

    // ============================================================
    //  ERRORS
    // ============================================================

    error ScoreBelowMinimum(uint8 score, uint8 minimum);
    error DeviceHasActiveRecall(uint256 tokenId);
    error DeviceIsDecommissioned(uint256 tokenId);
    error ProposalNotFound(bytes32 proposalId);
    error ProposalExpired(bytes32 proposalId);
    error ProposalAlreadyConfirmed(bytes32 proposalId);
    error ProposalAlreadyCancelled(bytes32 proposalId);
    error ConfirmerMustBeDeviceOwner(address caller, address owner);
    error ConfirmerMustBeDifferentFromProposer();
    error NoCertificationToRevoke(uint256 deviceTokenId);
    error ActiveProposalExists(uint256 deviceTokenId);
    error NotAuthorizedToRevoke();
    error SoulboundCannotTransfer();

    // ============================================================
    //  CONSTRUCTOR
    // ============================================================

    constructor(
        address _credentialRegistry,
        address _roleManager,
        address _scorer,
        address _passportNFT,
        address _serviceLog
    ) ERC721("MedPassport Certification", "MEDCERT") {
        require(_credentialRegistry != address(0), "Invalid registry");
        require(_roleManager != address(0), "Invalid roleManager");
        require(_scorer != address(0), "Invalid scorer");
        require(_passportNFT != address(0), "Invalid passportNFT");
        require(_serviceLog != address(0), "Invalid serviceLog");

        credentialRegistry = CredentialRegistry(_credentialRegistry);
        roleManager        = RoleManager(_roleManager);
        scorer             = ComplianceScorer(_scorer);
        passportNFT        = DevicePassportNFT(_passportNFT);
        serviceLog         = ServiceLogRegistry(_serviceLog);
    }

    // ============================================================
    //  STEP 1 — PROPOSE CERTIFICATION
    // ============================================================

    /**
     * @notice Propose a certification — first signature.
     * @dev Caller must hold CERTIFIER role with active credential.
     *      Score is calculated on-chain from service history.
     *      Score must meet minimum threshold of 60.
     *      Device must have no active recall and not be decommissioned.
     *
     * @param deviceTokenId  The device passport token to certify
     * @param deviceOwner    The current owner — expected second signer
     * @param validityDays   Certification validity in days
     * @param certifierOrg   Name of the certifying organization
     * @param certRef        External certification reference number
     * @param documentHash   Hash of the certification document
     * @return proposalId    The unique proposal ID
     */
    function proposeCertification(
        uint256 deviceTokenId,
        address deviceOwner,
        uint256 validityDays,
        string  calldata certifierOrg,
        string  calldata certRef,
        bytes32 documentHash
    ) external returns (bytes32 proposalId) {

        // Check caller is a certifier
        roleManager.requireCertifier(msg.sender);

        // Check device status
        DeviceTypes.DeviceIdentity memory device =
            passportNFT.getDevice(deviceTokenId);

        if (device.recallActive)
            revert DeviceHasActiveRecall(deviceTokenId);
        if (device.decommissioned)
            revert DeviceIsDecommissioned(deviceTokenId);

        // Calculate score on-chain
        uint256 score = scorer.calculateScoreSimple(deviceTokenId, passportNFT, serviceLog);
        if (score < MIN_SCORE)
            revert ScoreBelowMinimum(uint8(score), MIN_SCORE);

        // Check no active proposal exists
        if (_activeProposal[deviceTokenId] != bytes32(0)) {
            bytes32 existing = _activeProposal[deviceTokenId];
            if (block.timestamp <= _proposals[existing].expiresAt &&
                !_proposals[existing].confirmed &&
                !_proposals[existing].cancelled) {
                revert ActiveProposalExists(deviceTokenId);
            }
        }

        uint256 days_ = validityDays == 0
            ? DEFAULT_VALIDITY_DAYS
            : validityDays;

        proposalId = keccak256(
            abi.encodePacked(
                deviceTokenId,
                msg.sender,
                block.timestamp,
                proposalCount
            )
        );

        uint256 expiresAt = block.timestamp + CONFIRMATION_WINDOW;

        _proposals[proposalId] = DeviceTypes.PendingAction({
            actionId:     proposalId,
            tokenId:      deviceTokenId,
            proposer:     msg.sender,
            confirmer:    deviceOwner,
            documentHash: documentHash,
            proposedAt:   block.timestamp,
            expiresAt:    expiresAt,
            confirmed:    false,
            cancelled:    false
        });

        _proposalExists[proposalId]        = true;
        _activeProposal[deviceTokenId]     = proposalId;
        proposalCount++;

        emit CertificationProposed(
            proposalId,
            deviceTokenId,
            msg.sender,
            deviceOwner,
            uint8(score),
            expiresAt,
            block.timestamp
        );
    }

    // ============================================================
    //  STEP 2 — CONFIRM CERTIFICATION
    // ============================================================

    /**
     * @notice Confirm a certification proposal — second signature.
     * @dev Caller must be the declared device owner (confirmer).
     *      Caller must be different from the proposer.
     *      On success — SBT is minted to the device owner.
     *      Any existing certification for this device is revoked first.
     *
     * @param proposalId The proposal ID to confirm
     */
    function confirmCertification(bytes32 proposalId) external {
        if (!_proposalExists[proposalId])
            revert ProposalNotFound(proposalId);

        DeviceTypes.PendingAction storage proposal =
            _proposals[proposalId];

        if (proposal.confirmed)
            revert ProposalAlreadyConfirmed(proposalId);
        if (proposal.cancelled)
            revert ProposalAlreadyCancelled(proposalId);
        if (block.timestamp > proposal.expiresAt) {
            proposal.cancelled = true;
            _activeProposal[proposal.tokenId] = bytes32(0);
            revert ProposalExpired(proposalId);
        }

        // Confirmer must be device owner
        address currentOwner = passportNFT.ownerOf(proposal.tokenId);
        if (msg.sender != currentOwner)
            revert ConfirmerMustBeDeviceOwner(msg.sender, currentOwner);

        // Confirmer must be different from proposer
        if (msg.sender == proposal.proposer)
            revert ConfirmerMustBeDifferentFromProposer();

        // Confirmer must have active credential
        roleManager.requireActive(msg.sender);

        // Recalculate score at confirmation time
        uint256 score = scorer.calculateScoreSimple(proposal.tokenId, passportNFT, serviceLog);
        if (score < MIN_SCORE)
            revert ScoreBelowMinimum(uint8(score), MIN_SCORE);

        // Revoke any existing certification
        uint256 existingCert = activeCertification[proposal.tokenId];
        if (existingCert != 0 && _exists(existingCert)) {
            _revokeCertification(
                existingCert,
                proposal.tokenId,
                "Superseded by new certification",
                address(this)
            );
        }

        // Determine certification level
        (DeviceTypes.CertLevel level,) = scorer.getCertLevel(score);

        // Mint new certification SBT
        totalCertifications++;
        uint256 certTokenId = totalCertifications;

        uint256 validUntil = block.timestamp +
            (DEFAULT_VALIDITY_DAYS * 1 days);

        _certifications[certTokenId] = DeviceTypes.Certification({
            deviceTokenId:   proposal.tokenId,
            complianceScore: uint8(score > 100 ? 100 : score),
            issuedAt:        block.timestamp,
            validUntil:      validUntil,
            certifierAddress: proposal.proposer,
            certifierCredId:  credentialRegistry.getCredentialId(
                proposal.proposer
            ),
            certifierOrg:    "",
            certificationRef: "",
            level:           level,
            active:          true
        });

        activeCertification[proposal.tokenId] = certTokenId;

        // Mark proposal as confirmed
        proposal.confirmed = true;
        _activeProposal[proposal.tokenId] = bytes32(0);

        // Mint the SBT to device owner
        _safeMint(currentOwner, certTokenId);

        emit CertificationIssued(
            certTokenId,
            proposal.tokenId,
            level,
            uint8(score),
            validUntil,
            proposal.proposer,
            block.timestamp
        );
    }

    // ============================================================
    //  REVOCATION
    // ============================================================

    /**
     * @notice Revoke a certification.
     * @dev Callable by CERTIFIER or REGULATOR role.
     *      Called automatically when a recall is activated.
     *      The SBT is burned — it cannot be transferred anyway.
     *
     * @param deviceTokenId The device passport token
     * @param reason        Plain language reason for revocation
     */
    function revokeCertification(
        uint256 deviceTokenId,
        string calldata reason
    ) external {
        bool isCertifier = roleManager.hasRole(
            msg.sender,
            DeviceTypes.ActorRole.CERTIFIER
        );
        bool isRegulator = roleManager.hasRole(
            msg.sender,
            DeviceTypes.ActorRole.REGULATOR
        );

        if (!isCertifier && !isRegulator)
            revert NotAuthorizedToRevoke();

        uint256 certTokenId = activeCertification[deviceTokenId];
        if (certTokenId == 0 || !_exists(certTokenId))
            revert NoCertificationToRevoke(deviceTokenId);

        _revokeCertification(
            certTokenId,
            deviceTokenId,
            reason,
            msg.sender
        );
    }

    // ============================================================
    //  VIEW FUNCTIONS
    // ============================================================

    /**
     * @notice Get certification status for a device.
     * @param deviceTokenId The device passport token to query
     * @return valid        True if certification is active and not expired
     * @return certTokenId  The active certification token ID
     * @return level        Certification level
     * @return score        Compliance score at time of certification
     * @return validUntil   Expiry timestamp
     */
    function getCertificationStatus(uint256 deviceTokenId)
        external view
        returns (
            bool   valid,
            uint256 certTokenId,
            DeviceTypes.CertLevel level,
            uint8  score,
            uint256 validUntil
        )
    {
        certTokenId = activeCertification[deviceTokenId];
        if (certTokenId == 0 || !_exists(certTokenId)) {
            return (false, 0, DeviceTypes.CertLevel.BRONZE, 0, 0);
        }

        DeviceTypes.Certification storage cert =
            _certifications[certTokenId];

        valid     = cert.active &&
                    block.timestamp <= cert.validUntil;
        level     = cert.level;
        score     = cert.complianceScore;
        validUntil = cert.validUntil;
    }

    /**
     * @notice Get full certification details.
     * @param certTokenId The certification token ID to query
     */
    function getCertification(uint256 certTokenId)
        external view
        returns (DeviceTypes.Certification memory)
    {
        return _certifications[certTokenId];
    }

    // ============================================================
    //  ERC-5192 SOULBOUND — disable all transfers
    // ============================================================

    /**
     * @notice Per ERC-5192 — all tokens are locked (soulbound).
     */
    function locked(uint256) external pure returns (bool) {
        return true;
    }

  function transferFrom(address, address, uint256)
        public pure override
    {
        revert SoulboundCannotTransfer();
    }

    function safeTransferFrom(
        address,
        address,
        uint256,
        bytes memory
    ) public pure override {
        revert SoulboundCannotTransfer();
    }

    // ============================================================
    //  INTERNAL
    // ============================================================

    function _revokeCertification(
        uint256 certTokenId,
        uint256 deviceTokenId,
        string memory reason,
        address revokedBy
    ) internal {
        _certifications[certTokenId].active = false;
        activeCertification[deviceTokenId]  = 0;
        _burn(certTokenId);

        emit CertificationRevoked(
            certTokenId,
            deviceTokenId,
            reason,
            revokedBy,
            block.timestamp
        );
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}