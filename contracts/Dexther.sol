// SPDX-License-Identifier: MIT
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";


contract Dexther is ERC721 {
  enum BundleStatus { Available, Initiator, Counterparty, CollateralTaken, AssetsTaken, Finalized }

  struct Bundle {
    uint256 collateralAmount;
    address collateralTokenAddress;
    address[] tokensAddresses;
    uint256[] tokensIds;
    uint256[] tokensValues;
    BundleStatus status;
  }

  Bundle[] public bundles;
  mapping (uint256 => uint256) public swappedWith;
  uint256 public currentBundleId;

  // TODO: Add more events with indexed parameters to be able to fetch data
  event BundleCreated(
    address indexed creator,
    uint256 bundleId,
    uint256 indexed collateralAmount,
    address indexed collateralTokenAddress,
    address[] tokensAddresses,
    uint256[] tokensIds,
    uint256[] tokensValues
  );

  event BundleSwapped(
    uint256 initiatorBundleId,
    uint256 counterpartyBundleId
  );

  constructor(
    string memory initialBaseURI
  ) ERC721(
    "Dexther Collateralized NFT",
    "cNFT"
  ) {
    _setBaseURI(initialBaseURI);
  }

  function createBundle(
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

    _mint(msg.sender, currentBundleId);

    bundles.push(
       Bundle(
        collateralAmount,
        collateralTokenAddress,
        tokensAddresses,
        tokensIds,
        tokensValues,
        BundleStatus.Available
      )
    );

    emit BundleCreated(
      msg.sender,
      currentBundleId,
      collateralAmount,
      collateralTokenAddress,
      tokensAddresses,
      tokensIds,
      tokensValues
    );

    currentBundleId += 1;
  }

  function swapBundles(
    uint256 initiatorBundleId,
    uint256 counterpartyBundleId
  ) external {
    require(bundles[initiatorBundleId].status == BundleStatus.Available, "Bundle not available");
    require(bundles[counterpartyBundleId].status == BundleStatus.Available, "Bundle not available");
    require(ownerOf(initiatorBundleId) == msg.sender, "Not owner");

    require(
      bundles[initiatorBundleId].collateralAmount >= bundles[counterpartyBundleId].collateralAmount,
      "Bundle values is too low"
    )

    swappedWith[initiatorBundleId] = counterpartyBundleId;
    swappedWith[counterpartyBundleId] = initiatorBundleId;

    bundles[initiatorBundleId].status = BundleStatus.Initiator;
    bundles[counterpartyBundleId].status = BundleStatus.Counterparty;

    _transferAssets(
      address(this),
      msg.sender,
      bundles[counterpartyBundleId].tokensAddresses,
      bundles[counterpartyBundleId].tokensIds,
      bundles[counterpartyBundleId].tokensValues
    );

    emit BundlesSwapped(
      initiatorBundleId,
      counterpartyBundleId
    );
  }

  function finalizeBundle(
    uint256 initiatorBundleId,
    uint256 counterpartyBundleId,
    bool claimingAssets
  ) external {
    require(ownerOf(counterpartyBundleId) == msg.sender, "Not owner");

    require(bundles[initiatorBundleId].status == BundleStatus.Initiator, "Bundle not initiator");
    require(bundles[counterpartyBundleId].status == BundleStatus.Counterparty, "Bundle not counterparty");

    require(swappedWith[initatorBundleId] == counterpartyBundleId, "Bundles not swapped together");
    require(swappedWith[counterpartyBundleId] == initatorBundleId, "Bundles not swapped together");

    address from = claimingAssets ? ownerOf(counterpartyBundleId) : ownerOf(initiatorBundleId);
    address to = claimingAssets ? ownerOf(initiatorBundleId) : ownerOf(counterpartyBundleId);

    _transferAssets(
      address(this),
      msg.sender,
      bundles[initiatorBundleId].tokensAddresses,
      bundles[initiatorBundleId].tokensIds,
      bundles[initiatorBundleId].tokensValues
    );

    IERC20 initiatorCollateralToken = IERC20(bundles[initiatorBundleId].collateralTokenAddress);
    initiatorCollateralToken.transfer(msg.sender, bundles[initiatorBundleId].collateralAmount);

    IERC20 counterpartyCollateralToken = IERC20(bundles[counterpartyBundleId].collateralTokenAddress);
    counterpartyCollateralToken.transfer(msg.sender, bundles[counterpartyBundleId].collateralAmount);
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
