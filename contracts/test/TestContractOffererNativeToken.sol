// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

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
    Schema
} from "../lib/ConsiderationStructs.sol";

/**
 * @title TestContractOffererNativeToken
 */
contract TestContractOffererNativeToken is ContractOffererInterface {
    error OrderUnavailable();

    address private immutable _SEAPORT;

    SpentItem private _available;
    SpentItem private _required;

    bool public ready;
    bool public fulfilled;

    uint256 public extraAvailable;
    uint256 public extraRequired;

    constructor(address seaport) {
        // Set immutable values and storage variables.
        _SEAPORT = seaport;
        fulfilled = false;
        ready = false;
        extraAvailable = 0;
        extraRequired = 0;
    }

    receive() external payable {}

    function activate(
        SpentItem memory available,
        SpentItem memory required
    ) public payable {
        if (ready || fulfilled) {
            revert OrderUnavailable();
        }

        // Set storage variables.
        _available = available;
        _required = required;
        ready = true;
    }

    /// In case of criteria based orders and non-wildcard items, the member
    /// `available.identifier` would correspond to the `identifierOrCriteria`
    /// i.e., the merkle-root.
    /// @param identifier corresponds to the actual token-id that gets transferred.
    function activateWithCriteria(
        SpentItem memory available,
        SpentItem memory required,
        uint256 identifier
    ) public {
        if (ready || fulfilled) {
            revert OrderUnavailable();
        }

        if (available.itemType == ItemType.ERC721_WITH_CRITERIA) {
            ERC721Interface token = ERC721Interface(available.token);

            token.transferFrom(msg.sender, address(this), identifier);

            token.setApprovalForAll(_SEAPORT, true);
        } else if (available.itemType == ItemType.ERC1155_WITH_CRITERIA) {
            ERC1155Interface token = ERC1155Interface(available.token);

            token.safeTransferFrom(
                msg.sender,
                address(this),
                identifier,
                available.amount,
                ""
            );

            token.setApprovalForAll(_SEAPORT, true);
        }

        // Set storage variables.
        _available = available;
        _required = required;
        ready = true;
    }

    function extendAvailable() public {
        if (!ready || fulfilled) {
            revert OrderUnavailable();
        }

        extraAvailable++;

        _available.amount /= 2;
    }

    function extendRequired() public {
        if (!ready || fulfilled) {
            revert OrderUnavailable();
        }

        extraRequired++;
    }

    function generateOrder(
        address,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata context
    )
        external
        virtual
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Set the offer and consideration that were supplied during deployment.
        offer = new SpentItem[](1);
        consideration = new ReceivedItem[](1);

        // Send eth to Seaport.
        (bool success, ) = _SEAPORT.call{ value: minimumReceived[0].amount }(
            ""
        );

        // Revert if transaction fails.
        if (!success) {
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        // Set the offer item as the _available item in storage.
        offer[0] = minimumReceived[0];

        // Set the erc721 consideration item.
        consideration[0] = ReceivedItem({
            itemType: ItemType.ERC721,
            token: maximumSpent[0].token,
            identifier: maximumSpent[0].identifier,
            amount: maximumSpent[0].amount,
            recipient: payable(address(this))
        });

        // Update storage to reflect that the order has been fulfilled.
        fulfilled = true;
    }

    function previewOrder(
        address caller,
        address,
        SpentItem[] calldata,
        SpentItem[] calldata,
        bytes calldata context
    )
        external
        view
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Ensure the caller is Seaport & the order has not yet been fulfilled.
        if (!ready || fulfilled || caller != _SEAPORT || context.length != 0) {
            revert OrderUnavailable();
        }

        // Set the offer and consideration that were supplied during deployment.
        offer = new SpentItem[](1 + extraAvailable);
        consideration = new ReceivedItem[](1 + extraRequired);

        for (uint256 i = 0; i < 1 + extraAvailable; ++i) {
            offer[i] = _available;
        }

        for (uint256 i = 0; i < 1 + extraRequired; ++i) {
            consideration[i] = ReceivedItem({
                itemType: _required.itemType,
                token: _required.token,
                identifier: _required.identifier,
                amount: _required.amount,
                recipient: payable(address(this))
            });
        }
    }

    function getInventory()
        external
        view
        returns (SpentItem[] memory offerable, SpentItem[] memory receivable)
    {
        // Set offerable and receivable supplied at deployment if unfulfilled.
        if (!ready || fulfilled) {
            offerable = new SpentItem[](0);

            receivable = new SpentItem[](0);
        } else {
            offerable = new SpentItem[](1 + extraAvailable);
            for (uint256 i = 0; i < 1 + extraAvailable; ++i) {
                offerable[i] = _available;
            }

            receivable = new SpentItem[](1 + extraRequired);
            for (uint256 i = 0; i < 1 + extraRequired; ++i) {
                receivable[i] = _required;
            }
        }
    }

    function ratifyOrder(
        SpentItem[] calldata /* offer */,
        ReceivedItem[] calldata /* consideration */,
        bytes calldata /* context */,
        bytes32[] calldata /* orderHashes */,
        uint256 /* contractNonce */
    )
        external
        pure
        virtual
        override
        returns (bytes4 /* ratifyOrderMagicValue */)
    {
        return ContractOffererInterface.ratifyOrder.selector;
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

    /**
     * @dev Returns the metadata for this contract offerer.
     */
    function getSeaportMetadata()
        external
        pure
        override
        returns (
            string memory name,
            Schema[] memory schemas // map to Seaport Improvement Proposal IDs
        )
    {
        schemas = new Schema[](1);
        schemas[0].id = 1337;
        schemas[0].metadata = new bytes(0);

        return ("TestContractOffererNativeToken", schemas);
    }
}
