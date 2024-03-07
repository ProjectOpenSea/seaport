// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import {
    ConsiderationItemLib,
    FulfillmentComponentLib,
    OfferItemLib,
    OrderComponentsLib,
    OrderLib,
    OrderParametersLib,
    SeaportArrays
} from "seaport-sol/src/SeaportSol.sol";

import {
    ConsiderationItem,
    Fulfillment,
    FulfillmentComponent,
    OfferItem,
    Order,
    OrderComponents,
    OrderParameters
} from "seaport-sol/src/SeaportStructs.sol";

import { ItemType } from "seaport-sol/src/SeaportEnums.sol";

import { UnavailableReason } from "seaport-sol/src/SpaceEnums.sol";

import {
    MatchFulfillmentHelper
} from "seaport-sol/src/fulfillments/match/MatchFulfillmentHelper.sol";

import {
    MatchComponent,
    MatchComponentType
} from "seaport-sol/src/lib/types/MatchComponentType.sol";

import { BaseOrderTest } from "../../BaseOrderTest.sol";

contract MatchFulfillmentHelperTest is BaseOrderTest {
    using Strings for uint256;

    using ConsiderationItemLib for ConsiderationItem;
    using FulfillmentComponentLib for FulfillmentComponent;
    using MatchComponentType for MatchComponent;
    using OfferItemLib for OfferItem;
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using OrderParametersLib for OrderParameters;

    // MatchFulfillmentHelper matcher;

    struct MatchFulfillmentContext {
        FuzzArgs args;
    }

    struct FuzzArgs {
        bool useDifferentConduitKeys;
    }

    function setUp() public virtual override {
        super.setUp();

        // matcher = new MatchFulfillmentHelper();
    }

    function testGetMatchedFulfillments_self() public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withItemType(ItemType.ERC20)
                            .withAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withItemType(ItemType.ERC20)
                            .withAmount(100)
                    )
                ),
            signature: ""
        });

        order = _toMatchableOrder(order, offerer1, 0);

        Fulfillment memory expectedFulfillment = Fulfillment({
            offerComponents: SeaportArrays.FulfillmentComponents(
                FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
            ),
            considerationComponents: SeaportArrays.FulfillmentComponents(
                FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
            )
        });

        (Fulfillment[] memory fulfillments, , ) = matcher
            .getMatchedFulfillments(
                SeaportArrays.Orders(order),
                new bytes32[](1),
                new UnavailableReason[](1)
            );

        assertEq(fulfillments.length, 1);
        assertEq(fulfillments[0], expectedFulfillment, "fulfillments[0]");

        seaport.matchOrders({
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
                            .withToken(address(erc20s[0]))
                            .withItemType(ItemType.ERC20)
                            .withAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withItemType(ItemType.ERC20)
                            .withAmount(100)
                    )
                ),
            signature: ""
        });

        order = _toMatchableOrder(order, offerer1, 0);

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withItemType(ItemType.ERC20)
                            .withAmount(101)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withItemType(ItemType.ERC20)
                            .withAmount(101)
                    )
                )
                .withConduitKey(conduitKey),
            signature: ""
        });

        otherOrder = _toMatchableOrder(otherOrder, offerer1, 0);

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

        bytes32[] memory orderHashes = new bytes32[](2);

        (Fulfillment[] memory fulfillments, , ) = matcher
            .getMatchedFulfillments(
                SeaportArrays.Orders(order, otherOrder),
                orderHashes,
                new UnavailableReason[](2)
            );

        assertEq(fulfillments.length, 2);
        assertEq(fulfillments[0], expectedFulfillments[0], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[1], "fulfillments[1]");

        seaport.matchOrders({
            orders: SeaportArrays.Orders(order, otherOrder),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_1ItemTo1Item() public {
        execGetMatchedFulfillments_1ItemTo1Item(false);
        execGetMatchedFulfillments_1ItemTo1Item(true);
    }

    function execGetMatchedFulfillments_1ItemTo1Item(
        bool useDifferentConduits
    ) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(100)
                    )
                ),
            signature: ""
        });

        order = _toMatchableOrder(
            order,
            offerer1,
            useDifferentConduits ? 1 : 0
        );

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
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
                conduitKey
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits ? 1 : 0
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

        bytes32[] memory orderHashes = new bytes32[](2);

        (Fulfillment[] memory fulfillments, , ) = matcher
            .getMatchedFulfillments(
                SeaportArrays.Orders(otherOrder, order),
                orderHashes,
                new UnavailableReason[](2)
            );

        assertEq(fulfillments.length, 2, "fulfillments.length");
        assertEq(fulfillments[0], expectedFulfillments[1], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[0], "fulfillments[1]");

        seaport.matchOrders({
            orders: SeaportArrays.Orders(otherOrder, order),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_1ItemTo1Item_ascending() public {
        execGetMatchedFulfillments_1ItemTo1Item_ascending(false);
        execGetMatchedFulfillments_1ItemTo1Item_ascending(true);
    }

    function execGetMatchedFulfillments_1ItemTo1Item_ascending(
        bool useDifferentConduits
    ) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withStartAmount(1)
                            .withEndAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withStartAmount(1)
                            .withEndAmount(100)
                    )
                ),
            signature: ""
        });

        order = _toMatchableOrder(
            order,
            offerer1,
            useDifferentConduits ? 1 : 0
        );

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withStartAmount(1)
                            .withEndAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withStartAmount(1)
                            .withEndAmount(100)
                    )
                ),
            signature: ""
        });

        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKey
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits ? 1 : 0
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

        bytes32[] memory orderHashes = new bytes32[](2);

        (Fulfillment[] memory fulfillments, , ) = matcher
            .getMatchedFulfillments(
                SeaportArrays.Orders(otherOrder, order),
                orderHashes,
                new UnavailableReason[](2)
            );

        assertEq(fulfillments.length, 2, "fulfillments.length");
        assertEq(fulfillments[0], expectedFulfillments[1], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[0], "fulfillments[1]");

        seaport.matchOrders({
            orders: SeaportArrays.Orders(otherOrder, order),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_1ItemTo1Item_descending() public {
        execGetMatchedFulfillments_1ItemTo1Item_descending(false);
        execGetMatchedFulfillments_1ItemTo1Item_descending(true);
    }

    function execGetMatchedFulfillments_1ItemTo1Item_descending(
        bool useDifferentConduits
    ) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withStartAmount(100)
                            .withEndAmount(1)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withStartAmount(100)
                            .withEndAmount(1)
                    )
                ),
            signature: ""
        });

        order = _toMatchableOrder(
            order,
            offerer1,
            useDifferentConduits ? 1 : 0
        );

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withStartAmount(100)
                            .withEndAmount(1)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withStartAmount(100)
                            .withEndAmount(1)
                    )
                ),
            signature: ""
        });

        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKey
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits ? 1 : 0
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

        bytes32[] memory orderHashes = new bytes32[](2);

        (Fulfillment[] memory fulfillments, , ) = matcher
            .getMatchedFulfillments(
                SeaportArrays.Orders(otherOrder, order),
                orderHashes,
                new UnavailableReason[](2)
            );

        assertEq(fulfillments.length, 2, "fulfillments.length");
        assertEq(fulfillments[0], expectedFulfillments[1], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[0], "fulfillments[1]");

        seaport.matchOrders({
            orders: SeaportArrays.Orders(otherOrder, order),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_1ItemTo1Item_descending_leftover()
        public
    {
        execGetMatchedFulfillments_1ItemTo1Item_descending_leftover(false);
        execGetMatchedFulfillments_1ItemTo1Item_descending_leftover(true);
    }

    function execGetMatchedFulfillments_1ItemTo1Item_descending_leftover(
        bool useDifferentConduits
    ) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withStartAmount(100)
                            .withEndAmount(1)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withStartAmount(1)
                            .withEndAmount(100)
                    )
                ),
            signature: ""
        });

        order = _toMatchableOrder(
            order,
            offerer1,
            useDifferentConduits ? 1 : 0
        );

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withStartAmount(1)
                            .withEndAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withStartAmount(1)
                            .withEndAmount(100)
                    )
                ),
            signature: ""
        });

        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKey
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits ? 1 : 0
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

        bytes32[] memory orderHashes = new bytes32[](2);

        (
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory leftoverOffer,
            MatchComponent[] memory leftoverConsideration
        ) = matcher.getMatchedFulfillments(
                SeaportArrays.Orders(otherOrder, order),
                orderHashes,
                new UnavailableReason[](2)
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

        seaport.matchOrders({
            orders: SeaportArrays.Orders(otherOrder, order),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_1ItemTo1ItemExcessOffer() public {
        execGetMatchedFulfillments_1ItemTo1ItemExcessOffer(false);
        execGetMatchedFulfillments_1ItemTo1ItemExcessOffer(true);
    }

    function execGetMatchedFulfillments_1ItemTo1ItemExcessOffer(
        bool useDifferentConduits
    ) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(100)
                    )
                )
                .withOfferer(offerer1.addr),
            signature: ""
        });

        order = _toMatchableOrder(
            order,
            offerer1,
            useDifferentConduits ? 1 : 0
        );

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(200)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(100)
                    )
                )
                .withOfferer(offerer2.addr),
            signature: ""
        });

        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKey
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits ? 1 : 0
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

        bytes32[] memory orderHashes = new bytes32[](2);

        (Fulfillment[] memory fulfillments, , ) = matcher
            .getMatchedFulfillments(
                SeaportArrays.Orders(otherOrder, order),
                orderHashes,
                new UnavailableReason[](2)
            );

        assertEq(fulfillments.length, 2, "fulfillments.length");
        assertEq(fulfillments[0], expectedFulfillments[1], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[0], "fulfillments[1]");

        seaport.matchOrders({
            orders: SeaportArrays.Orders(otherOrder, order),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_3ItemsTo1Item() public {
        execGetMatchedFulfillments_3ItemsTo1Item(false);
        execGetMatchedFulfillments_3ItemsTo1Item(true);
    }

    function execGetMatchedFulfillments_3ItemsTo1Item(
        bool useDifferentConduits
    ) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(1),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(10),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(10)
                    )
                )
                .withOfferer(offerer1.addr),
            signature: ""
        });

        order = _toMatchableOrder(
            order,
            offerer1,
            useDifferentConduits ? 1 : 0
        );

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(1)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(80)
                            .withRecipient(offerer2.addr)
                    )
                )
                .withOfferer(offerer2.addr),
            signature: ""
        });

        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKey
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits ? 1 : 0
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

        bytes32[] memory orderHashes = new bytes32[](2);

        (Fulfillment[] memory fulfillments, , ) = matcher
            .getMatchedFulfillments(
                SeaportArrays.Orders(order, otherOrder),
                orderHashes,
                new UnavailableReason[](2)
            );

        assertEq(fulfillments.length, 3, "fulfillments.length");

        assertEq(fulfillments[0], expectedFulfillments[2], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[1], "fulfillments[1]");
        assertEq(fulfillments[2], expectedFulfillments[0], "fulfillments[2]");

        seaport.matchOrders({
            orders: SeaportArrays.Orders(order, otherOrder),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_3ItemsTo1Item_extra() public {
        execGetMatchedFulfillments_3ItemsTo1Item_extra(false);
        execGetMatchedFulfillments_3ItemsTo1Item_extra(true);
    }

    function execGetMatchedFulfillments_3ItemsTo1Item_extra(
        bool useDifferentConduits
    ) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(110)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(1),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(10),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(10)
                    )
                )
                .withOfferer(offerer1.addr),
            signature: ""
        });

        order = _toMatchableOrder(
            order,
            offerer1,
            useDifferentConduits ? 1 : 0
        );

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(1)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(80)
                            .withRecipient(offerer2.addr)
                    )
                )
                .withOfferer(offerer2.addr),
            signature: ""
        });

        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKey
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits ? 1 : 0
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

        bytes32[] memory orderHashes = new bytes32[](2);

        (Fulfillment[] memory fulfillments, , ) = matcher
            .getMatchedFulfillments(
                SeaportArrays.Orders(order, otherOrder),
                orderHashes,
                new UnavailableReason[](2)
            );

        assertEq(fulfillments.length, 3, "fulfillments.length");

        assertEq(fulfillments[0], expectedFulfillments[2], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[1], "fulfillments[1]");
        assertEq(fulfillments[2], expectedFulfillments[0], "fulfillments[2]");

        seaport.matchOrders({
            orders: SeaportArrays.Orders(order, otherOrder),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_3ItemsTo2Items() public {
        execGetMatchedFulfillments_3ItemsTo2Items(false);
        execGetMatchedFulfillments_3ItemsTo2Items(true);
    }

    function execGetMatchedFulfillments_3ItemsTo2Items(
        bool useDifferentConduits
    ) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(10),
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(90)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(1),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(10),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(10)
                    )
                )
                .withOfferer(offerer1.addr),
            signature: ""
        });

        order = _toMatchableOrder(
            order,
            offerer1,
            useDifferentConduits ? 1 : 0
        );

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(1)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(80)
                            .withRecipient(offerer2.addr)
                    )
                )
                .withOfferer(offerer2.addr),
            signature: ""
        });

        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKey
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits ? 1 : 0
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

        bytes32[] memory orderHashes = new bytes32[](2);

        (Fulfillment[] memory fulfillments, , ) = matcher
            .getMatchedFulfillments(
                SeaportArrays.Orders(order, otherOrder),
                orderHashes,
                new UnavailableReason[](2)
            );

        assertEq(fulfillments.length, 3, "fulfillments.length");

        // Note: the expected fulfillments will need to change in this case.
        assertEq(fulfillments[0], expectedFulfillments[0], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[1], "fulfillments[1]");
        assertEq(fulfillments[2], expectedFulfillments[2], "fulfillments[2]");

        seaport.matchOrders({
            orders: SeaportArrays.Orders(order, otherOrder),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_3ItemsTo2Items_swap() public {
        execGetMatchedFulfillments_3ItemsTo2Items_swap(false);
        execGetMatchedFulfillments_3ItemsTo2Items_swap(true);
    }

    function execGetMatchedFulfillments_3ItemsTo2Items_swap(
        bool useDifferentConduits
    ) public {
        Order memory order = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(90),
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(10)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(1),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(10),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(10)
                    )
                )
                .withOfferer(offerer1.addr),
            signature: ""
        });

        order = _toMatchableOrder(
            order,
            offerer1,
            useDifferentConduits ? 1 : 0
        );

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(1)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(80)
                            .withRecipient(offerer2.addr)
                    )
                )
                .withOfferer(offerer2.addr),
            signature: ""
        });

        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKey
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits ? 1 : 0
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

        bytes32[] memory orderHashes = new bytes32[](2);

        (Fulfillment[] memory fulfillments, , ) = matcher
            .getMatchedFulfillments(
                SeaportArrays.Orders(order, otherOrder),
                orderHashes,
                new UnavailableReason[](2)
            );

        assertEq(fulfillments.length, 3, "fulfillments.length");

        assertEq(fulfillments[0], expectedFulfillments[0], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[1], "fulfillments[1]");
        assertEq(fulfillments[2], expectedFulfillments[2], "fulfillments[2]");

        seaport.matchOrders({
            orders: SeaportArrays.Orders(order, otherOrder),
            fulfillments: fulfillments
        });
    }

    function testGetMatchedFulfillments_DoubleOrderPairs_1ItemTo1Item() public {
        execGetMatchedFulfillments_DoubleOrderPairs_1ItemTo1Item(false, false);
        execGetMatchedFulfillments_DoubleOrderPairs_1ItemTo1Item(true, false);
        execGetMatchedFulfillments_DoubleOrderPairs_1ItemTo1Item(false, true);
        // Can't do true, true until we set up another test conduit.
    }

    function execGetMatchedFulfillments_DoubleOrderPairs_1ItemTo1Item(
        bool useDifferentConduitsBetweenPrimeAndMirror,
        bool useDifferentConduitsBetweenOrderPairs
    ) public {
        Order memory orderOne = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(100)
                    )
                ),
            signature: ""
        });

        orderOne = _toMatchableOrder(
            orderOne,
            offerer1,
            useDifferentConduitsBetweenPrimeAndMirror
                ? 0
                : useDifferentConduitsBetweenOrderPairs
                ? 1
                : 2
        );

        Order memory otherOrderOne = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(100)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(100)
                    )
                ),
            signature: ""
        });

        if (useDifferentConduitsBetweenPrimeAndMirror) {
            otherOrderOne.parameters = otherOrderOne.parameters.withConduitKey(
                conduitKey
            );
        }

        otherOrderOne = _toMatchableOrder(
            otherOrderOne,
            offerer2,
            useDifferentConduitsBetweenPrimeAndMirror
                ? 0
                : useDifferentConduitsBetweenOrderPairs
                ? 1
                : 2
        );

        Order memory orderTwo = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(101)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(101)
                    )
                ),
            signature: ""
        });

        if (useDifferentConduitsBetweenOrderPairs) {
            orderTwo.parameters = orderTwo.parameters.withConduitKey(
                conduitKey
            );
        }

        orderTwo = _toMatchableOrder(
            orderTwo,
            offerer1,
            useDifferentConduitsBetweenPrimeAndMirror
                ? 0
                : useDifferentConduitsBetweenOrderPairs
                ? 1
                : 2
        );

        Order memory otherOrderTwo = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(101)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(101)
                    )
                ),
            signature: ""
        });

        if (
            useDifferentConduitsBetweenPrimeAndMirror ||
            useDifferentConduitsBetweenOrderPairs
        ) {
            otherOrderTwo.parameters = otherOrderTwo.parameters.withConduitKey(
                conduitKey
            );
        }

        otherOrderTwo = _toMatchableOrder(
            otherOrderTwo,
            offerer2,
            useDifferentConduitsBetweenPrimeAndMirror
                ? 0
                : useDifferentConduitsBetweenOrderPairs
                ? 1
                : 2
        );

        Fulfillment[] memory expectedFulfillments;

        if (!useDifferentConduitsBetweenOrderPairs) {
            expectedFulfillments = SeaportArrays.Fulfillments(
                Fulfillment({
                    offerComponents: SeaportArrays.FulfillmentComponents(
                        FulfillmentComponent({ orderIndex: 1, itemIndex: 0 }),
                        FulfillmentComponent({ orderIndex: 3, itemIndex: 0 })
                    ),
                    considerationComponents: SeaportArrays
                        .FulfillmentComponents(
                            FulfillmentComponent({
                                orderIndex: 0,
                                itemIndex: 0
                            }),
                            FulfillmentComponent({
                                orderIndex: 2,
                                itemIndex: 0
                            })
                        )
                }),
                Fulfillment({
                    offerComponents: SeaportArrays.FulfillmentComponents(
                        FulfillmentComponent({ orderIndex: 0, itemIndex: 0 }),
                        FulfillmentComponent({ orderIndex: 2, itemIndex: 0 })
                    ),
                    considerationComponents: SeaportArrays
                        .FulfillmentComponents(
                            FulfillmentComponent({
                                orderIndex: 1,
                                itemIndex: 0
                            }),
                            FulfillmentComponent({
                                orderIndex: 3,
                                itemIndex: 0
                            })
                        )
                })
            );
        } else {
            // [
            //     ([(1, 0)], [(0, 0), (2, 0)]),
            //     ([(3, 0)], [(0, 0)]),
            //     ([(0, 0)], [(1, 0), (3, 0)]),
            //     ([(2, 0)], [(1, 0)])
            // ]
            expectedFulfillments = SeaportArrays.Fulfillments(
                Fulfillment({
                    offerComponents: SeaportArrays.FulfillmentComponents(
                        FulfillmentComponent({ orderIndex: 1, itemIndex: 0 })
                    ),
                    considerationComponents: SeaportArrays
                        .FulfillmentComponents(
                            FulfillmentComponent({
                                orderIndex: 0,
                                itemIndex: 0
                            }),
                            FulfillmentComponent({
                                orderIndex: 2,
                                itemIndex: 0
                            })
                        )
                }),
                Fulfillment({
                    offerComponents: SeaportArrays.FulfillmentComponents(
                        FulfillmentComponent({ orderIndex: 3, itemIndex: 0 })
                    ),
                    considerationComponents: SeaportArrays
                        .FulfillmentComponents(
                            FulfillmentComponent({
                                orderIndex: 0,
                                itemIndex: 0
                            })
                        )
                }),
                Fulfillment({
                    offerComponents: SeaportArrays.FulfillmentComponents(
                        FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
                    ),
                    considerationComponents: SeaportArrays
                        .FulfillmentComponents(
                            FulfillmentComponent({
                                orderIndex: 1,
                                itemIndex: 0
                            }),
                            FulfillmentComponent({
                                orderIndex: 3,
                                itemIndex: 0
                            })
                        )
                }),
                Fulfillment({
                    offerComponents: SeaportArrays.FulfillmentComponents(
                        FulfillmentComponent({ orderIndex: 2, itemIndex: 0 })
                    ),
                    considerationComponents: SeaportArrays
                        .FulfillmentComponents(
                            FulfillmentComponent({
                                orderIndex: 1,
                                itemIndex: 0
                            })
                        )
                })
            );
        }

        bytes32[] memory orderHashes = new bytes32[](4);

        (Fulfillment[] memory fulfillments, , ) = matcher
            .getMatchedFulfillments(
                SeaportArrays.Orders(
                    orderOne,
                    otherOrderOne,
                    orderTwo,
                    otherOrderTwo
                ),
                orderHashes,
                new UnavailableReason[](4)
            );

        if (!useDifferentConduitsBetweenOrderPairs) {
            assertEq(fulfillments.length, 2, "fulfillments.length");
            assertEq(
                fulfillments[0],
                expectedFulfillments[0],
                "fulfillments[0]"
            );
            assertEq(
                fulfillments[1],
                expectedFulfillments[1],
                "fulfillments[1]"
            );
        } else {
            assertEq(fulfillments.length, 4, "fulfillments.length");
            assertEq(
                fulfillments[0],
                expectedFulfillments[0],
                "fulfillments[0]"
            );
            assertEq(
                fulfillments[1],
                expectedFulfillments[1],
                "fulfillments[1]"
            );
            assertEq(
                fulfillments[2],
                expectedFulfillments[2],
                "fulfillments[2]"
            );
            assertEq(
                fulfillments[3],
                expectedFulfillments[3],
                "fulfillments[3]"
            );
        }

        seaport.matchOrders({
            orders: SeaportArrays.Orders(
                orderOne,
                otherOrderOne,
                orderTwo,
                otherOrderTwo
            ),
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
                            .withToken(address(erc20s[0]))
                            .withAmount(90),
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(10)
                    )
                )
                .withConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(10),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(90),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(10)
                    )
                )
                .withOfferer(offerer1.addr),
            signature: ""
        });

        order = _toMatchableOrder(
            order,
            offerer1,
            useDifferentConduits ? 1 : 0
        );

        Order memory otherOrder = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(30)
                    )
                )
                .withConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(10)
                    )
                )
                .withOfferer(offerer2.addr),
            signature: ""
        });

        if (useDifferentConduits) {
            otherOrder.parameters = otherOrder.parameters.withConduitKey(
                conduitKey
            );
        }

        otherOrder = _toMatchableOrder(
            otherOrder,
            offerer2,
            useDifferentConduits ? 2 : 0
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

        bytes32[] memory orderHashes = new bytes32[](2);

        (Fulfillment[] memory fulfillments, , ) = matcher
            .getMatchedFulfillments(
                SeaportArrays.Orders(order, otherOrder),
                orderHashes,
                new UnavailableReason[](2)
            );
        assertEq(fulfillments.length, 3, "fulfillments.length");

        assertEq(fulfillments[0], expectedFulfillments[0], "fulfillments[0]");
        assertEq(fulfillments[1], expectedFulfillments[1], "fulfillments[1]");
        assertEq(fulfillments[2], expectedFulfillments[2], "fulfillments[2]");

        seaport.matchOrders({
            orders: SeaportArrays.Orders(order, otherOrder),
            fulfillments: fulfillments
        });
    }

    function testRemainingItems_availableOrder() public {
        Order memory order1 = Order({
            parameters: OrderParametersLib
                .empty()
                .withStartTime(block.timestamp)
                .withEndTime(block.timestamp + 1)
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(10),
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(11)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(1),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(2)
                    )
                )
                .withOfferer(offerer1.addr),
            signature: ""
        });

        // Note: there's no order 2.

        bytes32[] memory orderHashes = new bytes32[](1);

        (
            ,
            MatchComponent[] memory remainingOffer,
            MatchComponent[] memory remainingConsideration
        ) = matcher.getMatchedFulfillments(
                SeaportArrays.Orders(order1),
                orderHashes,
                new UnavailableReason[](1)
            );

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

    function testRemainingItems_unavailableOrder() public {
        Order memory order1 = Order({
            parameters: OrderParametersLib
                .empty()
                .withOffer(
                    SeaportArrays.OfferItems(
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(10),
                        OfferItemLib
                            .empty()
                            .withToken(address(erc20s[0]))
                            .withAmount(11)
                    )
                )
                .withTotalConsideration(
                    SeaportArrays.ConsiderationItems(
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(1),
                        ConsiderationItemLib
                            .empty()
                            .withToken(address(erc20s[1]))
                            .withAmount(2)
                    )
                )
                .withOfferer(offerer1.addr),
            signature: ""
        });

        // Note: there's no order 2.

        bytes32[] memory orderHashes = new bytes32[](1);

        (
            ,
            MatchComponent[] memory remainingOffer,
            MatchComponent[] memory remainingConsideration
        ) = matcher.getMatchedFulfillments(
                SeaportArrays.Orders(order1),
                orderHashes,
                new UnavailableReason[](1)
            );

        assertEq(remainingOffer.length, 0);
        assertEq(remainingConsideration.length, 0);
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
        uint256 salt
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
            .withEndTime(block.timestamp + 1)
            .withTotalOriginalConsiderationItems(
                order.parameters.consideration.length
            )
            .withSalt(salt);
        // Bump the end time by 100 so that the test doesn't try to match the
        // same order twice.

        OrderComponents memory orderComponents = parameters
            .toOrderComponents(seaport.getCounter(offerer.addr))
            .withCounter(seaport.getCounter(offerer.addr));

        bytes32 orderHash = seaport.getOrderHash(orderComponents);

        bytes memory signature = signOrder(seaport, offerer.key, orderHash);

        return Order({ parameters: parameters, signature: signature });
    }
}
