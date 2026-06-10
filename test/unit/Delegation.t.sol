// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {CredentialRegistry} from "../../src/access/CredentialRegistry.sol";
import {DeviceTypes} from "../../src/types/DeviceTypes.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title DelegationTest
 * @notice Tests EIP-712 DelegationToken signing and verification on
 *         CredentialRegistry.
 *
 *         Test categories:
 *         1. Signature verification
 *         2. Scope hash anchoring
 *         3. Nonce replay prevention
 *         4. Token expiry enforcement
 */
contract DelegationTest is Test {

    CredentialRegistry public registry;

    address public governance;

    address public orgWallet;
    uint256 public orgKey;

    address public strangerWallet;
    uint256 public strangerKey;

    bytes32 public orgId;

    uint256 internal constant CHAIN_ID = 80002;

    // ============================================================
    //  SETUP
    // ============================================================

    function setUp() public {
        vm.chainId(CHAIN_ID);

        governance = makeAddr("governance");
        (orgWallet, orgKey) = makeAddrAndKey("org");
        (strangerWallet, strangerKey) = makeAddrAndKey("stranger");

        registry = new CredentialRegistry(governance);

        vm.prank(governance);
        orgId = registry.grantCredential(
            orgWallet,
            DeviceTypes.ActorRole.CERTIFIED_SERVICE_ORG,
            "Test Service Org Ltd",
            "ISO-SVC-001"
        );
    }

    // ============================================================
    //  HELPERS
    // ============================================================

    function _baseToken() internal view returns (DeviceTypes.DelegationToken memory token) {
        bytes32[] memory udiScopes = new bytes32[](2);
        udiScopes[0] = keccak256("UDI-DEVICE-001");
        udiScopes[1] = keccak256("UDI-DEVICE-002");

        uint8[] memory eventTypes = new uint8[](2);
        eventTypes[0] = uint8(DeviceTypes.EventType.PREVENTIVE_MAINTENANCE);
        eventTypes[1] = uint8(DeviceTypes.EventType.CALIBRATION);

        token = DeviceTypes.DelegationToken({
            orgId:          orgId,
            technicianId:   keccak256("TECH-0001"),
            udiScopes:      udiScopes,
            eventTypes:     eventTypes,
            credentialTier: 1,
            issuedAt:       block.timestamp,
            expiresAt:      block.timestamp + 1 days,
            nonce:          keccak256("NONCE-0001")
        });
    }

    function _sign(DeviceTypes.DelegationToken memory token, uint256 pk)
        internal view returns (bytes memory signature)
    {
        bytes32 digest = registry.hashDelegationToken(token);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        signature = abi.encodePacked(r, s, v);
    }

    // ============================================================
    //  1. SIGNATURE VERIFICATION
    // ============================================================

    function test_VerifyDelegation_ValidSignature_Succeeds() public {
        DeviceTypes.DelegationToken memory token = _baseToken();
        bytes memory signature = _sign(token, orgKey);

        bytes32 expectedScopeHash = registry.getScopeHash(token);

        bytes32 scopeHash = registry.verifyDelegationToken(token, signature);

        assertEq(scopeHash, expectedScopeHash);
    }

    function test_VerifyDelegation_RevertsOnWrongSigner() public {
        DeviceTypes.DelegationToken memory token = _baseToken();
        bytes memory signature = _sign(token, strangerKey);

        vm.expectRevert(
            abi.encodeWithSelector(
                CredentialRegistry.InvalidDelegationSignature.selector,
                strangerWallet,
                orgWallet
            )
        );
        registry.verifyDelegationToken(token, signature);
    }

    function test_VerifyDelegation_RevertsOnTamperedToken() public {
        DeviceTypes.DelegationToken memory token = _baseToken();
        bytes memory signature = _sign(token, orgKey);

        // Tamper with the signed token after signing — credential tier
        // is bumped, which changes the EIP-712 digest and therefore
        // the recovered signer.
        token.credentialTier = 2;

        address recovered = ECDSA.recover(registry.hashDelegationToken(token), signature);

        vm.expectRevert(
            abi.encodeWithSelector(
                CredentialRegistry.InvalidDelegationSignature.selector,
                recovered,
                orgWallet
            )
        );
        registry.verifyDelegationToken(token, signature);
    }

    function test_VerifyDelegation_RevertsIfOrgCredentialUnknown() public {
        DeviceTypes.DelegationToken memory token = _baseToken();
        token.orgId = keccak256("UNKNOWN-ORG");
        bytes memory signature = _sign(token, orgKey);

        vm.expectRevert(
            abi.encodeWithSelector(
                CredentialRegistry.CredentialNotFound.selector,
                token.orgId
            )
        );
        registry.verifyDelegationToken(token, signature);
    }

    function test_VerifyDelegation_RevertsIfOrgCredentialRevoked() public {
        DeviceTypes.DelegationToken memory token = _baseToken();
        bytes memory signature = _sign(token, orgKey);

        vm.prank(governance);
        registry.revokeCredential(orgId, "Bad actor detected");

        vm.expectRevert(
            abi.encodeWithSelector(
                CredentialRegistry.DelegatingCredentialNotActive.selector,
                orgId
            )
        );
        registry.verifyDelegationToken(token, signature);
    }

    // ============================================================
    //  2. SCOPE HASH ANCHORING
    // ============================================================

    function test_ScopeHash_MatchesAbiEncodeOfToken() public view {
        DeviceTypes.DelegationToken memory token = _baseToken();
        assertEq(registry.getScopeHash(token), keccak256(abi.encode(token)));
    }

    function test_ScopeHash_ChangesWithUdiScopes() public view {
        DeviceTypes.DelegationToken memory token = _baseToken();
        bytes32 originalHash = registry.getScopeHash(token);

        token.udiScopes[0] = keccak256("UDI-DEVICE-999");

        assertTrue(registry.getScopeHash(token) != originalHash);
    }

    function test_ScopeHash_ChangesWithEventTypes() public view {
        DeviceTypes.DelegationToken memory token = _baseToken();
        bytes32 originalHash = registry.getScopeHash(token);

        token.eventTypes[0] = uint8(DeviceTypes.EventType.INSPECTION);

        assertTrue(registry.getScopeHash(token) != originalHash);
    }

    function test_ScopeHash_ChangesWithCredentialTier() public view {
        DeviceTypes.DelegationToken memory token = _baseToken();
        bytes32 originalHash = registry.getScopeHash(token);

        token.credentialTier = 2;

        assertTrue(registry.getScopeHash(token) != originalHash);
    }

    function test_VerifyDelegation_EmitsAnchorEventWithScopeHash() public {
        DeviceTypes.DelegationToken memory token = _baseToken();
        bytes memory signature = _sign(token, orgKey);

        bytes32 expectedScopeHash = registry.getScopeHash(token);

        vm.expectEmit(true, true, true, true);
        emit CredentialRegistry.DelegationVerified(
            expectedScopeHash,
            token.orgId,
            token.technicianId,
            token.nonce,
            block.timestamp
        );

        registry.verifyDelegationToken(token, signature);
    }

    // ============================================================
    //  3. NONCE REPLAY PREVENTION
    // ============================================================

    function test_Nonce_StartsUnused() public view {
        DeviceTypes.DelegationToken memory token = _baseToken();
        assertFalse(registry.isDelegationNonceUsed(token.nonce));
    }

    function test_Nonce_MarkedUsedAfterVerification() public {
        DeviceTypes.DelegationToken memory token = _baseToken();
        bytes memory signature = _sign(token, orgKey);

        registry.verifyDelegationToken(token, signature);

        assertTrue(registry.isDelegationNonceUsed(token.nonce));
    }

    function test_VerifyDelegation_RevertsOnNonceReplay() public {
        DeviceTypes.DelegationToken memory token = _baseToken();
        bytes memory signature = _sign(token, orgKey);

        registry.verifyDelegationToken(token, signature);

        vm.expectRevert(
            abi.encodeWithSelector(
                CredentialRegistry.NonceAlreadyUsed.selector,
                token.nonce
            )
        );
        registry.verifyDelegationToken(token, signature);
    }

    function test_VerifyDelegation_DifferentNonces_BothSucceed() public {
        DeviceTypes.DelegationToken memory token1 = _baseToken();
        registry.verifyDelegationToken(token1, _sign(token1, orgKey));

        DeviceTypes.DelegationToken memory token2 = _baseToken();
        token2.nonce = keccak256("NONCE-0002");
        registry.verifyDelegationToken(token2, _sign(token2, orgKey));

        assertTrue(registry.isDelegationNonceUsed(token1.nonce));
        assertTrue(registry.isDelegationNonceUsed(token2.nonce));
    }

    // ============================================================
    //  4. TOKEN EXPIRY ENFORCEMENT
    // ============================================================

    function test_VerifyDelegation_RevertsIfExpired() public {
        DeviceTypes.DelegationToken memory token = _baseToken();
        token.issuedAt = block.timestamp;
        token.expiresAt = block.timestamp + 1 hours;
        bytes memory signature = _sign(token, orgKey);

        vm.warp(block.timestamp + 2 hours);

        vm.expectRevert(
            abi.encodeWithSelector(
                CredentialRegistry.DelegationExpired.selector,
                token.expiresAt,
                block.timestamp
            )
        );
        registry.verifyDelegationToken(token, signature);
    }

    function test_VerifyDelegation_RevertsIfNotYetValid() public {
        DeviceTypes.DelegationToken memory token = _baseToken();
        token.issuedAt = block.timestamp + 1 hours;
        token.expiresAt = block.timestamp + 1 days;
        bytes memory signature = _sign(token, orgKey);

        vm.expectRevert(
            abi.encodeWithSelector(
                CredentialRegistry.DelegationNotYetValid.selector,
                token.issuedAt,
                block.timestamp
            )
        );
        registry.verifyDelegationToken(token, signature);
    }

    function test_VerifyDelegation_SucceedsAtExactExpiry() public {
        DeviceTypes.DelegationToken memory token = _baseToken();
        token.issuedAt = block.timestamp;
        token.expiresAt = block.timestamp + 1 hours;
        bytes memory signature = _sign(token, orgKey);

        vm.warp(token.expiresAt);

        bytes32 scopeHash = registry.verifyDelegationToken(token, signature);
        assertEq(scopeHash, registry.getScopeHash(token));
    }

    function test_VerifyDelegation_SucceedsAtExactIssuedAt() public {
        DeviceTypes.DelegationToken memory token = _baseToken();
        token.issuedAt = block.timestamp;
        token.expiresAt = block.timestamp + 1 hours;
        bytes memory signature = _sign(token, orgKey);

        bytes32 scopeHash = registry.verifyDelegationToken(token, signature);
        assertEq(scopeHash, registry.getScopeHash(token));
    }

    // ============================================================
    //  5. EIP-712 DOMAIN
    // ============================================================

    function test_DomainSeparator_IsNonZeroAndStable() public view {
        bytes32 domainSeparator = registry.domainSeparatorV4();
        assertTrue(domainSeparator != bytes32(0));
        assertEq(domainSeparator, registry.domainSeparatorV4());
    }

    function test_HashDelegationToken_DiffersFromScopeHash() public view {
        DeviceTypes.DelegationToken memory token = _baseToken();
        assertTrue(
            registry.hashDelegationToken(token) != registry.getScopeHash(token)
        );
    }
}
