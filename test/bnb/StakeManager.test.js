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
        expect(await manager.protocolFeeCommission()).to.equal(10n**17n)
    })

    it("should upgrade to version 2", async function () {
        const [deployer, admin, voter1, voter2, voter3]  = await ethers.getSigners() // use second account as admin
  
        const StakeManager = await ethers.getContractFactory("contracts/bnb/StakeManager.sol:StakeManager")
        const managerV1 = await upgrades.deployProxy(StakeManager, {
            initializer: false,
            kind: 'uups',
        })
        await managerV1.waitForDeployment()
  
        const StakePool = await ethers.getContractFactory("contracts/bnb/StakePool.sol:StakePool")
        const pool = await upgrades.deployProxy(StakePool, {
            initializer: false,
            kind: 'uups',
        })
        await pool.waitForDeployment()

        const LsdToken = await ethers.getContractFactory("LsdToken")
        const lsdToken = await LsdToken.deploy(managerV1.target, "rBNB", "rBNB")
        await pool.waitForDeployment()
  
        const fakeValidator = '0x0000000000000000000000000000000000000001'
        await managerV1.initialize([voter1, voter2, voter3], 2, lsdToken.target, pool.target, fakeValidator, admin)

        const StakeManagerV2 = await ethers.getContractFactory("contracts/mock/MockBnbStakeManagerV2.sol:MockBnbStakeManagerV2")

        // deployer cannot upgrade
        await expect(upgrades.upgradeProxy(managerV1, StakeManagerV2))
            .to.be.rejectedWith("VM Exception while processing transaction: reverted with custom error 'NotOwner()'")
        
        // only admin can upgrade
        const managerV2 = await upgrades.upgradeProxy(managerV1, StakeManagerV2.connect(admin), {
            call: {fn: 'initV2', args: ["this is a v2 variable", 1]}
        });
        
        expect(await managerV2.eraSeconds()).to.equal(86400)
        expect(await managerV2.getBondedPools()).to.deep.equal([pool.target])

        expect(await managerV2.version()).to.equal(2)
        expect(await managerV2.v2var()).to.equal("this is a v2 variable")
        expect(await managerV2.protocolFeeCommission()).to.equal(1)
    })
  })
})