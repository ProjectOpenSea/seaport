// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import { MatchFulfillmentHelper } from "seaport-sol/MatchFulfillmentHelper.sol";

import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";

import "seaport-sol/SeaportSol.sol";

contract MatchFulfillmentHelperTest is Test {
    using Strings for uint256;
    using OrderParametersLib for OrderParameters;
    using OfferItemLib for OfferItem;
    using ConsiderationItemLib for ConsiderationItem;

    address A;
    address B;
    address C;
    address D;
    address E;
    address F;
    address G;

    function setUp() public virtual {
        A = makeAddr("A");
        B = makeAddr("B");
        C = makeAddr("C");
        D = makeAddr("D");
        E = makeAddr("E");
        F = makeAddr("F");
        G = makeAddr("G");
    }

    function testGetMatchedFulfillments_self() public {
        Order memory order = Order({
            parameters: OrderParametersLib.empty().withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.empty().withToken(address(A)).withStartAmount(100)
                        .withEndAmount(100)
                )
                ).withConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib.empty().withToken(address(A))
                            .withStartAmount(100).withEndAmount(100)
                    )
                ),
            signature: ""
        });

        Fulfillment memory expectedFulfillment = Fulfillment({
            offerComponents: SeaportArrays.FulfillmentComponents(
                FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                ),
            considerationComponents: SeaportArrays.FulfillmentComponents(
                FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                )
        });

        Fulfillment[] memory fulfillments = MatchFulfillmentHelper
            .getMatchedFulfillments(SeaportArrays.Orders(order));

        assertEq(fulfillments.length, 1);
        assertEq(fulfillments[0], expectedFulfillment, "fulfillments[0]");
    }

    function testGetMatchedFulfillments_1to1() public {
        Order memory order = Order({
            parameters: OrderParametersLib.empty().withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.empty().withToken(address(A)).withStartAmount(100)
                        .withEndAmount(100)
                )
                ).withConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib.empty().withToken(address(B))
                            .withStartAmount(100).withEndAmount(100)
                    )
                ),
            signature: ""
        });

        Order memory otherOrder = Order({
            parameters: OrderParametersLib.empty().withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.empty().withToken(address(B)).withStartAmount(100)
                        .withEndAmount(100)
                )
                ).withConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib.empty().withToken(address(A))
                            .withStartAmount(100).withEndAmount(100)
                    )
                ),
            signature: ""
        });

        Fulfillment[] memory expectedFulfillments = SeaportArrays.Fulfillments(
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                    ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 1, itemIndex: 0 })
                    )
            }),
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 1, itemIndex: 0 })
                    ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                    )
            })
        );

        Fulfillment[] memory fulfillments = MatchFulfillmentHelper
            .getMatchedFulfillments(SeaportArrays.Orders(otherOrder, order));

        assertEq(fulfillments.length, 2, "fulfillments.length");
        assertEq(fulfillments[0], expectedFulfillments[1], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[0], "fulfillments[1]");
    }

    function testGetMatchedFulfillments_1to1ExcessOffer() public {
        Order memory order = Order({
            parameters: OrderParametersLib.empty().withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.empty().withToken(address(A)).withStartAmount(100)
                        .withEndAmount(100)
                )
                ).withConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib.empty().withToken(address(B))
                            .withStartAmount(100).withEndAmount(100)
                    )
                ).withOfferer(makeAddr("offerer 1")),
            signature: ""
        });

        Order memory otherOrder = Order({
            parameters: OrderParametersLib.empty().withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.empty().withToken(address(B)).withStartAmount(200)
                        .withEndAmount(200)
                )
                ).withConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib.empty().withToken(address(A))
                            .withStartAmount(100).withEndAmount(100)
                    )
                ).withOfferer(makeAddr("offerer 2")),
            signature: ""
        });

        Fulfillment[] memory expectedFulfillments = SeaportArrays.Fulfillments(
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                    ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 1, itemIndex: 0 })
                    )
            }),
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 1, itemIndex: 0 })
                    ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                    )
            })
        );

        Fulfillment[] memory fulfillments = MatchFulfillmentHelper
            .getMatchedFulfillments(SeaportArrays.Orders(otherOrder, order));

        assertEq(fulfillments.length, 2, "fulfillments.length");
        assertEq(fulfillments[0], expectedFulfillments[1], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[0], "fulfillments[1]");
    }

    function testGetMatchedFulfillments_3to1() public {
        Order memory order = Order({
            parameters: OrderParametersLib.empty().withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.empty().withToken(address(A)).withStartAmount(100)
                        .withEndAmount(100)
                )
                ).withConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib.empty().withToken(address(B))
                            .withStartAmount(1).withEndAmount(1),
                        ConsiderationItemLib.empty().withToken(address(A))
                            .withStartAmount(10).withEndAmount(10),
                        ConsiderationItemLib.empty().withToken(address(A))
                            .withStartAmount(10).withEndAmount(10)
                    )
                ).withOfferer(makeAddr("offerer1")),
            signature: ""
        });

        Order memory otherOrder = Order({
            parameters: OrderParametersLib.empty().withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.empty().withToken(address(B)).withStartAmount(1)
                        .withEndAmount(1)
                )
                ).withConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib.empty().withToken(address(A))
                            .withStartAmount(80).withEndAmount(80).withRecipient(
                            makeAddr("offerer2")
                        )
                    )
                ).withOfferer(makeAddr("offerer2")),
            signature: ""
        });

        Fulfillment[] memory expectedFulfillments = SeaportArrays.Fulfillments(
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                    ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 1, itemIndex: 0 })
                    )
            }),
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                    ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 1 }),
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 2 })
                    )
            }),
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 1, itemIndex: 0 })
                    ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                    )
            })
        );

        Fulfillment[] memory fulfillments = MatchFulfillmentHelper
            .getMatchedFulfillments(SeaportArrays.Orders(order, otherOrder));

        assertEq(fulfillments.length, 3, "fulfillments.length");

        assertEq(fulfillments[0], expectedFulfillments[2], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[1], "fulfillments[1]");
        assertEq(fulfillments[2], expectedFulfillments[0], "fulfillments[2]");
    }

    function testGetMatchedFulfillments_3to1Extra() public {
        Order memory order = Order({
            parameters: OrderParametersLib.empty().withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.empty().withToken(address(A)).withStartAmount(110)
                        .withEndAmount(110)
                )
                ).withConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib.empty().withToken(address(B))
                            .withStartAmount(1).withEndAmount(1),
                        ConsiderationItemLib.empty().withToken(address(A))
                            .withStartAmount(10).withEndAmount(10),
                        ConsiderationItemLib.empty().withToken(address(A))
                            .withStartAmount(10).withEndAmount(10)
                    )
                ).withOfferer(makeAddr("offerer1")),
            signature: ""
        });

        Order memory otherOrder = Order({
            parameters: OrderParametersLib.empty().withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.empty().withToken(address(B)).withStartAmount(1)
                        .withEndAmount(1)
                )
                ).withConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib.empty().withToken(address(A))
                            .withStartAmount(80).withEndAmount(80).withRecipient(
                            makeAddr("offerer2")
                        )
                    )
                ).withOfferer(makeAddr("offerer2")),
            signature: ""
        });

        Fulfillment[] memory expectedFulfillments = SeaportArrays.Fulfillments(
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                    ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 1, itemIndex: 0 })
                    )
            }),
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                    ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 1 }),
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 2 })
                    )
            }),
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 1, itemIndex: 0 })
                    ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                    )
            })
        );

        Fulfillment[] memory fulfillments = MatchFulfillmentHelper
            .getMatchedFulfillments(SeaportArrays.Orders(order, otherOrder));

        assertEq(fulfillments.length, 3, "fulfillments.length");

        assertEq(fulfillments[0], expectedFulfillments[2], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[1], "fulfillments[1]");
        assertEq(fulfillments[2], expectedFulfillments[0], "fulfillments[2]");
    }

    function testGetMatchedFulfillments_3to2() public {
        Order memory order = Order({
            parameters: OrderParametersLib.empty().withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.empty().withToken(address(A)).withStartAmount(10)
                        .withEndAmount(10),
                    OfferItemLib.empty().withToken(address(A)).withStartAmount(90)
                        .withEndAmount(90)
                )
                ).withConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib.empty().withToken(address(B))
                            .withStartAmount(1).withEndAmount(1),
                        ConsiderationItemLib.empty().withToken(address(A))
                            .withStartAmount(10).withEndAmount(10),
                        ConsiderationItemLib.empty().withToken(address(A))
                            .withStartAmount(10).withEndAmount(10)
                    )
                ).withOfferer(makeAddr("offerer1")),
            signature: ""
        });

        Order memory otherOrder = Order({
            parameters: OrderParametersLib.empty().withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.empty().withToken(address(B)).withStartAmount(1)
                        .withEndAmount(1)
                )
                ).withConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib.empty().withToken(address(A))
                            .withStartAmount(80).withEndAmount(80).withRecipient(
                            makeAddr("offerer2")
                        )
                    )
                ).withOfferer(makeAddr("offerer2")),
            signature: ""
        });

        Fulfillment[] memory expectedFulfillments = SeaportArrays.Fulfillments(
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 1 })
                    ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 1, itemIndex: 0 })
                    )
            }),
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 }),
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 1 })
                    ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 1 }),
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 2 })
                    )
            }),
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 1, itemIndex: 0 })
                    ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                    )
            })
        );

        Fulfillment[] memory fulfillments = MatchFulfillmentHelper
            .getMatchedFulfillments(SeaportArrays.Orders(order, otherOrder));

        assertEq(fulfillments.length, 3, "fulfillments.length");

        assertEq(fulfillments[0], expectedFulfillments[2], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[1], "fulfillments[1]");
        assertEq(fulfillments[2], expectedFulfillments[0], "fulfillments[2]");
    }

    function testGetMatchedFulfillments_3to2_swap() public {
        Order memory order = Order({
            parameters: OrderParametersLib.empty().withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.empty().withToken(address(A)).withStartAmount(90)
                        .withEndAmount(90),
                    OfferItemLib.empty().withToken(address(A)).withStartAmount(10)
                        .withEndAmount(10)
                )
                ).withConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib.empty().withToken(address(B))
                            .withStartAmount(1).withEndAmount(1),
                        ConsiderationItemLib.empty().withToken(address(A))
                            .withStartAmount(10).withEndAmount(10),
                        ConsiderationItemLib.empty().withToken(address(A))
                            .withStartAmount(10).withEndAmount(10)
                    )
                ).withOfferer(makeAddr("offerer1")),
            signature: ""
        });

        Order memory otherOrder = Order({
            parameters: OrderParametersLib.empty().withOffer(
                SeaportArrays.OfferItems(
                    OfferItemLib.empty().withToken(address(B)).withStartAmount(1)
                        .withEndAmount(1)
                )
                ).withConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib.empty().withToken(address(A))
                            .withStartAmount(80).withEndAmount(80).withRecipient(
                            makeAddr("offerer2")
                        )
                    )
                ).withOfferer(makeAddr("offerer2")),
            signature: ""
        });

        Fulfillment[] memory expectedFulfillments = SeaportArrays.Fulfillments(
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 1, itemIndex: 0 })
                    ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                    )
            }),
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                    ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 1 }),
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 2 })
                    )
            }),
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 }),
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 1 })
                    ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 1, itemIndex: 0 })
                    )
            })
        );
        address(0x1234).call("");
        Fulfillment[] memory fulfillments = MatchFulfillmentHelper
            .getMatchedFulfillments(SeaportArrays.Orders(order, otherOrder));

        assertEq(fulfillments.length, 3, "fulfillments.length");

        assertEq(fulfillments[0], expectedFulfillments[0], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[1], "fulfillments[1]");
        assertEq(fulfillments[2], expectedFulfillments[2], "fulfillments[2]");
    }

    event LogFulfillmentComponent(FulfillmentComponent);
    event LogFulfillment(Fulfillment);

    function getMatchedFulfillments(Order[] memory orders)
        external
        returns (Fulfillment[] memory)
    {
        return MatchFulfillmentHelper.getMatchedFulfillments(orders);
    }

    function assertEq(
        Fulfillment memory left,
        Fulfillment memory right,
        string memory message
    ) internal {
        emit LogFulfillment(left);
        emit LogFulfillment(right);
        emit Spacer();
        assertEq(
            left.offerComponents,
            right.offerComponents,
            string.concat(message, " offerComponents")
        );
        assertEq(
            left.considerationComponents,
            right.considerationComponents,
            string.concat(message, " considerationComponents")
        );
    }

    function assertEq(
        FulfillmentComponent[] memory left,
        FulfillmentComponent[] memory right,
        string memory message
    ) internal {
        assertEq(left.length, right.length, string.concat(message, " length"));

        for (uint256 i = 0; i < left.length; i++) {
            assertEq(
                left[i],
                right[i],
                string.concat(message, " index ", i.toString())
            );
        }
    }

    event Spacer();

    function assertEq(
        FulfillmentComponent memory left,
        FulfillmentComponent memory right,
        string memory message
    ) internal {
        emit LogFulfillmentComponent(left);
        emit LogFulfillmentComponent(right);
        emit Spacer();
        assertEq(
            left.orderIndex,
            right.orderIndex,
            string.concat(message, " orderIndex")
        );
        assertEq(
            left.itemIndex,
            right.itemIndex,
            string.concat(message, " itemIndex")
        );
    }
}
