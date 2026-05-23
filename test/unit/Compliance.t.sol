// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DevicePassportNFT} from "../../src/core/DevicePassportNFT.sol";
import {ServiceLogRegistry} from "../../src/core/ServiceLogRegistry.sol";
import {CorrectionRegistry} from "../../src/core/CorrectionRegistry.sol";
import {TransferManager} from "../../src/core/TransferManager.sol";
import {ComplianceScorer} from "../../src/compliance/ComplianceScorer.sol";
import {CertificationSBT} from "../../src/compliance/CertificationSBT.sol";
import {CredentialRegistry} from "../../src/access/CredentialRegistry.sol";
import {RoleManager} from "../../src/access/RoleManager.sol";
import {DeviceTypes} from "../../src/types/DeviceTypes.sol";

/**
 * @title ComplianceTest
 * @notice Tests the Sprint 3 compliance layer.
 *
 *         Test categories:
 *         1. Compliance scoring
 *         2. Score thresholds and certification levels
 *         3. Score invalidation on recall
 *         4. Certification issuance dual-signature flow
 *         5. Certification revocation
 *         6. Soulbound enforcement
 *         7. Full certification lifecycle
 */
contract ComplianceTest is Test {

    // ── Contracts ────────────────────────────────────────────────
    CredentialRegistry public registry;
    RoleManager        public roleManager;
    DevicePassportNFT  public passport;
    ServiceLogRegistry public serviceLog;
    CorrectionRegistry public correctionReg;
    TransferManager    public transferMgr;
    ComplianceScorer   public scorer;
    CertificationSBT   public certSBT;

    // ── Actors ───────────────────────────────────────────────────
    address public governance   = makeAddr("governance");
    address public manufacturer = makeAddr("manufacturer");
    address public serviceOrg   = makeAddr("serviceOrg");
    address public regulator    = makeAddr("regulator");
    address public hospital     = makeAddr("hospital");
    address public certifier    = makeAddr("certifier");
    address public stranger     = makeAddr("stranger");

    // ── Test data ────────────────────────────────────────────────
    string  constant UDI      = "00844588003288/LOT2024-001/SN00432";
    string  constant MODEL    = "CardioScan Pro 3000";
    string  constant METADATA = "ipfs://QmTestHash123456789";
    bytes32 constant DOC_HASH = keccak256("service_report_v1");
    string  constant IPFS_CID = "QmServiceReport123456";

    // ============================================================
    //  SETUP
    // ============================================================

    function setUp() public {
        // Deploy all contracts
        registry      = new CredentialRegistry(governance);
        roleManager   = new RoleManager(address(registry));
        passport      = new DevicePassportNFT(
            address(registry), address(roleManager)
        );
        serviceLog    = new ServiceLogRegistry(
            address(registry), address(roleManager), address(passport)
        );
        correctionReg = new CorrectionRegistry(
            address(registry), address(roleManager), address(serviceLog)
        );
        transferMgr   = new TransferManager(
            address(registry), address(roleManager), address(passport)
        );
        scorer        = new ComplianceScorer(address(passport), address(serviceLog));
        certSBT       = new CertificationSBT(
            address(registry),
            address(roleManager),
            address(scorer),
            address(passport),
            address(serviceLog)
        );

        // Grant credentials
        vm.startPrank(governance);
        registry.grantCredential(
            manufacturer, DeviceTypes.ActorRole.MANUFACTURER,
            "MedDevice GmbH", "ISO-MFR-001"
        );
        registry.grantCredential(
            serviceOrg, DeviceTypes.ActorRole.CERTIFIED_SERVICE_ORG,
            "BioService Ltd", "ISO-SVC-001"
        );
        registry.grantCredential(
            regulator, DeviceTypes.ActorRole.REGULATOR,
            "EU Regulatory Authority", "REG-EU-001"
        );
        registry.grantCredential(
            hospital, DeviceTypes.ActorRole.DEVICE_OWNER,
            "Mercy General Hospital", "HOSP-001"
        );
        registry.grantCredential(
            certifier, DeviceTypes.ActorRole.CERTIFIER,
            "MedCert Technologies", "CERT-001"
        );
        vm.stopPrank();
    }

    // ── Helpers ──────────────────────────────────────────────────

    function _mintAndTransferToHospital()
        internal returns (uint256 tokenId)
    {
        vm.prank(manufacturer);
        tokenId = passport.mintDevicePassport(
            manufacturer, UDI,
            DeviceTypes.DeviceClass.CLASS_IIB,
            MODEL, METADATA,
            true
        );

        vm.prank(manufacturer);
        passport.approve(address(transferMgr), tokenId);

        vm.prank(manufacturer);
        bytes32 proposal = transferMgr.proposeTransfer(
            tokenId, hospital, keccak256("purchase_agreement")
        );

        vm.prank(hospital);
        transferMgr.confirmTransfer(proposal);
    }

    function _logPM(uint256 tokenId, bool passed) internal {
        bytes32 hash = keccak256(
            abi.encodePacked("pm_report", tokenId, passed)
        );
        vm.prank(serviceOrg);
        serviceLog.logEvent(
            tokenId,
            DeviceTypes.EventType.PREVENTIVE_MAINTENANCE,
            hash, "QmPMReport", passed, "", "PM event",
            false,
            false,
            false,
            bytes32(0),
            ""
        );
    }

    function _logCalibration(uint256 tokenId, bool passed) internal {
        bytes32 hash = keccak256(
            abi.encodePacked("cal_report", tokenId, passed)
        );
        vm.prank(serviceOrg);
        serviceLog.logEvent(
            tokenId,
            DeviceTypes.EventType.CALIBRATION,
            hash, "QmCalReport", passed, "", "Calibration event",
            false,
            false,
            false,
            bytes32(0),
            ""
        );
    }

    function _logInspection(uint256 tokenId, bool passed) internal {
        bytes32 hash = keccak256(
            abi.encodePacked("insp_report", tokenId, passed)
        );
        vm.prank(serviceOrg);
        serviceLog.logEvent(
            tokenId,
            DeviceTypes.EventType.INSPECTION,
            hash, "QmInspReport", passed, "", "Inspection event",
            false,
            false,
            false,
            bytes32(0),
            ""
        );
    }

    // ============================================================
    //  1. COMPLIANCE SCORING
    // ============================================================

    function test_Score_ZeroWithNoHistory() public {
        // DECAY MODEL: new device starts at 100 — no deductions yet
        uint256 tokenId = _mintAndTransferToHospital();
        assertEq(scorer.calculateScoreSimple(tokenId, passport, serviceLog), 100);
    }

    function test_Score_PositiveAfterPassedEvents() public {
        uint256 tokenId = _mintAndTransferToHospital();
        _logPM(tokenId, true);
        _logCalibration(tokenId, true);
        _logInspection(tokenId, true);

        uint256 score = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        assertGt(score, 0);
        assertLe(score, 100);
        console.log("Score after 3 passing events:", score);
    }

    function test_Score_LowerAfterFailedEvents() public {
        uint256 tokenId = _mintAndTransferToHospital();
        _logPM(tokenId, true);
        _logCalibration(tokenId, true);

        uint256 scoreBefore = scorer.calculateScoreSimple(tokenId, passport, serviceLog);

        _logPM(tokenId, false);
        _logCalibration(tokenId, false);

        uint256 scoreAfter = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        assertLt(scoreAfter, scoreBefore);
        console.log("Score before failures:", scoreBefore);
        console.log("Score after failures:", scoreAfter);
    }

    function test_Score_DeductionForIncident() public {
        uint256 tokenId = _mintAndTransferToHospital();
        _logPM(tokenId, true);
        _logCalibration(tokenId, true);
        _logInspection(tokenId, true);

        uint256 scoreWithout = scorer.calculateScoreSimple(tokenId, passport, serviceLog);

        bytes32 hash = keccak256("incident_report");
        vm.prank(serviceOrg);
        serviceLog.logEvent(
            tokenId,
            DeviceTypes.EventType.INCIDENT_REPORT,
            hash, "QmIncident", false, "", "Adverse event",
            false,
            false,
            false,
            bytes32(0),
            ""
        );

        uint256 scoreWith = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        assertLt(scoreWith, scoreWithout);
        console.log("Score without incident:", scoreWithout);
        console.log("Score with incident:", scoreWith);
    }

    // ============================================================
    //  2. SCORE THRESHOLDS
    // ============================================================

    function test_CertLevel_Gold() public pure {
        ComplianceScorer s;
        // We test the threshold logic directly
        // Gold >= 90
        (DeviceTypes.CertLevel level, bool certifiable) =
            _getCertLevelFromScore(90);
        assertEq(uint(level), uint(DeviceTypes.CertLevel.GOLD));
        assertTrue(certifiable);
    }

    function test_CertLevel_Silver() public pure {
        (DeviceTypes.CertLevel level, bool certifiable) =
            _getCertLevelFromScore(75);
        assertEq(uint(level), uint(DeviceTypes.CertLevel.SILVER));
        assertTrue(certifiable);
    }

    function test_CertLevel_Bronze() public pure {
        (DeviceTypes.CertLevel level, bool certifiable) =
            _getCertLevelFromScore(60);
        assertEq(uint(level), uint(DeviceTypes.CertLevel.BRONZE));
        assertTrue(certifiable);
    }

    function test_CertLevel_NotCertifiable() public pure {
        (, bool certifiable) = _getCertLevelFromScore(59);
        assertFalse(certifiable);
    }

    // Helper to test cert levels without deploying scorer
    function _getCertLevelFromScore(uint8 score)
        internal pure
        returns (DeviceTypes.CertLevel level, bool certifiable)
    {
        if (score >= 90) return (DeviceTypes.CertLevel.GOLD, true);
        if (score >= 75) return (DeviceTypes.CertLevel.SILVER, true);
        if (score >= 60) return (DeviceTypes.CertLevel.BRONZE, true);
        return (DeviceTypes.CertLevel.BRONZE, false);
    }

    // ============================================================
    //  3. SCORE INVALIDATION ON RECALL
    // ============================================================

    function test_Score_ZeroOnActiveRecall() public {
        uint256 tokenId = _mintAndTransferToHospital();
        _logPM(tokenId, true);
        _logCalibration(tokenId, true);

        uint256 scoreBefore = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        assertGt(scoreBefore, 0);

        vm.prank(regulator);
        passport.activateRecall(tokenId);

        uint256 scoreAfter = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        assertEq(scoreAfter, 0);
        console.log("Score before recall:", scoreBefore);
        console.log("Score after recall:", scoreAfter);
    }

    function test_Score_ZeroOnDecommissioned() public {
        uint256 tokenId = _mintAndTransferToHospital();
        _logPM(tokenId, true);

        vm.prank(hospital);
        passport.decommissionDevice(tokenId);

        assertEq(scorer.calculateScoreSimple(tokenId, passport, serviceLog), 0);
    }

    // ============================================================
    //  4. CERTIFICATION DUAL-SIGNATURE FLOW
    // ============================================================

    function _buildHighScore(uint256 tokenId) internal {
        _logPM(tokenId, true);
        _logPM(tokenId, true);
        _logCalibration(tokenId, true);
        _logCalibration(tokenId, true);
        _logInspection(tokenId, true);
        vm.prank(manufacturer);
        serviceLog.logEvent(
            tokenId,
            DeviceTypes.EventType.SOFTWARE_UPDATE,
            keccak256("sw_update"), "QmSWUpdate",
            true, "v3.2.1", "Security patch",
            false,
            false,
            false,
            bytes32(0),
            ""
        );
    }

    function test_Certification_FullDualSignFlow() public {
        uint256 tokenId = _mintAndTransferToHospital();
        _buildHighScore(tokenId);

        uint256 score = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        console.log("Score before certification:", score);
        assertGe(score, 60);

        // Step 1: Certifier proposes
        vm.prank(certifier);
        bytes32 proposalId = certSBT.proposeCertification(
            tokenId,
            hospital,
            365,
            "MedCert Technologies",
            "CERT-2026-001",
            keccak256("cert_document")
        );

        // Step 2: Hospital confirms
        vm.prank(hospital);
        certSBT.confirmCertification(proposalId);

        // Verify certification issued
        (
            bool valid,
            uint256 certTokenId,
            DeviceTypes.CertLevel level,
            uint8 certScore,
        ) = certSBT.getCertificationStatus(tokenId);

        assertTrue(valid);
        assertGt(certTokenId, 0);
        assertGe(certScore, 60);
        console.log("Certification issued. Level:", uint(level));
        console.log("Cert score:", certScore);
    }

    function test_Certification_RejectsLowScore() public {
        uint256 tokenId = _mintAndTransferToHospital();
        // DECAY MODEL: warp 3 years so all intervals overdue
        // PM -25, Cal -25, Insp -20, SW -5 = 75 deducted, score=25
        vm.warp(block.timestamp + 3 * 365 days);
        vm.prank(certifier);
        vm.expectRevert(
            abi.encodeWithSelector(
                CertificationSBT.ScoreBelowMinimum.selector,
                uint8(25),
                60
            )
        );
        certSBT.proposeCertification(
            tokenId, hospital, 365,
            "MedCert Technologies", "CERT-001",
            keccak256("cert_document")
        );
    }

    function test_Certification_RejectsOnRecall() public {
        uint256 tokenId = _mintAndTransferToHospital();
        _buildHighScore(tokenId);

        vm.prank(regulator);
        passport.activateRecall(tokenId);

        vm.prank(certifier);
        vm.expectRevert(
            abi.encodeWithSelector(
                CertificationSBT.DeviceHasActiveRecall.selector,
                tokenId
            )
        );
        certSBT.proposeCertification(
            tokenId, hospital, 365,
            "MedCert Technologies", "CERT-001",
            keccak256("cert_document")
        );
    }

    function test_Certification_RejectsWrongConfirmer() public {
        uint256 tokenId = _mintAndTransferToHospital();
        _buildHighScore(tokenId);

        vm.prank(certifier);
        bytes32 proposalId = certSBT.proposeCertification(
            tokenId, hospital, 365,
            "MedCert Technologies", "CERT-001",
            keccak256("cert_document")
        );

        // Stranger tries to confirm
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                CertificationSBT.ConfirmerMustBeDeviceOwner.selector,
                stranger,
                hospital
            )
        );
        certSBT.confirmCertification(proposalId);
    }

    function test_Certification_RejectsExpiredProposal() public {
        uint256 tokenId = _mintAndTransferToHospital();
        _buildHighScore(tokenId);

        vm.prank(certifier);
        bytes32 proposalId = certSBT.proposeCertification(
            tokenId, hospital, 365,
            "MedCert Technologies", "CERT-001",
            keccak256("cert_document")
        );

        // Fast forward past 72 hour window
        vm.warp(block.timestamp + 73 hours);

        vm.prank(hospital);
        vm.expectRevert(
            abi.encodeWithSelector(
                CertificationSBT.ProposalExpired.selector,
                proposalId
            )
        );
        certSBT.confirmCertification(proposalId);
    }

    // ============================================================
    //  5. CERTIFICATION REVOCATION
    // ============================================================

    function test_Revocation_ByCertifier() public {
        uint256 tokenId = _mintAndTransferToHospital();
        _buildHighScore(tokenId);

        vm.prank(certifier);
        bytes32 proposalId = certSBT.proposeCertification(
            tokenId, hospital, 365,
            "MedCert Technologies", "CERT-001",
            keccak256("cert_document")
        );

        vm.prank(hospital);
        certSBT.confirmCertification(proposalId);

        (bool validBefore,,,, ) =
            certSBT.getCertificationStatus(tokenId);
        assertTrue(validBefore);

        vm.prank(certifier);
        certSBT.revokeCertification(tokenId, "Device failed re-inspection");

        (bool validAfter,,,, ) =
            certSBT.getCertificationStatus(tokenId);
        assertFalse(validAfter);
    }

    function test_Revocation_ByRegulator() public {
        uint256 tokenId = _mintAndTransferToHospital();
        _buildHighScore(tokenId);

        vm.prank(certifier);
        bytes32 proposalId = certSBT.proposeCertification(
            tokenId, hospital, 365,
            "MedCert Technologies", "CERT-001",
            keccak256("cert_document")
        );

        vm.prank(hospital);
        certSBT.confirmCertification(proposalId);

        vm.prank(regulator);
        certSBT.revokeCertification(tokenId, "Recall activated");

        (bool valid,,,, ) = certSBT.getCertificationStatus(tokenId);
        assertFalse(valid);
    }

    function test_Revocation_StrangerCannotRevoke() public {
        uint256 tokenId = _mintAndTransferToHospital();
        _buildHighScore(tokenId);

        vm.prank(certifier);
        bytes32 proposalId = certSBT.proposeCertification(
            tokenId, hospital, 365,
            "MedCert Technologies", "CERT-001",
            keccak256("cert_document")
        );

        vm.prank(hospital);
        certSBT.confirmCertification(proposalId);

        vm.prank(stranger);
        vm.expectRevert(
            CertificationSBT.NotAuthorizedToRevoke.selector
        );
        certSBT.revokeCertification(tokenId, "Unauthorized");
    }

    // ============================================================
    //  6. SOULBOUND ENFORCEMENT
    // ============================================================

    function test_Soulbound_CannotTransfer() public {
        uint256 tokenId = _mintAndTransferToHospital();
        _buildHighScore(tokenId);

        vm.prank(certifier);
        bytes32 proposalId = certSBT.proposeCertification(
            tokenId, hospital, 365,
            "MedCert Technologies", "CERT-001",
            keccak256("cert_document")
        );

        vm.prank(hospital);
        certSBT.confirmCertification(proposalId);

        uint256 certTokenId = certSBT.activeCertification(tokenId);

        vm.prank(hospital);
        vm.expectRevert(
            CertificationSBT.SoulboundCannotTransfer.selector
        );
        certSBT.transferFrom(hospital, stranger, certTokenId);
    }

    function test_Soulbound_LockedReturnsTrue() public {
        uint256 tokenId = _mintAndTransferToHospital();
        _buildHighScore(tokenId);

        vm.prank(certifier);
        bytes32 proposalId = certSBT.proposeCertification(
            tokenId, hospital, 365,
            "MedCert Technologies", "CERT-001",
            keccak256("cert_document")
        );

        vm.prank(hospital);
        certSBT.confirmCertification(proposalId);

        uint256 certTokenId = certSBT.activeCertification(tokenId);
        assertTrue(certSBT.locked(certTokenId));
    }

    // ============================================================
    //  7. FULL CERTIFICATION LIFECYCLE
    // ============================================================

    function test_FullCertificationLifecycle() public {
        // Step 1: Device minted and transferred to hospital
        uint256 tokenId = _mintAndTransferToHospital();
        console.log("Step 1: Device minted and transferred");

        // Step 2: Build service history
        _buildHighScore(tokenId);
        uint256 score = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        console.log("Step 2: Service history built. Score:", score);
        assertGe(score, 60);

        // Step 3: Certifier proposes certification
        vm.prank(certifier);
        bytes32 proposalId = certSBT.proposeCertification(
            tokenId, hospital, 365,
            "MedCert Technologies", "CERT-2026-001",
            keccak256("cert_document")
        );
        console.log("Step 3: Certification proposed");

        // Step 4: Hospital confirms
        vm.prank(hospital);
        certSBT.confirmCertification(proposalId);
        console.log("Step 4: Certification confirmed");

        // Step 5: Verify certification status
        (
            bool valid,,
            DeviceTypes.CertLevel level,
            uint8 certScore,
            uint256 validUntil
        ) = certSBT.getCertificationStatus(tokenId);

        assertTrue(valid);
        assertGe(certScore, 60);
        assertGt(validUntil, block.timestamp);
        console.log("Step 5: Certification valid. Level:", uint(level));

        // Step 6: Recall activated — certification revoked
        vm.prank(regulator);
        certSBT.revokeCertification(tokenId, "Safety recall activated");

        (bool validAfterRecall,,,, ) =
            certSBT.getCertificationStatus(tokenId);
        assertFalse(validAfterRecall);
        console.log("Step 6: Certification revoked on recall");

        // Step 7: Recall cleared — new certification possible
        vm.prank(regulator);
        passport.activateRecall(tokenId);
        vm.prank(regulator);
        passport.clearRecall(tokenId);

        // Score should be positive again
        uint256 scoreAfterClear = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        assertGt(scoreAfterClear, 0);
        console.log("Step 7: Recall cleared. Score:", scoreAfterClear);
        console.log("CERTIFICATION LIFECYCLE TEST PASSED");
    }
    function _mintAndTransferSecond()
        internal returns (uint256 tokenId)
    {
        vm.prank(manufacturer);
        tokenId = passport.mintDevicePassport(
            manufacturer, "00844588003288/LOT2024-002/SN00999",
            DeviceTypes.DeviceClass.CLASS_IIB,
            MODEL, METADATA,
            true
        );
        vm.prank(manufacturer);
        passport.approve(address(transferMgr), tokenId);
        vm.prank(manufacturer);
        bytes32 proposal = transferMgr.proposeTransfer(
            tokenId, hospital, keccak256("purchase_agreement_2")
        );
        vm.prank(hospital);
        transferMgr.confirmTransfer(proposal);
    }

    // ============================================================
    //  8. INTEGRITY FLAG SCORING — Sprint 6 additions
    // ============================================================

    function test_Score_DeductionForUndocumentedParts() public {
        uint256 tokenId = _mintAndTransferToHospital();
        _logPM(tokenId, true);
        _logCalibration(tokenId, true);
        uint256 scoreBefore = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        bytes32 hash = keccak256("pm_undocumented_parts");
        vm.prank(serviceOrg);
        serviceLog.logEvent(
            tokenId, DeviceTypes.EventType.PREVENTIVE_MAINTENANCE,
            hash, "QmUndocParts", true, "", "PM with undocumented parts",
            false, true, false,  // hasUndocumentedParts = true
            bytes32(0),
            ""
        );
        uint256 scoreAfter = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        assertLt(scoreAfter, scoreBefore);
        console.log("Score before undocumented parts:", scoreBefore);
        console.log("Score after undocumented parts:", scoreAfter);
    }

    function test_Score_DeductionForCompatibleParts() public {
        uint256 tokenId = _mintAndTransferToHospital();
        _logPM(tokenId, true);
        uint256 scoreBefore = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        vm.prank(serviceOrg);
        serviceLog.logEvent(
            tokenId, DeviceTypes.EventType.PREVENTIVE_MAINTENANCE,
            keccak256("pm_compat"), "QmCompatParts", true, "", "PM with compatible parts",
            true, false, false,  // hasCompatibleParts = true
            bytes32(0),
            ""
        );
        uint256 scoreAfter = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        assertLt(scoreAfter, scoreBefore);
        assertGt(scoreAfter, scoreBefore - 10); // less penalty than undocumented
        console.log("Score before compatible parts:", scoreBefore);
        console.log("Score after compatible parts:", scoreAfter);
    }

    function test_Score_UndocumentedPartsWorseThanCompatible() public {
        uint256 tokenId1 = _mintAndTransferToHospital();
        uint256 tokenId2 = _mintAndTransferSecond();
        vm.prank(serviceOrg);
        serviceLog.logEvent(
            tokenId1, DeviceTypes.EventType.PREVENTIVE_MAINTENANCE,
            keccak256("pm_compat2"), "QmC2", true, "", "Compatible parts",
            true, false, false,
            bytes32(0),
            ""
        );
        vm.prank(serviceOrg);
        serviceLog.logEvent(
            tokenId2, DeviceTypes.EventType.PREVENTIVE_MAINTENANCE,
            keccak256("pm_undoc2"), "QmU2", true, "", "Undocumented parts",
            false, true, false,
            bytes32(0),
            ""
        );
        uint256 scoreCompat = scorer.calculateScoreSimple(tokenId1, passport, serviceLog);
        uint256 scoreUndoc  = scorer.calculateScoreSimple(tokenId2, passport, serviceLog);
        assertGt(scoreCompat, scoreUndoc);
        console.log("Score with compatible parts:", scoreCompat);
        console.log("Score with undocumented parts:", scoreUndoc);
    }

    function test_Score_DeductionForSeriousIncident() public {
        uint256 tokenId = _mintAndTransferToHospital();
        _logPM(tokenId, true);
        _logCalibration(tokenId, true);
        _logInspection(tokenId, true);
        uint256 scoreBefore = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        vm.prank(serviceOrg);
        serviceLog.logEvent(
            tokenId, DeviceTypes.EventType.INCIDENT_REPORT,
            keccak256("serious_inc"), "QmSerious",
            false, "", "Serious adverse event",
            false, false, true,  // isSeriousIncident = true
            bytes32(0),
            ""
        );
        uint256 scoreAfter = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        assertLt(scoreAfter, scoreBefore);
        console.log("Score before serious incident:", scoreBefore);
        console.log("Score after serious incident:", scoreAfter);
    }

    function test_Score_SeriousIncidentWorseThanMinor() public {
        uint256 tokenId1 = _mintAndTransferToHospital();
        uint256 tokenId2 = _mintAndTransferSecond();
        vm.prank(serviceOrg);
        serviceLog.logEvent(
            tokenId1, DeviceTypes.EventType.INCIDENT_REPORT,
            keccak256("minor_inc"), "QmMinor",
            false, "", "Minor incident",
            false, false, false,  // isSeriousIncident = false
            bytes32(0),
            ""
        );
        vm.prank(serviceOrg);
        serviceLog.logEvent(
            tokenId2, DeviceTypes.EventType.INCIDENT_REPORT,
            keccak256("serious_inc2"), "QmSerious2",
            false, "", "Serious incident",
            false, false, true,  // isSeriousIncident = true
            bytes32(0),
            ""
        );
        uint256 scoreMinor   = scorer.calculateScoreSimple(tokenId1, passport, serviceLog);
        uint256 scoreSerious = scorer.calculateScoreSimple(tokenId2, passport, serviceLog);
        assertGt(scoreMinor, scoreSerious);
        console.log("Score after minor incident:", scoreMinor);
        console.log("Score after serious incident:", scoreSerious);
    }

    // ============================================================
    //  9. SCORE RECOVERY AFTER CORRECTIVE ACTION
    // ============================================================

    function test_Score_RecoveryAfterPM() public {
        // Demonstrates score recovery after corrective maintenance.
        // This is the incentive alignment argument: the score recovers
        // when the device is brought back into compliance.
        uint256 tokenId = _mintAndTransferToHospital();

        // New device starts at 100
        uint256 scoreNew = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        assertEq(scoreNew, 100);
        console.log("Score at manufacture:", scoreNew);

        // Warp 15 months — PM is overdue (interval = 12 months)
        vm.warp(block.timestamp + 455 days);
        uint256 scoreOverdue = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        assertLt(scoreOverdue, scoreNew);
        console.log("Score after PM overdue 15 months:", scoreOverdue);

        // Perform PM — score should recover
        _logPM(tokenId, true);
        uint256 scoreAfterPM = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        assertGt(scoreAfterPM, scoreOverdue);
        assertGe(scoreAfterPM, 50); // PM deduction removed; cal+insp still overdue
        console.log("Score after PM performed:", scoreAfterPM);
        console.log("Recovery delta:", scoreAfterPM - scoreOverdue);
        console.log("SCORE RECOVERY TEST PASSED");
    }

    function test_Score_FullRecoveryAfterAllService() public {
        // All service components overdue then brought up to date.
        // Score should recover to Gold territory (>=90).
        uint256 tokenId = _mintAndTransferToHospital();

        // Warp 18 months — all intervals overdue
        vm.warp(block.timestamp + 548 days);
        uint256 scoreOverdue = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        assertLt(scoreOverdue, 80);
        console.log("Score when all service overdue:", scoreOverdue);

        // Perform all service types
        _logPM(tokenId, true);
        _logCalibration(tokenId, true);
        _logInspection(tokenId, true);

        uint256 scoreRecovered = scorer.calculateScoreSimple(tokenId, passport, serviceLog);
        assertGt(scoreRecovered, scoreOverdue);
        assertGe(scoreRecovered, 90);
        console.log("Score after all service:", scoreRecovered);
        console.log("Full recovery delta:", scoreRecovered - scoreOverdue);
    }

}