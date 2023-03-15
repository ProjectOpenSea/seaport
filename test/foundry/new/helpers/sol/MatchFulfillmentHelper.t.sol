// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import { MatchFulfillmentHelper } from "seaport-sol/MatchFulfillmentHelper.sol";

import "seaport-sol/SeaportSol.sol";

contract MatchFulfillmentHelperTest is Test {
    using OrderParametersLib for OrderParameters;
    using OfferItemLib for OfferItem;
    using ConsiderationItemLib for ConsiderationItem;

    string constant ERC20 = "erc20";
    string constant ERC721 = "erc721";
    string constant ERC1155 = "erc1155";

    string constant ERC20_ONE = "erc20_one";
    string constant ERC20_TWO = "erc20_two";

    string constant ERC721_ONE = "erc721_one";
    string constant ERC721_TWO = "erc721_two";

    string constant ERC1155_ONE = "erc1155_one";
    string constant ERC1155_TWO = "erc1155_two";

    function setUp() public virtual {
        // Base configuration.
        OfferItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withStartAmount(1)
            .withEndAmount(1)
            .withIdentifierOrCriteria(0)
            .saveDefault(ERC20);
        ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withStartAmount(1)
            .withEndAmount(1)
            .withIdentifierOrCriteria(0)
            .withRecipient(address(0x1337))
            .saveDefault(ERC20);

        OfferItemLib
            .empty()
            .withItemType(ItemType.ERC721)
            .withStartAmount(1)
            .withEndAmount(1)
            .withIdentifierOrCriteria(1)
            .saveDefault(ERC721);
        ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC721)
            .withStartAmount(1)
            .withEndAmount(1)
            .withIdentifierOrCriteria(1)
            .withRecipient(address(0x1337))
            .saveDefault(ERC721);

        OfferItemLib
            .empty()
            .withItemType(ItemType.ERC1155)
            .withStartAmount(1)
            .withEndAmount(1)
            .withIdentifierOrCriteria(1)
            .saveDefault(ERC1155);
        ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC1155)
            .withStartAmount(1)
            .withEndAmount(1)
            .withIdentifierOrCriteria(1)
            .withRecipient(address(0x1337))
            .saveDefault(ERC1155);

        // Token configuration, offer side.
        OfferItemLib.fromDefault(ERC20).withToken(address(201)).saveDefault(
            ERC20_ONE
        );
        OfferItemLib.fromDefault(ERC20).withToken(address(202)).saveDefault(
            ERC20_TWO
        );

        OfferItemLib.fromDefault(ERC721).withToken(address(7211)).saveDefault(
            ERC721_ONE
        );
        OfferItemLib.fromDefault(ERC721).withToken(address(7212)).saveDefault(
            ERC721_TWO
        );

        OfferItemLib.fromDefault(ERC1155).withToken(address(11551)).saveDefault(
            ERC1155_ONE
        );
        OfferItemLib.fromDefault(ERC1155).withToken(address(11552)).saveDefault(
            ERC1155_TWO
        );

        // Token configuration, consideration side.
        ConsiderationItemLib
            .fromDefault(ERC20)
            .withToken(address(201))
            .saveDefault(ERC20_ONE);
        ConsiderationItemLib
            .fromDefault(ERC20)
            .withToken(address(202))
            .saveDefault(ERC20_TWO);

        ConsiderationItemLib
            .fromDefault(ERC721)
            .withToken(address(7211))
            .saveDefault(ERC721_ONE);
        ConsiderationItemLib
            .fromDefault(ERC721)
            .withToken(address(7212))
            .saveDefault(ERC721_TWO);

        ConsiderationItemLib
            .fromDefault(ERC1155)
            .withToken(address(11551))
            .saveDefault(ERC1155_ONE);
        ConsiderationItemLib
            .fromDefault(ERC1155)
            .withToken(address(11552))
            .saveDefault(ERC1155_TWO);
    }

    function testGetMatchedFulfillments_singlePair() public {
        OrderParameters memory orderParameters = OrderParametersLib
            .empty()
            .withOffer(
                SeaportArrays.OfferItems(
                    // Offer one ERC721
                    OfferItemLib.fromDefault(ERC721_ONE),
                    // Offer one ERC20
                    OfferItemLib.fromDefault(ERC20_ONE)
                )
            )
            .withConsideration(
                SeaportArrays.ConsiderationItems(
                    // Consider one ERC721
                    ConsiderationItemLib.fromDefault(ERC721_TWO),
                    // Consider one ERC20
                    ConsiderationItemLib.fromDefault(ERC20_TWO),
                    // Consider one ERC1155
                    ConsiderationItemLib.fromDefault(ERC1155_ONE)
                )
            );

        OrderParameters memory orderParametersMirror = OrderParametersLib
            .empty()
            .withOffer(
                SeaportArrays.OfferItems(
                    // Offer one ERC721
                    OfferItemLib.fromDefault(ERC721_TWO),
                    // Offer one ERC20
                    OfferItemLib.fromDefault(ERC20_TWO),
                    // Offer one ERC1155
                    OfferItemLib.fromDefault(ERC1155_ONE)
                )
            )
            .withConsideration(
                SeaportArrays.ConsiderationItems(
                    // Consider one ERC721
                    ConsiderationItemLib.fromDefault(ERC721_ONE),
                    // Consider one ERC20
                    ConsiderationItemLib.fromDefault(ERC20_ONE)
                )
            );

        OrderParameters[] memory orderParametersArray = new OrderParameters[](
            2
        );
        orderParametersArray[0] = orderParameters;
        orderParametersArray[1] = orderParametersMirror;

        Fulfillment[] memory fulfillments = MatchFulfillmentHelper
            .getMatchedFulfillments(orderParametersArray);

        assertEq(fulfillments.length, 5);

        for (uint256 i; i < fulfillments.length; ++i) {
            assertEq(fulfillments[i].offerComponents.length, 1);
            assertEq(fulfillments[i].considerationComponents.length, 1);

            assertTrue(
                fulfillments[i].offerComponents[0].orderIndex !=
                    fulfillments[i].considerationComponents[0].orderIndex
            );
        }

        assertEq(fulfillments[0].offerComponents[0].orderIndex, 1);
        assertEq(fulfillments[0].offerComponents[0].itemIndex, 0);
        assertEq(fulfillments[0].considerationComponents[0].orderIndex, 0);
        assertEq(fulfillments[0].considerationComponents[0].itemIndex, 0);
        assertEq(fulfillments[1].offerComponents[0].orderIndex, 1);
        assertEq(fulfillments[1].offerComponents[0].itemIndex, 1);
        assertEq(fulfillments[1].considerationComponents[0].orderIndex, 0);
        assertEq(fulfillments[1].considerationComponents[0].itemIndex, 1);
        assertEq(fulfillments[2].offerComponents[0].orderIndex, 1);
        assertEq(fulfillments[2].offerComponents[0].itemIndex, 2);
        assertEq(fulfillments[2].considerationComponents[0].orderIndex, 0);
        assertEq(fulfillments[2].considerationComponents[0].itemIndex, 2);
        assertEq(fulfillments[3].offerComponents[0].orderIndex, 0);
        assertEq(fulfillments[3].offerComponents[0].itemIndex, 0);
        assertEq(fulfillments[3].considerationComponents[0].orderIndex, 1);
        assertEq(fulfillments[3].considerationComponents[0].itemIndex, 0);
        assertEq(fulfillments[4].offerComponents[0].orderIndex, 0);
        assertEq(fulfillments[4].offerComponents[0].itemIndex, 1);
        assertEq(fulfillments[4].considerationComponents[0].orderIndex, 1);
        assertEq(fulfillments[4].considerationComponents[0].itemIndex, 1);
    }

    function testGetAggregatedFulfillmentComponents_multi() public {
        OrderParameters memory orderParameters = OrderParametersLib
            .empty()
            .withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.fromDefault(ERC20_ONE),
                    OfferItemLib.fromDefault(ERC20_ONE),
                    OfferItemLib.fromDefault(ERC721_ONE)
                )
            )
            .withConsideration(
                SeaportArrays.ConsiderationItems(
                    ConsiderationItemLib.fromDefault(ERC721_TWO),
                    ConsiderationItemLib.fromDefault(ERC1155_ONE),
                    ConsiderationItemLib.fromDefault(ERC1155_ONE)
                )
            );
        OrderParameters memory mirrorOrderParameters = OrderParametersLib
            .empty()
            .withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.fromDefault(ERC721_TWO),
                    OfferItemLib.fromDefault(ERC1155_ONE),
                    OfferItemLib.fromDefault(ERC1155_ONE)
                )
            )
            .withConsideration(
                SeaportArrays.ConsiderationItems(
                    ConsiderationItemLib.fromDefault(ERC20_ONE),
                    ConsiderationItemLib.fromDefault(ERC20_ONE),
                    ConsiderationItemLib.fromDefault(ERC721_ONE)
                )
            );

        OrderParameters memory orderParametersTwo = OrderParametersLib
            .empty()
            .withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.fromDefault(ERC20_ONE),
                    OfferItemLib.fromDefault(ERC1155_ONE)
                )
            )
            .withConsideration(
                SeaportArrays.ConsiderationItems(
                    ConsiderationItemLib.fromDefault(ERC1155_ONE),
                    ConsiderationItemLib.fromDefault(ERC1155_ONE)
                )
            );
        OrderParameters memory mirrorOrderParametersTwo = OrderParametersLib
            .empty()
            .withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.fromDefault(ERC1155_ONE),
                    OfferItemLib.fromDefault(ERC1155_ONE)
                )
            )
            .withConsideration(
                SeaportArrays.ConsiderationItems(
                    ConsiderationItemLib.fromDefault(ERC20_ONE),
                    ConsiderationItemLib.fromDefault(ERC1155_ONE)
                )
            );

        OrderParameters[] memory orderParametersArray = new OrderParameters[](
            4
        );
        orderParametersArray[0] = orderParameters;
        orderParametersArray[1] = orderParametersTwo;
        orderParametersArray[2] = mirrorOrderParameters;
        orderParametersArray[3] = mirrorOrderParametersTwo;

        Fulfillment[] memory fulfillments = MatchFulfillmentHelper
            .getMatchedFulfillments(orderParametersArray);

        // Uses ERC20_ONE, ERC721_ONE, ERC721_TWO, and ERC1155_ONE, all jumbled
        // up.  The fulfillments should get boiled down to 4 net transfers.
        assertEq(fulfillments.length, 4, "fulfillments length incorrect");

        for (uint256 i; i < fulfillments.length; ++i) {
            assertTrue(
                fulfillments[i].offerComponents[0].orderIndex !=
                    fulfillments[i].considerationComponents[0].orderIndex,
                "order indexes should not be equal"
            );
        }

        assertEq(fulfillments[0].offerComponents.length, 1);
        assertEq(fulfillments[0].considerationComponents.length, 1);
        assertEq(fulfillments[0].offerComponents[0].orderIndex, 2);
        assertEq(fulfillments[0].offerComponents[0].itemIndex, 0);
        assertEq(fulfillments[0].considerationComponents[0].orderIndex, 0);
        assertEq(fulfillments[0].considerationComponents[0].itemIndex, 0);

        assertEq(fulfillments[1].offerComponents.length, 5);
        assertEq(fulfillments[1].offerComponents[0].orderIndex, 1);
        assertEq(fulfillments[1].offerComponents[0].itemIndex, 1);
        assertEq(fulfillments[1].offerComponents[1].orderIndex, 2);
        assertEq(fulfillments[1].offerComponents[1].itemIndex, 1);
        assertEq(fulfillments[1].offerComponents[2].orderIndex, 2);
        assertEq(fulfillments[1].offerComponents[2].itemIndex, 2);
        assertEq(fulfillments[1].offerComponents[3].orderIndex, 3);
        assertEq(fulfillments[1].offerComponents[3].itemIndex, 0);
        assertEq(fulfillments[1].offerComponents[4].orderIndex, 3);
        assertEq(fulfillments[1].offerComponents[4].itemIndex, 1);
        assertEq(fulfillments[1].considerationComponents.length, 5);
        assertEq(fulfillments[1].considerationComponents[0].orderIndex, 0);
        assertEq(fulfillments[1].considerationComponents[0].itemIndex, 1);
        assertEq(fulfillments[1].considerationComponents[1].orderIndex, 0);
        assertEq(fulfillments[1].considerationComponents[1].itemIndex, 2);
        assertEq(fulfillments[1].considerationComponents[2].orderIndex, 1);
        assertEq(fulfillments[1].considerationComponents[2].itemIndex, 0);
        assertEq(fulfillments[1].considerationComponents[3].orderIndex, 1);
        assertEq(fulfillments[1].considerationComponents[3].itemIndex, 1);
        assertEq(fulfillments[1].considerationComponents[4].orderIndex, 3);
        assertEq(fulfillments[1].considerationComponents[4].itemIndex, 1);

        assertEq(fulfillments[2].offerComponents.length, 3);
        assertEq(fulfillments[2].offerComponents[0].orderIndex, 0);
        assertEq(fulfillments[2].offerComponents[0].itemIndex, 0);
        assertEq(fulfillments[2].offerComponents[1].orderIndex, 0);
        assertEq(fulfillments[2].offerComponents[1].itemIndex, 1);
        assertEq(fulfillments[2].offerComponents[2].orderIndex, 1);
        assertEq(fulfillments[2].offerComponents[2].itemIndex, 0);
        assertEq(fulfillments[2].considerationComponents.length, 3);
        assertEq(fulfillments[2].considerationComponents[0].orderIndex, 2);
        assertEq(fulfillments[2].considerationComponents[0].itemIndex, 0);
        assertEq(fulfillments[2].considerationComponents[1].orderIndex, 2);
        assertEq(fulfillments[2].considerationComponents[1].itemIndex, 1);
        assertEq(fulfillments[2].considerationComponents[2].orderIndex, 3);
        assertEq(fulfillments[2].considerationComponents[2].itemIndex, 0);

        assertEq(fulfillments[3].offerComponents.length, 1);
        assertEq(fulfillments[3].offerComponents[0].orderIndex, 0);
        assertEq(fulfillments[3].offerComponents[0].itemIndex, 2);
        assertEq(fulfillments[3].considerationComponents.length, 1);
        assertEq(fulfillments[3].considerationComponents[0].orderIndex, 2);
        assertEq(fulfillments[3].considerationComponents[0].itemIndex, 2);
    }
}
