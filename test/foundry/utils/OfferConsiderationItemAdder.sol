// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { ConsiderationItem, OfferItem, ItemType } from "../../../contracts/lib/ConsiderationStructs.sol";
import { TestTokenMinter } from "./TestTokenMinter.sol";

contract OfferConsiderationItemAdder is TestTokenMinter {
    OfferItem offerItem;
    ConsiderationItem considerationItem;
    OfferItem[] offerItems;
    ConsiderationItem[] considerationItems;

    function addConsiderationItem(
        address payable recipient,
        ItemType itemType,
        uint256 identifier,
        uint256 amt
    ) internal {
        if (itemType == ItemType.NATIVE) {
            addEthConsiderationItem(recipient, amt);
        } else if (itemType == ItemType.ERC20) {
            addErc20ConsiderationItem(recipient, amt);
        } else if (itemType == ItemType.ERC1155) {
            addErc1155ConsiderationItem(recipient, identifier, amt);
        } else {
            addErc721ConsiderationItem(recipient, identifier);
        }
    }

    function addOfferItem(
        ItemType itemType,
        uint256 identifier,
        uint256 startAmount,
        uint256 endAmount
    ) internal {
        if (itemType == ItemType.NATIVE) {
            addEthOfferItem(startAmount, endAmount);
        } else if (itemType == ItemType.ERC20) {
            addERC20OfferItem(startAmount, endAmount);
        } else if (itemType == ItemType.ERC1155) {
            addERC1155OfferItem(identifier, startAmount, endAmount);
        } else {
            addERC721OfferItem(identifier);
        }
    }

    function addOfferItem(
        ItemType itemType,
        uint256 identifier,
        uint256 amt
    ) internal {
        addOfferItem(itemType, identifier, amt, amt);
    }

    function addERC721OfferItem(uint256 tokenId) internal {
        addOfferItem(ItemType.ERC721, address(test721_1), tokenId, 1, 1);
    }

    function addERC1155OfferItem(uint256 tokenId, uint256 amount) internal {
        addOfferItem(
            ItemType.ERC1155,
            address(test1155_1),
            tokenId,
            amount,
            amount
        );
    }

    function addERC20OfferItem(uint256 startAmount, uint256 endAmount)
        internal
    {
        addOfferItem(
            ItemType.ERC20,
            address(token1),
            0,
            startAmount,
            endAmount
        );
    }

    function addERC20OfferItem(uint256 amount) internal {
        addERC20OfferItem(amount, amount);
    }

    function addERC1155OfferItem(
        uint256 tokenId,
        uint256 startAmount,
        uint256 endAmount
    ) internal {
        addOfferItem(
            ItemType.ERC1155,
            address(test1155_1),
            tokenId,
            startAmount,
            endAmount
        );
    }

    function addEthOfferItem(uint256 startAmount, uint256 endAmount) internal {
        addOfferItem(ItemType.NATIVE, address(0), 0, startAmount, endAmount);
    }

    function addEthOfferItem(uint256 paymentAmount) internal {
        addEthOfferItem(paymentAmount, paymentAmount);
    }

    function addEthConsiderationItem(
        address payable recipient,
        uint256 paymentAmount
    ) internal {
        addConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            paymentAmount,
            paymentAmount,
            recipient
        );
    }

    function addEthConsiderationItem(
        address payable recipient,
        uint256 startAmount,
        uint256 endAmount
    ) internal {
        addConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            startAmount,
            endAmount,
            recipient
        );
    }

    function addErc20ConsiderationItem(
        address payable receiver,
        uint256 startAmount,
        uint256 endAmount
    ) internal {
        addConsiderationItem(
            ItemType.ERC20,
            address(token1),
            0,
            startAmount,
            endAmount,
            receiver
        );
    }

    function addErc20ConsiderationItem(
        address payable receiver,
        uint256 paymentAmount
    ) internal {
        addErc20ConsiderationItem(receiver, paymentAmount, paymentAmount);
    }

    function addErc721ConsiderationItem(
        address payable recipient,
        uint256 tokenId
    ) internal {
        addConsiderationItem(
            ItemType.ERC721,
            address(test721_1),
            tokenId,
            1,
            1,
            recipient
        );
    }

    function addErc1155ConsiderationItem(
        address payable recipient,
        uint256 tokenId,
        uint256 amount
    ) internal {
        addConsiderationItem(
            ItemType.ERC1155,
            address(test1155_1),
            tokenId,
            amount,
            amount,
            recipient
        );
    }

    function addOfferItem(
        ItemType itemType,
        address token,
        uint256 identifier,
        uint256 startAmount,
        uint256 endAmount
    ) internal {
        offerItem.itemType = itemType;
        offerItem.token = token;
        offerItem.identifierOrCriteria = identifier;
        offerItem.startAmount = startAmount;
        offerItem.endAmount = endAmount;
        offerItems.push(offerItem);
    }

    function addConsiderationItem(
        ItemType itemType,
        address token,
        uint256 identifier,
        uint256 startAmount,
        uint256 endAmount,
        address payable recipient
    ) internal {
        considerationItem.itemType = itemType;
        considerationItem.token = token;
        considerationItem.identifierOrCriteria = identifier;
        considerationItem.startAmount = startAmount;
        considerationItem.endAmount = endAmount;
        considerationItem.recipient = recipient;
        considerationItems.push(considerationItem);
    }
}
