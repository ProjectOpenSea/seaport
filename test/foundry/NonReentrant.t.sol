// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient } from "../../contracts/lib/ConsiderationStructs.sol";
import { Consideration } from "../../contracts/Consideration.sol";
import { OfferItem, ConsiderationItem, OrderComponents, BasicOrderParameters } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../contracts/test/TestERC20.sol";

contract NonReentrantTest is BaseOrderTest {
    /**
     * @dev Enum of functions that set the reentrancy guard
     */
    enum EntryPoint {
        FULFILL_BASIC_ORDER,
        FULFILL_ORDER,
        FULFILL_ADVANCED_ORDER,
        FULFILL_AVAILABLE_ORDERS,
        FULFILL_AVAILABLE_ADVANCED_ORDERS,
        MATCH_ORDERS,
        MATCH_ADVANCED_ORDERS
    }

    /**
     * @dev Enum of functions that check the reentrancy guard
     */
    enum ReentrancyPoint {
        FULFILL_BASIC_ORDER,
        FULFILL_ORDER,
        FULFILL_ADVANCED_ORDER,
        FULFILL_AVAILABLE_ORDERS,
        FULFILL_AVAILABLE_ADVANCED_ORDERS,
        MATCH_ORDERS,
        MATCH_ADVANCED_ORDERS,
        CANCEL,
        VALIDATE,
        INCREMENT_NONCE
    }

    /**
     * @dev struct to test combinations of entrypoints and reentrancy points
     */
    struct NonReentrantInputs {
        EntryPoint entryPoint;
        ReentrancyPoint reentrancyPoint;
    }

    struct NonReentrantDifferentialInputs {
        Consideration consideration;
        NonReentrantInputs args;
    }

    // function testNonReentrant(NonReentrantInputs memory inputs) public {
    //     _testNonReentrant(
    //         NonReentrantDifferentialInputs(consideration, inputs)
    //     );
    //     _testNonReentrant(
    //         NonReentrantDifferentialInputs(referenceConsideration, inputs)
    //     );
    // }

    function _testNonReentrant(NonReentrantDifferentialInputs memory inputs)
        internal
        resetTokenBalancesBetweenRuns
    {}
}
