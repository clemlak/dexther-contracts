// SPDX-License-Identifier: MIT
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";


contract Dexther is ERC721 {
  enum Status { Available, Initiator, Counterparty, CollateralTaken, AssetsTaken, Finalized }

  struct CNFT {
    uint256 collateralAmount;
    address collateralTokenAddress;
    address[] tokensAddresses;
    uint256[] tokensIds;
    uint256[] tokensValues;
    Status status;
    uint256 swappedAt;
  }

  CNFT[] public cNFTS;
  mapping (uint256 => uint256) public swappedWith;
  uint256 public currentCNFTId;
  uint256 public forceDelay = 60 * 60 * 24 * 10;

  event Deposited(
    address creator,
    uint256 indexed cNFTId,
    uint256 indexed collateralAmount,
    address indexed collateralTokenAddress,
    address[] tokensAddresses,
    uint256[] tokensIds,
    uint256[] tokensValues
  );

  event Swapped(
    uint256 indexed initiatorCNFTId,
    uint256 indexed counterpartyCNFTId
  );

  event Claimed(
    uint256 indexed initiatorCNFTId,
    uint256 indexed counterpartyCNFTId,
    bool indexed assetsClaimed
  );

  event Finalized(
    uint256 indexed cNFTId
  );

  constructor(
    string memory initialBaseURI
  ) ERC721(
    "Dexther Collateralized NFT",
    "cNFT"
  ) {
    _setBaseURI(initialBaseURI);
  }

  function deposit(
    uint256 collateralAmount,
    address collateralTokenAddress,
    address[] memory tokensAddresses,
    uint256[] memory tokensIds,
    uint256[] memory tokensValues
  ) external {
    IERC20 collateralToken = IERC20(collateralTokenAddress);
    collateralToken.transferFrom(msg.sender, address(this), collateralAmount);

    require(tokensAddresses.length > 0, "No assets");
    require(tokensAddresses.length == tokensIds.length, "Tokens addresses or ids issue");
    require(tokensAddresses.length == tokensValues.length, "Tokens addresses or values issue");

    _transferAssets(
      msg.sender,
      address(this),
      tokensAddresses,
      tokensIds,
      tokensValues
    );

    _mint(msg.sender, currentCNFTId);

    cNFTS.push(
       CNFT(
        collateralAmount,
        collateralTokenAddress,
        tokensAddresses,
        tokensIds,
        tokensValues,
        Status.Available,
        0,
      )
    );

    emit Deposited(
      msg.sender,
      currentCNFTId,
      collateralAmount,
      collateralTokenAddress,
      tokensAddresses,
      tokensIds,
      tokensValues
    );

    currentCNFTId += 1;
  }

  function swap(
    uint256 initiatorCNFTId,
    uint256 counterpartyCNFTId
  ) external {
    require(cNFTS[initiatorCNFTId].status == Status.Available, "CNFT initiator not available");
    require(cNFTS[counterpartyCNFTId].status == Status.Available, "CNFT counterparty not available");
    require(ownerOf(initiatorCNFTId) == msg.sender, "Not owner");

    require(
      cNFTS[initiatorCNFTId].collateralAmount >= cNFTS[counterpartyCNFTId].collateralAmount,
      "Value is too low"
    );

    swappedWith[initiatorCNFTId] = counterpartyCNFTId;
    swappedWith[counterpartyCNFTId] = initiatorCNFTId;

    cNFTS[initiatorCNFTId].status = Status.Initiator;
    cNFTS[counterpartyCNFTId].status = Status.Counterparty;

    cNFTS[initiatorCNFTId].swappedAt = block.timestamp;
    cNFTS[counterpartyCNFTId].swappedAt = block.timestamp;

    _transferAssets(
      address(this),
      msg.sender,
      cNFTS[counterpartyCNFTId].tokensAddresses,
      cNFTS[counterpartyCNFTId].tokensIds,
      cNFTS[counterpartyCNFTId].tokensValues
    );

    emit Swapped(
      initiatorCNFTId,
      counterpartyCNFTId
    );
  }

  function claim(
    uint256 initiatorCNFTId,
    uint256 counterpartyCNFTId,
    bool claimingAssets
  ) external {
    require(ownerOf(counterpartyCNFTId) == msg.sender, "Not owner");

    require(cNFTS[initiatorCNFTId].status == Status.Initiator, "CNFT not initiator");
    require(cNFTS[counterpartyCNFTId].status == Status.Counterparty, "CNFT not counterparty");

    require(swappedWith[initiatorCNFTId] == counterpartyCNFTId, "cNFTS not swapped together");
    require(swappedWith[counterpartyCNFTId] == initiatorCNFTId, "cNFTS not swapped together");

    if (claimingAssets) {
      _transferAssets(
        address(this),
        msg.sender,
        cNFTS[initiatorCNFTId].tokensAddresses,
        cNFTS[initiatorCNFTId].tokensIds,
        cNFTS[initiatorCNFTId].tokensValues
      );

      cNFTS[initiatorCNFTId].status = Status.AssetsTaken;
    } else {
      IERC20 initiatorCollateralToken = IERC20(cNFTS[initiatorCNFTId].collateralTokenAddress);
      initiatorCollateralToken.transfer(msg.sender, cNFTS[initiatorCNFTId].collateralAmount);

      cNFTS[initiatorCNFTId].status = Status.CollateralTaken;
    }

    IERC20 counterpartyCollateralToken = IERC20(cNFTS[counterpartyCNFTId].collateralTokenAddress);
    counterpartyCollateralToken.transfer(msg.sender, cNFTS[counterpartyCNFTId].collateralAmount);

    cNFTS[counterpartyCNFTId].status = Status.Finalized;

    emit Claimed(
      initiatorCNFTId,
      counterpartyCNFTId,
      claimingAssets
    );
  }

  function finalize(
    uint256 initiatorCNFTId,
    uint256 counterpartyCNFTId
  ) external {
    require(ownerOf(initiatorCNFTId) == msg.sender, "Not owner");

    require(
      cNFTS[initiatorCNFTId].status == Status.CollateralTaken
      || cNFTS[initiatorCNFTId].status == Status.AssetsTaken,
      "CNFT not claimed yet"
    );
    require(
      cNFTS[counterpartyCNFTId].status == Status.Finalized,
      "Counterparty CNFT not finalized"
    );

    require(swappedWith[initiatorCNFTId] == counterpartyCNFTId, "cNFTS not swapped together");
    require(swappedWith[counterpartyCNFTId] == initiatorCNFTId, "cNFTS not swapped together");

    if (cNFTS[initiatorCNFTId].status == Status.AssetsTaken) {
      IERC20 initiatorCollateralToken = IERC20(cNFTS[initiatorCNFTId].collateralTokenAddress);
      initiatorCollateralToken.transfer(msg.sender, cNFTS[initiatorCNFTId].collateralAmount);
    } else {
      _transferAssets(
        address(this),
        msg.sender,
        cNFTS[initiatorCNFTId].tokensAddresses,
        cNFTS[initiatorCNFTId].tokensIds,
        cNFTS[initiatorCNFTId].tokensValues
      );
    }

    cNFTS[initiatorCNFTId].status = Status.Finalized;

    _burn(initiatorCNFTId);
    _burn(counterpartyCNFTId);

    emit Finalized(initiatorCNFTId);
  }

  function forceFinalize(
    uint256 initiatorCNFTId,
    uint256 counterpartyCNFTId,
    bool claimingAssets
  ) external {
    require(ownerOf(initiatorCNFTId) == msg.sender, "Not owner");

    require(cNFTS[initiatorCNFTId].status == Status.Initiator, "CNFT not initiator");
    require(cNFTS[counterpartyCNFTId].status == Status.Counterparty, "CNFT not counterparty");

    require(swappedWith[initiatorCNFTId] == counterpartyCNFTId, "cNFTS not swapped together");
    require(swappedWith[counterpartyCNFTId] == initiatorCNFTId, "cNFTS not swapped together");

    require(block.timestamp + forceDelay >= cNFTS[counterpartyCNFTId].swappedAt, "Too soon");
    require(block.timestamp + forceDelay >= cNFTS[initiatorCNFTId].swappedAt, "Too soon");

    address assetsReceiver = claimingAssets ? msg.sender : ownerOf(counterpartyCNFTId);
    address initiatorCollateralReceiver = claimingAssets ?
    address counterpartyCollateralReceiver;

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
}
