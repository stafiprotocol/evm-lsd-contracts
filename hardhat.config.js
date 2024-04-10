require("hardhat-contract-sizer")
require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");

// cp secrets-template.json secrets.json
// WARN: make sure only using test mnemonic words
const { mnemonic } = require('./secrets.json');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: false,
    }
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
    disambiguatePaths: true,
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
    local: {
      allowUnlimitedContractSize: true,
      url: "http://127.0.0.1:8545/"
    },
    bsc_testnet: {
      allowUnlimitedContractSize: true,
      url: "https://data-seed-prebsc-1-s1.bnbchain.org:8545",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: { mnemonic: mnemonic }
    },
  }
};
