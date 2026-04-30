// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DevicePassportNFT} from "../../src/core/DevicePassportNFT.sol";
import {ServiceLogRegistry} from "../../src/core/ServiceLogRegistry.sol";
import {CorrectionRegistry} from "../../src/core/CorrectionRegistry.sol";
import {TransferManager} from "../../src/core/TransferManager.sol";
import {CredentialRegistry} from "../../src/access/CredentialRegistry.sol";
import {RoleManager} from "../../src/access/RoleManager.sol";
import {DeviceTypes} from "../../src/types/DeviceTypes.sol";

/**
 * @title DevicePassportTest
 * @notice Tests the full Sprint 2 contract stack.
 *
 *         Test categories:
 *         1. Passport minting
 *         2. Recall and decommission
 *         3. Service event logging
 *         4. Correction chain
 *         5. Dual-signature transfer
 *         6. Full lifecycle - end to end
 */
contract DevicePassportTest is Test {

    // ── Contracts ────────────────────────────────────────────────
    CredentialRegistry public registry;
    RoleManager        public roleManager;
    DevicePassportNFT  public passport;
    ServiceLogRegistry public serviceLog;
    CorrectionRegistry public correctionReg;
    TransferManager    public transferMgr;

    // ── Actors ───────────────────────────────────────────────────
    address public governance    = makeAddr("governance");
    address public manufacturer  = makeAddr("manufacturer");
    address public serviceOrg    = makeAddr("serviceOrg");
    address public regulator     = makeAddr("regulator");
    address public hospital      = makeAddr("hospital");
    address public refurbisher   = makeAddr("refurbisher");
    address public stranger      = makeAddr("stranger");

    // ── Test device data ─────────────────────────────────────────
    string  constant UDI         = "00844588003288/LOT2024-001/SN00432";
    string  constant MODEL       = "CardioScan Pro 3000";
    string  constant METADATA    = "ipfs://QmTestHash123456789";
    bytes32 constant DOC_HASH    = keccak256("service_report_v1");
    string  constant IPFS_CID    = "QmServiceReport123456";

    // ============================================================
    //  SETUP
    // ============================================================

    function setUp() public {
        // Deploy contracts
        registry      = new CredentialRegistry(governance);
        roleManager   = new RoleManager(address(registry));
        passport      = new DevicePassportNFT(
            address(registry),
            address(roleManager)
        );
        serviceLog    = new ServiceLogRegistry(
            address(registry),
            address(roleManager),
            address(passport)
        );
        correctionReg = new CorrectionRegistry(
            address(registry),
            address(roleManager),
            address(serviceLog)
        );
        transferMgr   = new TransferManager(
            address(registry),
            address(roleManager),
            address(passport)
        );

        // Grant credentials
        vm.startPrank(governance);
        registry.grantCredential(
            manufacturer,
            DeviceTypes.ActorRole.MANUFACTURER,
            "MedDevice GmbH",
            "ISO-MFR-001"
        );
        registry.grantCredential(
            serviceOrg,
            DeviceTypes.ActorRole.CERTIFIED_SERVICE_ORG,
            "BioService Ltd",
            "ISO-SVC-001"
        );
        registry.grantCredential(
            regulator,
            DeviceTypes.ActorRole.REGULATOR,
            "EU Regulatory Authority",
            "REG-EU-001"
        );
        registry.grantCredential(
            hospital,
            DeviceTypes.ActorRole.DEVICE_OWNER,
            "Mercy General Hospital",
            "HOSP-001"
        );
        registry.grantCredential(
            refurbisher,
            DeviceTypes.ActorRole.DEVICE_OWNER,
            "MedRefurb GmbH",
            "REFURB-001"
        );
        vm.stopPrank();
    }

    // ── Helper: mint a device ────────────────────────────────────

    function _mintDevice() internal returns (uint256 tokenId) {
        vm.prank(manufacturer);
        tokenId = passport.mintDevicePassport(
            manufacturer,
            UDI,
            DeviceTypes.DeviceClass.CLASS_IIB,
            MODEL,
            METADATA
        );
    }

    // ── Helper: log a PM event ───────────────────────────────────

    function _logPM(uint256 tokenId) internal {
        vm.prank(serviceOrg);
        serviceLog.logEvent(
            tokenId,
            DeviceTypes.EventType.PREVENTIVE_MAINTENANCE,
            DOC_HASH,
            IPFS_CID,
            true,
            "",
            "Annual PM completed"
        );
    }

    // ============================================================
    //  1. PASSPORT MINTING
    // ============================================================

    function test_MintPassport_Success() public {
        uint256 tokenId = _mintDevice();

        assertEq(tokenId, 1);
        assertEq(passport.ownerOf(tokenId), manufacturer);
        assertEq(passport.totalDevices(), 1);

        DeviceTypes.DeviceIdentity memory device =
            passport.getDevice(tokenId);

        assertEq(device.udi, UDI);
        assertEq(device.model, MODEL);
        assertFalse(device.recallActive);
        assertFalse(device.decommissioned);
    }

    function test_MintPassport_UDILookup() public {
        uint256 tokenId = _mintDevice();
        assertEq(passport.getTokenIdByUDI(UDI), tokenId);
    }

    function test_MintPassport_RejectsDuplicateUDI() public {
        _mintDevice();

        vm.prank(manufacturer);
        vm.expectRevert(
            abi.encodeWithSelector(
                DevicePassportNFT.UDIAlreadyRegistered.selector,
                UDI
            )
        );
        passport.mintDevicePassport(
            manufacturer,
            UDI,
            DeviceTypes.DeviceClass.CLASS_IIB,
            MODEL,
            METADATA
        );
    }

    function test_MintPassport_OnlyManufacturer() public {
        vm.prank(stranger);
        vm.expectRevert();
        passport.mintDevicePassport(
            stranger,
            UDI,
            DeviceTypes.DeviceClass.CLASS_I,
            MODEL,
            METADATA
        );
    }

    // ============================================================
    //  2. RECALL AND DECOMMISSION
    // ============================================================

    function test_Recall_ActivatedByRegulator() public {
        uint256 tokenId = _mintDevice();

        vm.prank(regulator);
        passport.activateRecall(tokenId);

        DeviceTypes.DeviceIdentity memory device =
            passport.getDevice(tokenId);
        assertTrue(device.recallActive);
        assertFalse(passport.isOperational(tokenId));
    }

    function test_Recall_ClearedByRegulator() public {
        uint256 tokenId = _mintDevice();

        vm.prank(regulator);
        passport.activateRecall(tokenId);

        vm.prank(regulator);
        passport.clearRecall(tokenId);

        assertTrue(passport.isOperational(tokenId));
    }

    function test_Recall_OnlyRegulator() public {
        uint256 tokenId = _mintDevice();

        vm.prank(stranger);
        vm.expectRevert();
        passport.activateRecall(tokenId);
    }

    function test_Decommission_ByOwner() public {
        uint256 tokenId = _mintDevice();

        vm.prank(manufacturer);
        passport.decommissionDevice(tokenId);

        DeviceTypes.DeviceIdentity memory device =
            passport.getDevice(tokenId);
        assertTrue(device.decommissioned);
        assertFalse(passport.isOperational(tokenId));
    }

    function test_Decommission_CannotDecommissionTwice() public {
        uint256 tokenId = _mintDevice();

        vm.prank(manufacturer);
        passport.decommissionDevice(tokenId);

        vm.prank(manufacturer);
        vm.expectRevert(
            abi.encodeWithSelector(
                DevicePassportNFT.DeviceAlreadyDecommissioned.selector,
                tokenId
            )
        );
        passport.decommissionDevice(tokenId);
    }

    // ============================================================
    //  3. SERVICE EVENT LOGGING
    // ============================================================

    function test_LogEvent_PMSuccess() public {
        uint256 tokenId = _mintDevice();
        _logPM(tokenId);

        assertEq(serviceLog.getEventCount(tokenId), 1);

        DeviceTypes.ServiceEvent memory evt =
            serviceLog.getEvent(tokenId, 0);

        assertEq(uint(evt.eventType),
            uint(DeviceTypes.EventType.PREVENTIVE_MAINTENANCE));
        assertEq(evt.reportedBy, serviceOrg);
        assertTrue(evt.passedInspection);
        assertEq(evt.documentHash, DOC_HASH);
    }

    function test_LogEvent_IncreasesPassportEventCount() public {
        uint256 tokenId = _mintDevice();
        _logPM(tokenId);

        DeviceTypes.DeviceIdentity memory device =
            passport.getDevice(tokenId);
        assertEq(device.eventCount, 1);
    }

    function test_LogEvent_SoftwareUpdate_OnlyManufacturer() public {
        uint256 tokenId = _mintDevice();

        vm.prank(serviceOrg);
        vm.expectRevert();
        serviceLog.logEvent(
            tokenId,
            DeviceTypes.EventType.SOFTWARE_UPDATE,
            DOC_HASH,
            IPFS_CID,
            true,
            "v3.2.1",
            "Security patch"
        );
    }

    function test_LogEvent_RejectsDecommissioned() public {
        uint256 tokenId = _mintDevice();

        vm.prank(manufacturer);
        passport.decommissionDevice(tokenId);

        vm.prank(serviceOrg);
        vm.expectRevert(
            abi.encodeWithSelector(
                ServiceLogRegistry.DeviceIsDecommissioned.selector,
                tokenId
            )
        );
        serviceLog.logEvent(
            tokenId,
            DeviceTypes.EventType.PREVENTIVE_MAINTENANCE,
            DOC_HASH,
            IPFS_CID,
            true,
            "",
            "Should be rejected"
        );
    }

    function test_LogEvent_DocumentVerification() public {
        uint256 tokenId = _mintDevice();
        _logPM(tokenId);

        assertTrue(serviceLog.verifyDocument(tokenId, 0, DOC_HASH));
        assertFalse(serviceLog.verifyDocument(
            tokenId, 0,
            keccak256("tampered_document")
        ));
    }

    // ============================================================
    //  4. CORRECTION CHAIN
    // ============================================================

    function test_Correction_AppendSupersedes() public {
        uint256 tokenId = _mintDevice();
        _logPM(tokenId);

        bytes32 correctionHash = keccak256("correction_report");

        vm.prank(serviceOrg);
        correctionReg.appendCorrection(
            tokenId,
            0,
            DOC_HASH,
            DeviceTypes.CorrectionType.SUPERSEDES,
            correctionHash,
            "QmCorrectionCID",
            "Wrong date recorded - corrected to 2026-03-12"
        );

        assertTrue(correctionReg.isSuperseded(DOC_HASH));
        assertFalse(correctionReg.isEventActive(DOC_HASH));
        assertEq(correctionReg.getCorrectionCount(tokenId), 1);
    }

    function test_Correction_OnlyOneSupersedes() public {
        uint256 tokenId = _mintDevice();
        _logPM(tokenId);

        vm.prank(serviceOrg);
        correctionReg.appendCorrection(
            tokenId, 0, DOC_HASH,
            DeviceTypes.CorrectionType.SUPERSEDES,
            keccak256("correction1"), "QmCID1",
            "First correction"
        );

        vm.prank(serviceOrg);
        vm.expectRevert(
            abi.encodeWithSelector(
                CorrectionRegistry.AlreadySuperseded.selector,
                DOC_HASH
            )
        );
        correctionReg.appendCorrection(
            tokenId, 0, DOC_HASH,
            DeviceTypes.CorrectionType.SUPERSEDES,
            keccak256("correction2"), "QmCID2",
            "Second correction - should fail"
        );
    }

    function test_Correction_DisputeDoesNotSupersede() public {
        uint256 tokenId = _mintDevice();
        _logPM(tokenId);

        vm.prank(serviceOrg);
        correctionReg.appendCorrection(
            tokenId, 0, DOC_HASH,
            DeviceTypes.CorrectionType.DISPUTES,
            keccak256("dispute_report"), "QmDisputeCID",
            "Service date disputed by hospital"
        );

        assertTrue(correctionReg.isDisputed(DOC_HASH));
        assertTrue(correctionReg.isEventActive(DOC_HASH));
    }

    // ============================================================
    //  5. DUAL-SIGNATURE TRANSFER
    // ============================================================

    function test_Transfer_FullFlow() public {
        uint256 tokenId = _mintDevice();

        // Manufacturer transfers to hospital
        vm.prank(manufacturer);
        passport.approve(address(transferMgr), tokenId);

        vm.prank(manufacturer);
        bytes32 proposalId = transferMgr.proposeTransfer(
            tokenId,
            hospital,
            keccak256("transfer_agreement")
        );

        // Hospital confirms
        vm.prank(hospital);
        transferMgr.confirmTransfer(proposalId);

        assertEq(passport.ownerOf(tokenId), hospital);
    }

    function test_Transfer_RejectsIfConfirmerIsProposer() public {
        uint256 tokenId = _mintDevice();

        vm.prank(manufacturer);
        passport.approve(address(transferMgr), tokenId);

        vm.prank(manufacturer);
        bytes32 proposalId = transferMgr.proposeTransfer(
            tokenId,
            hospital,
            keccak256("transfer_agreement")
        );

 // Manufacturer tries to confirm own transfer
        vm.prank(manufacturer);
        vm.expectRevert(
            abi.encodeWithSelector(
                TransferManager.ConfirmerMustBeNewOwner.selector,
                manufacturer,
                hospital
            )
        );
        transferMgr.confirmTransfer(proposalId);
    }

    function test_Transfer_RejectsOnActiveRecall() public {
        uint256 tokenId = _mintDevice();

        vm.prank(regulator);
        passport.activateRecall(tokenId);

        vm.prank(manufacturer);
        vm.expectRevert(
            abi.encodeWithSelector(
                TransferManager.DeviceHasActiveRecall.selector,
                tokenId
            )
        );
        transferMgr.proposeTransfer(
            tokenId,
            hospital,
            keccak256("transfer_agreement")
        );
    }

    function test_Transfer_ExpiryWindow() public {
        uint256 tokenId = _mintDevice();

        vm.prank(manufacturer);
        passport.approve(address(transferMgr), tokenId);

        vm.prank(manufacturer);
        bytes32 proposalId = transferMgr.proposeTransfer(
            tokenId,
            hospital,
            keccak256("transfer_agreement")
        );

        // Fast forward 73 hours - past expiry
        vm.warp(block.timestamp + 73 hours);

        vm.prank(hospital);
        vm.expectRevert(
            abi.encodeWithSelector(
                TransferManager.ProposalExpired.selector,
                proposalId
            )
        );
        transferMgr.confirmTransfer(proposalId);
    }

    // ============================================================
    //  6. FULL LIFECYCLE - END TO END
    // ============================================================

    /**
     * @notice Simulates the complete CT scanner pilot workflow:
     *         Manufacture → Hospital sale → PM service → Correction
     *         → Refurbisher sale → Verify history
     */
    function test_FullLifecycle_CTScannerPilot() public {
        // ── Step 1: Manufacturer mints passport ──────────────────
        uint256 tokenId = _mintDevice();
        assertEq(passport.ownerOf(tokenId), manufacturer);
        console.log("Step 1: Device minted. Token ID:", tokenId);

        // ── Step 2: Transfer to hospital ─────────────────────────
        vm.prank(manufacturer);
        passport.approve(address(transferMgr), tokenId);

        vm.prank(manufacturer);
        bytes32 proposal1 = transferMgr.proposeTransfer(
            tokenId,
            hospital,
            keccak256("hospital_purchase_agreement")
        );

        vm.prank(hospital);
        transferMgr.confirmTransfer(proposal1);

        assertEq(passport.ownerOf(tokenId), hospital);
        console.log("Step 2: Device transferred to hospital");

        // ── Step 3: Service org logs PM ──────────────────────────
        _logPM(tokenId);
        assertEq(serviceLog.getEventCount(tokenId), 1);
        console.log("Step 3: PM event logged");

        // ── Step 4: Calibration logged ───────────────────────────
        bytes32 calHash = keccak256("calibration_cert_2026");
        vm.prank(serviceOrg);
        serviceLog.logEvent(
            tokenId,
            DeviceTypes.EventType.CALIBRATION,
            calHash,
            "QmCalibrationCert",
            true,
            "",
            "Annual calibration passed"
        );
        assertEq(serviceLog.getEventCount(tokenId), 2);
        console.log("Step 4: Calibration logged");

        // ── Step 5: Correction on PM event ───────────────────────
        vm.prank(serviceOrg);
        correctionReg.appendCorrection(
            tokenId, 0, DOC_HASH,
            DeviceTypes.CorrectionType.AMENDS,
            keccak256("amended_pm_report"),
            "QmAmendedPM",
            "Technician ID corrected from TECH-001 to TECH-042"
        );
        assertEq(correctionReg.getCorrectionCount(tokenId), 1);
        console.log("Step 5: PM event amended");

        // ── Step 6: Hospital transfers to refurbisher ────────────
        vm.prank(hospital);
        passport.approve(address(transferMgr), tokenId);

        vm.prank(hospital);
        bytes32 proposal2 = transferMgr.proposeTransfer(
            tokenId,
            refurbisher,
            keccak256("refurbisher_purchase_agreement")
        );

        vm.prank(refurbisher);
        transferMgr.confirmTransfer(proposal2);

        assertEq(passport.ownerOf(tokenId), refurbisher);
        console.log("Step 6: Device transferred to refurbisher");

        // ── Step 7: Verify full history survived all transfers ────
        assertEq(serviceLog.getEventCount(tokenId), 2);
        assertEq(correctionReg.getCorrectionCount(tokenId), 1);

        DeviceTypes.DeviceIdentity memory device =
            passport.getDevice(tokenId);
        assertEq(device.eventCount, 2);
        assertFalse(device.recallActive);
        assertFalse(device.decommissioned);

        console.log("Step 7: Full history verified");
        console.log("Service events:", serviceLog.getEventCount(tokenId));
        console.log("Corrections:", correctionReg.getCorrectionCount(tokenId));
        console.log("LIFECYCLE TEST PASSED");
    }
}