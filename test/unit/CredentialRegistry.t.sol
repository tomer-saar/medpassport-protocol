// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {CredentialRegistry} from "../../src/access/CredentialRegistry.sol";
import {DeviceTypes} from "../../src/types/DeviceTypes.sol";

/**
 * @title CredentialRegistryTest
 * @notice Tests every rule defined in ADR-001 — Credential States
 *         and Role Matrix.
 *
 *         Test categories:
 *         1. Granting credentials
 *         2. State transitions — ACTIVE to each state
 *         3. Terminal states — REVOKED and MIGRATED cannot change
 *         4. Migration — authorship preservation
 *         5. Permission abuse — unauthorized actors rejected
 *         6. View functions — correct data returned
 */
contract CredentialRegistryTest is Test {

    CredentialRegistry public registry;

    // Test addresses
    address public governance  = makeAddr("governance");
    address public manufacturer = makeAddr("manufacturer");
    address public serviceOrg  = makeAddr("serviceOrg");
    address public certifier   = makeAddr("certifier");
    address public regulator   = makeAddr("regulator");
    address public stranger    = makeAddr("stranger");
    address public successor   = makeAddr("successor");

    // ============================================================
    //  SETUP — runs before every test
    // ============================================================

    function setUp() public {
        registry = new CredentialRegistry(governance);
    }

    // ============================================================
    //  HELPER — grant a credential in one line
    // ============================================================

    function _grantManufacturer(address wallet)
        internal returns (bytes32)
    {
        vm.prank(governance);
        return registry.grantCredential(
            wallet,
            DeviceTypes.ActorRole.MANUFACTURER,
            "Test Manufacturer GmbH",
            "ISO-MFR-001"
        );
    }

    function _grantServiceOrg(address wallet)
        internal returns (bytes32)
    {
        vm.prank(governance);
        return registry.grantCredential(
            wallet,
            DeviceTypes.ActorRole.CERTIFIED_SERVICE_ORG,
            "Test Service Org Ltd",
            "ISO-SVC-001"
        );
    }

    // ============================================================
    //  1. GRANTING CREDENTIALS
    // ============================================================

    function test_GrantCredential_Success() public {
        bytes32 credId = _grantManufacturer(manufacturer);

        assertTrue(registry.isActive(manufacturer));
        assertEq(
            uint(registry.getRole(manufacturer)),
            uint(DeviceTypes.ActorRole.MANUFACTURER)
        );
        assertFalse(credId == bytes32(0));
    }

    function test_GrantCredential_EmitsEvent() public {
        vm.prank(governance);
        vm.expectEmit(false, true, false, false);
        emit CredentialRegistry.CredentialGranted(
            bytes32(0),
            manufacturer,
            DeviceTypes.ActorRole.MANUFACTURER,
            "Test Manufacturer GmbH",
            block.timestamp
        );
        registry.grantCredential(
            manufacturer,
            DeviceTypes.ActorRole.MANUFACTURER,
            "Test Manufacturer GmbH",
            "ISO-MFR-001"
        );
    }

    function test_GrantCredential_OnlyGovernance() public {
        vm.prank(stranger);
        vm.expectRevert(CredentialRegistry.NotGovernance.selector);
        registry.grantCredential(
            manufacturer,
            DeviceTypes.ActorRole.MANUFACTURER,
            "Test Manufacturer GmbH",
            "ISO-MFR-001"
        );
    }

    function test_GrantCredential_RejectsDoubleGrant() public {
        _grantManufacturer(manufacturer);

        vm.prank(governance);
        vm.expectRevert(
            abi.encodeWithSelector(
                CredentialRegistry.WalletAlreadyCredentialed.selector,
                manufacturer
            )
        );
        registry.grantCredential(
            manufacturer,
            DeviceTypes.ActorRole.MANUFACTURER,
            "Duplicate",
            "DUP-001"
        );
    }

    function test_GrantCredential_IncreasesCount() public {
        assertEq(registry.credentialCount(), 0);
        _grantManufacturer(manufacturer);
        assertEq(registry.credentialCount(), 1);
        _grantServiceOrg(serviceOrg);
        assertEq(registry.credentialCount(), 2);
    }

    // ============================================================
    //  2. STATE TRANSITIONS
    // ============================================================

    function test_Revoke_ActiveCredential() public {
        bytes32 credId = _grantManufacturer(manufacturer);

        vm.prank(governance);
        registry.revokeCredential(credId, "Bad actor detected");

        assertFalse(registry.isActive(manufacturer));
        assertEq(
            uint(registry.getCredentialState(credId)),
            uint(DeviceTypes.CredentialState.REVOKED)
        );
    }

    function test_Inactivate_ActiveCredential() public {
        bytes32 credId = _grantManufacturer(manufacturer);

        vm.prank(governance);
        registry.inactivateCredential(credId, "Pending review");

        assertFalse(registry.isActive(manufacturer));
        assertEq(
            uint(registry.getCredentialState(credId)),
            uint(DeviceTypes.CredentialState.INACTIVE)
        );
    }

    function test_Reactivate_InactiveCredential() public {
        bytes32 credId = _grantManufacturer(manufacturer);

        vm.prank(governance);
        registry.inactivateCredential(credId, "Pending review");

        vm.prank(governance);
        registry.reactivateCredential(credId);

        assertTrue(registry.isActive(manufacturer));
        assertEq(
            uint(registry.getCredentialState(credId)),
            uint(DeviceTypes.CredentialState.ACTIVE)
        );
    }

    function test_Reactivate_Fails_OnActiveCredential() public {
        bytes32 credId = _grantManufacturer(manufacturer);

        vm.prank(governance);
        vm.expectRevert("Only INACTIVE credentials can be reactivated");
        registry.reactivateCredential(credId);
    }

    // ============================================================
    //  3. TERMINAL STATES
    // ============================================================

    function test_Revoked_CannotBeRevoked_Again() public {
        bytes32 credId = _grantManufacturer(manufacturer);

        vm.prank(governance);
        registry.revokeCredential(credId, "First revocation");

        vm.prank(governance);
        vm.expectRevert(
            abi.encodeWithSelector(
                CredentialRegistry.TerminalState.selector,
                credId
            )
        );
        registry.revokeCredential(credId, "Second revocation");
    }

    function test_Revoked_CannotBeInactivated() public {
        bytes32 credId = _grantManufacturer(manufacturer);

        vm.prank(governance);
        registry.revokeCredential(credId, "Revoked");

        vm.prank(governance);
        vm.expectRevert(
            abi.encodeWithSelector(
                CredentialRegistry.TerminalState.selector,
                credId
            )
        );
        registry.inactivateCredential(credId, "Attempt to inactivate");
    }

    function test_Revoked_CannotBeReactivated() public {
        bytes32 credId = _grantManufacturer(manufacturer);

        vm.prank(governance);
        registry.revokeCredential(credId, "Revoked");

        vm.prank(governance);
        vm.expectRevert("Only INACTIVE credentials can be reactivated");
        registry.reactivateCredential(credId);
    }

    // ============================================================
    //  4. MIGRATION
    // ============================================================

    function test_Migration_Success() public {
        bytes32 originalId = _grantManufacturer(manufacturer);

        vm.prank(governance);
        bytes32 successorId = registry.migrateCredential(
            originalId,
            successor,
            "Successor Corp",
            "ISO-SUCC-001",
            "ACQ-REF-2026"
        );

        // Original is MIGRATED
        assertEq(
            uint(registry.getCredentialState(originalId)),
            uint(DeviceTypes.CredentialState.MIGRATED)
        );

        // Original is no longer active
        assertFalse(registry.isActive(manufacturer));

        // Successor is ACTIVE
        assertTrue(registry.isActive(successor));

        // Successor has same role as original
        assertEq(
            uint(registry.getRole(successor)),
            uint(DeviceTypes.ActorRole.MANUFACTURER)
        );

        // Original points to successor
        DeviceTypes.Credential memory originalCred =
            registry.getCredentialById(originalId);
        assertEq(originalCred.successorId, successorId);
    }

    function test_Migration_PreservesOriginalAuthorship() public {
        bytes32 originalId = _grantManufacturer(manufacturer);

        vm.prank(governance);
        registry.migrateCredential(
            originalId,
            successor,
            "Successor Corp",
            "ISO-SUCC-001",
            "ACQ-REF-2026"
        );

        // Original credential record still shows original wallet
        DeviceTypes.Credential memory cred =
            registry.getCredentialById(originalId);
        assertEq(cred.wallet, manufacturer);
        assertEq(cred.organizationName, "Test Manufacturer GmbH");
    }

    function test_Migration_FailsIfSuccessorAlreadyActive() public {
        bytes32 originalId = _grantManufacturer(manufacturer);
        _grantServiceOrg(successor);

        vm.prank(governance);
        vm.expectRevert(
            abi.encodeWithSelector(
                CredentialRegistry.SuccessorAlreadyCredentialed.selector,
                successor
            )
        );
        registry.migrateCredential(
            originalId,
            successor,
            "Successor Corp",
            "ISO-SUCC-001",
            "ACQ-REF-2026"
        );
    }

    function test_Migrated_IsTerminal() public {
        bytes32 originalId = _grantManufacturer(manufacturer);

        vm.prank(governance);
        registry.migrateCredential(
            originalId,
            successor,
            "Successor Corp",
            "ISO-SUCC-001",
            "ACQ-REF-2026"
        );

        vm.prank(governance);
        vm.expectRevert(
            abi.encodeWithSelector(
                CredentialRegistry.TerminalState.selector,
                originalId
            )
        );
        registry.revokeCredential(originalId, "Attempt after migration");
    }

    // ============================================================
    //  5. PERMISSION ABUSE
    // ============================================================

    function test_Stranger_CannotGrantCredential() public {
        vm.prank(stranger);
        vm.expectRevert(CredentialRegistry.NotGovernance.selector);
        registry.grantCredential(
            manufacturer,
            DeviceTypes.ActorRole.MANUFACTURER,
            "Fake Org",
            "FAKE-001"
        );
    }

    function test_Stranger_CannotRevokeCredential() public {
        bytes32 credId = _grantManufacturer(manufacturer);

        vm.prank(stranger);
        vm.expectRevert(CredentialRegistry.NotGovernance.selector);
        registry.revokeCredential(credId, "Unauthorized revocation");
    }

    function test_WalletWithNoCredential_IsNotActive() public view {
        assertFalse(registry.isActive(stranger));
    }

    // ============================================================
    //  6. VIEW FUNCTIONS
    // ============================================================

    function test_GetCredentialByWallet() public {
        _grantManufacturer(manufacturer);

        DeviceTypes.Credential memory cred =
            registry.getCredentialByWallet(manufacturer);

        assertEq(cred.wallet, manufacturer);
        assertEq(cred.organizationName, "Test Manufacturer GmbH");
        assertEq(
            uint(cred.role),
            uint(DeviceTypes.ActorRole.MANUFACTURER)
        );
        assertEq(
            uint(cred.state),
            uint(DeviceTypes.CredentialState.ACTIVE)
        );
    }

    function test_GetCredentialState_ReturnsCorrectState() public {
        bytes32 credId = _grantManufacturer(manufacturer);

        assertEq(
            uint(registry.getCredentialState(credId)),
            uint(DeviceTypes.CredentialState.ACTIVE)
        );
    }

    function test_GetCredentialId_ReturnsCorrectId() public {
        bytes32 credId = _grantManufacturer(manufacturer);
        assertEq(registry.getCredentialId(manufacturer), credId);
    }
}