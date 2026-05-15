-- =====================================================
-- SecureDocs Complete Database Schema
-- Combined from all schema files for DE_PROJECTDUpdate
-- Generated: 2026-05-15
-- =====================================================
-- This file contains every table, index, and constraint
-- needed for the project to run correctly.
-- Usage (PowerShell):
--   Get-Content INFO\securedocs_db_complete.sql | mysql -u root -p
-- =====================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

-- =====================================================
-- Database
-- =====================================================
CREATE DATABASE IF NOT EXISTS `securedocs_db` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `securedocs_db`;

-- =====================================================
-- Table: users
-- Stores all user accounts (patients, doctors, admins)
-- =====================================================
CREATE TABLE IF NOT EXISTS `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role` enum('admin','patient','doctor') DEFAULT 'patient',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `2fa_secret` varchar(255) DEFAULT NULL,
  `auth0_id` varchar(255) DEFAULT NULL,
  `profile_photo` longblob DEFAULT NULL,
  `private_key` text DEFAULT NULL COMMENT 'RSA private key for document signing',
  `public_key` text DEFAULT NULL COMMENT 'RSA public key for signature verification',
  -- Patient / Doctor profile fields
  `first_name` varchar(50) DEFAULT NULL,
  `last_name` varchar(50) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `date_of_birth` date DEFAULT NULL,
  `gender` enum('M','F','O') DEFAULT NULL,
  `blood_type` varchar(5) DEFAULT NULL,
  `emergency_contact` varchar(100) DEFAULT NULL,
  `emergency_phone` varchar(20) DEFAULT NULL,
  -- Doctor-specific fields
  `specialization` varchar(100) DEFAULT NULL,
  `license_number` varchar(50) DEFAULT NULL,
  `doctor_id_image` longblob DEFAULT NULL,
  -- Blockchain
  `wallet_address` varchar(42) DEFAULT NULL COMMENT 'MetaMask Ethereum wallet address',
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `wallet_address` (`wallet_address`),
  KEY `idx_role` (`role`),
  KEY `idx_patient_name` (`first_name`, `last_name`),
  KEY `idx_patient_dob` (`date_of_birth`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
COMMENT='Stores all user accounts including patients, doctors, and admins';

-- =====================================================
-- Table: documents
-- Encrypted document storage with hashes and signatures
-- =====================================================
CREATE TABLE IF NOT EXISTS `documents` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `filename` varchar(255) NOT NULL,
  `original_filename` varchar(255) NOT NULL,
  `upload_time` timestamp NOT NULL DEFAULT current_timestamp(),
  `file_hash` varchar(64) NOT NULL,
  `signature` text DEFAULT NULL,
  `signature_time` timestamp NULL DEFAULT NULL,
  `signed_by` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  FOREIGN KEY (`signed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- =====================================================
-- Table: logs
-- System activity and audit logs
-- =====================================================
CREATE TABLE IF NOT EXISTS `logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) DEFAULT NULL,
  `action_type` varchar(100) DEFAULT NULL,
  `message` text DEFAULT NULL,
  `timestamp` timestamp NOT NULL DEFAULT current_timestamp(),
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` text DEFAULT NULL,
  `affected_record_id` int(11) DEFAULT NULL,
  `affected_record_type` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_logs_username` (`username`),
  KEY `idx_logs_timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- =====================================================
-- Table: medical_records
-- Patient medical records created by doctors
-- Includes blockchain anchoring fields
-- =====================================================
CREATE TABLE IF NOT EXISTS `medical_records` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `patient_id` int(11) NOT NULL,
  `doctor_id` int(11) NOT NULL,
  `record_date` datetime NOT NULL,
  `diagnosis` text NOT NULL,
  `treatment` text DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `follow_up_date` date DEFAULT NULL,
  `signature` text DEFAULT NULL COMMENT 'Digital signature of the record',
  `signature_time` datetime DEFAULT NULL,
  `signed_by` int(11) DEFAULT NULL,
  -- Blockchain integrity fields
  `record_hash` varchar(64) DEFAULT NULL COMMENT 'SHA-256 hash for integrity verification',
  `blockchain_record_id` bigint(20) DEFAULT NULL COMMENT 'Record ID on smart contract',
  `blockchain_tx` varchar(66) DEFAULT NULL COMMENT 'Ethereum transaction hash',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_medical_records_patient` (`patient_id`),
  KEY `idx_medical_records_doctor` (`doctor_id`),
  KEY `idx_record_date` (`record_date`),
  KEY `idx_medical_record_patient_date` (`patient_id`, `record_date`),
  KEY `idx_record_hash` (`record_hash`),
  KEY `idx_blockchain_record_id` (`blockchain_record_id`),
  FOREIGN KEY (`patient_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  FOREIGN KEY (`doctor_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
COMMENT='Medical records created by doctors for patients';

-- =====================================================
-- Table: appointments
-- Patient appointments with doctors
-- =====================================================
CREATE TABLE IF NOT EXISTS `appointments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `patient_id` int(11) NOT NULL,
  `doctor_id` int(11) NOT NULL,
  `appointment_date` datetime NOT NULL,
  `status` enum('scheduled','completed','cancelled','no_show') NOT NULL DEFAULT 'scheduled',
  `reason` text DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_appointments_patient` (`patient_id`),
  KEY `idx_appointments_doctor` (`doctor_id`),
  KEY `idx_appointments_date` (`appointment_date`),
  KEY `idx_appointments_status` (`status`),
  KEY `idx_appointment_patient_status` (`patient_id`, `status`),
  FOREIGN KEY (`patient_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  FOREIGN KEY (`doctor_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
COMMENT='Patient appointments scheduled with doctors';

-- =====================================================
-- Table: prescriptions
-- Medications prescribed by doctors
-- =====================================================
CREATE TABLE IF NOT EXISTS `prescriptions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `patient_id` int(11) NOT NULL,
  `doctor_id` int(11) NOT NULL,
  `prescription_date` datetime NOT NULL,
  `medication_name` varchar(100) NOT NULL,
  `dosage` varchar(50) NOT NULL,
  `frequency` varchar(50) NOT NULL,
  `duration` varchar(50) NOT NULL,
  `instructions` text DEFAULT NULL,
  `status` enum('active','completed','cancelled') NOT NULL DEFAULT 'active',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_prescriptions_patient` (`patient_id`),
  KEY `idx_prescriptions_doctor` (`doctor_id`),
  KEY `idx_prescriptions_status` (`status`),
  KEY `idx_prescriptions_date` (`prescription_date`),
  KEY `idx_prescription_patient_status` (`patient_id`, `status`),
  FOREIGN KEY (`patient_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  FOREIGN KEY (`doctor_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
COMMENT='Medications prescribed by doctors to patients';

-- =====================================================
-- Table: doctor_patient_assignments
-- Doctor-patient relationships
-- =====================================================
CREATE TABLE IF NOT EXISTS `doctor_patient_assignments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `doctor_id` int(11) NOT NULL,
  `patient_id` int(11) NOT NULL,
  `assigned_date` timestamp NOT NULL DEFAULT current_timestamp(),
  `status` enum('active','inactive') NOT NULL DEFAULT 'active',
  `notes` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_assignment` (`doctor_id`,`patient_id`),
  KEY `patient_id` (`patient_id`),
  KEY `idx_doctor_patient_assignments` (`doctor_id`,`patient_id`),
  KEY `idx_assignment_status` (`status`),
  FOREIGN KEY (`doctor_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  FOREIGN KEY (`patient_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
COMMENT='Many-to-many relationship between doctors and their assigned patients';

-- =====================================================
-- Table: doctor_notifications
-- Internal notifications for doctors
-- =====================================================
CREATE TABLE IF NOT EXISTS `doctor_notifications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `doctor_id` int(11) NOT NULL,
  `message` text NOT NULL,
  `is_read` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `doctor_id` (`doctor_id`),
  FOREIGN KEY (`doctor_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- =====================================================
-- Table: notifications
-- Patient-facing notifications
-- =====================================================
CREATE TABLE IF NOT EXISTS `notifications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `patient_id` int(11) NOT NULL,
  `doctor_id` int(11) DEFAULT NULL COMMENT 'Doctor who triggered the notification',
  `notification_type` enum('doctor_access','appointment','prescription','medical_record','message') NOT NULL DEFAULT 'doctor_access',
  `title` varchar(255) NOT NULL,
  `message` text NOT NULL,
  `related_resource_type` varchar(50) DEFAULT NULL COMMENT 'Type: medical_record, appointment, etc.',
  `related_resource_id` int(11) DEFAULT NULL COMMENT 'ID of the related resource',
  `is_read` tinyint(1) DEFAULT 0 COMMENT '0=unread, 1=read',
  `read_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `doctor_id` (`doctor_id`),
  KEY `idx_notifications_patient` (`patient_id`),
  KEY `idx_notifications_read` (`patient_id`,`is_read`),
  KEY `idx_notifications_created` (`created_at`),
  FOREIGN KEY (`patient_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  FOREIGN KEY (`doctor_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- =====================================================
-- Table: radiology_files
-- Patient radiology/MRI scan files and AI analysis results
-- =====================================================
CREATE TABLE IF NOT EXISTS `radiology_files` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `patient_id` int(11) NOT NULL,
  `original_filename` varchar(255) NOT NULL,
  `stored_filename` varchar(255) NOT NULL,
  `file_type` varchar(50) DEFAULT NULL COMMENT 'File extension (jpg, png, pdf, etc.)',
  `folder` varchar(255) DEFAULT NULL COMMENT 'Folder name for organizing scans',
  -- MRI Analysis Results
  `tumor_detected` varchar(50) DEFAULT NULL COMMENT 'Result: Glioma, Meningioma, Pituitary, No Tumor, etc.',
  `confidence` decimal(5,3) DEFAULT NULL COMMENT 'Confidence score 0.000 to 1.000',
  `analysis_date` timestamp NULL DEFAULT NULL COMMENT 'When MRI analysis was performed',
  `analysis_model_version` varchar(50) DEFAULT NULL COMMENT 'Model version used for analysis',
  -- File metadata
  `file_size` bigint(20) DEFAULT NULL COMMENT 'File size in bytes',
  `uploaded_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_radiology_patient` (`patient_id`),
  KEY `idx_radiology_folder` (`patient_id`, `folder`),
  KEY `idx_tumor_detected` (`tumor_detected`),
  KEY `idx_analysis_date` (`analysis_date`),
  KEY `idx_radiology_tumor_confidence` (`tumor_detected`, `confidence`),
  FOREIGN KEY (`patient_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
COMMENT='Radiology scan files (MRI, CT, X-ray) with AI analysis results';

-- =====================================================
-- Table: patient_vital_signs
-- Patient vital signs over time
-- =====================================================
CREATE TABLE IF NOT EXISTS `patient_vital_signs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `patient_id` int(11) NOT NULL,
  `recorded_date` datetime NOT NULL,
  `recorded_by` int(11) DEFAULT NULL COMMENT 'User ID who recorded (doctor/nurse)',
  `blood_pressure_systolic` int(11) DEFAULT NULL,
  `blood_pressure_diastolic` int(11) DEFAULT NULL,
  `heart_rate` int(11) DEFAULT NULL,
  `temperature` decimal(4,1) DEFAULT NULL COMMENT 'Temperature in Celsius',
  `weight` decimal(5,2) DEFAULT NULL COMMENT 'Weight in kg',
  `height` decimal(5,2) DEFAULT NULL COMMENT 'Height in cm',
  `oxygen_saturation` decimal(4,1) DEFAULT NULL COMMENT 'O2 saturation percentage',
  `notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_vitals_patient` (`patient_id`),
  KEY `idx_vitals_date` (`recorded_date`),
  FOREIGN KEY (`patient_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  FOREIGN KEY (`recorded_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- =====================================================
-- Table: patient_allergies
-- Patient allergies and reactions
-- =====================================================
CREATE TABLE IF NOT EXISTS `patient_allergies` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `patient_id` int(11) NOT NULL,
  `allergen` varchar(100) NOT NULL COMMENT 'Substance causing allergy',
  `reaction` text DEFAULT NULL COMMENT 'Type of reaction',
  `severity` enum('mild','moderate','severe','life_threatening') DEFAULT 'moderate',
  `diagnosed_date` date DEFAULT NULL,
  `diagnosed_by` int(11) DEFAULT NULL COMMENT 'Doctor ID who diagnosed',
  `notes` text DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1 COMMENT '1 if allergy is still active',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_allergies_patient` (`patient_id`),
  KEY `idx_allergies_active` (`patient_id`, `is_active`),
  FOREIGN KEY (`patient_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  FOREIGN KEY (`diagnosed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- =====================================================
-- Table: patient_lab_results
-- Lab test results for patients
-- =====================================================
CREATE TABLE IF NOT EXISTS `patient_lab_results` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `patient_id` int(11) NOT NULL,
  `test_name` varchar(255) NOT NULL,
  `test_type` varchar(100) DEFAULT NULL COMMENT 'Blood, Urine, Imaging, etc.',
  `test_date` datetime NOT NULL,
  `ordered_by` int(11) DEFAULT NULL COMMENT 'Doctor ID who ordered',
  `results` text DEFAULT NULL COMMENT 'Test results data',
  `normal_range` varchar(100) DEFAULT NULL,
  `status` enum('pending','completed','cancelled') DEFAULT 'pending',
  `file_attachment` varchar(255) DEFAULT NULL COMMENT 'Path to attached file if any',
  `notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_lab_patient` (`patient_id`),
  KEY `idx_lab_date` (`test_date`),
  KEY `idx_lab_status` (`status`),
  FOREIGN KEY (`patient_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  FOREIGN KEY (`ordered_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- =====================================================
-- Table: medical_record_mri_links
-- Links medical records to specific MRI scans
-- =====================================================
CREATE TABLE IF NOT EXISTS `medical_record_mri_links` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `medical_record_id` int(11) NOT NULL,
  `radiology_file_id` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_record_file_link` (`medical_record_id`, `radiology_file_id`),
  KEY `idx_link_record` (`medical_record_id`),
  KEY `idx_link_file` (`radiology_file_id`),
  FOREIGN KEY (`medical_record_id`) REFERENCES `medical_records` (`id`) ON DELETE CASCADE,
  FOREIGN KEY (`radiology_file_id`) REFERENCES `radiology_files` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- =====================================================
-- VIEWS
-- =====================================================

-- View: Patient Complete Profile
CREATE OR REPLACE VIEW `patient_complete_profile` AS
SELECT
    u.id,
    u.username,
    u.email,
    u.first_name,
    u.last_name,
    CONCAT(u.first_name, ' ', u.last_name) AS full_name,
    u.phone,
    u.date_of_birth,
    TIMESTAMPDIFF(YEAR, u.date_of_birth, CURDATE()) AS age,
    u.gender,
    u.blood_type,
    u.emergency_contact,
    u.emergency_phone,
    u.created_at AS registration_date,
    (SELECT COUNT(*) FROM appointments WHERE patient_id = u.id) AS total_appointments,
    (SELECT COUNT(*) FROM medical_records WHERE patient_id = u.id) AS total_medical_records,
    (SELECT COUNT(*) FROM prescriptions WHERE patient_id = u.id AND status = 'active') AS active_prescriptions,
    (SELECT COUNT(*) FROM radiology_files WHERE patient_id = u.id) AS total_scans,
    (SELECT COUNT(*) FROM radiology_files WHERE patient_id = u.id AND tumor_detected IS NOT NULL AND tumor_detected != 'No Tumor' AND tumor_detected != 'notumor') AS scans_with_tumors
FROM users u
WHERE u.role = 'patient';

-- View: Patient MRI Analysis Summary
CREATE OR REPLACE VIEW `patient_mri_summary` AS
SELECT
    rf.patient_id,
    COUNT(*) AS total_scans,
    SUM(CASE WHEN rf.tumor_detected IS NOT NULL THEN 1 ELSE 0 END) AS analyzed_scans,
    SUM(CASE WHEN rf.tumor_detected IS NOT NULL AND rf.tumor_detected != 'No Tumor' AND rf.tumor_detected != 'notumor' THEN 1 ELSE 0 END) AS tumor_detected_count,
    MAX(rf.confidence) AS highest_confidence,
    MIN(rf.confidence) AS lowest_confidence,
    AVG(rf.confidence) AS average_confidence,
    MAX(rf.analysis_date) AS latest_analysis_date
FROM radiology_files rf
GROUP BY rf.patient_id;

-- =====================================================
COMMIT;
-- =====================================================

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

-- =====================================================
-- END OF COMPLETE SCHEMA
-- =====================================================
