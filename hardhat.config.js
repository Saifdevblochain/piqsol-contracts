
require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          "viaIR": true,
          optimizer: {
            enabled: true,
            runs: 1000000,
            "details": {
              "yulDetails": {
                "optimizerSteps": "u"
              }
            }

          },
        },
      },
    ],
  },
  networks: {
    goerli: {
      url: process.env.URL,
      accounts: [process.env.PRIVATE_KEY],
    },
    avax: {
      url: process.env.URL_MAIN,
      accounts: [process.env.PRIVATE_KEY_MAIN],
      chainId: 1,
    },
    mainnet: {
      url: 'https://api.avax.network/ext/bc/C/rpc',
      gasPrice: 225000000000,
      chainId: 43114,
      accounts: [process.env.PRIVATE_KEY_MAIN]
    },
    sepolia: {
      url: process.env.SEPOLIA,
      accounts: [process.env.PRIVATE_KEY_SEPOLIA],
    },
  },
  etherscan: {
    apiKey: process.env.API_KEY,
  },
};

// npx hardhat ignition deploy ignition / modules / Lock.js--network sepolia

