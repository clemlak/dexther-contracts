/* global artifacts, contract, it, assert, beforeEach, web3 */
const {
  expectRevert,
  expectEvent,
} = require('@openzeppelin/test-helpers');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');
const {
  utils,
} = require('ethers');

const Dexther = artifacts.require('Dexther');
const DummyERC20 = artifacts.require('DummyERC20');
const DummyERC721 = artifacts.require('DummyERC721');
const DummyERC1155 = artifacts.require('DummyERC1155');

contract('Dexther', (accounts) => {
  let instance;
  let dummyERC20;
  let dummyERC721;
  let dummyERC1155;

  beforeEach(async () => {
    instance = await Dexther.new('https://dexther.co/id=');
    dummyERC20 = await DummyERC20.new();
    dummyERC721 = await DummyERC721.new();
    dummyERC1155 = await DummyERC1155.new();
  });

  it('Should get the name', async () => {
    const name = await instance.name();
    assert.equal(name, 'Dexther Collateralized NFT', 'Name is wrong');
  });

  it('Should get the symbol', async () => {
    const symbol = await instance.symbol();
    assert.equal(symbol, 'cNFT');
  });

  it('Should get the base URI', async () => {
    const baseURI = await instance.baseURI();
    assert.equal(baseURI, 'https://dexther.co/id=');
  });

  it('Should create a collateralized NFT', async () => {
    await dummyERC20.mint(accounts[0], utils.parseEther('100').toString());
    await dummyERC20.approve(instance.address, utils.parseEther('100').toString());

    await dummyERC721.mint(accounts[0], '0');

    const receipt = await instance.createBundle(
      utils.parseEther('100').toString(),
      dummyERC20.address,
      [dummyERC721.address],
      ['0'],
      ['0'],
    );

    /*
    expectEvent(receipt, 'BundleCreated', {
      creator: accounts[0],
      bundleId: new web3.utils.BN(0),
      collateralAmount: utils.parseEther('100').toString(),
      collateralTokenAddress: dummyERC20.address,
      tokensAddresses: [dummyERC721.address],
      tokensIds: ['0'],
      tokensValues: ['0'],
    });
    */

    expectEvent(receipt, 'BundleCreated');

    const tokenURI = await instance.tokenURI(0);
    assert.equal(tokenURI, 'https://dexther.co/id=0', 'Wrong token URI');

    const balance = await instance.balanceOf(accounts[0]);
    assert.equal(balance.toString(), '1', 'Balance is wrong');

    const owner = await instance.ownerOf('0');
    assert.equal(owner, accounts[0], 'Owner is wrong');
  });
});
