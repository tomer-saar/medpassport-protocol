// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DeviceTypes} from "../types/DeviceTypes.sol";
import {ServiceLogRegistry} from "../core/ServiceLogRegistry.sol";
import {DevicePassportNFT} from "../core/DevicePassportNFT.sol";

/**
 * @title ComplianceScorer
 * @author Tomer Saar, PMP
 * @notice Calculates a compliance score (0-100) for a medical device
 *         based on its verified service history.
 *
 *         The score determines certification level:
 *         - GOLD   (90-100): Premium certified
 *         - SILVER (75-89):  Standard certified
 *         - BRONZE (60-74):  Baseline certified
 *         - NONE   (0-59):   Not certifiable
 *
 *         Scoring weights reflect clinical and regulatory importance:
 *         - Calibration:            30 points maximum
 *         - Preventive Maintenance: 30 points maximum
 *         - Inspection:             25 points maximum
 *         - Software currency:      15 points maximum
 *
 *         Automatic deductions:
 *         - Active recall:         Score forced to 0
 *         - Open incident report:  15 point deduction
 *         - Decommissioned:        Score forced to 0
 *
 * @dev Stateless contract — no storage, only computation.
 *      Called by CertificationSBT before issuing any certification.
 *      ISO 13485:2016 - continual improvement evidence
 */
contract ComplianceScorer {

    // ============================================================
    //  CONSTANTS — scoring weights
    // ============================================================

    uint256 public constant CALIBRATION_WEIGHT = 30;
    uint256 public constant PM_WEIGHT          = 30;
    uint256 public constant INSPECTION_WEIGHT  = 25;
    uint256 public constant SOFTWARE_WEIGHT    = 15;
    uint256 public constant INCIDENT_DEDUCTION = 15;

    // Certification thresholds
    uint8 public constant GOLD_THRESHOLD   = 90;
    uint8 public constant SILVER_THRESHOLD = 75;
    uint8 public constant BRONZE_THRESHOLD = 60;

    // ============================================================
    //  STATE VARIABLES
    // ============================================================

    /// @notice Reference to the ServiceLogRegistry
    ServiceLogRegistry public immutable serviceLog;

    /// @notice Reference to the DevicePassportNFT
    DevicePassportNFT public immutable passportNFT;

    // ============================================================
    //  CONSTRUCTOR
    // ============================================================

    constructor(
        address _serviceLog,
        address _passportNFT
    ) {
        require(
            _serviceLog != address(0),
            "ServiceLog cannot be zero address"
        );
        require(
            _passportNFT != address(0),
            "PassportNFT cannot be zero address"
        );
        serviceLog  = ServiceLogRegistry(_serviceLog);
        passportNFT = DevicePassportNFT(_passportNFT);
    }

    // ============================================================
    //  CORE FUNCTION — CALCULATE SCORE
    // ============================================================

    /**
     * @notice Calculate the compliance score for a device.
     * @dev Reads the full service history from ServiceLogRegistry
     *      and computes a weighted score based on event types
     *      and pass/fail outcomes.
     *
     *      Returns 0 immediately if:
     *      - Device has an active recall
     *      - Device is decommissioned
     *      - Device has no service history
     *
     * @param tokenId The device passport token to score
     * @return score  Compliance score 0-100
     */
    function calculateScore(uint256 tokenId)
        external view
        returns (uint8 score)
    {
        // Check device status — recall or decommission = score 0
        DeviceTypes.DeviceIdentity memory device =
            passportNFT.getDevice(tokenId);

        if (device.recallActive || device.decommissioned) {
            return 0;
        }

        // Get full service history
        DeviceTypes.ServiceEvent[] memory history =
            serviceLog.getHistory(tokenId);

        if (history.length == 0) {
            return 0;
        }

        // Count events by type
        uint256 calibrationPassed;
        uint256 calibrationTotal;
        uint256 pmPassed;
        uint256 pmTotal;
        uint256 inspectionPassed;
        uint256 inspectionTotal;
        bool    hasSoftwareEvent;
        bool    hasOpenIncident;

        for (uint256 i = 0; i < history.length; i++) {
            DeviceTypes.EventType et = history[i].eventType;

            if (et == DeviceTypes.EventType.CALIBRATION) {
                calibrationTotal++;
                if (history[i].passedInspection) calibrationPassed++;

            } else if (
                et == DeviceTypes.EventType.PREVENTIVE_MAINTENANCE
            ) {
                pmTotal++;
                if (history[i].passedInspection) pmPassed++;

            } else if (et == DeviceTypes.EventType.INSPECTION) {
                inspectionTotal++;
                if (history[i].passedInspection) inspectionPassed++;

            } else if (et == DeviceTypes.EventType.SOFTWARE_UPDATE) {
                hasSoftwareEvent = true;

            } else if (et == DeviceTypes.EventType.INCIDENT_REPORT) {
                hasOpenIncident = true;
            }
        }

        // Calculate weighted score
        uint256 total = 0;

        // Calibration component — 30 points max
        if (calibrationTotal > 0) {
            total += (calibrationPassed * CALIBRATION_WEIGHT)
                / calibrationTotal;
        } else {
            // No calibration events — neutral score for this component
            total += CALIBRATION_WEIGHT / 2;
        }

        // PM component — 30 points max
        if (pmTotal > 0) {
            total += (pmPassed * PM_WEIGHT) / pmTotal;
        } else {
            total += PM_WEIGHT / 2;
        }

        // Inspection component — 25 points max
        if (inspectionTotal > 0) {
            total += (inspectionPassed * INSPECTION_WEIGHT)
                / inspectionTotal;
        } else {
            total += INSPECTION_WEIGHT / 2;
        }

        // Software component — 15 points max
        // Full points if any software update recorded
        // Half points if no update recorded
        total += hasSoftwareEvent
            ? SOFTWARE_WEIGHT
            : SOFTWARE_WEIGHT / 2;

        // Deduction for open incident report
        if (hasOpenIncident && total >= INCIDENT_DEDUCTION) {
            total -= INCIDENT_DEDUCTION;
        }

        // Cap at 100
        score = total > 100 ? 100 : uint8(total);
    }

    // ============================================================
    //  VIEW FUNCTIONS
    // ============================================================

    /**
     * @notice Determine certification level from a score.
     * @param score The compliance score 0-100
     * @return level The certification level
     * @return certifiable True if score meets minimum threshold
     */
    function getCertLevel(uint8 score)
        external pure
        returns (DeviceTypes.CertLevel level, bool certifiable)
    {
        if (score >= GOLD_THRESHOLD) {
            return (DeviceTypes.CertLevel.GOLD, true);
        } else if (score >= SILVER_THRESHOLD) {
            return (DeviceTypes.CertLevel.SILVER, true);
        } else if (score >= BRONZE_THRESHOLD) {
            return (DeviceTypes.CertLevel.BRONZE, true);
        } else {
            return (DeviceTypes.CertLevel.BRONZE, false);
        }
    }

    /**
     * @notice Get a full score breakdown for a device.
     * @dev Returns the raw component scores before weighting.
     *      Useful for the enterprise dashboard to show detail.
     *
     * @param tokenId The device passport token to analyse
     * @return totalScore       Final weighted score 0-100
     * @return calibrationScore Calibration component 0-30
     * @return pmScore          PM component 0-30
     * @return inspectionScore  Inspection component 0-25
     * @return softwareScore    Software component 0-15
     * @return hasIncident      True if open incident exists
     */
    function getScoreBreakdown(uint256 tokenId)
        external view
        returns (
            uint8  totalScore,
            uint256 calibrationScore,
            uint256 pmScore,
            uint256 inspectionScore,
            uint256 softwareScore,
            bool    hasIncident
        )
    {
        DeviceTypes.DeviceIdentity memory device =
            passportNFT.getDevice(tokenId);

        if (device.recallActive || device.decommissioned) {
            return (0, 0, 0, 0, 0, false);
        }

        DeviceTypes.ServiceEvent[] memory history =
            serviceLog.getHistory(tokenId);

        if (history.length == 0) {
            return (0, 0, 0, 0, 0, false);
        }

        uint256 calibrationPassed;
        uint256 calibrationTotal;
        uint256 pmPassed;
        uint256 pmTotal;
        uint256 inspectionPassed;
        uint256 inspectionTotal;
        bool    hasSoftwareEvent;

        for (uint256 i = 0; i < history.length; i++) {
            DeviceTypes.EventType et = history[i].eventType;

            if (et == DeviceTypes.EventType.CALIBRATION) {
                calibrationTotal++;
                if (history[i].passedInspection) calibrationPassed++;
            } else if (
                et == DeviceTypes.EventType.PREVENTIVE_MAINTENANCE
            ) {
                pmTotal++;
                if (history[i].passedInspection) pmPassed++;
            } else if (et == DeviceTypes.EventType.INSPECTION) {
                inspectionTotal++;
                if (history[i].passedInspection) inspectionPassed++;
            } else if (et == DeviceTypes.EventType.SOFTWARE_UPDATE) {
                hasSoftwareEvent = true;
            } else if (et == DeviceTypes.EventType.INCIDENT_REPORT) {
                hasIncident = true;
            }
        }

        calibrationScore = calibrationTotal > 0
            ? (calibrationPassed * CALIBRATION_WEIGHT) / calibrationTotal
            : CALIBRATION_WEIGHT / 2;

        pmScore = pmTotal > 0
            ? (pmPassed * PM_WEIGHT) / pmTotal
            : PM_WEIGHT / 2;

        inspectionScore = inspectionTotal > 0
            ? (inspectionPassed * INSPECTION_WEIGHT) / inspectionTotal
            : INSPECTION_WEIGHT / 2;

        softwareScore = hasSoftwareEvent
            ? SOFTWARE_WEIGHT
            : SOFTWARE_WEIGHT / 2;

        uint256 total = calibrationScore + pmScore +
                        inspectionScore + softwareScore;

        if (hasIncident && total >= INCIDENT_DEDUCTION) {
            total -= INCIDENT_DEDUCTION;
        }

        totalScore = total > 100 ? 100 : uint8(total);
    }
}