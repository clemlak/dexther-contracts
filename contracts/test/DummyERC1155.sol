// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";


contract DummyERC1155 is ERC1155 {
  constructor() ERC1155(
    "https://token-cdn-domain/{id}.json"
  ) {}

  function mint(address to, uint256 tokenId, uint256 amount, bytes memory data) external {
    _mint(to, tokenId, amount, data);
  }
}
