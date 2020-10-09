require('dotenv').config();
const HDWalletProvider = require('@truffle/hdwallet-provider');

const {
  WALLET_PRIVATE_KEY,
  INFURA_API_KEY,
} = process.env;

module.exports = {
  networks: {
    development: {
      host: '127.0.0.1',
      port: 8545,
      network_id: '*',
    },
    ropsten: {
      provider: () => new HDWalletProvider(WALLET_PRIVATE_KEY, `https://ropsten.infura.io/v3/${INFURA_API_KEY}`),
      network_id: 3,
      gas: 5500000,
      timeoutBlocks: 200,
    },
  },
  mocha: {
    timeout: 100000,
  },
  compilers: {
    solc: {
      version: '0.7.1',
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    },
  },
};
