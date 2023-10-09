const { expect } = require("chai")
const { ethers, upgrades } = require("hardhat")

const bnbGovStakingAddress = '0x0000000000000000000000000000000000002001'

describe("StakePool (BNB)", function () {
  describe("Deployment", function () {
    it("should deploy with uups", async function () {
      const StakePool = await ethers.getContractFactory("contracts/bnb/StakePool.sol:StakePool")
      const pool = await upgrades.deployProxy(StakePool, {
          initializer: false,
          kind: 'uups',
      })
      await pool.waitForDeployment()
      expect(await pool.owner()).to.equal('0x0000000000000000000000000000000000000000')
      expect(await pool.version()).to.equal(0)
    })

    it("should initialize contract states", async function () {
      const [deployer, admin]  = await ethers.getSigners() // use second account as admin

      const StakeManager = await ethers.getContractFactory("contracts/bnb/StakeManager.sol:StakeManager")
      const manager = await upgrades.deployProxy(StakeManager, {
          initializer: false,
          kind: 'uups',
      })
      await manager.waitForDeployment()

      const StakePool = await ethers.getContractFactory("contracts/bnb/StakePool.sol:StakePool")
      const pool = await upgrades.deployProxy(StakePool, {
          initializer: false,
          kind: 'uups',
      })
      await pool.waitForDeployment()

      await pool.initialize(bnbGovStakingAddress, manager.target, admin)

      expect(await pool.owner()).to.equal(admin.address)
      expect(await pool.version()).to.equal(1)
    })
  })
})