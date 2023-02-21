// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { stdStorage, StdStorage } from "forge-std/Test.sol";

import {
    ConsiderationInterface
} from "../../../contracts/interfaces/ConsiderationInterface.sol";

import { OrderType } from "../../../contracts/lib/ConsiderationEnums.sol";

import {
    BasicOrder_additionalRecipients_data_cdPtr,
    TwoWords
} from "../../../contracts/lib/ConsiderationConstants.sol";
import {
    AdditionalRecipient,
    Fulfillment,
    FulfillmentComponent,
    Order,
    OrderComponents,
    OrderParameters
} from "../../../contracts/lib/ConsiderationStructs.sol";

import { ArithmeticUtil } from "./ArithmeticUtil.sol";

import { OrderBuilder } from "./OrderBuilder.sol";

import { AmountDeriver } from "../../../contracts/lib/AmountDeriver.sol";

/// @dev base test class for cases that depend on pre-deployed token contracts
contract BaseOrderTest is OrderBuilder, AmountDeriver {
    using stdStorage for StdStorage;
    using ArithmeticUtil for uint256;
    using ArithmeticUtil for uint128;
    using ArithmeticUtil for uint120;

    ///@dev used to store address and key outputs from makeAddrAndKey(name)
    struct Account {
        address addr;
        uint256 key;
    }

    FulfillmentComponent firstOrderFirstItem;
    FulfillmentComponent firstOrderSecondItem;
    FulfillmentComponent secondOrderFirstItem;
    FulfillmentComponent secondOrderSecondItem;
    FulfillmentComponent[] firstOrderFirstItemArray;
    FulfillmentComponent[] firstOrderSecondItemArray;
    FulfillmentComponent[] secondOrderFirstItemArray;
    FulfillmentComponent[] secondOrderSecondItemArray;
    Fulfillment firstFulfillment;
    Fulfillment secondFulfillment;
    Fulfillment thirdFulfillment;
    Fulfillment fourthFulfillment;

    AdditionalRecipient[] additionalRecipients;

    Account offerer1;

    event Transfer(address indexed from, address indexed to, uint256 value);

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );

    modifier onlyPayable(address _addr) {
        {
            bool success;
            assembly {
                // Transfer the native token and store if it succeeded or not.
                success := call(gas(), _addr, 1, 0, 0, 0, 0)
            }
            vm.assume(success);
            vm.deal(address(this), uint128(MAX_INT));
        }
        _;
    }

    /// @dev convenience wrapper for makeAddrAndKey
    function makeAccount(string memory name) internal returns (Account memory) {
        (address addr, uint256 key) = makeAddrAndKey(name);
        return Account(addr, key);
    }

    /// @dev convenience wrapper for makeAddrAndKey that also allocates tokens,
    /// ether, and approvals
    function makeAndAllocateAccount(
        string memory name
    ) internal returns (Account memory) {
        Account memory account = makeAccount(name);
        allocateTokensAndApprovals(account.addr, uint128(MAX_INT));
        return account;
    }

    function setUp() public virtual override {
        super.setUp();

        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(cal, "cal");
        vm.label(address(this), "testContract");

        _deployTestTokenContracts();
        erc20s = [token1, token2, token3];
        erc721s = [test721_1, test721_2, test721_3];
        erc1155s = [test1155_1, test1155_2, test1155_3];

        // allocate funds and tokens to test addresses
        allocateTokensAndApprovals(address(this), uint128(MAX_INT));
        allocateTokensAndApprovals(alice, uint128(MAX_INT));
        allocateTokensAndApprovals(bob, uint128(MAX_INT));
        allocateTokensAndApprovals(cal, uint128(MAX_INT));
        allocateTokensAndApprovals(offerer1.addr, uint128(MAX_INT));

        offerer1 = makeAndAllocateAccount("offerer1");
    }

    function resetOfferComponents() internal {
        delete offerComponents;
    }

    function resetConsiderationComponents() internal {
        delete considerationComponents;
    }

    function _validateOrder(
        Order memory order,
        ConsiderationInterface _consideration
    ) internal returns (bool) {
        Order[] memory orders = new Order[](1);
        orders[0] = order;
        return _validateOrders(orders, _consideration);
    }

    function _validateOrders(
        Order[] memory orders,
        ConsiderationInterface _consideration
    ) internal returns (bool) {
        return _consideration.validate(orders);
    }

    function _prepareOrder(
        uint256 tokenId,
        uint256 totalConsiderationItems
    )
        internal
        returns (
            Order memory order,
            OrderParameters memory orderParameters,
            bytes memory signature
        )
    {
        test1155_1.mint(address(this), tokenId, 10);

        addErc1155OfferItem(tokenId, 10);
        for (uint256 i = 0; i < totalConsiderationItems; i++) {
            addErc20ConsiderationItem(alice, 10);
        }
        uint256 nonce = consideration.getCounter(address(this));

        orderParameters = getOrderParameters(
            payable(this),
            OrderType.FULL_OPEN
        );
        OrderComponents memory orderComponents = toOrderComponents(
            orderParameters,
            nonce
        );

        bytes32 orderHash = consideration.getOrderHash(orderComponents);

        signature = signOrder(consideration, alicePk, orderHash);
        order = Order(orderParameters, signature);
    }

    function _subtractAmountFromLengthInOrderCalldata(
        bytes memory orderCalldata,
        uint256 relativeOrderParametersOffset,
        uint256 relativeItemsLengthOffset,
        uint256 amtToSubtractFromLength
    ) internal pure {
        bytes32 lengthPtr = _getItemsLengthPointerInOrderCalldata(
            orderCalldata,
            relativeOrderParametersOffset,
            relativeItemsLengthOffset
        );
        assembly {
            let length := mload(lengthPtr)
            mstore(lengthPtr, sub(length, amtToSubtractFromLength))
        }
    }

    function _dirtyFirstAdditionalRecipient(
        bytes memory orderCalldata
    ) internal pure {
        assembly {
            let firstAdditionalRecipientOffset := add(
                orderCalldata,
                add(TwoWords, BasicOrder_additionalRecipients_data_cdPtr)
            )
            // Dirty the top byte of the first additional recipient address.
            mstore8(firstAdditionalRecipientOffset, 1)
        }
    }

    function _getItemsLengthPointerInOrderCalldata(
        bytes memory orderCalldata,
        uint256 relativeOrderParametersOffset,
        uint256 relativeItemsLengthOffset
    ) internal pure returns (bytes32 lengthPtr) {
        assembly {
            // Points to the order parameters in the order calldata.
            let orderParamsOffsetPtr := add(
                orderCalldata,
                relativeOrderParametersOffset
            )
            // Points to the items offset value.
            // Note: itemsOffsetPtr itself is not the offset value;
            // the value stored at itemsOffsetPtr is the offset value.
            let itemsOffsetPtr := add(
                orderParamsOffsetPtr,
                relativeItemsLengthOffset
            )
            // Value of the items offset, which is the offset of the items
            // array relative to the start of order parameters.
            let itemsOffsetValue := mload(itemsOffsetPtr)

            // The memory for an array will always start with a word
            // indicating the length of the array, so length pointer
            // can simply point to the start of the items array.
            lengthPtr := add(orderParamsOffsetPtr, itemsOffsetValue)
        }
    }

    function _getItemsLengthAtOffsetInOrderCalldata(
        bytes memory orderCalldata,
        // Relative offset of start of order parameters
        // in the order calldata.
        uint256 relativeOrderParametersOffset,
        // Relative offset of items pointer (which points to items' length)
        // to the start of order parameters in order calldata.
        uint256 relativeItemsLengthOffset
    ) internal pure returns (uint256 length) {
        bytes32 lengthPtr = _getItemsLengthPointerInOrderCalldata(
            orderCalldata,
            relativeOrderParametersOffset,
            relativeItemsLengthOffset
        );
        assembly {
            length := mload(lengthPtr)
        }
    }

    function _performTestFulfillOrderRevertInvalidArrayLength(
        ConsiderationInterface _consideration,
        Order memory order,
        bytes memory fulfillOrderCalldata,
        // Relative offset of start of order parameters
        // in the order calldata.
        uint256 relativeOrderParametersOffset,
        // Relative offset of items pointer (which points to items' length)
        // to the start of order parameters in order calldata.
        uint256 relativeItemsLengthOffset,
        uint256 originalItemsLength,
        uint256 amtToSubtractFromItemsLength
    ) internal {
        assertTrue(_validateOrder(order, _consideration));

        bool overwriteItemsLength = amtToSubtractFromItemsLength > 0;
        if (overwriteItemsLength) {
            // Get the array length from the calldata and
            // store the length - amtToSubtractFromItemsLength in the calldata
            // so that the length value does _not_ accurately represent the actual
            // total array length.
            _subtractAmountFromLengthInOrderCalldata(
                fulfillOrderCalldata,
                relativeOrderParametersOffset,
                relativeItemsLengthOffset,
                amtToSubtractFromItemsLength
            );
        }

        uint256 finalItemsLength = _getItemsLengthAtOffsetInOrderCalldata(
            fulfillOrderCalldata,
            // Relative offset of start of order parameters
            // in the order calldata.
            relativeOrderParametersOffset,
            // Relative offset of items
            // pointer to the start of order parameters in order calldata.
            relativeItemsLengthOffset
        );

        assertEq(
            finalItemsLength,
            originalItemsLength - amtToSubtractFromItemsLength
        );

        bool success = _callConsiderationFulfillOrderWithCalldata(
            address(_consideration),
            fulfillOrderCalldata
        );

        // If overwriteItemsLength is True, the call should
        // have failed (success should be False) and if overwriteItemsLength is False,
        // the call should have succeeded (success should be True).
        assertEq(success, !overwriteItemsLength);
    }

    function _callConsiderationFulfillOrderWithCalldata(
        address considerationAddress,
        bytes memory orderCalldata
    ) internal returns (bool success) {
        (success, ) = considerationAddress.call(orderCalldata);
    }

    function getMaxConsiderationValue() internal view returns (uint256) {
        uint256 value = 0;
        for (uint256 i = 0; i < considerationItems.length; ++i) {
            uint256 amount = considerationItems[i].startAmount >
                considerationItems[i].endAmount
                ? considerationItems[i].startAmount
                : considerationItems[i].endAmount;
            value += amount;
        }
        return value;
    }

    /**
     * @dev return OrderComponents for a given OrderParameters and offerer counter
     */
    function getOrderComponents(
        OrderParameters memory parameters,
        uint256 counter
    ) internal pure returns (OrderComponents memory) {
        return
            OrderComponents(
                parameters.offerer,
                parameters.zone,
                parameters.offer,
                parameters.consideration,
                parameters.orderType,
                parameters.startTime,
                parameters.endTime,
                parameters.zoneHash,
                parameters.salt,
                parameters.conduitKey,
                counter
            );
    }

    function getOrderParameters(
        address offerer,
        OrderType orderType
    ) internal returns (OrderParameters memory) {
        return
            OrderParameters({
                offerer: offerer,
                zone: address(0),
                offer: offerItems,
                consideration: considerationItems,
                orderType: orderType,
                startTime: block.timestamp,
                endTime: block.timestamp + 1,
                zoneHash: bytes32(0),
                salt: globalSalt++,
                conduitKey: bytes32(0),
                totalOriginalConsiderationItems: considerationItems.length
            });
    }

    function toOrderComponents(
        OrderParameters memory _params,
        uint256 nonce
    ) internal pure returns (OrderComponents memory) {
        return
            OrderComponents(
                _params.offerer,
                _params.zone,
                _params.offer,
                _params.consideration,
                _params.orderType,
                _params.startTime,
                _params.endTime,
                _params.zoneHash,
                _params.salt,
                _params.conduitKey,
                nonce
            );
    }

    ///@dev allow signing for this contract since it needs to be recipient of basic order to reenter on receive
    function isValidSignature(
        bytes32,
        bytes memory
    ) external pure virtual returns (bytes4) {
        return 0x1626ba7e;
    }

    receive() external payable virtual {}
}
