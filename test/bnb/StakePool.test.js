const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("StakePool (BNB)", function () {
  describe("Deployment", function () {
    it("should deploy with uups", async function () {
        const StakePool = await ethers.getContractFactory("contracts/bnb/StakePool.sol:StakePool")
        const pool = await upgrades.deployProxy(StakePool, {
            initializer: false,
            kind: 'uups',
        })
        expect(await pool.version()).to.equal(0)
    });
  });
});