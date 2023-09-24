// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const { expect } = require("chai");

// Step 1: Deploy Timelock controller

function sleep(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

async function main() {
  const minDelay = 100;

  const timelockCtlAddr = "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6";
  const uupsProxyAddr = "0x8A791620dd6260079BF849Dc5567aDC3F2FdC318";
  const [acc0, acc1, acc2, acc3] = await ethers.getSigners();
  const TimelockController = await ethers.getContractFactory("TimelockController");
  const tlc = TimelockController.attach(timelockCtlAddr);
  console.log("timelock ctl addr:", tlc.target);


  const Mars = await ethers.getContractFactory("Mars");
  const MarsV2 = await ethers.getContractFactory("MarsV2");

  const marsv1 = Mars.attach(uupsProxyAddr);

  // check if is MarsV2 a safe upgradeable contract
  await hre.upgrades.validateUpgrade(Mars, MarsV2);
  const marsv2ImplAddr = await hre.upgrades.deployImplementation(MarsV2, false);
  console.log("MarsV2 contract addr:", marsv2ImplAddr);
  
  
  const upgradeToV2Data = Mars.interface.encodeFunctionData("upgradeTo", [marsv2ImplAddr]);
  
  await tlc.connect(acc2).schedule(marsv1.target, "0x0", upgradeToV2Data, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""), minDelay);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
