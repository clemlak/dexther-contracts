// SPDX-License-Identifier: MIT
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";


contract Dexther {
  enum Status { Available, Swapped, Finalized, Canceled }

  struct Offer {
    address creator;
    uint256 estimateAmount;
    address estimateTokenAddress;
    address[] offerTokensAddresses;
    uint256[] offerTokensIds;
    uint256[] offerTokensValues;
    address[] expectedTokens;
    address restrictedTo;
    address swapper;
    uint256 swappedAt;
    address[] swapTokensAddresses;
    uint256[] swapTokensIds;
    uint256[] swapTokensValues;
    Status status;
  }

  Offer[] public offers;
  uint256 public choicePeriod = 60 * 60 * 24 * 10;

  address public owner;
  uint256 public currentFee = 1;
  mapping (address => uint256) public availableFees;

  event Created(
    address indexed creator,
    uint256 indexed offerId,
    uint256 estimateAmount,
    address indexed estimateTokenAddress,
    address[] offerTokensAddresses,
    uint256[] offersTokensIds,
    uint256[] offerTokensValues,
    address[] expectedTokens,
    address restrictedTo
  );

  event Canceled(
    uint256 indexed offerId
  );

  event Swapped(
    address indexed swapper,
    uint256 indexed offerId
  );

  constructor() {
    owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "Not owner");
    _;
  }

  function updateOwner(address newOwner) external onlyOwner() {
    owner = newOwner;
  }

  function updateFee(uint256 newCurrentFee) external onlyOwner() {
    require(newCurrentFee < 100, "Fee too high");
    currentFee = newCurrentFee;
  }

  function withdrawFees(
    address tokenAddress,
    uint256 amount
  ) external onlyOwner() {
    require(amount <= availableFees[tokenAddress], "Amount too high");

    availableFees[tokenAddress] = SafeMath.sub(
      availableFees[tokenAddress],
      amount
    );

    IERC20 token = IERC20(tokenAddress);
    token.transfer(msg.sender, amount);
  }

  function createOffer(
    uint256 estimateAmount,
    address estimateTokenAddress,
    address[] memory offerTokensAddresses,
    uint256[] memory offerTokensIds,
    uint256[] memory offerTokensValues,
    address[] memory expectedTokens,
    address restrictedTo
  ) external {
    require(offerTokensAddresses.length > 0, "No assets");
    require(offerTokensAddresses.length == offerTokensIds.length, "Tokens addresses or ids error");
    require(offerTokensAddresses.length == offerTokensValues.length, "Tokens addresses or values error");

    _transferAssets(
      msg.sender,
      address(this),
      offerTokensAddresses,
      offerTokensIds,
      offerTokensValues
    );

    offers.push(
      Offer(
        msg.sender,
        estimateAmount,
        estimateTokenAddress,
        offerTokensAddresses,
        offerTokensIds,
        offerTokensValues,
        expectedTokens,
        restrictedTo,
        address(0),
        0,
        new address[](0),
        new uint256[](0),
        new uint256[](0),
        Status.Available
      )
    );

    emit Created(
      msg.sender,
      offers.length - 1,
      estimateAmount,
      estimateTokenAddress,
      offerTokensAddresses,
      offerTokensIds,
      offerTokensValues,
      expectedTokens,
      restrictedTo
    );
  }

  function cancelOffer(
    uint256 offerId
  ) external {
    require(offers[offerId].creator == msg.sender, "Not creator");
    require(offers[offerId].status == Status.Available, "Already used");

    offers[offerId].status = Status.Canceled;

    emit Canceled(offerId);

    _transferAssets(
      address(this),
      msg.sender,
      offers[offerId].offerTokensAddresses,
      offers[offerId].offerTokensIds,
      offers[offerId].offerTokensValues
    );
  }

  function swap(
    uint256 offerId,
    address[] memory swapTokensAddresses,
    uint256[] memory swapTokensIds,
    uint256[] memory swapTokensValues
  ) external {
    require(offers[offerId].status == Status.Available, "Offer not available");

    if (offers[offerId].restrictedTo != address(0)) {
      require(offers[offerId].restrictedTo == msg.sender, "Not authorized");
    }

    if (offers[offerId].expectedTokens.length > 0) {
      for (uint256 i = 0; i < swapTokensAddresses.length; i += 1) {
        require(
          _includes(offers[offerId].expectedTokens, swapTokensAddresses[i]),
          "Swap token not expected"
        );
      }
    }

    IERC20 estimateToken = IERC20(offers[offerId].estimateTokenAddress);
    estimateToken.transferFrom(msg.sender, address(this), offers[offerId].estimateAmount);

    _transferAssets(
      msg.sender,
      address(this),
      swapTokensAddresses,
      swapTokensIds,
      swapTokensValues
    );

    _transferAssets(
      address(this),
      msg.sender,
      offers[offerId].offerTokensAddresses,
      offers[offerId].offerTokensIds,
      offers[offerId].offerTokensValues
    );

    offers[offerId].swapper = msg.sender;
    offers[offerId].swappedAt = block.timestamp;
    offers[offerId].status = Status.Swapped;
    offers[offerId].swapTokensAddresses = swapTokensAddresses;
    offers[offerId].swapTokensIds = swapTokensIds;
    offers[offerId].swapTokensValues = swapTokensValues;

    emit Swapped(
      msg.sender,
      offerId
    );
  }

  function finalize(
    uint256 offerId,
    bool claimingAssets
  ) external {
    require(msg.sender == offers[offerId].creator, "Not creator");
    require(offers[offerId].status == Status.Swapped, "Not swapped");

    address assetsReceiver = claimingAssets ? msg.sender : offers[offerId].swapper;
    address collateralReceiver = claimingAssets ? offers[offerId].swapper : msg.sender;

    _transferAssets(
      address(this),
      assetsReceiver,
      offers[offerId].swapTokensAddresses,
      offers[offerId].swapTokensIds,
      offers[offerId].swapTokensValues
    );

    IERC20 estimateToken = IERC20(offers[offerId].estimateTokenAddress);

    uint256 fee = SafeMath.mul(
      SafeMath.div(
        offers[offerId].estimateAmount,
        10000
      ),
      currentFee
    );

    availableFees[offers[offerId].estimateTokenAddress] = SafeMath.add(
      availableFees[offers[offerId].estimateTokenAddress],
      fee
    );

    uint256 estimateAmountMinusFee = SafeMath.sub(
      offers[offerId].estimateAmount,
      fee
    );

    estimateToken.transfer(collateralReceiver, estimateAmountMinusFee);
    offers[offerId].status = Status.Finalized;
  }

  function forceChoice(
    uint256 offerId,
    bool claimingAssets
  ) external {
    require(msg.sender == offers[offerId].swapper, "Not swapper");
    require(offers[offerId].status == Status.Swapped, "Not swapped");
    require(block.timestamp + choicePeriod >= offers[offerId].swappedAt, "Too soon");

    address assetsReceiver = claimingAssets ? offers[offerId].swapper : msg.sender;
    address collateralReceiver = claimingAssets ? msg.sender : offers[offerId].swapper;

    _transferAssets(
      address(this),
      assetsReceiver,
      offers[offerId].swapTokensAddresses,
      offers[offerId].swapTokensIds,
      offers[offerId].swapTokensValues
    );

    IERC20 estimateToken = IERC20(offers[offerId].estimateTokenAddress);

    uint256 fee = SafeMath.mul(
      SafeMath.div(
        offers[offerId].estimateAmount,
        10000
      ),
      currentFee
    );

    availableFees[offers[offerId].estimateTokenAddress] = SafeMath.add(
      availableFees[offers[offerId].estimateTokenAddress],
      fee
    );

    uint256 estimateAmountMinusFee = SafeMath.sub(
      offers[offerId].estimateAmount,
      fee
    );

    estimateToken.transfer(address(this), collateralReceiver, estimateAmountMinusFee);
    offers[offerId].status = Status.Finalized;
  }

  function getOffer(
    uint256 offerId
  ) external view returns (Offer memory) {
    return offers[offerId];
  }

  function _transferAssets(
    address from,
    address to,
    address[] memory tokensAddresses,
    uint256[] memory tokensIds,
    uint256[] memory tokensValues
  ) private {
    for (uint256 i = 0; i < tokensAddresses.length; i += 1) {
      IERC165 tokenWithoutInterface = IERC165(tokensAddresses[i]);

      try tokenWithoutInterface.supportsInterface(0xd9b67a26) returns (bool hasInterface) {
          if (hasInterface) {
              IERC1155 token = IERC1155(tokensAddresses[i]);
              bytes memory data;
              token.safeTransferFrom(from, to, tokensIds[i], tokensValues[i], data);
          } else {
              IERC721 token = IERC721(tokensAddresses[i]);
              try token.transferFrom(from, to, tokensIds[i]) {
                // Success
              } catch {
                // address(token).transfer(to, tokensIds[i]);
              }
          }
      } catch {
        IERC20 token = IERC20(tokensAddresses[i]);
        try token.transferFrom(from, to, tokensIds[i]) {
          //
        } catch {
          token.transfer(to, tokensIds[i]);
        }
      }
    }
  }

  function _includes(
    address[] memory source,
    address value
  ) private pure returns (bool) {
    bool isIncluded = false;

    for (uint256 i = 0; i < source.length; i += 1) {
      if (source[i] == value) {
        isIncluded = true;
      }
    }

    return isIncluded;
  }
}
