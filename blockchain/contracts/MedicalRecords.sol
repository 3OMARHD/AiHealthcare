// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title MedicalRecords
 * @dev Blockchain-based medical records system with role-based access control.
 *
 * Roles:
 *  - DEFAULT_ADMIN_ROLE: Can grant/revoke roles. Sees metadata only.
 *  - DOCTOR_ROLE: Can add records and view full records they created.
 *  - PATIENT_ROLE: Can view full records linked to their address.
 *
 * Storage strategy:
 *  - Only the SHA-256 hash of the record content is stored on-chain.
 *  - The actual record content lives off-chain (local DApp storage).
 *  - The hash acts as a tamper-proof integrity proof.
 */
contract MedicalRecords is AccessControl {
    bytes32 public constant DOCTOR_ROLE = keccak256("DOCTOR_ROLE");
    bytes32 public constant PATIENT_ROLE = keccak256("PATIENT_ROLE");

    uint256 private _recordCounter;

    struct Record {
        uint256 id;
        address doctor;
        address patient;
        bytes32 recordHash;       // SHA-256 hash of actual record content
        string  diagnosisLabel;   // Short label visible to admin (e.g. "Cardiology Consult")
        string  recordType;       // e.g. "Consultation", "Lab Result", "Prescription"
        uint256 timestamp;
        bool    exists;
    }

    // recordId => Record
    mapping(uint256 => Record) private _records;

    // patient address => list of their record IDs
    mapping(address => uint256[]) private _patientRecords;

    // doctor address => list of record IDs they created
    mapping(address => uint256[]) private _doctorRecords;

    // Total record count (for admin metadata)
    uint256[] private _allRecordIds;

    // ─── Events ──────────────────────────────────────────────────────────────
    event RecordAdded(
        uint256 indexed recordId,
        address indexed doctor,
        address indexed patient,
        bytes32 recordHash,
        string  diagnosisLabel,
        string  recordType,
        uint256 timestamp
    );

    event RoleGrantedToUser(address indexed account, bytes32 role);

    // ─── Constructor ─────────────────────────────────────────────────────────
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // ─── Role Management ─────────────────────────────────────────────────────

    /**
     * @dev Grant DOCTOR_ROLE to an address. Admin only.
     */
    function registerDoctor(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(DOCTOR_ROLE, account);
        emit RoleGrantedToUser(account, DOCTOR_ROLE);
    }

    /**
     * @dev Grant PATIENT_ROLE to an address. Admin only.
     */
    function registerPatient(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(PATIENT_ROLE, account);
        emit RoleGrantedToUser(account, PATIENT_ROLE);
    }

    // ─── Record Management ───────────────────────────────────────────────────

    /**
     * @dev Add a new medical record. Doctor only.
     * @param patient          The patient's wallet address.
     * @param recordHash       SHA-256 hash of the full record content (computed off-chain).
     * @param diagnosisLabel   Short human-readable label visible to admin.
     * @param recordType       Category of record (Consultation / Lab / Prescription).
     */
    function addRecord(
        address patient,
        bytes32 recordHash,
        string calldata diagnosisLabel,
        string calldata recordType
    ) external onlyRole(DOCTOR_ROLE) returns (uint256) {
        require(hasRole(PATIENT_ROLE, patient), "Target address is not a registered patient");
        require(recordHash != bytes32(0), "Record hash cannot be empty");
        require(bytes(diagnosisLabel).length > 0, "Diagnosis label cannot be empty");

        _recordCounter++;
        uint256 newId = _recordCounter;

        _records[newId] = Record({
            id:             newId,
            doctor:         msg.sender,
            patient:        patient,
            recordHash:     recordHash,
            diagnosisLabel: diagnosisLabel,
            recordType:     recordType,
            timestamp:      block.timestamp,
            exists:         true
        });

        _patientRecords[patient].push(newId);
        _doctorRecords[msg.sender].push(newId);
        _allRecordIds.push(newId);

        emit RecordAdded(
            newId,
            msg.sender,
            patient,
            recordHash,
            diagnosisLabel,
            recordType,
            block.timestamp
        );

        return newId;
    }

    // ─── Read Functions ───────────────────────────────────────────────────────

    /**
     * @dev Get full record details. Only the doctor who created it or the patient it belongs to.
     */
    function getRecord(uint256 recordId)
        external
        view
        returns (
            uint256 id,
            address doctor,
            address patient,
            bytes32 recordHash,
            string memory diagnosisLabel,
            string memory recordType,
            uint256 timestamp
        )
    {
        Record storage r = _records[recordId];
        require(r.exists, "Record does not exist");
        require(
            msg.sender == r.doctor || msg.sender == r.patient,
            "Access denied: not the doctor or patient for this record"
        );

        return (r.id, r.doctor, r.patient, r.recordHash, r.diagnosisLabel, r.recordType, r.timestamp);
    }

    /**
     * @dev Get record metadata only (no content hash). Admin, doctor, or patient.
     */
    function getRecordMetadata(uint256 recordId)
        external
        view
        returns (
            uint256 id,
            address doctor,
            address patient,
            string memory diagnosisLabel,
            string memory recordType,
            uint256 timestamp
        )
    {
        Record storage r = _records[recordId];
        require(r.exists, "Record does not exist");
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) ||
            msg.sender == r.doctor ||
            msg.sender == r.patient,
            "Access denied"
        );

        return (r.id, r.doctor, r.patient, r.diagnosisLabel, r.recordType, r.timestamp);
    }

    /**
     * @dev Get all record IDs for a patient. Doctor or the patient themselves.
     */
    function getPatientRecordIds(address patient)
        external
        view
        returns (uint256[] memory)
    {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) ||
            msg.sender == patient ||
            hasRole(DOCTOR_ROLE, msg.sender),
            "Access denied"
        );
        return _patientRecords[patient];
    }

    /**
     * @dev Get all record IDs created by a doctor. Doctor themselves or admin.
     */
    function getDoctorRecordIds(address doctor)
        external
        view
        returns (uint256[] memory)
    {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || msg.sender == doctor,
            "Access denied"
        );
        return _doctorRecords[doctor];
    }

    /**
     * @dev Get all record IDs in the system. Admin only.
     */
    function getAllRecordIds() external view onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256[] memory) {
        return _allRecordIds;
    }

    /**
     * @dev Get the role of a given address (returns "admin", "doctor", "patient", or "none").
     */
    function getRole(address account) external view returns (string memory) {
        if (hasRole(DEFAULT_ADMIN_ROLE, account)) return "admin";
        if (hasRole(DOCTOR_ROLE, account))         return "doctor";
        if (hasRole(PATIENT_ROLE, account))        return "patient";
        return "none";
    }

    /**
     * @dev Get total number of records.
     */
    function totalRecords() external view returns (uint256) {
        return _recordCounter;
    }
}
