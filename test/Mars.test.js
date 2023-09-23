const { expect } = require("chai");
const { ethers } = require("hardhat");


// describe("Mars", function () {
//   describe("Deployment", function () {
//     it("goes to mars", async function () {
//       const Mars = await ethers.getContractFactory("Mars");
//       const MarsV2 = await ethers.getContractFactory("MarsV2");
      

//       const marsv1 = await hre.upgrades.deployProxy(Mars, ['Mars'], {kind: 'uups'});
      
//       expect(await marsv1.name()).to.equal('Mars');
      
//       const marsv2 = await hre.upgrades.upgradeProxy(marsv1, MarsV2);
//       expect(await marsv2.name()).to.equal('Mars');
//       expect(await marsv2.version()).to.equal('v2');
//     });
//   });
// });

function sleep(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

describe("Mars with timelock", function () {
  describe("Deployment", function () {
    it("goes to mars", async function () {
      const [acc0, acc1, acc2, acc3] = await ethers.getSigners();

      const TimelockController = await ethers.getContractFactory("TimelockController");
      const tlc = await TimelockController.deploy(1, [acc2.address], [acc3.address], acc1);
      
      const Mars = await ethers.getContractFactory("Mars");
     
      const MarsV2 = await ethers.getContractFactory("MarsV2");
      const marsv2Impl = await MarsV2.deploy();

      const marsv1 = await hre.upgrades.deployProxy(Mars, ['Mars'], {kind: 'uups'});
      console.log(acc0.address);
      console.log(await marsv1.owner());

       await marsv1.transferOwnership(tlc.target);
       console.log(tlc.target);
       console.log(await marsv1.owner());

      // todo: check is marsv2 a upgradeable contract
      const upgradeToV2Data = Mars.interface.encodeFunctionData("upgradeTo", [marsv2Impl.target]);
      await tlc.connect(acc2).schedule(marsv1.target, "0x0",upgradeToV2Data ,ethers.encodeBytes32String(""), ethers.encodeBytes32String(""), "0x1");

      await sleep(1000);
      await tlc.connect(acc3).execute(marsv1.target, "0x0",upgradeToV2Data ,ethers.encodeBytes32String(""), ethers.encodeBytes32String(""));
      const marsv2 = MarsV2.attach(marsv1.target);

     
      expect(await marsv2.version()).to.equal('v2');
    });
  });
});