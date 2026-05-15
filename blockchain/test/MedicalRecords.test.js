const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MedicalRecords", function () {
  let contract;
  let admin, doctor, patient, stranger;

  const fakeHash = ethers.keccak256(ethers.toUtf8Bytes("Patient has high blood pressure"));
  const diagnosisLabel = "Cardiology Consult";
  const recordType = "Consultation";

  beforeEach(async function () {
    [admin, doctor, patient, stranger] = await ethers.getSigners();

    const MedicalRecords = await ethers.getContractFactory("MedicalRecords");
    contract = await MedicalRecords.deploy();
    await contract.waitForDeployment();

    await contract.connect(admin).registerDoctor(doctor.address);
    await contract.connect(admin).registerPatient(patient.address);
  });

  // ── Role Assignment ────────────────────────────────────────────────────────
  describe("Role Management", function () {
    it("deployer has admin role", async function () {
      expect(await contract.getRole(admin.address)).to.equal("admin");
    });

    it("registered address has doctor role", async function () {
      expect(await contract.getRole(doctor.address)).to.equal("doctor");
    });

    it("registered address has patient role", async function () {
      expect(await contract.getRole(patient.address)).to.equal("patient");
    });

    it("unregistered address has no role", async function () {
      expect(await contract.getRole(stranger.address)).to.equal("none");
    });

    it("non-admin cannot register a doctor", async function () {
      await expect(
        contract.connect(doctor).registerDoctor(stranger.address)
      ).to.be.reverted;
    });
  });

  // ── Adding Records ─────────────────────────────────────────────────────────
  describe("Adding Records", function () {
    it("doctor can add a record for a registered patient", async function () {
      const tx = await contract
        .connect(doctor)
        .addRecord(patient.address, fakeHash, diagnosisLabel, recordType);

      await expect(tx).to.emit(contract, "RecordAdded");
      expect(await contract.totalRecords()).to.equal(1);
    });

    it("non-doctor cannot add a record", async function () {
      await expect(
        contract.connect(stranger).addRecord(patient.address, fakeHash, diagnosisLabel, recordType)
      ).to.be.reverted;
    });

    it("doctor cannot add record for unregistered patient", async function () {
      await expect(
        contract.connect(doctor).addRecord(stranger.address, fakeHash, diagnosisLabel, recordType)
      ).to.be.revertedWith("Target address is not a registered patient");
    });

    it("doctor cannot add record with empty hash", async function () {
      await expect(
        contract.connect(doctor).addRecord(patient.address, ethers.ZeroHash, diagnosisLabel, recordType)
      ).to.be.revertedWith("Record hash cannot be empty");
    });
  });

  // ── Reading Records ────────────────────────────────────────────────────────
  describe("Reading Records", function () {
    beforeEach(async function () {
      await contract
        .connect(doctor)
        .addRecord(patient.address, fakeHash, diagnosisLabel, recordType);
    });

    it("doctor who created the record can read it (including hash)", async function () {
      const [, , , hash] = await contract.connect(doctor).getRecord(1);
      expect(hash).to.equal(fakeHash);
    });

    it("patient can read their own record (including hash)", async function () {
      const [, , , hash] = await contract.connect(patient).getRecord(1);
      expect(hash).to.equal(fakeHash);
    });

    it("admin CANNOT read the full record", async function () {
      await expect(
        contract.connect(admin).getRecord(1)
      ).to.be.revertedWith("Access denied: not the doctor or patient for this record");
    });

    it("stranger CANNOT read the record", async function () {
      await expect(
        contract.connect(stranger).getRecord(1)
      ).to.be.revertedWith("Access denied: not the doctor or patient for this record");
    });
  });

  // ── Metadata Access ────────────────────────────────────────────────────────
  describe("Metadata Access", function () {
    beforeEach(async function () {
      await contract
        .connect(doctor)
        .addRecord(patient.address, fakeHash, diagnosisLabel, recordType);
    });

    it("admin can read metadata (no hash)", async function () {
      const [id, doc, pat, label, type] = await contract
        .connect(admin)
        .getRecordMetadata(1);

      expect(id).to.equal(1);
      expect(doc).to.equal(doctor.address);
      expect(pat).to.equal(patient.address);
      expect(label).to.equal(diagnosisLabel);
      expect(type).to.equal(recordType);
    });

    it("doctor can read metadata", async function () {
      const [id] = await contract.connect(doctor).getRecordMetadata(1);
      expect(id).to.equal(1);
    });

    it("patient can read metadata", async function () {
      const [id] = await contract.connect(patient).getRecordMetadata(1);
      expect(id).to.equal(1);
    });

    it("stranger cannot read metadata", async function () {
      await expect(
        contract.connect(stranger).getRecordMetadata(1)
      ).to.be.revertedWith("Access denied");
    });
  });

  // ── Record ID Lookups ──────────────────────────────────────────────────────
  describe("Record ID Lookups", function () {
    beforeEach(async function () {
      await contract.connect(doctor).addRecord(patient.address, fakeHash, "Checkup", "Consultation");
      await contract.connect(doctor).addRecord(patient.address, fakeHash, "Blood Test", "Lab Result");
    });

    it("patient can get their own record IDs", async function () {
      const ids = await contract.connect(patient).getPatientRecordIds(patient.address);
      expect(ids.length).to.equal(2);
    });

    it("doctor can get their own record IDs", async function () {
      const ids = await contract.connect(doctor).getDoctorRecordIds(doctor.address);
      expect(ids.length).to.equal(2);
    });

    it("admin can get all record IDs", async function () {
      const ids = await contract.connect(admin).getAllRecordIds();
      expect(ids.length).to.equal(2);
    });

    it("stranger cannot get all record IDs", async function () {
      await expect(
        contract.connect(stranger).getAllRecordIds()
      ).to.be.reverted;
    });
  });
});
