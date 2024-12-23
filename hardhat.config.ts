import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  // solidity: {
  //   compilers: [
  //     {
  //       version: '0.8.0',
  //     },
  //     {
  //       version: '<0.9.0',
  //       settings: {},
  //     },
  //   ],
  // },
  networks: {
    testnet_bitfinity: {
      url: "https://testnet.bitfinity.network",
      chainId: 355133,
    },
    develop_bitfinity: {
      url: "http://127.0.0.1:8545",
      accounts: [
        "0xe8f100acb99f812bc252ee898f2f71bd2f78c84dddc82ae73386e5c6f2cc6754",
      ],
    },
  },
};

export default config;
