// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../core/DevicePassportNFT.sol";
import "../core/ServiceLogRegistry.sol";
import "../types/DeviceTypes.sol";

/**
 * @title ComplianceScorer v2
 * @notice Decay-from-100 scoring. New device = 100. Deductions on deviation.
 */
contract ComplianceScorer {

    uint256 public constant MAX_SCORE    = 100;
    uint256 public constant INTERVAL     = 365 days;
    uint256 public constant THREE_MONTHS = 90  days;
    uint256 public constant SIX_MONTHS   = 180 days;

    DevicePassportNFT  public immutable nft;
    ServiceLogRegistry public immutable log;
    address            public admin;

    constructor(address _nft, address _log) {
        nft   = DevicePassportNFT(_nft);
        log   = ServiceLogRegistry(_log);
        admin = msg.sender;
    }

    // ── Main scoring function ─────────────────────────────────────

    function calculateScore(uint256 tokenId) public view returns (uint256) {
        DeviceTypes.DeviceIdentity memory dev = nft.getDevice(tokenId);
        if (dev.recallActive)   return 0;
        if (dev.decommissioned) return 0;

        uint256 d = 0;
        d += _calDeduction(tokenId, dev.manufactureDate);
        d += _pmDeduction(tokenId, dev.manufactureDate);
        d += _inspDeduction(tokenId, dev.manufactureDate);
        d += _swDeduction(tokenId, dev.manufactureDate);
        d += _partsDeduction(tokenId);
        d += _complaintDeduction(tokenId);

        return d >= MAX_SCORE ? 0 : MAX_SCORE - d;
    }

    // ── Per-component deduction functions ────────────────────────

    function _calDeduction(uint256 tid, uint256 mfDate) internal view returns (uint256) {
        return _serviceDeduction(tid, DeviceTypes.EventType.CALIBRATION, 25, mfDate);
    }

    function _pmDeduction(uint256 tid, uint256 mfDate) internal view returns (uint256) {
        return _serviceDeduction(tid, DeviceTypes.EventType.PREVENTIVE_MAINTENANCE, 25, mfDate);
    }

    function _inspDeduction(uint256 tid, uint256 mfDate) internal view returns (uint256) {
        return _serviceDeduction(tid, DeviceTypes.EventType.INSPECTION, 20, mfDate);
    }

    function _swDeduction(uint256 tid, uint256 mfDate) internal view returns (uint256) {
        (uint256 last, bool passed) = _lastEvent(tid, DeviceTypes.EventType.SOFTWARE_UPDATE);
        if (last > 0 && !passed) return 10;
        if (last == 0 && block.timestamp - mfDate > INTERVAL + THREE_MONTHS) return 5;
        return 0;
    }

    function _partsDeduction(uint256 tid) internal view returns (uint256) {
        uint256 count = log.getEventCount(tid);
        if (count == 0) return 0;
        DeviceTypes.ServiceEvent memory evt = log.getEvent(tid, count - 1);
        if (evt.hasUndocumentedParts)  return 10;
        if (evt.hasCompatibleParts)    return 3;
        return 0;
    }

    function _complaintDeduction(uint256 tid) internal view returns (uint256) {
        uint256 count = log.getEventCount(tid);
        bool hasSerious;
        bool hasMinor;
        for (uint256 i = 0; i < count; i++) {
            DeviceTypes.ServiceEvent memory evt = log.getEvent(tid, i);
            if (evt.eventType == DeviceTypes.EventType.INCIDENT_REPORT
                && !evt.passedInspection) {
                if (evt.isSeriousIncident) hasSerious = true;
                else hasMinor = true;
            }
        }
        if (hasSerious) return 20;
        if (hasMinor)   return 5;
        return 0;
    }

    // ── Generic service event deduction ──────────────────────────

    function _serviceDeduction(
        uint256 tid,
        DeviceTypes.EventType evType,
        uint256 maxPts,
        uint256 mfDate
    ) internal view returns (uint256) {
        (uint256 last, bool passed) = _lastEvent(tid, evType);
        if (last == 0) return (block.timestamp - mfDate > INTERVAL) ? maxPts : 0;
        if (!passed)   return maxPts;
        uint256 overdue = block.timestamp - last;
        if (overdue <= INTERVAL) return 0;
        overdue -= INTERVAL;
        if (overdue <= THREE_MONTHS) return 5;
        if (overdue <= SIX_MONTHS)   return 15;
        return maxPts;
    }

    // ── Last event lookup ─────────────────────────────────────────

    function _lastEvent(
        uint256 tid,
        DeviceTypes.EventType evType
    ) internal view returns (uint256 ts, bool passed) {
        uint256 count = log.getEventCount(tid);
        for (uint256 i = count; i > 0; i--) {
            DeviceTypes.ServiceEvent memory evt = log.getEvent(tid, i - 1);
            if (evt.eventType == evType) return (evt.timestamp, evt.passedInspection);
        }
    }

    // ── Certification level ───────────────────────────────────────

    function getCertLevel(uint256 score)
        external pure returns (DeviceTypes.CertLevel, uint256)
    {
        if (score >= 90) return (DeviceTypes.CertLevel.GOLD,   score);
        if (score >= 75) return (DeviceTypes.CertLevel.SILVER, score);
        return (DeviceTypes.CertLevel.BRONZE, score);
    }

    // ── Compatibility wrapper ─────────────────────────────────────

    function calculateScoreSimple(
        uint256 tokenId,
        DevicePassportNFT,
        ServiceLogRegistry
    ) external view returns (uint256) {
        return calculateScore(tokenId);
    }
}
