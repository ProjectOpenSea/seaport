// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "seaport-sol/SeaportSol.sol";

interface TestERC20 {
    function mint(address to, uint256 amount) external;

    function increaseAllowance(address spender, uint256 amount) external;
}

interface TestERC721 {
    function mint(address to, uint256 tokenId) external;

    function approve(address to, uint256 tokenId) external;

    function getApproved(uint256 tokenId) external view returns (address);

    function setApprovalForAll(address operator, bool approved) external;
}

interface TestERC1155 {
    function mint(address to, uint256 tokenId, uint256 amount) external;

    function setApprovalForAll(address operator, bool approved) external;
}

abstract contract FuzzSetup is Test {
    function setUpOfferItems(
        address offerer,
        OfferItem[] memory items,
        address approveTo
    ) public {
        for (uint256 i = 0; i < items.length; i++) {
            OfferItem memory item = items[i];

            if (item.itemType == ItemType.ERC20) {
                TestERC20(item.token).mint(offerer, item.startAmount);
                vm.prank(offerer);
                TestERC20(item.token).increaseAllowance(
                    approveTo,
                    item.startAmount
                );
            }

            if (item.itemType == ItemType.ERC721) {
                TestERC721(item.token).mint(offerer, item.identifierOrCriteria);
                vm.prank(offerer);
                TestERC721(item.token).approve(
                    approveTo,
                    item.identifierOrCriteria
                );
            }

            if (item.itemType == ItemType.ERC1155) {
                TestERC1155(item.token).mint(
                    offerer,
                    item.identifierOrCriteria,
                    item.startAmount
                );
                vm.prank(offerer);
                TestERC1155(item.token).setApprovalForAll(approveTo, true);
            }
        }
    }

    function setUpConsiderationItems(
        address owner,
        ConsiderationItem[] memory items,
        address approveTo
    ) public {
        for (uint256 i = 0; i < items.length; i++) {
            ConsiderationItem memory item = items[i];

            if (item.itemType == ItemType.ERC20) {
                TestERC20(item.token).mint(owner, item.startAmount);
                vm.prank(owner);
                TestERC20(item.token).increaseAllowance(
                    approveTo,
                    item.startAmount
                );
            }

            if (item.itemType == ItemType.ERC721) {
                TestERC721(item.token).mint(owner, item.identifierOrCriteria);
                vm.prank(owner);
                TestERC721(item.token).approve(
                    approveTo,
                    item.identifierOrCriteria
                );
            }

            if (item.itemType == ItemType.ERC1155) {
                TestERC1155(item.token).mint(
                    owner,
                    item.identifierOrCriteria,
                    item.startAmount
                );
                vm.prank(owner);
                TestERC1155(item.token).setApprovalForAll(approveTo, true);
            }
        }
    }
}
