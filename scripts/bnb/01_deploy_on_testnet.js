const { ethers, upgrades } = require("hardhat")

// step1. deploy StakeManager and StakePool via remix

// testnet
let stakeManagerLogicAddress = "0xE27Df917b7557f0B427c768e90819D1e6Db70F1E"
let stakePoolLogicAddress = "0x3C5EA15f6e702FcC0351605b867E9ff33E1fd6BF"
let lsdTokenAddress = "0x97813c834c4a601CF13Cf969401E91fDAb917c44"
let stakeManagerProxyAddress = "0x5e44EFdb2F1D7b1bcaA34d622F8945786cBAdE43"
let stakePoolProxyAddress = "0xb9F68498237Cc0ebD655fD9E9D7Dd6D78aB27FE4"
const validatorAddress = "0x0cDcE3d8D17c0553270064cEe95C73F17534d5A0"
const bnbGovStakingAddress = '0x0000000000000000000000000000000000002001'

async function main() {
    console.log("Retriving accounts...")
    const accounts = (await ethers.getSigners()).slice(0, 10)
    const [deployer, admin, voter1, voter2, voter3] = accounts
    for (const acc of accounts) {
        console.log(acc.address)
    }
    console.log()

    console.log("Deploying LSDToken...")
    const lsdToken = await ethers.getContractAt("contracts/LsdToken.sol:LsdToken", lsdTokenAddress)
    console.log("lsd token:", lsdToken.target)
    console.log()

    console.log("Deploying StakeManager...")
    const managerProxy = await ethers.getContractAt("contracts/bnb/StakeManager.sol:StakeManager", stakeManagerProxyAddress)
    console.log("manager proxy:", managerProxy.target)
    console.log()
    

    console.log("Deploying StakePool...")
    const poolProxy = await ethers.getContractAt("contracts/bnb/StakePool.sol:StakePool", stakePoolProxyAddress)
    console.log("pool proxy:", poolProxy.target)
    console.log()

    const managerVer = await managerProxy.version()
    console.log("StakeManager version:", managerVer)
    if (0 == managerVer) {
        console.log("Initializing StakeManager...")
        const tx = await managerProxy.initialize([voter1, voter2, voter3], 2, lsdToken.target, poolProxy.target, validatorAddress, admin.address)
        const receipt = await tx.wait()
        console.log(receipt)
        const managerVer = await managerProxy.version()
        console.log("StakeManager version:", managerVer)
    }
    console.log()

    const poolVer = await poolProxy.version()
    console.log("StakePool version:", poolVer)
    if (0 == poolVer) {
        console.log("Initializing StakePool...")
        const tx = await poolProxy.initialize(bnbGovStakingAddress, managerProxy.target, admin.address)
        const receipt = await tx.wait()
        console.log(receipt)

        const poolVer = await poolProxy.version()
        console.log("StakePool version:", poolVer)
    }
    console.log()

    try {
        const balance = await lsdToken.balanceOf(deployer)
        console.log(balance)
        console.log(ethers.parseEther("1", 'ether'))
        const tx = await managerProxy.withdraw.staticCall({value: ethers.parseUnits('16000000000000000', 'wei')})
        console.log(tx);
    } catch (err) {
        console.error(err);
        const code = err.data.replace('Reverted ','');
        console.log(code)
        console.log(managerProxy.interface.parseError(code))
    }
    // try {
    //     const gasPrice = 1000000000000000000; // 10 Gwei
    //     const gasLimit = 6660666;
    //     const txHash = '0xe9f2257bd57f313ad778b7e39d7deb580edd0c21888eef44e750d5b7f1ee977e'
    //     const tx = await ethers.provider.getTransaction(txHash)
    //     let code = await ethers.provider.call(tx, tx.blockNumber, {
    //         gasPrice, gasLimit,
    //     })
    //     console.log(code)
    //     // const tx = await managerProxy.settle.staticCall(poolProxy.target)
    //     // console.log(tx)
    // } catch (err) {
    //     console.log(err)
    //     const code = err.data.replace('Reverted ','')
    //     console.log('revert code', code)
    //     console.log('revert info:', managerProxy.interface.parseError(code))
    // }

    return
}

main().catch(async error => {
    console.error(error);
    process.exit(1);
});

async function deployERC1967Proxy() {
    // deploy erc1967proxy for stake manager
    let ERC1967Proxy = await ethers.getContractFactory("ERC1967Proxy")
    const managerProxy = await ERC1967Proxy.deploy(stakeManagerLogicAddress, "0x")
    await managerProxy.waitForDeployment()
    console.log("manager proxy:", managerProxy.target)

    // deploy erc1967proxy for stake manager
    ERC1967Proxy = await ethers.getContractFactory("ERC1967Proxy")
    const poolProxy = await ERC1967Proxy.deploy(stakePoolLogicAddress, "0x")
    await poolProxy.waitForDeployment()
    console.log("pool proxy:", poolProxy.target)
}

// Uncomment below to deploy ERC1967Proxy
// deployERC1967Proxy().catch(error => {
//     console.error(error);
//     process.exit(1);
// })

async function upgradeContract() {
    const managerProxy = await ethers.getContractAt("contracts/bnb/StakeManager.sol:StakeManager", stakeManagerProxyAddress)
    const newManager = await ethers.getContractFactory("contracts/bnb/StakeManager.sol:StakeManager")
    const newProxy = await upgrades.upgradeProxy(managerProxy, newManager)
    console.log(newProxy)
}

// upgradeContract().catch(async error => {
//     console.error(error);
//     process.exit(1);
// });