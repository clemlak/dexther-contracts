/* global artifacts, contract, it, assert, beforeEach, web3 */
const {
  expectRevert,
  expectEvent,
} = require('@openzeppelin/test-helpers');
const {
  utils,
  constants,
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
    instance = await Dexther.new();
    dummyERC20 = await DummyERC20.new();
    dummyERC721 = await DummyERC721.new();
    dummyERC1155 = await DummyERC1155.new();
  });

  it('Should create an offer', async () => {
    await dummyERC721.mint(accounts[0], 0);
    await dummyERC721.approve(instance.address, 0);

    const tx = await instance.createOffer(
      '100000000000000000000',
      dummyERC20.address,
      [dummyERC721.address],
      [0],
      [0],
      [],
      constants.AddressZero,
    );

    /*
    await expectEvent(tx.receipt, 'Created', {
      creator: accounts[0],
      offerId: '0',
      estimateAmount: '100000000000000000000',
      estimateTokenAddress: [dummyERC20.address],
      offerTokensAddresses: [dummyERC721.address],
      offersTokendsIds: ['0'],
      offersTokendsValues: ['0'],
    });
    */

    const offer = await instance.getOffer(0);
    console.log(offer);
  });

  it('Should create an offer and swap NFTs', async () => {
    await dummyERC721.mint(accounts[0], 0);
    await dummyERC721.approve(instance.address, 0);

    await instance.createOffer(
      web3.utils.toWei('100').toString(),
      dummyERC20.address,
      [dummyERC721.address],
      [0],
      [1],
      [],
      constants.AddressZero,
    );

    await dummyERC721.mint(accounts[1], 1);
    await dummyERC721.approve(instance.address, 1, {
      from: accounts[1],
    });

    await dummyERC20.mint(accounts[1], web3.utils.toWei('100'));
    await dummyERC20.approve(instance.address, web3.utils.toWei('100'), {
      from: accounts[1],
    });

    await instance.swap(
      0,
      [dummyERC721.address],
      [1],
      [0], {
        from: accounts[1],
      },
    );
  });

  it('Should create an offer and swap NFTs', async () => {
    await dummyERC721.mint(accounts[0], 0);
    await dummyERC721.approve(instance.address, 0);

    await instance.createOffer(
      web3.utils.toWei('100').toString(),
      dummyERC20.address,
      [dummyERC721.address],
      [0],
      [1],
      [],
      constants.AddressZero,
    );

    await dummyERC721.mint(accounts[1], 1);
    await dummyERC721.approve(instance.address, 1, {
      from: accounts[1],
    });

    await dummyERC20.mint(accounts[1], web3.utils.toWei('100'));
    await dummyERC20.approve(instance.address, web3.utils.toWei('100'), {
      from: accounts[1],
    });

    await instance.swap(
      0,
      [dummyERC721.address],
      [1],
      [0], {
        from: accounts[1],
      },
    );

    await instance.finalize(
      0,
      true,
    );
  });
});
