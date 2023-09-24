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
  const timelockCtlAddr = "0x7a2088a1bFc9d81c55368AE168C2C02570cB814F";
  const uupsProxyAddr = "0x09635F643e140090A9A8Dcd712eD6285858ceBef";
  const marsv2ImplAddr = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";

  const [acc0, acc1, acc2, acc3] = await ethers.getSigners();
  const TimelockController = await ethers.getContractFactory("TimelockController");
  const tlc = TimelockController.attach(timelockCtlAddr);
  console.log("timelock ctl addr:", tlc.target);


  const Mars = await ethers.getContractFactory("Mars");
  const MarsV2 = await ethers.getContractFactory("MarsV2");

  const marsv1 = Mars.attach(uupsProxyAddr);

  // check if is MarsV2 a safe upgradeable contract
  await hre.upgrades.validateUpgrade(Mars, MarsV2);
  console.log("MarsV2 contract addr:", marsv2ImplAddr);

  const initFnCallData = MarsV2.interface.encodeFunctionData("initializev2", [2]);
  const upgradeToV2Data = Mars.interface.encodeFunctionData("upgradeToAndCall", [marsv2ImplAddr, initFnCallData]);
  await tlc.connect(acc3).execute(marsv1.target, "0x0", upgradeToV2Data, ethers.encodeBytes32String(""), ethers.encodeBytes32String(""));
  const marsv2 = MarsV2.attach(marsv1.target);

  expect(await marsv2.version()).to.equal(2);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
