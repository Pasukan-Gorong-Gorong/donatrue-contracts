import hre from "hardhat";
import "dotenv/config";
import { parseEther } from "ethers";

async function main() {
  const provider = new hre.ethers.JsonRpcProvider(
    "https://testnet.bitfinity.network",
    {
      chainId: 355113,
      name: "testnet.bitfinity.network",
      ensAddress: "0x0000000000000000000000000000000000000000",
      ensNetwork: 1,
    }
  );

  const deployerWallet = new hre.ethers.Wallet(
    process.env.PRIVATE_KEY!,
    provider
  );

  const factory = await hre.ethers.getContractFactory("CreatorFactory");
  const deployedFactory = await factory.deploy(parseEther("0.001"));

  await deployedFactory.waitForDeployment();
  console.log("Factory deployed to:", deployedFactory.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
