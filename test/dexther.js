/* global artifacts, contract, it, assert, beforeEach */
const {
  expectRevert,
} = require('@openzeppelin/test-helpers');

const {
  signSwap,
  getDigest,
} = require('../utils/sign');

const Dexther = artifacts.require('Dexther');
const CryptoDogs = artifacts.require('CryptoDogs');

const alicePrivateKey = '0x511aa64b036d7e415c8c527e684f02dfac78db7d888e6ee9b6c687e22a9feaf0';
const bobPrivateKey = '0x79c2d003af0de1979f97d718ccf255b382c606c35b3b385f2e6cdb49e47854f4';

contract('Dexther', (accounts) => {
  let instance;
  let cryptoDogs;

  const alice = accounts[1];
  const bob = accounts[2];

  beforeEach(async () => {
    instance = await Dexther.new(9999);
    cryptoDogs = await CryptoDogs.new();
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

  it('Should get the domain separator', async () => {
    const DOMAIN_SEPARATOR = await instance.DOMAIN_SEPARATOR();
    // console.log(DOMAIN_SEPARATOR);
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
      0,
      bob,
      ['0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'],
      [0],
      0,
    );

    const digest = getDigest(
      DOMAIN_SEPARATOR,
      SWAP_TYPEHASH,
      alice,
      ['0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'],
      [0],
      0,
      bob,
      ['0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'],
      [0],
      0,
    );

    const signer = await instance.recover(digest, sig);
    assert.equal(signer, alice, 'Signer is wrong');
  });

  it('Should mint a CryptoDogs token', async () => {
    cryptoDogs.mint(alice, '0');
  });
});
