import hardhatToolboxMochaEthersPlugin from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import hardhatContractSizer from "@solidstate/hardhat-contract-sizer";
import { defineConfig } from "hardhat/config";
import "dotenv/config";

export default defineConfig({
  plugins: [hardhatToolboxMochaEthersPlugin, hardhatContractSizer],
  solidity: {
    version: "0.8.26",
    settings: {
      evmVersion: "cancun",
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  networks: {
    sepolia: {
      type: "http",
      chainType: "l1",
      url: process.env.SEPOLIA_RPC_URL!,
      accounts: [process.env.SEPOLIA_PRIVATE_KEY!],
    },
    hoodi: {
      type: "http",
      chainType: "l1",
      url: process.env.HOODI_RPC_URL!,
      accounts: [process.env.HOODI_PRIVATE_KEY!],
    },
    tbsc: {
      type: "http",
      chainType: "l1",
      url: process.env.TBSC_RPC_URL!,
      accounts: [process.env.TBSC_PRIVATE_KEY!],
    },
  },
  verify: {
    etherscan: {
      apiKey: process.env.ETHERSCAN_API_KEY,
    },
    blockscout: {
      enabled: false,
    },
    sourcify: {
      enabled: false,
    },
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
    strict: true,
    only: [],
    unit: "KiB",
  },
  test: {
    mocha: {
      timeout: 1000000,
    },
    solidity: {
      forking: {
        // url: `${process.env.HOODI_RPC_URL}` || "https://0xrpc.io/hoodi",
      },
    },
  },
});
