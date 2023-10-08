const hre = require("hardhat");
const { expect } = require("chai");


let factoryAdmin = "";           // factory admin: 

// Dev Hardhat
const minDelay = 100;
const govStakeManagerAddress = "0x00200eA4Ee292E253E6Ca07dBA5EdC07c8Aa37A3";
const validatorShareAddress = "0x15ED57Ca28cbebb58d9c6C62F570046BC089bC66";
let stakeTokenAddress = "";

// Goerli
// const minDelay = 100;
// const govStakeManagerAddress = "0x00200eA4Ee292E253E6Ca07dBA5EdC07c8Aa37A3";
// const validatorShareAddress = "0x15ED57Ca28cbebb58d9c6C62F570046BC089bC66";
// const stakeTokenAddress = "0x0165878A594ca255338adfa4d48449f69242Eb8F";

// Mainnet
// const minDelay = FIXME;
// const govStakeManagerAddress = "0x5e3Ef299fDDf15eAa0432E6e66473ace8c13D908";
// const validatorShareAddress = "0x01d5dc56ad4206bb0c132d834644d57f51fed5ec";
// const stakeTokenAddress = "0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0";

async function main() {
  const [acc0, acc1, acc2, acc3] = await ethers.getSigners();
  if (!factoryAdmin) {
    console.log("WARN: use acc1 as factory admin");
    factoryAdmin = acc1.address;
  }
  if (!stakeTokenAddress) {
    const DummyToken = await hre.ethers.getContractFactory("ERC20");
    const token = await DummyToken.deploy("Dummy Token", "DMTK");
    stakeTokenAddress = token.target;
    console.log("WARN: created dummy token as stake token:", stakeTokenAddress);
  }

  const MaticStakeManager = await hre.ethers.getContractFactory("contracts/matic/StakeManager.sol:StakeManager");
  const managerLogicContract = await MaticStakeManager.deploy();

  const MaticStakePool = await hre.ethers.getContractFactory("contracts/matic/StakePool.sol:StakePool");
  const poolLogicContract = await MaticStakePool.deploy();

  const stakeManagerLogicAddress = managerLogicContract.target;
  const stakePoolLogicAddress = poolLogicContract.target;

  const LsdNetworkFactory = await hre.ethers.getContractFactory("contracts/matic/LsdNetworkFactory.sol:LsdNetworkFactory");

  initArgs = [factoryAdmin, govStakeManagerAddress, validatorShareAddress, stakeTokenAddress, stakeManagerLogicAddress, stakePoolLogicAddress];
  const factory = await hre.upgrades.deployProxy(LsdNetworkFactory, initArgs, { kind: 'uups' });

  console.log("MATIC Stake Manager Logic Address:", stakeManagerLogicAddress);
  console.log("MATIC Stake Pool Logic Address:", stakePoolLogicAddress);

  console.log("Factory UUPS proxy addr:", factory.target);
  console.log("Factory UUPS proxy admin addr:", await factory.factoryAdmin());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
