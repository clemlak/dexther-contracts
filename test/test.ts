/* eslint-env node, mocha */

import { ethers } from 'hardhat';
import {
  Contract,
  Signer,
  utils,
} from 'ethers';
import { expect } from 'chai';

describe('Dexther', () => {
  let accounts: Signer[];
  let dexther: Contract;

  beforeEach(async () => {
    accounts = await ethers.getSigners();
    const Dexther = await ethers.getContractFactory('Dexther');

    dexther = await Dexther.deploy('0');
  });

  it('Should check the current fee', async () => {
    expect(await dexther.currentFee()).to.equal('0');
  });
});
