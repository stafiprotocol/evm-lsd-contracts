const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("StakeManager (BNB)", function () {
  describe("Deployment", function () {
    it("should deploy with uups", async function () {
        const StakeManager = await ethers.getContractFactory("contracts/bnb/StakeManager.sol:StakeManager")
        const manager = await upgrades.deployProxy(StakeManager, {
            initializer: false,
            kind: 'uups',
        })
        expect(await manager.version()).to.equal(0)
    });
  });
});