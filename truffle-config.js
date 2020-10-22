require('dotenv').config();
const HDWalletProvider = require('@truffle/hdwallet-provider');

const {
  PRIVATE_KEY,
  INFURA_ID,
} = process.env;

module.exports = {
  networks: {
    development: {
      host: '127.0.0.1',
      port: 8545,
      network_id: '*',
    },
    rinkeby: {
      provider: () => new HDWalletProvider(PRIVATE_KEY, `https://rinkeby.infura.io/v3/${INFURA_ID}`),
      network_id: 4,
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
