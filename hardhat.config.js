// const env = require("hardhat");

require("@nomiclabs/hardhat-waffle");
// require('@openzeppelin/hardhat-upgrades');
// require("@nomiclabs/hardhat-etherscan");
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.4.18",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: "0.5.0",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: "0.5.16",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: "0.6.0",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: "0.6.2",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: "0.6.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: "0.7.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: "0.8.13",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }
    ]
  },
  networks: {
    hardhat: {
      chainId: 31337
    },
    chain1: {
      url: "http://localhost:8546/",
      chainId: 8546,
    },
    chain2: {
      url: "http://localhost:8547/",
      chainId: 8547,
    },
    chain3: {
      url: "http://localhost:8548/",
      chainId: 8548,
    },
    testnet: {
      // url: "https://speedy-nodes-nyc.moralis.io/9c7d826e61445651ed4326f8/bsc/testnet",
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: [process.env.privateKey]
    },
    mainnet: {
      url: "https://bsc-dataseed1.binance.org/",
      chainId: 56,
      accounts: [process.env.privateKey]
    },
    avalancheFujiTestnet: {
      url: 'https://api.avax-test.network/ext/bc/C/rpc',
      gasPrice: 250000000000,
      chainId: 43113,
      // accounts: process.env.privateKey
      accounts: [process.env.privateKey]
    },
    goerli: {
      url: "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
      chainId: 5,
      accounts: [process.env.privateKey],
    },
  },
  etherscan: {
    // apiKey: "GJQFD5BXR754QEI1221TPAM94IRIE7B2FD"
    apiKey: {
      avalancheFujiTestnet:"ZGR21YGDGQSIVXI5B2NR5K73MFCDI4QPH8",
      goerli: "55I2YRDX4453DEYQ94MHZUK33DE7MHQZCM"
    }
  },
  abiExporter: {
    path: './abi',
    runOnCompile: true,
    clear: true,
    flat: true,
    spacing: 2,
    pretty: true,
  }
};
