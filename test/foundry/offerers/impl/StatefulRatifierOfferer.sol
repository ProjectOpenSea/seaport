// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "../../../../contracts/interfaces/AbridgedTokenInterfaces.sol";

import {
    ContractOffererInterface
} from "../../../../contracts/interfaces/ContractOffererInterface.sol";

import {
    ItemType,
    Side
} from "../../../../contracts/lib/ConsiderationEnums.sol";

import {
    SpentItem,
    ReceivedItem,
    Schema
} from "../../../../contracts/lib/ConsiderationStructs.sol";

interface ERC20Mintable {
    function mint(address to, uint256 amount) external;
}

contract StatefulRatifierOfferer is ContractOffererInterface {
    error IncorrectValue(uint256 actual, uint256 expected);
    error IncorrectToken(address actual, address expected);
    error IncorrectItemType(ItemType actual, ItemType expected);
    error IncorrectContext(bytes context);
    error IncorrectOrderHashesLength(uint256 actual, uint256 expected);
    error IncorrectLength(Side side, uint256 actual, uint256 expected);

    ERC20Interface token1;
    ERC721Interface token2;
    uint256 value;
    bool public called;
    uint256 numOffersToReturn;

    constructor(
        address seaport,
        ERC20Interface _token1,
        ERC721Interface _token2,
        uint256 _numOffersToReturn
    ) {
        numOffersToReturn = _numOffersToReturn;
        _token1.approve(seaport, type(uint256).max);
        token1 = _token1;
        token2 = _token2;
        ERC20Mintable(address(_token1)).mint(address(this), 100000);
    }

    /**
     * @dev Generates an order with the specified minimum and maximum spent items,
     * and the optional extra data.
     *
     * @param -               Fulfiller, unused here.
     * @param minimumReceived The minimum items that the caller is willing to
     *                        receive.
     * @param -               maximumSent, unused here.
     * @param -               context, unused here.
     *
     * @return offer         A tuple containing the offer items.
     * @return consideration A tuple containing the consideration items.
     */
    function generateOrder(
        address,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata,
        bytes calldata
    )
        external
        virtual
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Generate an offer of ERC20 items.
        value = minimumReceived[0].amount;
        offer = new SpentItem[](numOffersToReturn);
        for (uint256 i; i < numOffersToReturn; i++) {
            // Create a new ERC20 item with a unique value.
            offer[i] = SpentItem({
                itemType: ItemType.ERC20,
                token: address(token1),
                identifier: 0,
                amount: value + i
            });
        }

        // Generate a consideration of a three ERC721 items.
        consideration = new ReceivedItem[](3);
        consideration[0] = ReceivedItem({
            itemType: ItemType.ERC721,
            token: address(token2),
            identifier: 42,
            amount: 1,
            recipient: payable(address(this))
        });

        // Return the offer and consideration.
        consideration[1] = ReceivedItem({
            itemType: ItemType.ERC721,
            token: address(token2),
            identifier: 43,
            amount: 1,
            recipient: payable(address(this))
        });
        consideration[2] = ReceivedItem({
            itemType: ItemType.ERC721,
            token: address(token2),
            identifier: 44,
            amount: 1,
            recipient: payable(address(this))
        });
        return (offer, consideration);
    }

    /**
     * @dev Generates an order in response to a minimum received set of items.
     *
     * @param -               caller, unused here.
     * @param -               fulfiller, unused here.
     * @param minimumReceived The minimum received set.
     * @param -               maximumSpent, unused here.
     * @param -               context, unused here.
     *
     * @return offer         The offer for the order.
     * @return consideration The consideration for the order.
     */
    function previewOrder(
        address,
        address,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata,
        bytes calldata
    )
        external
        view
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Set the value of the items to be spent.
        uint256 _value = minimumReceived[0].amount;

        // Create an offer array and populate it with ERC20 items.
        offer = new SpentItem[](numOffersToReturn);
        for (uint256 i; i < numOffersToReturn; i++) {
            offer[i] = SpentItem({
                itemType: ItemType.ERC20,
                token: address(token1),
                identifier: 0,
                amount: _value + i
            });
        }

        // Create a consideration array with three ERC721 items.
        consideration = new ReceivedItem[](3);
        consideration[0] = ReceivedItem({
            itemType: ItemType.ERC721,
            token: address(token2),
            identifier: 42,
            amount: 1,
            recipient: payable(address(this))
        });

        // Return the offer and consideration.
        consideration[1] = ReceivedItem({
            itemType: ItemType.ERC721,
            token: address(token2),
            identifier: 43,
            amount: 1,
            recipient: payable(address(this))
        });
        consideration[2] = ReceivedItem({
            itemType: ItemType.ERC721,
            token: address(token2),
            identifier: 44,
            amount: 1,
            recipient: payable(address(this))
        });
        return (offer, consideration);
    }

    function ratifyOrder(
        SpentItem[] calldata minimumReceived /* offer */,
        ReceivedItem[] calldata maximumSpent /* consideration */,
        bytes calldata context /* context */,
        bytes32[] calldata orderHashes /* orderHashes */,
        uint256 /* contractNonce */
    ) external override returns (bytes4 /* ratifyOrderMagicValue */) {
        // check that the length matches what is expected
        if (minimumReceived.length != numOffersToReturn) {
            revert IncorrectLength(
                Side.OFFER,
                minimumReceived.length,
                numOffersToReturn
            );
        }
        // Check that all minimumReceived items are of type ERC20.

        for (uint256 i = 0; i < minimumReceived.length; i++) {
            if (minimumReceived[i].itemType != ItemType.ERC20) {
                revert IncorrectItemType(
                    minimumReceived[i].itemType,
                    ItemType.ERC20
                );
            }

            // Check that the token address for each minimumReceived item is
            // correct.
            if (minimumReceived[i].token != address(token1)) {
                revert IncorrectToken(
                    minimumReceived[i].token,
                    address(token1)
                );
            }

            // Check that the value of each minimumReceived item is correct.
            if (minimumReceived[i].amount != value + i) {
                revert IncorrectValue(minimumReceived[i].amount, value + i);
            }
        }

        if (maximumSpent.length != 3) {
            revert IncorrectLength(Side.CONSIDERATION, maximumSpent.length, 3);
        }
        // Check that all maximumSpent items are of type ERC721, that the
        // address is correct, and that the token ID is correct.
        for (uint256 i; i < maximumSpent.length; i++) {
            if (maximumSpent[i].itemType != ItemType.ERC721) {
                revert IncorrectItemType(
                    maximumSpent[i].itemType,
                    ItemType.ERC721
                );
            }
            if (maximumSpent[i].token != address(token2)) {
                revert IncorrectToken(maximumSpent[i].token, address(token2));
            }
            if (maximumSpent[i].identifier != 42 + i) {
                revert IncorrectValue(maximumSpent[i].identifier, 42 + i);
            }
        }

        // Check that the context is correct.
        if (keccak256(context) != keccak256("context")) {
            revert IncorrectContext(context);
        }

        // Check that the orderHashes length is correct.
        if (orderHashes.length < 1) {
            revert IncorrectOrderHashesLength(orderHashes.length, 1);
        }

        // Set the public called bool to true.
        called = true;

        // Return the ratifyOrderMagicValue.
        return ContractOffererInterface.ratifyOrder.selector;
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

        return ("StatefulRatifierOfferer", schemas);
    }
}
