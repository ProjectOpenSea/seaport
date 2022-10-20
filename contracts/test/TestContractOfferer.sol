// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "../interfaces/AbridgedTokenInterfaces.sol";

import {
    ContractOffererInterface
} from "../interfaces/ContractOffererInterface.sol";

import { ItemType } from "../lib/ConsiderationEnums.sol";

import {
    SpentItem,
    ReceivedItem,
    InventoryUpdate
} from "../lib/ConsiderationStructs.sol";

/**
 * @title TestContractOfferer
 * @author 0age
 * @notice TestContractOfferer is a maximally simple contract offerer. It offers
 *         a single item and expects to receive back another single item, and
 *         ignores all parameters supplied to it when previewing or generating
 *         an order. The offered item is placed into this contract as part of
 *         deployment and the corresponding token approvals are set for Seaport.
 */
contract TestContractOfferer is ContractOffererInterface {
    error OrderUnavailable();

    address private immutable _SEAPORT;

    SpentItem private _available;
    SpentItem private _required;

    bool public ready;
    bool public fulfilled;

    constructor(address seaport) {
        // Set immutable values and storage variables.
        _SEAPORT = seaport;
        fulfilled = false;
        ready = false;
    }

    receive() external payable {}

    function activate(SpentItem memory available, SpentItem memory required)
        public
        payable
    {
        if (ready || fulfilled) {
            revert OrderUnavailable();
        }

        // Retrieve the offered item and set associated approvals.
        if (available.itemType == ItemType.NATIVE) {
            available.amount = address(this).balance;
        } else if (available.itemType == ItemType.ERC20) {
            ERC20Interface token = ERC20Interface(available.token);

            token.transferFrom(msg.sender, address(this), available.amount);

            token.approve(_SEAPORT, available.amount);
        } else if (available.itemType == ItemType.ERC721) {
            ERC721Interface token = ERC721Interface(available.token);

            token.transferFrom(msg.sender, address(this), available.identifier);

            token.setApprovalForAll(_SEAPORT, true);
        } else if (available.itemType == ItemType.ERC1155) {
            ERC1155Interface token = ERC1155Interface(available.token);

            token.safeTransferFrom(
                msg.sender,
                address(this),
                available.identifier,
                available.amount,
                ""
            );

            token.setApprovalForAll(_SEAPORT, true);
        }

        // Emit an event indicating that the initial inventory has been updated.
        InventoryUpdate[] memory inventoryUpdate = new InventoryUpdate[](2);

        inventoryUpdate[0] = InventoryUpdate({
            item: available,
            offerable: true,
            receivable: false
        });
        inventoryUpdate[1] = InventoryUpdate({
            item: required,
            offerable: false,
            receivable: true
        });

        emit InventoryUpdated(inventoryUpdate);

        // Set storage variables.
        _available = available;
        _required = required;
        ready = true;
    }

    function generateOrder(
        SpentItem[] calldata,
        SpentItem[] calldata,
        bytes calldata
    )
        external
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Ensure the caller is Seaport & the order has not yet been fulfilled.
        if (!ready || fulfilled || msg.sender != _SEAPORT) {
            revert OrderUnavailable();
        }

        // Set the offer and consideration that were supplied during deployment.
        offer = new SpentItem[](1);
        consideration = new ReceivedItem[](1);

        offer[0] = _available;
        consideration[0] = ReceivedItem({
            itemType: _required.itemType,
            token: _required.token,
            identifier: _required.identifier,
            amount: _required.amount,
            recipient: payable(address(this))
        });

        // Emit an event indicating that the inventory has been updated.
        InventoryUpdate[] memory inventoryUpdate = new InventoryUpdate[](2);

        inventoryUpdate[0] = InventoryUpdate({
            item: _available,
            offerable: false,
            receivable: false
        });
        inventoryUpdate[1] = InventoryUpdate({
            item: _required,
            offerable: false,
            receivable: false
        });

        emit InventoryUpdated(inventoryUpdate);

        // Update storage to reflect that the order has been fulfilled.
        fulfilled = true;
    }

    function previewOrder(
        address caller,
        SpentItem[] calldata,
        SpentItem[] calldata,
        bytes calldata
    )
        external
        view
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Ensure the caller is Seaport & the order has not yet been fulfilled.
        if (!ready || fulfilled || caller != _SEAPORT) {
            revert OrderUnavailable();
        }

        // Set the offer and consideration that were supplied during deployment.
        offer = new SpentItem[](1);
        consideration = new ReceivedItem[](1);

        offer[0] = _available;
        consideration[0] = ReceivedItem({
            itemType: _required.itemType,
            token: _required.token,
            identifier: _required.identifier,
            amount: _required.amount,
            recipient: payable(address(this))
        });
    }

    function getInventory()
        external
        view
        override
        returns (SpentItem[] memory offerable, SpentItem[] memory receivable)
    {
        // Set offerable and receivable supplied at deployment if unfulfilled.
        if (!ready || fulfilled) {
            offerable = new SpentItem[](0);

            receivable = new SpentItem[](0);
        } else {
            offerable = new SpentItem[](1);
            offerable[0] = _available;

            receivable = new SpentItem[](1);
            receivable[0] = _required;
        }
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return bytes4(0xf23a6e61);
    }
}
