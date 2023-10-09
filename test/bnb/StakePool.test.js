const { expect } = require("chai")
const { ethers, upgrades } = require("hardhat")

const bnbGovStakingAddress = '0x0000000000000000000000000000000000002001'

describe("StakePool (BNB)", function () {
  describe("Deployment", function () {
    let manager
    let lsdToken

    beforeEach(async () => {
      const StakeManager = await ethers.getContractFactory("contracts/bnb/StakeManager.sol:StakeManager")
      manager = await upgrades.deployProxy(StakeManager, {
          initializer: false,
          kind: 'uups',
      })
      await manager.waitForDeployment()

      const LsdToken = await ethers.getContractFactory("LsdToken")
      lsdToken = await LsdToken.deploy(manager.target, "rBNB", "rBNB")
      await lsdToken.waitForDeployment()
    })

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

      const StakePool = await ethers.getContractFactory("contracts/bnb/StakePool.sol:StakePool")
      const pool = await upgrades.deployProxy(StakePool, {
          initializer: false,
          kind: 'uups',
      })
      await pool.waitForDeployment()
      await pool.initialize(bnbGovStakingAddress, manager.target, admin)

      expect(await pool.owner()).to.equal(admin.address)
      expect(await pool.stakingAddress()).to.equal(bnbGovStakingAddress)
      expect(await pool.stakeManagerAddress()).to.equal(manager.target)
      expect(await pool.version()).to.equal(1)
    })

    it("should upgrade to version 2", async function () {
      const [deployer, admin, voter1, voter2, voter3]  = await ethers.getSigners() // use second account as admin

      const StakePool = await ethers.getContractFactory("contracts/bnb/StakePool.sol:StakePool")
      const poolV1 = await upgrades.deployProxy(StakePool, {
          initializer: false,
          kind: 'uups',
      })
      await poolV1.waitForDeployment()
      await poolV1.initialize(bnbGovStakingAddress, manager.target, admin)

      const StakePoolV2 = await ethers.getContractFactory("contracts/mock/MockBnbStakePoolV2.sol:MockBnbStakePoolV2")

      // deployer cannot upgrade
      await expect(upgrades.upgradeProxy(poolV1, StakePoolV2))
          .to.be.rejectedWith("VM Exception while processing transaction: reverted with custom error 'NotOwner()'")
      
      // only admin can upgrade
      const poolV2 = await upgrades.upgradeProxy(poolV1, StakePoolV2.connect(admin), {
          call: {fn: 'initV2', args: ["this is a v2 variable", "0x0000000000000000000000000000000000000099"]}
      });

      expect(await poolV2.owner()).to.equal(admin.address)
      expect(await poolV2.stakeManagerAddress()).to.equal(manager.target)
      
      expect(await poolV2.version()).to.equal(2)
      expect(await poolV2.v2var()).to.equal("this is a v2 variable")
      expect(await poolV2.stakingAddress()).to.equal("0x0000000000000000000000000000000000000099")
    })
  })
})