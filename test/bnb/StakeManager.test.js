const { expect } = require("chai")
const { ethers, upgrades } = require("hardhat")

describe("StakeManager (BNB)", function () {
  describe("Deployment", function () {
    it("should deploy with uups", async function () {
        const StakeManager = await ethers.getContractFactory("contracts/bnb/StakeManager.sol:StakeManager")
        const manager = await upgrades.deployProxy(StakeManager, {
            initializer: false,
            kind: 'uups',
        })
        await manager.waitForDeployment()

        expect(await manager.owner()).to.equal('0x0000000000000000000000000000000000000000')
        expect(await manager.version()).to.equal(0)
    })

    it("should initialize contract states", async function () {
        const [deployer, admin, voter1, voter2, voter3]  = await ethers.getSigners() // use second account as admin
  
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

        const LsdToken = await ethers.getContractFactory("LsdToken")
        const lsdToken = await LsdToken.deploy(manager.target, "rBNB", "rBNB")
        await pool.waitForDeployment()
  
        const fakeValidator = '0x0000000000000000000000000000000000000001'
        await manager.initialize([voter1, voter2, voter3], 2, lsdToken.target, pool.target, fakeValidator, admin)

        expect(await manager.owner()).to.equal(admin.address)
        expect(await manager.version()).to.equal(1)
        expect(await manager.eraSeconds()).to.equal(86400)
        expect(await manager.getBondedPools()).to.deep.equal([pool.target])
    })
  })
})