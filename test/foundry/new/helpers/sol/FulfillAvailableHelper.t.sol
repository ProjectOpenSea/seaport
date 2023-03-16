// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import "seaport-sol/SeaportSol.sol";
import {
    FulfillAvailableHelper
} from "seaport-sol/fulfillments/available/FulfillAvailableHelper.sol";

contract FulfillAvailableHelperTest is Test {
    using OrderParametersLib for OrderParameters;
    using OfferItemLib for OfferItem;
    using ConsiderationItemLib for ConsiderationItem;

    function testGetNaiveFulfillmentComponents() public {
        OrderParameters memory orderParameters = OrderParametersLib
            .empty()
            .withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib
                        .empty()
                        .withItemType(ItemType.ERC721)
                        .withToken(address(1234)),
                    OfferItemLib.empty().withItemType(ItemType.ERC20).withToken(
                        address(5678)
                    )
                )
            )
            .withConsideration(
                SeaportArrays.ConsiderationItems(
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC721)
                        .withToken(address(1234)),
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC20)
                        .withToken(address(5678)),
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC1155)
                        .withToken(address(9101112))
                )
            );

        (
            FulfillmentComponent[][] memory offer,
            FulfillmentComponent[][] memory consideration
        ) = FulfillAvailableHelper.getNaiveFulfillmentComponents(
                SeaportArrays.OrderParametersArray(orderParameters)
            );

        assertEq(offer.length, 2);
        assertEq(offer[0].length, 1);
        assertEq(offer[0][0].orderIndex, 0);
        assertEq(offer[0][0].itemIndex, 0);
        assertEq(offer[1].length, 1);
        assertEq(offer[1][0].orderIndex, 0);
        assertEq(offer[1][0].itemIndex, 1);
        assertEq(consideration.length, 3);
        assertEq(consideration[0].length, 1);
        assertEq(consideration[0][0].orderIndex, 0);
        assertEq(consideration[0][0].itemIndex, 0);
        assertEq(consideration[1].length, 1);
        assertEq(consideration[1][0].orderIndex, 0);
        assertEq(consideration[1][0].itemIndex, 1);
        assertEq(consideration[2].length, 1);
        assertEq(consideration[2][0].orderIndex, 0);
        assertEq(consideration[2][0].itemIndex, 2);

        OrderParameters memory orderParamtersTwo = OrderParametersLib
            .empty()
            .withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib
                        .empty()
                        .withItemType(ItemType.ERC721)
                        .withToken(address(1235)),
                    OfferItemLib.empty().withItemType(ItemType.ERC20).withToken(
                        address(5679)
                    ),
                    OfferItemLib
                        .empty()
                        .withItemType(ItemType.ERC1155)
                        .withToken(address(9101113))
                )
            )
            .withConsideration(
                SeaportArrays.ConsiderationItems(
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC721)
                        .withToken(address(1235)),
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC20)
                        .withToken(address(5679))
                )
            );

        (offer, consideration) = FulfillAvailableHelper
            .getNaiveFulfillmentComponents(
                SeaportArrays.OrderParametersArray(
                    orderParameters,
                    orderParamtersTwo
                )
            );
        assertEq(offer.length, 5);
        assertEq(offer[0].length, 1);
        assertEq(offer[0][0].orderIndex, 0);
        assertEq(offer[0][0].itemIndex, 0);
        assertEq(offer[1].length, 1);
        assertEq(offer[1][0].orderIndex, 0);
        assertEq(offer[1][0].itemIndex, 1);
        assertEq(offer[2].length, 1);
        assertEq(offer[2][0].orderIndex, 1);
        assertEq(offer[2][0].itemIndex, 0);
        assertEq(offer[3].length, 1);
        assertEq(offer[3][0].orderIndex, 1);
        assertEq(offer[3][0].itemIndex, 1);
        assertEq(offer[4].length, 1);
        assertEq(offer[4][0].orderIndex, 1);
        assertEq(offer[4][0].itemIndex, 2);
        assertEq(consideration.length, 5);
        assertEq(consideration[0].length, 1);
        assertEq(consideration[0][0].orderIndex, 0);
        assertEq(consideration[0][0].itemIndex, 0);
        assertEq(consideration[1].length, 1);
        assertEq(consideration[1][0].orderIndex, 0);
        assertEq(consideration[1][0].itemIndex, 1);
        assertEq(consideration[2].length, 1);
        assertEq(consideration[2][0].orderIndex, 0);
        assertEq(consideration[2][0].itemIndex, 2);
        assertEq(consideration[3].length, 1);
        assertEq(consideration[3][0].orderIndex, 1);
        assertEq(consideration[3][0].itemIndex, 0);
        assertEq(consideration[4].length, 1);
        assertEq(consideration[4][0].orderIndex, 1);
        assertEq(consideration[4][0].itemIndex, 1);
    }

    function testGetAggregatedFulfillmentComponents_single() public {
        OrderParameters memory orderParameters = OrderParametersLib
            .empty()
            .withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.empty().withItemType(ItemType.ERC20).withToken(
                        address(1234)
                    ),
                    OfferItemLib
                        .empty()
                        .withItemType(ItemType.ERC721)
                        .withToken(address(1235)),
                    OfferItemLib.empty().withItemType(ItemType.ERC20).withToken(
                        address(1234)
                    )
                )
            )
            .withConsideration(
                SeaportArrays.ConsiderationItems(
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC721)
                        .withToken(address(1234)),
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC1155)
                        .withToken(address(5678)),
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC1155)
                        .withToken(address(5678))
                )
            );

        (
            FulfillmentComponent[][] memory offer,
            FulfillmentComponent[][] memory consideration
        ) = FulfillAvailableHelper.getAggregatedFulfillmentComponents(
                SeaportArrays.OrderParametersArray(orderParameters)
            );
        assertEq(offer.length, 2, "offer length incorrect");
        assertEq(offer[0].length, 2, "offer index 0 length incorrect");
        assertEq(
            offer[0][0].orderIndex,
            0,
            "offer index 0 index 0 order index incorrect"
        );
        assertEq(
            offer[0][0].itemIndex,
            0,
            "offer index 0 index 0 item index incorrect"
        );
        assertEq(
            offer[0][1].orderIndex,
            0,
            "offer index 0 index 1 order index incorrect"
        );
        assertEq(
            offer[0][1].itemIndex,
            2,
            "offer index 0 index 1 item index incorrect"
        );
        assertEq(offer[1].length, 1, "offer index 1 length incorrect");
        assertEq(
            offer[1][0].orderIndex,
            0,
            "offer index 1 index 0 order index incorrect"
        );
        assertEq(
            offer[1][0].itemIndex,
            1,
            "offer index 1 index 0 item index incorrect"
        );

        assertEq(consideration.length, 2, "consideration length incorrect");
        assertEq(
            consideration[0].length,
            1,
            "consideration index 0 length incorrect"
        );
        assertEq(
            consideration[0][0].orderIndex,
            0,
            "consideration index 0 index 0 order index incorrect"
        );
        assertEq(
            consideration[0][0].itemIndex,
            0,
            "consideration index 0 index 0 item index incorrect"
        );
        assertEq(
            consideration[1].length,
            2,
            "consideration index 1 length incorrect"
        );
        assertEq(
            consideration[1][0].orderIndex,
            0,
            "consideration index 1 index 0 order index incorrect"
        );
        assertEq(
            consideration[1][0].itemIndex,
            1,
            "consideration index 1 index 0 item index incorrect"
        );
        assertEq(
            consideration[1][1].orderIndex,
            0,
            "consideration index 1 index 1 order index incorrect"
        );
        assertEq(
            consideration[1][1].itemIndex,
            2,
            "consideration index 1 index 1 item index incorrect"
        );
    }

    function testGetAggregatedFulfillmentComponents_multi() public {
        OrderParameters memory orderParameters = OrderParametersLib
            .empty()
            .withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.empty().withItemType(ItemType.ERC20).withToken(
                        address(1234)
                    ),
                    OfferItemLib
                        .empty()
                        .withItemType(ItemType.ERC721)
                        .withToken(address(1235)),
                    OfferItemLib.empty().withItemType(ItemType.ERC20).withToken(
                        address(1234)
                    )
                )
            )
            .withConsideration(
                SeaportArrays.ConsiderationItems(
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC721)
                        .withToken(address(1234)),
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC1155)
                        .withToken(address(5678)),
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC1155)
                        .withToken(address(5678))
                )
            );
        OrderParameters memory orderParamtersTwo = OrderParametersLib
            .empty()
            .withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.empty().withItemType(ItemType.ERC20).withToken(
                        address(1234)
                    ),
                    OfferItemLib
                        .empty()
                        .withItemType(ItemType.ERC1155)
                        .withToken(address(5678))
                )
            )
            .withConsideration(
                SeaportArrays.ConsiderationItems(
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC1155)
                        .withToken(address(5678)),
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC1155)
                        .withToken(address(5678))
                )
            );

        (
            FulfillmentComponent[][] memory offer,
            FulfillmentComponent[][] memory consideration
        ) = FulfillAvailableHelper.getAggregatedFulfillmentComponents(
                SeaportArrays.OrderParametersArray(
                    orderParameters,
                    orderParamtersTwo
                )
            );

        assertEq(offer.length, 3, "offer length incorrect");
        assertEq(offer[0].length, 3, "offer index 0 length incorrect");
        assertEq(
            offer[0][0].orderIndex,
            0,
            "offer index 0 index 0 order index incorrect"
        );
        assertEq(
            offer[0][0].itemIndex,
            0,
            "offer index 0 index 0 item index incorrect"
        );
        assertEq(
            offer[0][1].orderIndex,
            0,
            "offer index 0 index 1 order index incorrect"
        );
        assertEq(
            offer[0][1].itemIndex,
            2,
            "offer index 0 index 1 item index incorrect"
        );
        assertEq(
            offer[0][2].orderIndex,
            1,
            "offer index 0 index 2 order index incorrect"
        );
        assertEq(
            offer[0][2].itemIndex,
            0,
            "offer index 0 index 2 item index incorrect"
        );

        assertEq(offer[1].length, 1, "offer index 1 length incorrect");
        assertEq(
            offer[1][0].orderIndex,
            0,
            "offer index 1 index 0 order index incorrect"
        );
        assertEq(
            offer[1][0].itemIndex,
            1,
            "offer index 1 index 0 item index incorrect"
        );

        assertEq(offer[2].length, 1, "offer index 2 length incorrect");
        assertEq(
            offer[2][0].orderIndex,
            1,
            "offer index 2 index 0 order index incorrect"
        );
        assertEq(
            offer[2][0].itemIndex,
            1,
            "offer index 2 index 0 item index incorrect"
        );

        assertEq(consideration.length, 2, "consideration length incorrect");
        assertEq(
            consideration[0].length,
            1,
            "consideration index 0 length incorrect"
        );
        assertEq(
            consideration[0][0].orderIndex,
            0,
            "consideration index 0 index 0 order index incorrect"
        );
        assertEq(
            consideration[0][0].itemIndex,
            0,
            "consideration index 0 index 0 item index incorrect"
        );

        assertEq(
            consideration[1].length,
            4,
            "consideration index 1 length incorrect"
        );
        assertEq(
            consideration[1][0].orderIndex,
            0,
            "consideration index 1 index 0 order index incorrect"
        );
        assertEq(
            consideration[1][0].itemIndex,
            1,
            "consideration index 1 index 0 item index incorrect"
        );
        assertEq(
            consideration[1][1].orderIndex,
            0,
            "consideration index 1 index 1 order index incorrect"
        );
        assertEq(
            consideration[1][1].itemIndex,
            2,
            "consideration index 1 index 1 item index incorrect"
        );
        assertEq(
            consideration[1][2].orderIndex,
            1,
            "consideration index 1 index 2 order index incorrect"
        );
        assertEq(
            consideration[1][2].itemIndex,
            0,
            "consideration index 1 index 2 item index incorrect"
        );
        assertEq(
            consideration[1][3].orderIndex,
            1,
            "consideration index 1 index 3 order index incorrect"
        );
        assertEq(
            consideration[1][3].itemIndex,
            1,
            "consideration index 1 index 3 item index incorrect"
        );
    }

    function testAggregated_multi_conduitKey() public {
        OrderParameters memory orderParameters = OrderParametersLib
            .empty()
            .withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.empty().withItemType(ItemType.ERC20).withToken(
                        address(1234)
                    ),
                    OfferItemLib
                        .empty()
                        .withItemType(ItemType.ERC721)
                        .withToken(address(1235)),
                    OfferItemLib.empty().withItemType(ItemType.ERC20).withToken(
                        address(1234)
                    )
                )
            )
            .withConsideration(
                SeaportArrays.ConsiderationItems(
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC721)
                        .withToken(address(1234)),
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC1155)
                        .withToken(address(5678)),
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC1155)
                        .withToken(address(5678))
                )
            );
        OrderParameters memory orderParametersTwo = OrderParametersLib
            .empty()
            .withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.empty().withItemType(ItemType.ERC20).withToken(
                        address(1234)
                    ),
                    OfferItemLib
                        .empty()
                        .withItemType(ItemType.ERC1155)
                        .withToken(address(5678))
                )
            )
            .withConsideration(
                SeaportArrays.ConsiderationItems(
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC1155)
                        .withToken(address(5678)),
                    ConsiderationItemLib
                        .empty()
                        .withItemType(ItemType.ERC1155)
                        .withToken(address(5678))
                )
            )
            .withConduitKey(bytes32(uint256(1)));

        (
            FulfillmentComponent[][] memory offer,
            FulfillmentComponent[][] memory consideration
        ) = FulfillAvailableHelper.getAggregatedFulfillmentComponents(
                SeaportArrays.OrderParametersArray(
                    orderParameters,
                    orderParametersTwo
                )
            );

        assertEq(offer.length, 4, "offer length incorrect");
        assertEq(offer[0].length, 2, "offer index 0 length incorrect");
        assertEq(
            offer[0][0].orderIndex,
            0,
            "offer index 0 index 0 order index incorrect"
        );
        assertEq(
            offer[0][0].itemIndex,
            0,
            "offer index 0 index 0 item index incorrect"
        );
        assertEq(
            offer[0][1].orderIndex,
            0,
            "offer index 0 index 1 order index incorrect"
        );
        assertEq(
            offer[0][1].itemIndex,
            2,
            "offer index 0 index 1 item index incorrect"
        );
        // assertEq(
        //     offer[0][2].orderIndex,
        //     1,
        //     "offer index 0 index 2 order index incorrect"
        // );
        // assertEq(
        //     offer[0][2].itemIndex,
        //     0,
        //     "offer index 0 index 2 item index incorrect"
        // );

        assertEq(offer[1].length, 1, "offer index 1 length incorrect");
        assertEq(
            offer[1][0].orderIndex,
            0,
            "offer index 1 index 0 order index incorrect"
        );
        assertEq(
            offer[1][0].itemIndex,
            1,
            "offer index 1 index 0 item index incorrect"
        );

        assertEq(offer[2].length, 1, "offer index 2 length incorrect");
        assertEq(
            offer[2][0].orderIndex,
            1,
            "offer index 2 index 0 order index incorrect"
        );
        assertEq(
            offer[2][0].itemIndex,
            0,
            "offer index 2 index 0 item index incorrect"
        );

        assertEq(offer[3].length, 1, "offer index 2 length incorrect");
        assertEq(
            offer[3][0].orderIndex,
            1,
            "offer index 2 index 0 order index incorrect"
        );
        assertEq(
            offer[3][0].itemIndex,
            1,
            "offer index 2 index 0 item index incorrect"
        );

        assertEq(consideration.length, 2, "consideration length incorrect");
        assertEq(
            consideration[0].length,
            1,
            "consideration index 0 length incorrect"
        );
        assertEq(
            consideration[0][0].orderIndex,
            0,
            "consideration index 0 index 0 order index incorrect"
        );
        assertEq(
            consideration[0][0].itemIndex,
            0,
            "consideration index 0 index 0 item index incorrect"
        );

        assertEq(
            consideration[1].length,
            4,
            "consideration index 1 length incorrect"
        );
        assertEq(
            consideration[1][0].orderIndex,
            0,
            "consideration index 1 index 0 order index incorrect"
        );
        assertEq(
            consideration[1][0].itemIndex,
            1,
            "consideration index 1 index 0 item index incorrect"
        );
        assertEq(
            consideration[1][1].orderIndex,
            0,
            "consideration index 1 index 1 order index incorrect"
        );
        assertEq(
            consideration[1][1].itemIndex,
            2,
            "consideration index 1 index 1 item index incorrect"
        );
        assertEq(
            consideration[1][2].orderIndex,
            1,
            "consideration index 1 index 2 order index incorrect"
        );
        assertEq(
            consideration[1][2].itemIndex,
            0,
            "consideration index 1 index 2 item index incorrect"
        );
        assertEq(
            consideration[1][3].orderIndex,
            1,
            "consideration index 1 index 3 order index incorrect"
        );
        assertEq(
            consideration[1][3].itemIndex,
            1,
            "consideration index 1 index 3 item index incorrect"
        );
    }
}
