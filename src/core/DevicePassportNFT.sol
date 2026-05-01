// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {DeviceTypes} from "../types/DeviceTypes.sol";
import {CredentialRegistry} from "../access/CredentialRegistry.sol";
import {RoleManager} from "../access/RoleManager.sol";

/**
 * @title DevicePassportNFT
 * @author Tomer Saar, PMP
 * @notice The core identity contract of the MedPassport Protocol.
 *         Every medical device registered on MedPassport receives
 *         a unique ERC-721 token — its Digital Product Passport.
 *
 *         One token per physical device. The token ID is permanently
 *         tied to the device's Unique Device Identifier (UDI).
 *         Duplicate UDI registration is rejected at the contract level.
 *
 *         The passport records:
 *         - Device identity — manufacturer, model, UDI, class
 *         - Ownership history — every transfer timestamped
 *         - Recall and decommission status
 *         - Reference to the off-chain DPP JSON document via IPFS
 *
 * @dev Regulatory alignment:
 *      ISO 13485:2016 §7.5.8 — Identification and traceability
 *      EU MDR 2017/745 Art. 27 — Unique Device Identification
 *      FDA 21 CFR Part 820.60 — Identification
 *      FDA 21 CFR Part 820.65 — Traceability
 */
contract DevicePassportNFT is ERC721 {

    // ============================================================
    //  STATE VARIABLES
    // ============================================================

    /// @notice Reference to the CredentialRegistry
    CredentialRegistry public immutable credentialRegistry;

    /// @notice Reference to the RoleManager
    RoleManager public immutable roleManager;

    /// @notice Total number of device passports minted
    uint256 public totalDevices;

    /// @dev UDI hash => token ID — prevents duplicate registration
    mapping(bytes32 => uint256) private _udiToTokenId;

    /// @dev token ID => device identity
    mapping(uint256 => DeviceTypes.DeviceIdentity) private _devices;

    /// @dev token ID => IPFS metadata URI
    mapping(uint256 => string) private _metadataURIs;

    // ============================================================
    //  EVENTS
    // ============================================================

    event DeviceMinted(
        uint256 indexed tokenId,
        string  udi,
        address indexed manufacturer,
        DeviceTypes.DeviceClass deviceClass,
        uint256 timestamp
    );

    event RecallActivated(
        uint256 indexed tokenId,
        address indexed regulator,
        uint256 timestamp
    );

    event RecallCleared(
        uint256 indexed tokenId,
        address indexed regulator,
        uint256 timestamp
    );

    event DeviceDecommissioned(
        uint256 indexed tokenId,
        address indexed initiator,
        uint256 timestamp
    );

    event MetadataUpdated(
        uint256 indexed tokenId,
        string  newURI,
        uint256 timestamp
    );

    // ============================================================
    //  ERRORS
    // ============================================================

    error UDIAlreadyRegistered(string udi);
    error TokenDoesNotExist(uint256 tokenId);
    error DeviceAlreadyDecommissioned(uint256 tokenId);
    error RecallAlreadyActive(uint256 tokenId);
    error RecallNotActive(uint256 tokenId);
    error NotDeviceOwner(address caller, uint256 tokenId);
    error DeviceIsDecommissioned(uint256 tokenId);
    error DeviceHasActiveRecall(uint256 tokenId);

    // ============================================================
    //  CONSTRUCTOR
    // ============================================================

    constructor(
        address _credentialRegistry,
        address _roleManager
    ) ERC721("MedPassport Device", "MEDDEV") {
        require(
            _credentialRegistry != address(0),
            "CredentialRegistry cannot be zero address"
        );
        require(
            _roleManager != address(0),
            "RoleManager cannot be zero address"
        );
        credentialRegistry = CredentialRegistry(_credentialRegistry);
        roleManager        = RoleManager(_roleManager);
    }

    // ============================================================
    //  CORE FUNCTIONS
    // ============================================================

    /**
     * @notice Mint a new Device Passport for a manufactured device.
     * @dev Only callable by addresses with MANUFACTURER role.
     *      Each UDI can only be registered once — globally unique.
     *      The token ID is auto-incremented starting from 1.
     *
     * @param to          Recipient address — typically manufacturer wallet
     * @param udi         Full Unique Device Identifier string
     * @param deviceClass Regulatory device classification
     * @param model       Manufacturer model or catalog number
     * @param metadataURI IPFS URI pointing to full DPP JSON document
     * @return tokenId    The newly minted token ID
     */
    function mintDevicePassport(
        address to,
        string  calldata udi,
        DeviceTypes.DeviceClass deviceClass,
        string  calldata model,
        string  calldata metadataURI,
        bool    simulatedDevice
    ) external returns (uint256 tokenId) {
        // Check caller has MANUFACTURER role and active credential
        roleManager.requireManufacturer(msg.sender);

        // Check UDI is not already registered
        bytes32 udiHash = keccak256(bytes(udi));
        if (_udiToTokenId[udiHash] != 0)
            revert UDIAlreadyRegistered(udi);

        require(to != address(0), "Recipient cannot be zero address");
        require(bytes(udi).length > 0, "UDI cannot be empty");
        if (!simulatedDevice) {
            require(_isValidGS1UDI(udi), "UDI must follow GS1 format");
        }
        require(bytes(model).length > 0, "Model cannot be empty");

        // Mint the token
        totalDevices++;
        tokenId = totalDevices;
        _safeMint(to, tokenId);

        // Store device identity
        _devices[tokenId] = DeviceTypes.DeviceIdentity({
            udi:               udi,
            deviceIdentifier:  udi,
            basicUdiDi:        "",
            gudidRef:          "",
            eudamedRef:        "",
            deviceClass:       deviceClass,
            model:             model,
            manufacturerWallet: msg.sender,
            manufactureDate:   block.timestamp,
            metadataURI:       metadataURI,
            recallActive:      false,
            decommissioned:    false,
            lastServiceBlock:  0,
            eventCount:        0
        });

        _udiToTokenId[udiHash] = tokenId;
        _metadataURIs[tokenId] = metadataURI;

        emit DeviceMinted(
            tokenId,
            udi,
            msg.sender,
            deviceClass,
            block.timestamp
        );
    }

    /**
     * @notice Activate a recall flag on a device.
     * @dev Only callable by REGULATOR role.
     *      Recall activation should trigger certification revocation
     *      in the CertificationSBT contract — handled off-chain
     *      in v1 via event monitoring.
     *
     * @param tokenId The device passport token to flag
     */
    function activateRecall(uint256 tokenId) external {
        roleManager.requireRegulator(msg.sender);
        _requireExists(tokenId);

        if (_devices[tokenId].recallActive)
            revert RecallAlreadyActive(tokenId);

        _devices[tokenId].recallActive = true;

        emit RecallActivated(tokenId, msg.sender, block.timestamp);
    }

    /**
     * @notice Clear an active recall flag on a device.
     * @dev Only callable by REGULATOR role.
     *
     * @param tokenId The device passport token to clear
     */
    function clearRecall(uint256 tokenId) external {
        roleManager.requireRegulator(msg.sender);
        _requireExists(tokenId);

        if (!_devices[tokenId].recallActive)
            revert RecallNotActive(tokenId);

        _devices[tokenId].recallActive = false;

        emit RecallCleared(tokenId, msg.sender, block.timestamp);
    }

    /**
     * @notice Mark a device as decommissioned.
     * @dev Callable by the current device owner or the manufacturer.
     *      Decommissioned devices are permanently read-only —
     *      no new service events can be logged against them.
     *      Maps to Axiom 2 — append only, but terminal state.
     *
     * @param tokenId The device passport token to decommission
     */
    function decommissionDevice(uint256 tokenId) external {
        _requireExists(tokenId);

        bool isOwner        = ownerOf(tokenId) == msg.sender;
        bool isManufacturer = credentialRegistry.isActive(msg.sender) &&
            credentialRegistry.getRole(msg.sender) ==
            DeviceTypes.ActorRole.MANUFACTURER;

        require(
            isOwner || isManufacturer,
            "Only device owner or manufacturer can decommission"
        );

        if (_devices[tokenId].decommissioned)
            revert DeviceAlreadyDecommissioned(tokenId);

        _devices[tokenId].decommissioned = true;

        emit DeviceDecommissioned(tokenId, msg.sender, block.timestamp);
    }

    /**
     * @notice Update the metadata URI for a device passport.
     * @dev Only callable by the original manufacturer of the device.
     *      Used when the DPP JSON document is revised on IPFS.
     *
     * @param tokenId    The device passport token to update
     * @param newURI     New IPFS URI pointing to revised DPP JSON
     */
    function updateMetadata(
        uint256 tokenId,
        string calldata newURI
    ) external {
        _requireExists(tokenId);
        require(
            _devices[tokenId].manufacturerWallet == msg.sender,
            "Only the original manufacturer can update metadata"
        );
        require(
            !_devices[tokenId].decommissioned,
            "Cannot update metadata on decommissioned device"
        );

        _devices[tokenId].metadataURI = newURI;
        _metadataURIs[tokenId]        = newURI;

        emit MetadataUpdated(tokenId, newURI, block.timestamp);
    }

    /**
     * @notice Increment the event count for a device.
     * @dev Called by ServiceLogRegistry when a new event is logged.
     *      Only callable by contracts — not by EOAs directly.
     *
     * @param tokenId The device passport token to update
     */
    function incrementEventCount(uint256 tokenId) external {
        _requireExists(tokenId);
        _devices[tokenId].eventCount++;
        _devices[tokenId].lastServiceBlock = block.number;
    }

    // ============================================================
    //  VIEW FUNCTIONS
    // ============================================================

    /**
     * @notice Get the full device identity for a token.
     * @param tokenId The device passport token to query
     */
    function getDevice(uint256 tokenId)
        external view
        returns (DeviceTypes.DeviceIdentity memory)
    {
        _requireExists(tokenId);
        return _devices[tokenId];
    }

    /**
     * @notice Look up a token ID by UDI string.
     * @param udi The Unique Device Identifier to look up
     * @return tokenId The token ID — 0 if not registered
     */
    function getTokenIdByUDI(string calldata udi)
        external view
        returns (uint256)
    {
        return _udiToTokenId[keccak256(bytes(udi))];
    }

    /**
     * @notice Check if a device is safe to operate.
     * @dev Returns false if device has active recall or is decommissioned.
     * @param tokenId The device passport token to check
     */
    function isOperational(uint256 tokenId)
        external view
        returns (bool)
    {
        if (!_exists(tokenId)) return false;
        DeviceTypes.DeviceIdentity storage d = _devices[tokenId];
        return !d.recallActive && !d.decommissioned;
    }

    /**
     * @notice Get the metadata URI for a device passport.
     * @param tokenId The device passport token to query
     */
    function tokenURI(uint256 tokenId)
        public view
        override
        returns (string memory)
    {
        _requireExists(tokenId);
        return _metadataURIs[tokenId];
    }

    // ============================================================
    //  INTERNAL HELPERS
    // ============================================================

    function _requireExists(uint256 tokenId) internal view {
        if (!_exists(tokenId))
            revert TokenDoesNotExist(tokenId);
    }
function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @notice Validates that a UDI string follows GS1 format.
     * @dev GS1 UDI-DI must be a 14-digit GTIN.
     *      The UDI string must be non-empty and at least 14
     *      characters long to contain a valid GTIN component.
     *      Full GS1 check digit validation is performed on
     *      the first 14 characters.
     *
     *      Format accepted:
     *      - 14-digit GTIN only: "00844588003288"
     *      - GTIN with UDI-PI:   "00844588003288/LOT2026-001/SN00432"
     *      - AI-encoded format:  "(01)00844588003288..."
     *
     * @param udi The UDI string to validate
     * @return True if the UDI passes GS1 format validation
     */
    function _isValidGS1UDI(string calldata udi)
        internal pure returns (bool)
    {
        bytes memory b = bytes(udi);

        // Must be at least 14 characters to contain a GTIN
        if (b.length < 14) return false;

        // Find the start of the 14-digit GTIN
        // Handle AI-encoded format: "(01)XXXXXXXXXXXXXX"
        uint256 start = 0;
        if (b.length >= 4 &&
            b[0] == '(' && b[1] == '0' &&
            b[2] == '1' && b[3] == ')') {
            start = 4;
            if (b.length < start + 14) return false;
        }

        // Extract and validate 14 GTIN digits
        uint256[14] memory digits;
        for (uint256 i = 0; i < 14; i++) {
            uint8 c = uint8(b[start + i]);
            if (c < 48 || c > 57) return false; // not a digit
            digits[i] = c - 48;
        }

        // GS1 check digit validation — Luhn-style algorithm
        // Multiply alternating digits by 3 and 1 from right
        uint256 sum = 0;
        for (uint256 i = 0; i < 13; i++) {
            // positions 0,2,4,6,8,10,12 multiplied by 3
            // positions 1,3,5,7,9,11   multiplied by 1
            if (i % 2 == 0) {
                sum += digits[i] * 3;
            } else {
                sum += digits[i];
            }
        }

        uint256 checkDigit = (10 - (sum % 10)) % 10;
        return checkDigit == digits[13];
    }
}
