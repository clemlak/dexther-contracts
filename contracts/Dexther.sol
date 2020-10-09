// SPDX-License-Identifier: MIT
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";


contract Dexther {
  address public admin;
  uint256 public fee;

  string public constant name = "Dexther";
  string public constant version = "1";
  uint256 public chainId;
  bytes32 public DOMAIN_SEPARATOR;
  bytes32 public constant SWAP_TYPEHASH = keccak256("Swap(address alice,address[] aliceTokens,uint256[] aliceTokensIds,uint256[] aliceTokensValues,uint256 aliceNonce,address bob,address[] bobTokens,uint256[] bobTokensIds,uint256[] bobTokensValues,uint256 bobNonce)");

  struct Swap {
    address alice;
    address[] aliceTokens;
    uint256[] aliceTokensIds;
    uint256[] aliceTokensValues;
    uint256 aliceNonce;
    bytes aliceSig;
    address bob;
    address[] bobTokens;
    uint256[] bobTokensIds;
    uint256[] bobTokensValues;
    uint256 bobNonce;
    bytes bobSig;
  }

  mapping (address => uint256) public nonces;
  mapping (bytes32 => bool) public isSwapCanceled;

  bytes4 private constant ERC155_INTERFACE = 0xd9b67a26;
  bytes4 private constant ERC721_INTERFACE = 0x80ac58cd;

  event Swapped(
    address indexed alice,
    address[] aliceTokens,
    uint256[] aliceTokensIds,
    uint256[] aliceTokensValues,
    address indexed bob,
    address[] bobTokens,
    uint256[] bobTokensIds,
    uint256[] bobTokensValues
  );

  modifier onlyAdmin() {
    require(msg.sender == admin, "Not admin");
    _;
  }

  constructor(uint256 initialChaindId, uint256 initialFee) {
    admin = msg.sender;
    chainId = initialChaindId;
    fee = initialFee;

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

  function performSwap(
    Swap memory swap
  ) external payable {
    // require(msg.value == fee, "Wrong fee");
    require(swap.aliceNonce == nonces[swap.alice], "Alice nonce is wrong");
    require(swap.bobNonce == nonces[swap.bob], "Bob nonce is wrong");
    require(swap.aliceTokens.length == swap.aliceTokensIds.length, "Alice tokens ids error");
    require(swap.aliceTokens.length == swap.aliceTokensValues.length, "Alice tokens values error");

    require(swap.bobTokens.length == swap.bobTokensIds.length, "Bob tokens ids error");
    require(swap.bobTokens.length == swap.bobTokensValues.length, "Bob tokens values error");

    bytes32 digest = keccak256(
      abi.encodePacked(
        "\x19\x01",
        DOMAIN_SEPARATOR,
        keccak256(
          abi.encode(
            SWAP_TYPEHASH,
            swap.alice,
            swap.aliceTokens,
            swap.aliceTokensIds,
            swap.aliceTokensValues,
            swap.aliceNonce,
            swap.bob,
            swap.bobTokens,
            swap.bobTokensIds,
            swap.bobTokensValues,
            swap.bobNonce
          )
        )
      )
    );

    require(swap.alice == recover(digest, swap.aliceSig), "Alice sig is wrong");
    require(swap.bob == recover(digest, swap.bobSig), "Bob sig is wrong");

    _swap(swap.alice, swap.bob, swap.aliceTokens, swap.aliceTokensIds, swap.aliceTokensValues);
    _swap(swap.bob, swap.alice, swap.bobTokens, swap.bobTokensIds, swap.bobTokensValues);

    nonces[swap.alice] += 1;
    nonces[swap.bob] += 1;

    emit Swapped(
      swap.alice,
      swap.aliceTokens,
      swap.aliceTokensIds,
      swap.aliceTokensValues,
      swap.bob,
      swap.bobTokens,
      swap.bobTokensIds,
      swap.bobTokensValues
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

  function _swap(
    address from,
    address to,
    address[] memory tokens,
    uint256[] memory tokensIds,
    uint256[] memory tokensValues
  ) private {
    for (uint256 i = 0; i < tokens.length; i += 1) {
      IERC165 tokenWithoutInterface = IERC165(tokens[i]);

      try tokenWithoutInterface.supportsInterface(0xd9b67a26) returns (bool hasInterface) {
          if (hasInterface) {
              IERC1155 token = IERC1155(tokens[i]);
              bytes memory data;
              token.safeTransferFrom(from, to, tokensIds[i], tokensValues[i], data);
          } else {
              IERC721 token = IERC721(tokens[i]);
              token.safeTransferFrom(from, to, tokensIds[i]);
          }
      } catch {
        IERC20 token = IERC20(tokens[i]);
        token.transferFrom(from, to, tokensIds[i]);
      }
    }
  }
}
