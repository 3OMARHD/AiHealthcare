# Secure Health — Blockchain-Anchored Medical Records System

Secure Health is a full-stack healthcare application that combines a Flask web backend, MySQL data storage, and an Ethereum-compatible smart contract layer to give medical records tamper-evident, verifiable integrity. Doctors sign and anchor patient records on-chain via MetaMask; patients and admins can independently verify record authenticity against the blockchain. The system also includes an AI-assisted MRI brain tumor classification module and a security layer built for healthcare-grade data protection.

## Core Concept

Traditional medical record systems store data in a database with no independent way to prove a record hasn't been altered after the fact. Secure Health addresses this by:

1. Storing full record data (diagnosis, treatment) encrypted in MySQL, scoped to role-based access.
2. Hashing and RSA-signing each record server-side at creation time.
3. Anchoring the record hash on a local Ethereum blockchain (Hardhat) through a doctor-signed MetaMask transaction.
4. Letting patients and admins verify a record's on-chain hash matches its database state — exposing tampering if the two diverge.

Admins can see *who* accessed or modified *what* (audit trail, doctor → patient transaction ledger) without seeing clinical content itself (diagnosis/treatment are not visible on the admin dashboard).

## Features

### Roles
- **Patient** — registers, books appointments, views own medical records with on-chain verification badges.
- **Doctor** — manages assigned patients and appointments, creates medical records, signs and anchors records on-chain via MetaMask.
- **Admin** — user and wallet management, blockchain status dashboard, transaction ledger (metadata only, no clinical data), record verification tool.

### Blockchain Integration
- Solidity smart contract (`MedicalRecords`) deployed to a local Hardhat network (Chain ID `31337`)
- Contract functions: `registerDoctor`, `registerPatient`, `addRecord`, `getRecord`, `getPatientRecordIds`, `getAllRecordIds`
- Doctor-signed transactions via MetaMask + ethers.js for on-chain record anchoring
- On-chain verification badge and transaction hash lookup from the patient dashboard

### AI-Assisted Diagnostics
- MRI brain tumor classification using a Keras/TensorFlow CNN
- Accepts 224×224 RGB input, binary classification output
- Pluggable model file (`mri_brain_tumor.h5`) loaded at runtime

### Security Layer
- **Authentication**: bcrypt password hashing, 12+ character complexity requirement, TOTP-based two-factor authentication (pyotp)
- **Session security**: IP/user-agent validation, session existence checks per request, hijacking detection
- **Authorization**: Role-based access control (Patient / Doctor / Admin) with resource-level permission checks (e.g., a doctor may only access assigned patients)
- **Input handling**: parameterized SQL queries, SQL injection and XSS pattern detection, path traversal protection on file uploads, filename/type/size validation
- **CSRF protection**: per-session tokens, validated on all POST requests
- **Rate limiting**: login/2FA/registration attempt throttling with lockout windows
- **Encryption**: AES-256 (Fernet) for sensitive fields at rest; RSA digital signatures for record integrity; HTTPS enforced in production
- **Audit logging**: every data access, modification, login/logout, and permission denial is logged with user, timestamp, IP, and outcome
- **Security headers**: CSP, HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy
- **Error handling**: generic user-facing errors, full detail logged server-side only

## Technical Stack

**Backend**
- Python 3.10+, Flask
- MySQL (via XAMPP)
- PyCryptodome / `cryptography` (Fernet, AES-256)
- Flask-Session, Flask-Bcrypt, pyotp
- TensorFlow / Keras (MRI classification)

**Blockchain**
- Solidity smart contracts
- Hardhat (local Ethereum network, Chain ID 31337)
- ethers.js
- MetaMask (transaction signing)

**Frontend**
- HTML5, CSS3, Bootstrap 5, Font Awesome
- JavaScript

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│   Browser   │────▶│  Flask App   │────▶│  MySQL (XAMPP)   │
│  (MetaMask) │     │  :5000       │     │  securedocs_db   │
└──────┬──────┘     └──────┬───────┘     └─────────────────┘
       │                   │
       │  ethers.js        │  web3 (blockchain_utils.py)
       ▼                   ▼
┌──────────────────────────────────┐
│     Hardhat Local Blockchain     │
│     :8545  (Chain ID: 31337)     │
│                                  │
│  MedicalRecords Contract         │
│  - registerDoctor()              │
│  - registerPatient()             │
│  - addRecord()  ← MetaMask       │
│  - getRecord()                   │
│  - getPatientRecordIds()         │
│  - getAllRecordIds()             │
└──────────────────────────────────┘
```

**Record creation flow:**
1. Doctor submits diagnosis/treatment via dashboard.
2. Flask saves the record to MySQL and RSA-signs it.
3. Browser prompts MetaMask; doctor confirms the transaction.
4. `addRecord()` anchors the record hash on-chain (patient, hash, label, type).
5. MySQL is updated with the resulting transaction hash.
6. Patient sees an on-chain verification badge and can independently confirm the hash via MetaMask.

## Setup

### Prerequisites

| Software | Version | Notes |
|---|---|---|
| XAMPP (MySQL + Apache) | 8.x | Local database |
| Python | 3.10+ | Backend runtime |
| Node.js | 18+ | Hardhat/blockchain tooling |
| MetaMask | Latest | Browser extension for transaction signing |

### 1. Database
```bash
# Start MySQL via XAMPP, then create the database
# In phpMyAdmin: New → securedocs_db → Import → INFO/securedocs_db_complete.sql
```
Or via CLI:
```bash
Get-Content "INFO\securedocs_db_complete.sql" | & "C:\xampp\mysql\bin\mysql.exe" -u root securedocs_db
```

### 2. Python Environment
```bash
cd INFO
python -m venv .venv
.\.venv\Scripts\Activate     # Windows
pip install -r requirements.txt
```

Create a `.env` file:
```
SECRET_KEY=your-secret-key
ENCRYPTION_KEY=your-fernet-key
MYSQL_HOST=localhost
MYSQL_USER=root
MYSQL_PASSWORD=
MYSQL_DB=securedocs_db
SESSION_COOKIE_SECURE=False   # set True in production (HTTPS)
```

Generate keys:
```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"                          # SECRET_KEY
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"  # ENCRYPTION_KEY
```

### 3. MRI Model
Place a trained Keras model at `model/mri_brain_tumor.h5`:
- Input shape: `(224, 224, 3)`
- Output: single sigmoid value (binary classification)
- Source it from a public dataset/notebook or train your own (see `MODEL_SETUP_GUIDE.md` for a minimal training script).

### 4. Blockchain
```bash
cd blockchain
npm install

# Terminal 1 — keep running
npx hardhat node

# Terminal 2
npx hardhat run scripts/deploy.js --network localhost
# Note the deployed contract address
```

Add the Hardhat network to MetaMask:

| Field | Value |
|---|---|
| Network Name | Hardhat Local |
| RPC URL | `http://127.0.0.1:8545` |
| Chain ID | `31337` |
| Currency | ETH |

Import test accounts (Admin, Doctor, Patient) from the Hardhat node output into MetaMask.

### 5. Run the App
```bash
cd INFO
python app.py
```
App runs at `http://127.0.0.1:5000`. Three terminals should be active: Hardhat node, deployed contract, Flask app.

## Usage Overview

1. Register as Patient or Doctor, providing a wallet address matching an imported MetaMask account.
2. Complete 2FA setup (scan TOTP QR code).
3. Patient books an appointment with a registered doctor.
4. Doctor switches MetaMask to their wallet, opens the appointment, and adds a medical record — this triggers the sign-and-anchor flow.
5. Patient views the record with its on-chain badge and can verify the transaction from their dashboard.
6. Admin monitors system-wide activity (user counts, on-chain record counts, transaction ledger, wallet assignment) without visibility into clinical content.

## Project Structure

```
INFO/                      # Flask application (routes, models, MRI module)
├── model/                 # MRI classifier (mri_brain_tumor.h5)
├── security_module.py     # Rate limiting, validation, CSRF, encryption, audit logging, access control
├── security_middleware.py # Security headers, request validation/monitoring
├── security_integration.py# Flask decorators and integration helpers
├── app.py
blockchain/                # Hardhat project: contracts, deploy scripts
```

## Acknowledgments

Built on top of an earlier document-management project ("SecureDocs"), extended with role-based clinical workflows, blockchain-anchored record integrity, and MRI-based diagnostic assistance.

## License

MIT License — see `LICENSE` for details.
