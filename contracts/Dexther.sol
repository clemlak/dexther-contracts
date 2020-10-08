// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";


contract Dexther {
  address public admin;
  uint256 public fee = 0.00003 ether;

  string public constant name = "Dexther";
  string public constant version = "1";
  uint256 public chainId;
  bytes32 public DOMAIN_SEPARATOR;
  bytes32 public constant SWAP_TYPEHASH = keccak256("Swap(address alice,address[] aliceTokens,uint256[] aliceTokensIds,uint256 aliceNonce, address bob,address[] bobTokens,uint256[] bobTokensIds,uint256 bobNonce)");

  mapping (address => uint256) public nonces;
  mapping (bytes32 => bool) public isSwapCanceled;

  event Swapped(
    address indexed alice,
    address[] aliceTokens,
    uint256[] aliceTokensIds,
    address indexed bob,
    address[] bobTokens,
    uint256[] bobTokensIds
  );

  modifier onlyAdmin() {
    require(msg.sender == admin, "Not admin");
    _;
  }

  constructor(uint256 initialChaindId) {
    admin = msg.sender;
    chainId = initialChaindId;

    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256("EIP721Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        keccak256(bytes(name)),
        keccak256(bytes(version)),
        chainId,
        address(this)
      )
    );
  }

  function setAdmin(address newAdmin) external onlyAdmin() {
    admin = newAdmin;
  }

  function updateFee(uint256 newFee) external onlyAdmin() {
    fee = newFee;
  }

  /**
   * @notice Perform a swap between 2 users
   */
  function swap(
    address alice,
    address[] memory aliceTokens,
    uint256[] memory aliceTokensIds,
    uint256 aliceNonce,
    bytes memory aliceSig,
    address bob,
    address[] memory bobTokens,
    uint256[] memory bobTokensIds,
    uint256 bobNonce,
    bytes memory bobSig
  ) external payable {
    require(msg.value == fee, "Wrong fee");
    require(aliceNonce == nonces[alice], "Alice nonce is wrong");
    require(bobNonce == nonces[bob], "Bob nonce is wrong");
    require(aliceTokens.length == aliceTokensIds.length, "Alice tokens error");
    require(bobTokens.length == aliceTokensIds.length, "Bob tokens error");

    bytes32 digest = keccak256(
      abi.encodePacked(
        "\x19\x01",
        DOMAIN_SEPARATOR,
        keccak256(
          abi.encode(
            SWAP_TYPEHASH,
            alice,
            aliceTokens,
            aliceTokensIds,
            aliceNonce,
            bob,
            bobTokens,
            bobTokensIds,
            bobNonce
          )
        )
      )
    );

    require(alice == recover(digest, aliceSig), "Alice sig is wrong");
    require(bob == recover(digest, bobSig), "Bob sig is wrong");

    for (uint256 i = 0; i < aliceTokens.length; i += 1) {
      IERC721 token = IERC721(aliceTokens[i]);
      token.transferFrom(alice, bob, aliceTokensIds[i]);
    }

    for (uint256 i = 0; i < bobTokens.length; i += 1) {
      IERC721 token = IERC721(bobTokens[i]);
      token.transferFrom(alice, bob, bobTokensIds[i]);
    }

    nonces[alice] += 1;
    nonces[bob] += 1;

    emit Swapped(
      alice,
      aliceTokens,
      aliceTokensIds,
      bob,
      bobTokens,
      bobTokensIds
    );
  }

  function recover(bytes32 hash, bytes memory signature) public pure returns (address) {
    if (signature.length != 65) {
      revert("ECDSA: invalid signature length");
    }

    bytes32 r;
    bytes32 s;
    uint8 v;

    assembly {
      r := mload(add(signature, 0x20))
      s := mload(add(signature, 0x40))
      v := byte(0, mload(add(signature, 0x60)))
    }

    if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
      revert("ECDSA: invalid signature 's' value");
    }

    if (v != 27 && v != 28) {
      revert("ECDSA: invalid signature 'v' value");
    }

    address signer = ecrecover(hash, v, r, s);
    require(signer != address(0), "ECDSA: invalid signature");

    return signer;
  }
}
