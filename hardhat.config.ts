import {
  HardhatUserConfig,
} from 'hardhat/config';
import '@nomiclabs/hardhat-waffle';
import * as dotenv from 'dotenv';
import 'hardhat-typechain';
import '@nomiclabs/hardhat-etherscan';

dotenv.config();

const config: HardhatUserConfig = {
  solidity: '0.7.3',
  networks: {
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_ID}`,
      accounts: [process.env.TEST_PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
