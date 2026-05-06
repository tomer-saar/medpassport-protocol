// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {CredentialRegistry} from "../../src/access/CredentialRegistry.sol";
import {RoleManager} from "../../src/access/RoleManager.sol";
import {MigrationGovernance} from "../../src/access/MigrationGovernance.sol";
import {DevicePassportNFT} from "../../src/core/DevicePassportNFT.sol";
import {ServiceLogRegistry} from "../../src/core/ServiceLogRegistry.sol";
import {CorrectionRegistry} from "../../src/core/CorrectionRegistry.sol";
import {TransferManager} from "../../src/core/TransferManager.sol";
import {ComplianceScorer} from "../../src/compliance/ComplianceScorer.sol";
import {CertificationSBT} from "../../src/compliance/CertificationSBT.sol";

contract DeployAll is Script {

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);

        console.log("===========================================");
        console.log("MedPassport Protocol - Full Deployment");
        console.log("===========================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("");

        vm.startBroadcast(deployerKey);

        // 1. CredentialRegistry
        CredentialRegistry registry =
            new CredentialRegistry(deployer);
        console.log("1. CredentialRegistry:", address(registry));

        // 2. RoleManager
        RoleManager roleManager =
            new RoleManager(address(registry));
        console.log("2. RoleManager:", address(roleManager));

        // 3. MigrationGovernance
    address[] memory signatories = new address[](2);
        signatories[0] = deployer;
        signatories[1] = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
        MigrationGovernance migration =
            new MigrationGovernance(
                address(registry),
                signatories,
                2
            );
        console.log("3. MigrationGovernance:", address(migration));

        // 4. DevicePassportNFT
        DevicePassportNFT passport =
            new DevicePassportNFT(
                address(registry),
                address(roleManager)
            );
        console.log("4. DevicePassportNFT:", address(passport));

        // 5. ServiceLogRegistry
        ServiceLogRegistry serviceLog =
            new ServiceLogRegistry(
                address(registry),
                address(roleManager),
                address(passport)
            );
        console.log("5. ServiceLogRegistry:", address(serviceLog));

        // 6. CorrectionRegistry
        CorrectionRegistry correctionReg =
            new CorrectionRegistry(
                address(registry),
                address(roleManager),
                address(serviceLog)
            );
        console.log("6. CorrectionRegistry:", address(correctionReg));

        // 7. TransferManager
        TransferManager transferMgr =
            new TransferManager(
                address(registry),
                address(roleManager),
                address(passport)
            );
        console.log("7. TransferManager:", address(transferMgr));

        // 8. ComplianceScorer
        ComplianceScorer scorer = new ComplianceScorer(address(passport), address(serviceLog));
        console.log("8. ComplianceScorer:", address(scorer));

        // 9. CertificationSBT
        CertificationSBT certSBT =
            new CertificationSBT(
                address(registry),
                address(roleManager),
                address(scorer),
                address(passport),
                address(serviceLog)
            );
        console.log("9. CertificationSBT:", address(certSBT));

        vm.stopBroadcast();

        console.log("");
        console.log("===========================================");
        console.log("Deployment complete - 9 contracts deployed");
        console.log("===========================================");
    }
}