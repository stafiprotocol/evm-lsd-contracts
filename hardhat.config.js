require("hardhat-contract-sizer")

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.19",
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
    viaIR: true,
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
    disambiguatePaths: false,
  },
};
