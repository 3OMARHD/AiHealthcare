const { ethers, artifacts } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying MedicalRecords with account:", deployer.address);
  console.log("Account balance:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)), "ETH\n");

  const MedicalRecords = await ethers.getContractFactory("MedicalRecords");
  const contract = await MedicalRecords.deploy();
  await contract.waitForDeployment();

  const contractAddress = await contract.getAddress();
  console.log("✅ MedicalRecords deployed to:", contractAddress);

  const artifact = await artifacts.readArtifact("MedicalRecords");

  const config = {
    contractAddress,
    abi: artifact.abi,
    network: "Hardhat Local (localhost:8545)",
    chainId: 31337,
    deployedAt: new Date().toISOString(),
    deployer: deployer.address,
  };

  const dappDir = path.join(__dirname, "..", "dapp");
  if (!fs.existsSync(dappDir)) fs.mkdirSync(dappDir, { recursive: true });

  fs.writeFileSync(
    path.join(dappDir, "contract-config.json"),
    JSON.stringify(config, null, 2)
  );

  console.log("\n📄 Contract config written to dapp/contract-config.json");
  console.log("\n📋 Next Steps:");
  console.log("1. Open dapp/index.html in your browser (use a local HTTP server)");
  console.log("2. Add Hardhat Local network to MetaMask: RPC=http://127.0.0.1:8545, ChainID=31337");
  console.log("3. Import Hardhat test accounts using private keys shown in the node terminal");
  console.log("4. Connect as Admin and register Doctor + Patient addresses\n");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Deployment failed:", err);
    process.exit(1);
  });