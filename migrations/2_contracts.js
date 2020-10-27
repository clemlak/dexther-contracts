/* global artifacts */

const Dexther = artifacts.require('Dexther');
const DummyERC20 = artifacts.require('DummyERC20');
const DummyERC721 = artifacts.require('DummyERC721');
const DummyERC1155 = artifacts.require('DummyERC1155');

module.exports = (deployer, network) => {
  if (network === 'development') {
    deployer.deploy(Dexther, '0');
    deployer.deploy(DummyERC20);
    deployer.deploy(DummyERC721);
    deployer.deploy(DummyERC1155);
  } else {
    deployer.deploy(Dexther, '0');
  }
};
