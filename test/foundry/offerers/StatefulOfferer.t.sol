// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";
import { StatefulRatifierOfferer } from "./impl/StatefulRatifierOfferer.sol";
import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "../../../contracts/interfaces/AbridgedTokenInterfaces.sol";
import {
    ConsiderationInterface
} from "../../../contracts/interfaces/ConsiderationInterface.sol";
import {
    OfferItem,
    ConsiderationItem,
    AdvancedOrder,
    CriteriaResolver,
    SpentItem,
    OrderParameters,
    OrderComponents,
    ReceivedItem
} from "../../../contracts/lib/ConsiderationStructs.sol";
import {
    ItemType,
    OrderType
} from "../../../contracts/lib/ConsiderationEnums.sol";

contract StatefulOffererTest is BaseOrderTest {
    StatefulRatifierOfferer offerer;

    struct Context {
        ConsiderationInterface consideration;
    }

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testNormalFulfill() public {
        test(
            this.execFulfillAdvanced,
            Context({ consideration: consideration })
        );
        test(
            this.execFulfillAdvanced,
            Context({ consideration: referenceConsideration })
        );
    }

    function execFulfillAdvanced(Context memory context) public stateless {
        offerer = new StatefulRatifierOfferer(
            address(context.consideration),
            ERC20Interface(address(token1)),
            ERC721Interface(address(test721_1))
        );
        addErc20OfferItem(1);
        addErc721ConsiderationItem(payable(address(offerer)), 42);
        test721_1.mint(address(this), 42);
        _configureOrderParameters({
            offerer: address(offerer),
            zone: address(0),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.orderType = OrderType.CONTRACT;

        _configureOrderComponents(0);

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: ""
        });

        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);

        context.consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertTrue(offerer.called());
    }

    function execFulfillBasic(Context memory context) public stateless {
        offerer = new StatefulRatifierOfferer(
            address(context.consideration),
            ERC20Interface(address(token1)),
            ERC721Interface(address(test721_1))
        );
        addErc20OfferItem(1);
        addErc721ConsiderationItem(payable(address(offerer)), 42);
        test721_1.mint(address(this), 42);
        _configureOrderParameters({
            offerer: address(offerer),
            zone: address(0),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.orderType = OrderType.CONTRACT;

        _configureOrderComponents(0);

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: ""
        });

        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);

        context.consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertTrue(offerer.called());
    }
}
