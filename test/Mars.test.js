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

function genOperation(target, value, data, predecessor, salt) {
  const id = web3.utils.keccak256(
    web3.eth.abi.encodeParameters(
      ['address', 'uint256', 'bytes', 'uint256', 'bytes32'],
      [target, value, data, predecessor, salt],
    ),
  );
  return { id, target, value, data, predecessor, salt };
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
      
      await marsv1.upgradeTo(marsv2Impl.target);
      const marsv2 = MarsV2.attach(marsv1.target);

      // await marsv1.transferOwnership(tlc.target);

      // console.log(await marsv1.owner());
      // console.log(tlc.target);

     
      // console.log(Mars.interface.encodeFunctionData("upgradeTo", []));

      // console.log(Mars);
      // await tlc.schedule(marsv1.target,0, ,0,0,2)

      // expect(await marsv1.name()).to.equal('Mars');
      
      // const marsv2 = await hre.upgrades.upgradeProxy(marsv1, MarsV2);
      // expect(await marsv2.name()).to.equal('Mars');
      expect(await marsv2.version()).to.equal('v2');
    });
  });
});