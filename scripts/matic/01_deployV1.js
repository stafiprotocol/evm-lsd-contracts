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
  const [acc0, acc1, acc2, acc3] = await ethers.getSigners();

  const TimelockController = await ethers.getContractFactory("TimelockController");
  const tlc = await TimelockController.deploy(minDelay, [acc2.address], [acc3.address], acc1);

  const Mars = await ethers.getContractFactory("Mars");

  const MarsV2 = await ethers.getContractFactory("MarsV2");

  // check if MarsV2 is a safe upgradeable contract
  await hre.upgrades.validateUpgrade(Mars, MarsV2);
  const marsv2ImplAddr = await hre.upgrades.deployImplementation(MarsV2, false);
  console.log(marsv2ImplAddr);

  const marsv1 = await hre.upgrades.deployProxy(Mars, ['Mars'], { kind: 'uups' });

  await marsv1.transferOwnership(tlc.target);


   expect(await marsv1.version()).to.equal(1);


 

  console.log("min delay:", minDelay);
  console.log("admin: acc1:", acc1.address);
  console.log("proposer1: acc2:", acc2.address);
  console.log("executor: acc3:", acc3.address);
  console.log("timelock ctl addr:", tlc.target);

  console.log("UUPS proxy addr:", marsv1.target);
  console.log("UUPS proxy owner addr:", await marsv1.owner());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
