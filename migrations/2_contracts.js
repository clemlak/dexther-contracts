/* global artifacts */

const Dexther = artifacts.require('Dexther');
const CryptoDogs = artifacts.require('CryptoDogs');

module.exports = (deployer, network) => {
  if (network === 'development') {
    deployer.deploy(Dexther, 9999);
    deployer.deploy(CryptoDogs);
  }
};
