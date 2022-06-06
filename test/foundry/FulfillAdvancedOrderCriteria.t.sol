// SPDX-License-Identifier: MIT

pragma solidity >=0.8.13;

import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { Merkle } from "murky/Merkle.sol";
import { ConsiderationInterface } from "../../contracts/interfaces/ConsiderationInterface.sol";
import { OfferItem, OrderComponents, AdvancedOrder } from "../../contracts/lib/ConsiderationStructs.sol";
import { ItemType } from "../../contracts/lib/ConsiderationEnums.sol";

contract FulfillAvailableAdvancedOrderCriteria is BaseOrderTest {
    struct FuzzArgs {
        uint256[8] identifiers;
    }

    struct Context {
        ConsiderationInterface consideration;
        FuzzArgs args;
    }

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testFulfillAdvancedOrderWithCriteria(FuzzArgs memory args)
        public
    {}

    function fulfillAdvancedOrderWithCriteria(Context memory context)
        external
        stateless
    {
        bytes32[] memory identifiers = new bytes32[](4);
        for (uint256 i = 0; i < 4; i++) {
            test721_1.mint(alice, i);
            identifiers[i] = bytes32(i);
        }
        Merkle merkle = new Merkle();
        bytes32 root = merkle.getRoot(identifiers);

        addOfferItem721Criteria(address(test721_1), uint256(root));
        _configureEthConsiderationItem(alice, 1);

        _configureOrderParameters(alice, address(0), bytes32(0), 0, false);
        OrderComponents memory orderComponents = getOrderComponents(
            baseOrderParameters,
            context.consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );
        AdvancedOrder memory advancedOrder = AdvancedOrder(
            baseOrderParameters,
            1,
            1,
            signature,
            ""
        );

        context.consideration.fulfillAdvancedOrder(
            advancedOrder,
            criteriaResolvers,
            bytes32(0),
            address(0)
        );

        // consideration.

        // ConsiderationItem

        // AdvancedOrder memory advancedOrder
    }

    function addOfferItem721Criteria(address token, uint256 identifierHash)
        internal
    {
        addOfferItem721Criteria(token, identifierHash, 1, 1);
    }

    function addOfferItem721Criteria(
        address token,
        uint256 identifierHash,
        uint256 amount
    ) internal {
        addOfferItem721Criteria(token, identifierHash, amount, amount);
    }

    function addOfferItem721Criteria(
        address token,
        uint256 identifierHash,
        uint256 startAmount,
        uint256 endAmount
    ) internal {
        offerItems.push(
            OfferItem(
                ItemType.ERC721_WITH_CRITERIA,
                token,
                identifierHash,
                startAmount,
                endAmount
            )
        );
    }
}
