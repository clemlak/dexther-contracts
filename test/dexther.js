/* global artifacts, contract, it, assert, beforeEach */
const {
  expectRevert,
} = require('@openzeppelin/test-helpers');
const {
  utils,
} = require('ethers');

const {
  signSwap,
  getDigest,
} = require('../utils/sign');

const Dexther = artifacts.require('Dexther');
const DummyERC20 = artifacts.require('DummyERC20');
const DummyERC721 = artifacts.require('DummyERC721');
const DummyERC1155 = artifacts.require('DummyERC1155');

const alicePrivateKey = '0x511aa64b036d7e415c8c527e684f02dfac78db7d888e6ee9b6c687e22a9feaf0';
const bobPrivateKey = '0x79c2d003af0de1979f97d718ccf255b382c606c35b3b385f2e6cdb49e47854f4';

contract('Dexther', (accounts) => {
  let instance;
  let dummyERC20;
  let dummyERC721;
  let dummyERC1155;

  const alice = accounts[1];
  const bob = accounts[2];

  beforeEach(async () => {
    instance = await Dexther.new(9999, 0);
    dummyERC20 = await DummyERC20.new();
    dummyERC721 = await DummyERC721.new();
    dummyERC1155 = await DummyERC1155.new();
  });

  it('Should get the chain id', async () => {
    const chaindId = await instance.chainId();
    assert.equal(chaindId.toString(), '9999', 'Wrong chain id');
  });

  it('Should get the admin', async () => {
    const admin = await instance.admin();
    assert.equal(admin, accounts[0], 'Wrong admin');
  });

  it('Should set a new admin', async () => {
    await instance.setAdmin(alice);
    const admin = await instance.admin();
    assert.equal(admin, alice, 'Wrong admin');
  });

  it('Should NOT set a new admin', async () => {
    await expectRevert(
      instance.setAdmin(alice, {
        from: alice,
      }),
      'Not admin',
    );
  });

  it('Should get the current fee', async () => {
    const currentFee = await instance.fee();
    assert.equal(currentFee, 0, 'Fee is wrong');
  });

  it('Should update the current fee', async () => {
    await instance.updateFee(utils.parseEther('0.001'));
    const currentFee = await instance.fee();
    assert.equal(currentFee.toString(), utils.parseEther('0.001').toString(), 'Fee is wrong');
  });

  it('Should NOT update the current fee', async () => {
    await expectRevert(
      instance.updateFee('1', {
        from: accounts[1],
      }),
      'Not admin',
    );
  });

  it('Should check the signature', async () => {
    const DOMAIN_SEPARATOR = await instance.DOMAIN_SEPARATOR();
    const SWAP_TYPEHASH = await instance.SWAP_TYPEHASH();

    const sig = signSwap(
      alicePrivateKey,
      DOMAIN_SEPARATOR,
      SWAP_TYPEHASH,
      alice,
      ['0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'],
      [0],
      [0],
      0,
      bob,
      ['0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'],
      [0],
      [0],
      0,
    );

    const digest = getDigest(
      DOMAIN_SEPARATOR,
      SWAP_TYPEHASH,
      alice,
      ['0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'],
      [0],
      [0],
      0,
      bob,
      ['0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'],
      [0],
      [0],
      0,
    );

    const signer = await instance.recover(digest, sig);
    assert.equal(signer, alice, 'Signer is wrong');
  });

  it('Should perform a swap', async () => {
    await dummyERC20.mint(alice, utils.parseEther('100'));
    await dummyERC20.approve(instance.address, utils.parseEther('100'), {
      from: alice,
    });

    await dummyERC721.mint(bob, 0);
    await dummyERC721.approve(instance.address, 0, {
      from: bob,
    });

    await dummyERC1155.mint(bob, 0, 1, utils.randomBytes(4));
    await dummyERC1155.setApprovalForAll(instance.address, true, {
      from: bob,
    });

    const DOMAIN_SEPARATOR = await instance.DOMAIN_SEPARATOR();
    const SWAP_TYPEHASH = await instance.SWAP_TYPEHASH();

    const aliceSig = signSwap(
      alicePrivateKey,
      DOMAIN_SEPARATOR,
      SWAP_TYPEHASH,
      alice,
      [dummyERC20.address],
      [utils.parseEther('100')],
      [0],
      0,
      bob,
      [dummyERC721.address, dummyERC1155.address],
      [0, 0],
      [0, 1],
      0,
    );

    const bobSig = signSwap(
      bobPrivateKey,
      DOMAIN_SEPARATOR,
      SWAP_TYPEHASH,
      alice,
      [dummyERC20.address],
      [utils.parseEther('100')],
      [0],
      0,
      bob,
      [dummyERC721.address, dummyERC1155.address],
      [0, 0],
      [0, 1],
      0,
    );

    await instance.performSwap({
      alice,
      aliceTokens: [dummyERC20.address],
      aliceTokensIds: [utils.parseEther('100')],
      aliceTokensValues: [0],
      aliceNonce: 0,
      aliceSig,
      bob,
      bobTokens: [dummyERC721.address, dummyERC1155.address],
      bobTokensIds: [0, 0],
      bobTokensValues: [0, 1],
      bobNonce: 0,
      bobSig,
    }, {
      from: alice,
    });

    const balance = await dummyERC20.balanceOf(bob);
    assert.equal(balance.toString(), utils.parseEther('100').toString(), 'Bob balance is wrong');

    const owner = await dummyERC721.ownerOf(0);
    assert.equal(owner, alice, 'Alice owner is wrong');

    const balance1155 = await dummyERC1155.balanceOf(alice, 0);
    assert.equal(balance1155.toString(), 1, 'Alice balance is wrong');
  });
});
