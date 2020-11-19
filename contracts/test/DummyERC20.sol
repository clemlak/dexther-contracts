// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract DummyERC20 is ERC20 {
  constructor() ERC20(
    "DummyERC20",
    "DUMMY20"
  ) {}

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }
}
