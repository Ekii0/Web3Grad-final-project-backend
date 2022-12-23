require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy");
require("dotenv").config();

const GOERLI_RPC_URL = process.env.GOERLI_RPC_URL;
const TESTNET_DEPLOYER_KEY = process.env.TESTNET_DEPLOYER_KEY;
const POLYGON_ALCHEMY_RPC_URL = process.env.POLYGON_ALCHEMY_RPC_URL;
const POLYGON_DEPLOYER_KEY = process.env.POLYGON_DEPLOYER_KEY;
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.17",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 31337,
      forking: {
        url: POLYGON_ALCHEMY_RPC_URL,
      },
    },
    goerli: {
      chainId: 5,
      accounts: [TESTNET_DEPLOYER_KEY],
      url: GOERLI_RPC_URL,
      saveDeployments: true,
    },
    polygon: {
      chainId: 137,
      accounts: [POLYGON_DEPLOYER_KEY],
      url: POLYGON_ALCHEMY_RPC_URL,
      saveDeployments: true,
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  etherscan: {
    apiKey: {
      polygon: POLYGONSCAN_API_KEY || "",
    },
  },
};
