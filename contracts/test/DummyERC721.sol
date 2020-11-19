// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract DummyERC721 is ERC721 {
  constructor() ERC721(
    "DummyERC721",
    "DUMMY721"
  ) {}

  function mint(address to, uint256 tokenId) external {
    _mint(to, tokenId);
  }
}
