import json
import os
import hashlib
from web3 import Web3

# Connect to local Hardhat node
W3 = Web3(Web3.HTTPProvider("http://127.0.0.1:8545"))

# Load contract config
_config_path = os.path.join(
    os.path.dirname(__file__),
    '..', 'blockchain', 'dapp', 'contract-config.json'
)

try:
    with open(_config_path) as f:
        _config = json.load(f)
    CONTRACT_ADDRESS = Web3.to_checksum_address(_config['contractAddress'])
    CONTRACT_ABI = _config['abi']
    DEPLOYER_ADDRESS = Web3.to_checksum_address(_config['deployer'])
    CONTRACT_CONFIG_LOADED = True
except Exception as e:
    CONTRACT_ADDRESS = None
    CONTRACT_ABI = []
    DEPLOYER_ADDRESS = None
    CONTRACT_CONFIG_LOADED = False
    print(f"Warning: Could not load contract config: {e}")

# Hardhat account #0 private key (admin/deployer)
# This is the fixed private key for Hardhat account #0 — safe for local dev only
DEPLOYER_PRIVATE_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

# Create contract instance only if config loaded
contract = None
if CONTRACT_CONFIG_LOADED and CONTRACT_ADDRESS:
    contract = W3.eth.contract(address=CONTRACT_ADDRESS, abi=CONTRACT_ABI)

# Hardhat test account private keys — local dev only
HARDHAT_KEYS = {
    '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266': '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',  #admin
    '0x70997970c51812dc3a010c7d01b50e0d17dc79c8': '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d',  #doctor
    '0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc': '0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a',  #patient
}

def get_key_for_wallet(wallet: str) -> str:
    return HARDHAT_KEYS.get(wallet.lower())

def _send_tx(fn):
    """Build, sign and send a transaction. Returns tx hash."""
    tx = fn.build_transaction({
        'from': DEPLOYER_ADDRESS,
        'nonce': W3.eth.get_transaction_count(DEPLOYER_ADDRESS),
        'gas': 300000,
        'gasPrice': W3.to_wei('1', 'gwei'),
    })
    signed = W3.eth.account.sign_transaction(tx, DEPLOYER_PRIVATE_KEY)
    tx_hash = W3.eth.send_raw_transaction(signed.raw_transaction)
    W3.eth.wait_for_transaction_receipt(tx_hash)
    return tx_hash.hex()


def register_doctor_onchain(wallet_address: str) -> str:
    """Register a wallet as doctor on the contract. Returns tx hash."""
    addr = Web3.to_checksum_address(wallet_address)
    return _send_tx(contract.functions.registerDoctor(addr))


def register_patient_onchain(wallet_address: str) -> str:
    """Register a wallet as patient on the contract. Returns tx hash."""
    addr = Web3.to_checksum_address(wallet_address)
    return _send_tx(contract.functions.registerPatient(addr))


def add_record_onchain(
    patient_wallet: str,
    doctor_wallet: str,
    doctor_private_key: str,
    diagnosis: str,
    treatment: str,
    patient_id: int,
    doctor_id: int
):
    payload = f"{patient_id}|{doctor_id}|{diagnosis}|{treatment}"
    record_hash_hex = hashlib.sha256(payload.encode()).hexdigest()
    record_hash_bytes = bytes.fromhex(record_hash_hex)

    patient_addr = Web3.to_checksum_address(patient_wallet)
    doctor_addr  = Web3.to_checksum_address(doctor_wallet)

    tx = contract.functions.addRecord(
        patient_addr,
        record_hash_bytes,
        diagnosis[:50],
        "Consultation"
    ).build_transaction({
        'from': doctor_addr,
        'nonce': W3.eth.get_transaction_count(doctor_addr),
        'gas': 500000,
        'gasPrice': W3.to_wei('1', 'gwei'),
    })

    signed = W3.eth.account.sign_transaction(tx, doctor_private_key)
    tx_hash = W3.eth.send_raw_transaction(signed.raw_transaction)
    receipt = W3.eth.wait_for_transaction_receipt(tx_hash)

    logs = contract.events.RecordAdded().process_receipt(receipt)
    blockchain_record_id = logs[0]['args']['recordId'] if logs else None

    return record_hash_hex, blockchain_record_id, tx_hash.hex()


def get_role_onchain(wallet_address: str) -> str:
    """Read the role of a wallet from the contract."""
    addr = Web3.to_checksum_address(wallet_address)
    return contract.functions.getRole(addr).call()


# ─── NEW: Helper functions for admin dashboard integration ─────────────

def is_blockchain_connected() -> bool:
    """Check if the Hardhat blockchain node is reachable."""
    try:
        return W3.is_connected() and contract is not None
    except Exception:
        return False


def get_blockchain_stats() -> dict:
    """
    Get blockchain statistics for the admin dashboard.
    Returns dict with total_records, connected status, contract address.
    """
    stats = {
        'connected': False,
        'total_records': 0,
        'contract_address': CONTRACT_ADDRESS or 'N/A',
        'chain_id': None,
        'block_number': 0,
    }

    try:
        if not is_blockchain_connected():
            return stats

        stats['connected'] = True
        stats['chain_id'] = W3.eth.chain_id
        stats['block_number'] = W3.eth.block_number
        stats['total_records'] = contract.functions.totalRecords().call()

    except Exception as e:
        stats['error'] = str(e)

    return stats


def get_all_record_metadata() -> list:
    """
    Fetch metadata for all records from the blockchain.
    Returns list of dicts with id, doctor, patient, label, type, timestamp.
    """
    records = []
    try:
        if not is_blockchain_connected():
            return records

        all_ids = contract.functions.getAllRecordIds().call(
            {'from': DEPLOYER_ADDRESS}
        )

        for rid in all_ids:
            try:
                data = contract.functions.getRecordMetadata(int(rid)).call(
                    {'from': DEPLOYER_ADDRESS}
                )
                records.append({
                    'id': int(data[0]),
                    'doctor': data[1],
                    'patient': data[2],
                    'diagnosis_label': data[3],
                    'record_type': data[4],
                    'timestamp': int(data[5]),
                })
            except Exception:
                continue

    except Exception:
        pass

    return records


def get_registered_roles(wallet_addresses: list) -> dict:
    """
    Check on-chain role for a list of wallet addresses.
    Returns dict of {wallet_address: role_string}.
    """
    roles = {}
    if not is_blockchain_connected():
        return roles

    for wallet in wallet_addresses:
        try:
            if wallet:
                addr = Web3.to_checksum_address(wallet)
                role = contract.functions.getRole(addr).call()
                roles[wallet.lower()] = role
        except Exception:
            roles[wallet.lower()] = 'error'

    return roles


def sync_user_to_blockchain(wallet_address: str, role: str) -> dict:
    """
    Register a single user on the blockchain based on their role.
    Returns dict with success status, tx_hash.
    """
    result = {'success': False, 'tx_hash': None, 'error': None}

    if not is_blockchain_connected():
        result['error'] = 'Blockchain not connected'
        return result

    try:
        addr = Web3.to_checksum_address(wallet_address)
        current_role = contract.functions.getRole(addr).call()

        # Skip if already registered with correct role
        if (role == 'doctor' and current_role == 'doctor') or \
           (role == 'patient' and current_role == 'patient'):
            result['success'] = True
            result['already_registered'] = True
            return result

        if role == 'doctor':
            tx_hash = register_doctor_onchain(wallet_address)
        elif role == 'patient':
            tx_hash = register_patient_onchain(wallet_address)
        else:
            result['error'] = f'Cannot register role "{role}" on blockchain (only doctor/patient)'
            return result

        result['success'] = True
        result['tx_hash'] = tx_hash

    except Exception as e:
        result['error'] = str(e)

    return result


def compute_record_hash(patient_id: int, doctor_id: int, diagnosis: str, treatment: str) -> str:
    """
    Compute SHA-256 hash for a medical record.
    This is the same hash format used when anchoring to blockchain.
    """
    payload = f"{patient_id}|{doctor_id}|{diagnosis}|{treatment}"
    return hashlib.sha256(payload.encode()).hexdigest()


def verify_record_onchain(blockchain_record_id: int) -> dict:
    """
    Verify a record exists on blockchain and return its metadata.
    """
    result = {'exists': False}

    if not is_blockchain_connected():
        result['error'] = 'Blockchain not connected'
        return result

    try:
        data = contract.functions.getRecordMetadata(blockchain_record_id).call(
            {'from': DEPLOYER_ADDRESS}
        )
        result['exists'] = True
        result['id'] = int(data[0])
        result['doctor'] = data[1]
        result['patient'] = data[2]
        result['diagnosis_label'] = data[3]
        result['record_type'] = data[4]
        result['timestamp'] = int(data[5])
    except Exception as e:
        result['error'] = str(e)

    return result