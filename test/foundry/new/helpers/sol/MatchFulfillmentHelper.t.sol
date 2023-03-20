// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "../../../utils/BaseOrderTest.sol";

import "seaport-sol/SeaportSol.sol";

import {
    MatchFulfillmentHelper
} from "seaport-sol/fulfillments/match/MatchFulfillmentHelper.sol";

import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";

import {
    MatchComponent,
    MatchComponentType
} from "seaport-sol/lib/types/MatchComponentType.sol";

contract MatchFulfillmentHelperTest is BaseOrderTest {
    using Strings for uint256;

    using ConsiderationItemLib for ConsiderationItem;
    using FulfillmentComponentLib for FulfillmentComponent;
    using OfferItemLib for OfferItem;
    using OrderComponentsLib for OrderComponents;
    using OrderParametersLib for OrderParameters;
    using OrderLib for Order;

    MatchFulfillmentHelper test;

    struct Context {
        FuzzArgs args;
    }

    struct FuzzArgs {
        bool useDifferentConduitKeys;
    }

    function setUp() public virtual override {
        super.setUp();

        test = new MatchFulfillmentHelper();
    }

    function testGetMatchedFulfillments_self() public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token1))
                            .withItemType(ItemType.ERC20)
                            .withAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withItemType(ItemType.ERC20)
                            .withAmount(100)
                    )
                ),
            signature: ""
        });

        order = _toMatchableOrder(order, offerer1, false);

        Fulfillment memory expectedFulfillment = Fulfillment({
            offerComponents: SeaportArrays.FulfillmentComponents(
                FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
            ),
            considerationComponents: SeaportArrays.FulfillmentComponents(
                FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
            )
        });

        (Fulfillment[] memory fulfillments, , ) = test.getMatchedFulfillments(
            SeaportArrays.Orders(order)
        );

        assertEq(fulfillments.length, 1);
        assertEq(fulfillments[0], expectedFulfillment, "fulfillments[0]");

        consideration.matchOrders({
            orders: SeaportArrays.Orders(order),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_self_conduitDisparity() public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token1))
                            .withItemType(ItemType.ERC20)
                            .withAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withItemType(ItemType.ERC20)
                            .withAmount(100)
                    )
                ),
            signature: ""
        });

        order = _toMatchableOrder(order, offerer1, false);

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token1))
                            .withItemType(ItemType.ERC20)
                            .withAmount(101)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withItemType(ItemType.ERC20)
                            .withAmount(101)
                    )
                )
                .withConduitKey(conduitKeyOne),
            signature: ""
        });

        otherOrder = _toMatchableOrder(otherOrder, offerer1, false);

        Fulfillment[] memory expectedFulfillments = SeaportArrays.Fulfillments(
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 }),
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

        (Fulfillment[] memory fulfillments, , ) = test.getMatchedFulfillments(
            SeaportArrays.Orders(order, otherOrder)
        );

        assertEq(fulfillments.length, 2);
        assertEq(fulfillments[0], expectedFulfillments[0], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[1], "fulfillments[1]");

        consideration.matchOrders({
            orders: SeaportArrays.Orders(order, otherOrder),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_1to1() public {
        execGetMatchedFulfillments_1to1(false);
        execGetMatchedFulfillments_1to1(true);
    }

    function execGetMatchedFulfillments_1to1(bool useDifferentConduits) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token2))
                            .withAmount(100)
                    )
                ),
            signature: ""
        });

        order = _toMatchableOrder(order, offerer1, useDifferentConduits);

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token2))
                            .withAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(100)
                    )
                ),
            signature: ""
        });

        // No expected difference between the fulfillments when the two orders
        // use different conduit keys, so just toggle it back and for to make
        // sure nothing goes wrong.
        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKeyOne
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits
        );

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

        (Fulfillment[] memory fulfillments, , ) = test.getMatchedFulfillments(
            SeaportArrays.Orders(otherOrder, order)
        );

        assertEq(fulfillments.length, 2, "fulfillments.length");
        assertEq(fulfillments[0], expectedFulfillments[1], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[0], "fulfillments[1]");

        consideration.matchOrders({
            orders: SeaportArrays.Orders(otherOrder, order),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_1to1_ascending() public {
        execGetMatchedFulfillments_1to1_ascending(false);
        execGetMatchedFulfillments_1to1_ascending(true);
    }

    function execGetMatchedFulfillments_1to1_ascending(
        bool useDifferentConduits
    ) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token1))
                            .withStartAmount(1)
                            .withEndAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token2))
                            .withStartAmount(1)
                            .withEndAmount(100)
                    )
                ),
            signature: ""
        });

        order = _toMatchableOrder(order, offerer1, useDifferentConduits);

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token2))
                            .withStartAmount(1)
                            .withEndAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withStartAmount(1)
                            .withEndAmount(100)
                    )
                ),
            signature: ""
        });

        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKeyOne
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits
        );

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

        (Fulfillment[] memory fulfillments, , ) = test.getMatchedFulfillments(
            SeaportArrays.Orders(otherOrder, order)
        );

        assertEq(fulfillments.length, 2, "fulfillments.length");
        assertEq(fulfillments[0], expectedFulfillments[1], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[0], "fulfillments[1]");

        consideration.matchOrders({
            orders: SeaportArrays.Orders(otherOrder, order),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_1to1_descending() public {
        execGetMatchedFulfillments_1to1_descending(false);
        execGetMatchedFulfillments_1to1_descending(true);
    }

    function execGetMatchedFulfillments_1to1_descending(
        bool useDifferentConduits
    ) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token1))
                            .withStartAmount(100)
                            .withEndAmount(1)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token2))
                            .withStartAmount(100)
                            .withEndAmount(1)
                    )
                ),
            signature: ""
        });

        order = _toMatchableOrder(order, offerer1, useDifferentConduits);

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token2))
                            .withStartAmount(100)
                            .withEndAmount(1)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withStartAmount(100)
                            .withEndAmount(1)
                    )
                ),
            signature: ""
        });

        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKeyOne
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits
        );

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

        (Fulfillment[] memory fulfillments, , ) = test.getMatchedFulfillments(
            SeaportArrays.Orders(otherOrder, order)
        );

        assertEq(fulfillments.length, 2, "fulfillments.length");
        assertEq(fulfillments[0], expectedFulfillments[1], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[0], "fulfillments[1]");

        consideration.matchOrders({
            orders: SeaportArrays.Orders(otherOrder, order),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_1to1_descending_leftover() public {
        execGetMatchedFulfillments_1to1_descending_leftover(false);
        execGetMatchedFulfillments_1to1_descending_leftover(true);
    }

    function execGetMatchedFulfillments_1to1_descending_leftover(
        bool useDifferentConduits
    ) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token1))
                            .withStartAmount(100)
                            .withEndAmount(1)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token2))
                            .withStartAmount(1)
                            .withEndAmount(100)
                    )
                ),
            signature: ""
        });

        order = _toMatchableOrder(order, offerer1, useDifferentConduits);

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token2))
                            .withStartAmount(1)
                            .withEndAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withStartAmount(1)
                            .withEndAmount(100)
                    )
                ),
            signature: ""
        });

        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKeyOne
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits
        );

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

        (
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory leftoverOffer,
            MatchComponent[] memory leftoverConsideration
        ) = test.getMatchedFulfillments(
                SeaportArrays.Orders(otherOrder, order)
            );

        assertEq(fulfillments.length, 2, "fulfillments.length");
        assertEq(fulfillments[0], expectedFulfillments[1], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[0], "fulfillments[1]");
        assertEq(leftoverOffer.length, 1, "leftoverOffer.length");
        assertEq(leftoverOffer[0].getAmount(), 99, "leftoverOffer[0].amount()");
        assertEq(
            leftoverConsideration.length,
            0,
            "leftoverConsideration.length"
        );

        consideration.matchOrders({
            orders: SeaportArrays.Orders(otherOrder, order),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_1to1ExcessOffer() public {
        execGetMatchedFulfillments_1to1ExcessOffer(false);
        execGetMatchedFulfillments_1to1ExcessOffer(true);
    }

    function execGetMatchedFulfillments_1to1ExcessOffer(
        bool useDifferentConduits
    ) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token2))
                            .withAmount(100)
                    )
                )
                .withOfferer(offerer1.addr),
            signature: ""
        });

        order = _toMatchableOrder(order, offerer1, useDifferentConduits);

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token2))
                            .withAmount(200)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(100)
                    )
                )
                .withOfferer(offerer2.addr),
            signature: ""
        });

        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKeyOne
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits
        );

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

        (Fulfillment[] memory fulfillments, , ) = test.getMatchedFulfillments(
            SeaportArrays.Orders(otherOrder, order)
        );

        assertEq(fulfillments.length, 2, "fulfillments.length");
        assertEq(fulfillments[0], expectedFulfillments[1], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[0], "fulfillments[1]");

        consideration.matchOrders({
            orders: SeaportArrays.Orders(otherOrder, order),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_3to1() public {
        execGetMatchedFulfillments_3to1(false);
        execGetMatchedFulfillments_3to1(true);
    }

    function execGetMatchedFulfillments_3to1(bool useDifferentConduits) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token2))
                            .withAmount(1),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(10),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(10)
                    )
                )
                .withOfferer(offerer1.addr),
            signature: ""
        });

        order = _toMatchableOrder(order, offerer1, useDifferentConduits);

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token2))
                            .withAmount(1)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(80)
                            .withRecipient(offerer2.addr)
                    )
                )
                .withOfferer(offerer2.addr),
            signature: ""
        });

        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKeyOne
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits
        );

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

        (Fulfillment[] memory fulfillments, , ) = test.getMatchedFulfillments(
            SeaportArrays.Orders(order, otherOrder)
        );

        assertEq(fulfillments.length, 3, "fulfillments.length");

        assertEq(fulfillments[0], expectedFulfillments[2], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[1], "fulfillments[1]");
        assertEq(fulfillments[2], expectedFulfillments[0], "fulfillments[2]");

        consideration.matchOrders({
            orders: SeaportArrays.Orders(order, otherOrder),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_3to1Extra() public {
        execGetMatchedFulfillments_3to1Extra(false);
        execGetMatchedFulfillments_3to1Extra(true);
    }

    function execGetMatchedFulfillments_3to1Extra(
        bool useDifferentConduits
    ) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(110)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token2))
                            .withAmount(1),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(10),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(10)
                    )
                )
                .withOfferer(offerer1.addr),
            signature: ""
        });

        order = _toMatchableOrder(order, offerer1, useDifferentConduits);

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token2))
                            .withAmount(1)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(80)
                            .withRecipient(offerer2.addr)
                    )
                )
                .withOfferer(offerer2.addr),
            signature: ""
        });

        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKeyOne
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits
        );

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

        (Fulfillment[] memory fulfillments, , ) = test.getMatchedFulfillments(
            SeaportArrays.Orders(order, otherOrder)
        );

        assertEq(fulfillments.length, 3, "fulfillments.length");

        assertEq(fulfillments[0], expectedFulfillments[2], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[1], "fulfillments[1]");
        assertEq(fulfillments[2], expectedFulfillments[0], "fulfillments[2]");

        consideration.matchOrders({
            orders: SeaportArrays.Orders(order, otherOrder),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_3to2() public {
        execGetMatchedFulfillments_3to2(false);
        execGetMatchedFulfillments_3to2(true);
    }

    function execGetMatchedFulfillments_3to2(bool useDifferentConduits) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(10),
                        OfferItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(90)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token2))
                            .withAmount(1),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(10),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(10)
                    )
                )
                .withOfferer(offerer1.addr),
            signature: ""
        });

        order = _toMatchableOrder(order, offerer1, useDifferentConduits);

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token2))
                            .withAmount(1)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(80)
                            .withRecipient(offerer2.addr)
                    )
                )
                .withOfferer(offerer2.addr),
            signature: ""
        });

        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKeyOne
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits
        );

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
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 1, itemIndex: 0 })
                )
            })
        );

        (Fulfillment[] memory fulfillments, , ) = test.getMatchedFulfillments(
            SeaportArrays.Orders(order, otherOrder)
        );

        assertEq(fulfillments.length, 3, "fulfillments.length");

        // Note: the expected fulfillments will need to change in this case.
        assertEq(fulfillments[0], expectedFulfillments[0], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[1], "fulfillments[1]");
        assertEq(fulfillments[2], expectedFulfillments[2], "fulfillments[2]");

        consideration.matchOrders({
            orders: SeaportArrays.Orders(order, otherOrder),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_3to2_swap() public {
        execGetMatchedFulfillments_3to2_swap(false);
        execGetMatchedFulfillments_3to2_swap(true);
    }

    function execGetMatchedFulfillments_3to2_swap(
        bool useDifferentConduits
    ) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(90),
                        OfferItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(10)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token2))
                            .withAmount(1),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(10),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(10)
                    )
                )
                .withOfferer(offerer1.addr),
            signature: ""
        });

        order = _toMatchableOrder(order, offerer1, useDifferentConduits);

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token2))
                            .withAmount(1)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(80)
                            .withRecipient(offerer2.addr)
                    )
                )
                .withOfferer(offerer2.addr),
            signature: ""
        });

        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKeyOne
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits
        );

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
        (Fulfillment[] memory fulfillments, , ) = test.getMatchedFulfillments(
            SeaportArrays.Orders(order, otherOrder)
        );

        assertEq(fulfillments.length, 3, "fulfillments.length");

        assertEq(fulfillments[0], expectedFulfillments[0], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[1], "fulfillments[1]");
        assertEq(fulfillments[2], expectedFulfillments[2], "fulfillments[2]");

        consideration.matchOrders({
            orders: SeaportArrays.Orders(order, otherOrder),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_consolidatedConsideration() public {
        execGetMatchedFulfillments_consolidatedConsideration(false);
        execGetMatchedFulfillments_consolidatedConsideration(true);
    }

    function execGetMatchedFulfillments_consolidatedConsideration(
        bool useDifferentConduits
    ) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(90),
                        OfferItemLib
                            .empty()
                            .withToken(address(token2))
                            .withAmount(10)
                    )
                )
                .withConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(10),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(90),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(10)
                    )
                )
                .withOfferer(offerer1.addr),
            signature: ""
        });

        order = _toMatchableOrder(order, offerer1, useDifferentConduits);

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(30)
                    )
                )
                .withConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token2))
                            .withAmount(10)
                    )
                )
                .withOfferer(offerer2.addr),
            signature: ""
        });

        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKeyOne
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits
        );

        Fulfillment[] memory expectedFulfillments = SeaportArrays.Fulfillments(
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 0 }),
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
            }),
            Fulfillment({
                offerComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 0, itemIndex: 1 })
                ),
                considerationComponents: SeaportArrays.FulfillmentComponents(
                    FulfillmentComponent({ orderIndex: 1, itemIndex: 0 })
                )
            })
        );
        (Fulfillment[] memory fulfillments, , ) = test.getMatchedFulfillments(
            SeaportArrays.Orders(order, otherOrder)
        );
        assertEq(fulfillments.length, 3, "fulfillments.length");

        assertEq(fulfillments[0], expectedFulfillments[0], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[1], "fulfillments[1]");
        assertEq(fulfillments[2], expectedFulfillments[2], "fulfillments[2]");

        consideration.matchOrders({
            orders: SeaportArrays.Orders(order, otherOrder),
            fulfillments: fulfillments
        });
    }

    function testRemainingItems() public {
        Order memory order1 = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(10),
                        OfferItemLib
                            .empty()
                            .withToken(address(token1))
                            .withAmount(11)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token2))
                            .withAmount(1),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(token2))
                            .withAmount(2)
                    )
                )
                .withOfferer(offerer1.addr),
            signature: ""
        });

        // Note: there's no order 2.

        (
            ,
            MatchComponent[] memory remainingOffer,
            MatchComponent[] memory remainingConsideration
        ) = test.getMatchedFulfillments(SeaportArrays.Orders(order1));

        assertEq(remainingOffer.length, 2, "remainingOffer.length");
        assertEq(
            remainingConsideration.length,
            2,
            "remainingConsideration.length"
        );
        assertEq(
            remainingOffer[0].getOrderIndex(),
            0,
            "remainingOffer[0].orderIndex"
        );
        assertEq(
            remainingOffer[0].getItemIndex(),
            0,
            "remainingOffer[0].itemIndex"
        );
        assertEq(remainingOffer[0].getAmount(), 10, "remainingOffer[0].amount");
        assertEq(
            remainingOffer[1].getOrderIndex(),
            0,
            "remainingOffer[1].orderIndex"
        );
        assertEq(
            remainingOffer[1].getItemIndex(),
            1,
            "remainingOffer[1].itemIndex"
        );
        assertEq(remainingOffer[1].getAmount(), 11, "remainingOffer[1].amount");

        assertEq(
            remainingConsideration[0].getOrderIndex(),
            0,
            "remainingConsideration[0].orderIndex"
        );
        assertEq(
            remainingConsideration[0].getItemIndex(),
            0,
            "remainingConsideration[0].itemIndex"
        );
        assertEq(
            remainingConsideration[0].getAmount(),
            1,
            "remainingConsideration[0].amount"
        );
        assertEq(
            remainingConsideration[1].getOrderIndex(),
            0,
            "remainingConsideration[1].orderIndex"
        );
        assertEq(
            remainingConsideration[1].getItemIndex(),
            1,
            "remainingConsideration[1].itemIndex"
        );
        assertEq(
            remainingConsideration[1].getAmount(),
            2,
            "remainingConsideration[1].amount"
        );
    }

    function assertEq(
        Fulfillment memory left,
        Fulfillment memory right,
        string memory message
    ) internal {
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

    function assertEq(
        FulfillmentComponent memory left,
        FulfillmentComponent memory right,
        string memory message
    ) internal {
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

    function _toMatchableOrder(
        Order memory order,
        Account memory offerer,
        bool useDifferentConduits
    ) internal view returns (Order memory) {
        for (uint256 i = 0; i < order.parameters.offer.length; i++) {
            order.parameters.offer[i] = order
                .parameters
                .offer[i]
                .copy()
                .withItemType(ItemType.ERC20);
        }

        for (uint256 i = 0; i < order.parameters.consideration.length; i++) {
            order.parameters.consideration[i] = order
                .parameters
                .consideration[i]
                .copy()
                .withItemType(ItemType.ERC20);
        }

        OrderParameters memory parameters = order
        .parameters
        .copy()
        .withOfferer(offerer.addr)
        .withStartTime(block.timestamp)
        // Bump the end time by 1 so that the test doesn't try to match the
        // same order twice.
            .withEndTime(block.timestamp + (useDifferentConduits ? 2 : 1))
            .withTotalOriginalConsiderationItems(
                order.parameters.consideration.length
            );

        OrderComponents memory orderComponents = parameters
            .toOrderComponents(consideration.getCounter(offerer.addr))
            .withCounter(consideration.getCounter(offerer.addr));

        bytes32 orderHash = consideration.getOrderHash(orderComponents);

        bytes memory signature = signOrder(
            consideration,
            offerer.key,
            orderHash
        );

        return Order({ parameters: parameters, signature: signature });
    }
}
