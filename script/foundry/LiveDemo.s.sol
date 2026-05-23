// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {CredentialRegistry} from "../../src/access/CredentialRegistry.sol";
import {DevicePassportNFT} from "../../src/core/DevicePassportNFT.sol";
import {ServiceLogRegistry} from "../../src/core/ServiceLogRegistry.sol";
import {TransferManager} from "../../src/core/TransferManager.sol";
import {ComplianceScorer} from "../../src/compliance/ComplianceScorer.sol";
import {CertificationSBT} from "../../src/compliance/CertificationSBT.sol";
import {DeviceTypes} from "../../src/types/DeviceTypes.sol";

contract LiveDemo is Script {

    address constant REGISTRY     = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    address constant PASSPORT     = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
    address constant SERVICE_LOG  = 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9;
    address constant TRANSFER_MGR = 0x0165878A594ca255338adfa4d48449f69242Eb8F;
    address constant SCORER       = 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853;
    address constant CERT_SBT     = 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6;

    uint256 constant DEPLOYER_KEY     = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 constant MANUFACTURER_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 constant SERVICE_ORG_KEY  = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    uint256 constant HOSPITAL_KEY     = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;
    uint256 constant CERTIFIER_KEY    = 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a;

    function run() external {
        address manufacturer = vm.addr(MANUFACTURER_KEY);
        address serviceOrg   = vm.addr(SERVICE_ORG_KEY);
        address hospital     = vm.addr(HOSPITAL_KEY);
        address certifier    = vm.addr(CERTIFIER_KEY);

        CredentialRegistry registry = CredentialRegistry(REGISTRY);
        DevicePassportNFT  passport = DevicePassportNFT(PASSPORT);
        ServiceLogRegistry svcLog   = ServiceLogRegistry(SERVICE_LOG);
        TransferManager    transfer  = TransferManager(TRANSFER_MGR);
        ComplianceScorer   scorer   = ComplianceScorer(SCORER);
        CertificationSBT   certSBT  = CertificationSBT(CERT_SBT);

        console.log("===========================================");
        console.log("MedPassport - CT Scanner Pilot Demo");
        console.log("===========================================");
        console.log("");

        // STEP 1: Grant ALL credentials first
        console.log("STEP 1: Granting credentials...");
        vm.startBroadcast(DEPLOYER_KEY);
        registry.grantCredential(
            manufacturer,
            DeviceTypes.ActorRole.MANUFACTURER,
            "MedDevice GmbH", "ISO-MFR-2026-001"
        );
        registry.grantCredential(
            serviceOrg,
            DeviceTypes.ActorRole.CERTIFIED_SERVICE_ORG,
            "BioService Ltd", "ISO-SVC-2026-001"
        );
        registry.grantCredential(
            hospital,
            DeviceTypes.ActorRole.DEVICE_OWNER,
            "Mercy General Hospital", "HOSP-EU-2026-001"
        );
        registry.grantCredential(
            certifier,
            DeviceTypes.ActorRole.CERTIFIER,
            "MedCert Technologies", "CERT-EU-2026-001"
        );
        vm.stopBroadcast();
        console.log("Credentials granted to 4 actors");
        console.log("");

        // STEP 2: Mint device passport
        console.log("STEP 2: Minting CT scanner passport...");
        vm.startBroadcast(MANUFACTURER_KEY);
        uint256 tokenId = passport.mintDevicePassport(
            manufacturer,
            "00844588003288/LOT2026-001/SN00432",
            DeviceTypes.DeviceClass.CLASS_IIB,
            "CardioScan Pro 3000",
            "ipfs://QmMedPassportDemoCTScanner2026",
            true
        );
        vm.stopBroadcast();
        console.log("Device passport minted. Token ID:", tokenId);
        console.log("");

        // STEP 3: Approve TransferManager and propose transfer
        console.log("STEP 3: Proposing transfer to hospital...");
        vm.startBroadcast(MANUFACTURER_KEY);
        passport.approve(TRANSFER_MGR, tokenId);
        bytes32 proposal = transfer.proposeTransfer(
            tokenId,
            hospital,
            keccak256("hospital_purchase_agreement_2026")
        );
        vm.stopBroadcast();
        console.log("Transfer proposed by manufacturer");

        // STEP 4: Hospital confirms transfer
        console.log("STEP 4: Hospital confirms transfer...");
        vm.warp(block.timestamp + 1);
        vm.startBroadcast(HOSPITAL_KEY);
        transfer.confirmTransfer(proposal);
        vm.stopBroadcast();
        console.log("Ownership transferred to hospital");
        console.log("New owner:", hospital);
        console.log("");

        // STEP 5: Log service events
        console.log("STEP 5: Logging service events...");
        vm.startBroadcast(SERVICE_ORG_KEY);
        svcLog.logEvent(
            tokenId,
            DeviceTypes.EventType.PREVENTIVE_MAINTENANCE,
            keccak256("pm_report_2026_Q1"),
            "QmPMReport2026Q1",
            true, "", "Annual PM - all checks passed",
            false,
            false,
            false,
            bytes32(0)
        );
        svcLog.logEvent(
            tokenId,
            DeviceTypes.EventType.CALIBRATION,
            keccak256("calibration_cert_2026"),
            "QmCalibCert2026",
            true, "", "Annual calibration passed",
            false,
            false,
            false,
            bytes32(0)
        );
        svcLog.logEvent(
            tokenId,
            DeviceTypes.EventType.INSPECTION,
            keccak256("regulatory_inspection_2026"),
            "QmInspection2026",
            true, "", "Regulatory inspection passed",
            false,
            false,
            false,
            bytes32(0)
        );
        vm.stopBroadcast();

        vm.startBroadcast(MANUFACTURER_KEY);
        svcLog.logEvent(
            tokenId,
            DeviceTypes.EventType.SOFTWARE_UPDATE,
            keccak256("sw_update_v321"),
            "QmSWUpdateV321",
            true, "v3.2.1", "Security patch applied",
            false,
            false,
            false,
            bytes32(0)
        );
        vm.stopBroadcast();
        console.log("4 service events logged on-chain");
        console.log("");

        // STEP 6: Calculate compliance score
        console.log("STEP 6: Calculating compliance score...");
        uint256 score = scorer.calculateScoreSimple(tokenId, passport, svcLog);
        console.log("Compliance score:", score);
        string memory level = score >= 90 ? "GOLD" : score >= 75 ? "SILVER" : "BRONZE";
        console.log("Certification level:", level);
        console.log("");

        // STEP 7: Certifier proposes certification
        console.log("STEP 7: Certifier proposes certification...");
        vm.startBroadcast(CERTIFIER_KEY);
        bytes32 certProposal = certSBT.proposeCertification(
            tokenId,
            hospital,
            365,
            "MedCert Technologies",
            "CERT-2026-CT-00001",
            keccak256("certification_document_2026")
        );
        vm.stopBroadcast();
        console.log("Certification proposed");
        console.log("");

        // STEP 8: Hospital confirms certification
        console.log("STEP 8: Hospital confirms certification...");
        vm.warp(block.timestamp + 1);
        vm.startBroadcast(HOSPITAL_KEY);
        certSBT.confirmCertification(certProposal);
        vm.stopBroadcast();
        console.log("Certification confirmed");
        console.log("");

        // STEP 9: Verify final status
        console.log("STEP 9: Final passport verification...");
        (
            bool valid,,
            DeviceTypes.CertLevel certLevel,
            uint8 certScore,
            uint256 validUntil
        ) = certSBT.getCertificationStatus(tokenId);

        DeviceTypes.DeviceIdentity memory device =
            passport.getDevice(tokenId);

        console.log("===========================================");
        console.log("PASSPORT STATUS - CardioScan Pro 3000");
        console.log("===========================================");
        console.log("Token ID:          ", tokenId);
        console.log("Owner:             ", hospital);
        console.log("Recall active:     ", device.recallActive);
        console.log("Service events:    ", device.eventCount);
        console.log("Compliance score:  ", certScore);
        console.log("Certified:         ", valid);
        console.log("Cert level:        ", uint(certLevel));
        console.log("Valid until:       ", validUntil);
        console.log("===========================================");
        console.log("DEMO COMPLETE - PILOT WORKFLOW VERIFIED");
        console.log("===========================================");
    }
}