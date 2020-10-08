const {
  utils,
} = require('ethers');

function getDigest(
  domainSeparator,
  swapTypehash,
  alice,
  aliceTokens,
  aliceTokensIds,
  aliceNonce,
  bob,
  bobTokens,
  bobTokensIds,
  bobNonce,
) {
  const hashedData = utils.keccak256(
    utils.defaultAbiCoder.encode([
      'bytes32',
      'address',
      'address[]',
      'uint256[]',
      'uint256',
      'address',
      'address[]',
      'uint256[]',
      'uint256',
    ], [
      swapTypehash,
      alice,
      aliceTokens,
      aliceTokensIds,
      aliceNonce,
      bob,
      bobTokens,
      bobTokensIds,
      bobNonce,
    ]),
  );

  const digest = utils.solidityKeccak256([
    'string',
    'bytes32',
    'bytes32',
  ], [
    '\x19\x01',
    domainSeparator,
    hashedData,
  ]);

  return digest;
}

function signSwap(
  privateKey,
  domainSeparator,
  swapTypehash,
  alice,
  aliceTokens,
  aliceTokensIds,
  aliceNonce,
  bob,
  bobTokens,
  bobTokensIds,
  bobNonce,
) {
  const digest = getDigest(
    domainSeparator,
    swapTypehash,
    alice,
    aliceTokens,
    aliceTokensIds,
    aliceNonce,
    bob,
    bobTokens,
    bobTokensIds,
    bobNonce,
  );

  const arrifyiedDigest = utils.arrayify(digest);
  const signingKey = new utils.SigningKey(privateKey);

  const flatSig = signingKey.signDigest(arrifyiedDigest);
  return utils.joinSignature(flatSig);
}

module.exports = {
  signSwap,
  getDigest,
};
