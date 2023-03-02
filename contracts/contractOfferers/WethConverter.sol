// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ContractOffererInterface
} from "../interfaces/ContractOffererInterface.sol";

import { ItemType } from "../lib/ConsiderationEnums.sol";

import {
    ReceivedItem,
    Schema,
    SpentItem
} from "../lib/ConsiderationStructs.sol";

interface IWETH {
    function withdraw(uint256) external;

    function balanceOf(address) external view returns (uint256);

    function approve(address, uint256) external returns (bool);
}

/**
 * @title WethConverter
 * @author 0age
 * @notice WethConverter is a proof of concept for an ETH <> WETH conversion
 *         contract offerer. It will offer ETH and require an equivalent amount
 *         of WETH back, or will offer WETH and require an equivalent amount of
 *         ETH back, wrapping and unwrapping its internal balance as required to
 *         provide the requested amount. It also enables conditionally reducing
 *         the offered amount based on whether conditional listings are still
 *         available for fulfillment.
 */
contract WethConverter is ContractOffererInterface {
    address private immutable _SEAPORT;
    IWETH private immutable _WETH;

    mapping(address => uint256) public balanceOf;

    event Deposit(address indexed account, uint256 amount);
    event Withdrawal(address indexed account, uint256 amount);

    error InvalidCaller(address caller);
    error InvalidTotalMaximumSpentItems(uint256 items);
    error InvalidMaximumSpentItem(SpentItem item);
    error InsufficientMaximumSpentAmount();
    error InvalidItems();
    error InvalidTotalMinimumReceivedItems();
    error UnsupportedExtraDataVersion(uint8 version);
    error InvalidExtraDataEncoding(uint8 version);
    error NativeTokenTransferFailure(address target, uint256 amount);
    error CallFailed(); // 0x3204506f
    error NotImplemented();

    constructor(address seaport, address weth) {
        _SEAPORT = seaport;
        _WETH = IWETH(weth);

        _WETH.approve(seaport, type(uint256).max);
    }

    /**
     * @dev Generates an order with the specified minimum and maximum spent
     *      items, and optional context (supplied as extraData).
     *
     * @custom:param fulfiller The address of the fulfiller.
     * @param minimumReceived  The minimum items that the caller must receive.
     * @param maximumSpent     The maximum items the caller is willing to spend.
     * @param context          Additional context of the order.
     *
     * @return offer         A tuple containing the offer items.
     * @return consideration An array containing the consideration items.
     */
    function generateOrder(
        address /* fulfiller */,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata context // encoded based on the schemaID
    )
        external
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        address seaport = _SEAPORT;
        address weth = address(_WETH);

        // Declare an error buffer; first check is that caller is Seaport.
        uint256 errorBuffer = _cast(msg.sender != _SEAPORT);

        // Next, check the length of the maximum spent array.
        errorBuffer |= _cast(maximumSpent.length != 1) << 1;

        SpentItem calldata maximumSpentItem = maximumSpent[0];

        ItemType considerationItemType;

        assembly {
            considerationItemType := calldataload(maximumSpentItem)

            // If the item type is too high, or if the item is an ERC20
            // token and the token address is not WETH, the item is invalid.
            let invalidMaximumSpentItem := or(
                gt(considerationItemType, 1),
                and(
                    considerationItemType,
                    eq(calldataload(add(maximumSpentItem, 0x20)), weth)
                )
            )

            errorBuffer := or(errorBuffer, shl(3, invalidMaximumSpentItem))
        }

        uint256 amount;
        assembly {
            amount := calldataload(add(maximumSpentItem, 0x60))
        }

        amount = _filterUnavailable(amount, context);

        // If a native token is supplied for maximumSpent, wrap & offer WETH.
        if (considerationItemType == ItemType.NATIVE) {
            _wrapIfNecessary(amount);

            offer = new SpentItem[](1);
            offer[0].itemType = ItemType.ERC20;
            offer[0].token = address(_WETH);
            offer[0].amount = amount;
        } else {
            // Otherwise, unwrap & offer ETH (only supply minimumReceived if a
            // minimumReceived item was provided).
            _unwrapIfNecessary(amount);

            // Supply the native tokens to Seaport and update the error buffer
            // if the call fails.
            assembly {
                errorBuffer := or(
                    errorBuffer,
                    shl(7, iszero(call(gas(), seaport, amount, 0, 0, 0, 0)))
                )
            }

            if (minimumReceived.length > 0) {
                offer = new SpentItem[](1);
                offer[0].amount = amount;
            }
        }

        if (errorBuffer > 0) {
            if (errorBuffer << 255 != 0) {
                revert InvalidCaller(msg.sender);
            } else if (errorBuffer << 254 != 0) {
                revert InvalidTotalMaximumSpentItems(maximumSpent.length);
            } else if (errorBuffer << 252 != 0) {
                revert InvalidMaximumSpentItem(maximumSpent[0]);
            } else if (errorBuffer << 248 != 0) {
                revert NativeTokenTransferFailure(seaport, amount);
            }
        }

        consideration = new ReceivedItem[](1);
        consideration[0] = _copySpentAsReceivedToSelf(maximumSpentItem, amount);

        return (offer, consideration);
    }

    /**
     * @dev Enable accepting native tokens.
     */
    receive() external payable {}

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public {
        // Use checked arithmetic so underflows will revert.
        balanceOf[msg.sender] -= amount;

        // Unwrap native tokens if the current internal balance is insufficient.
        _unwrapIfNecessary(amount);

        // Return the native tokens.
        assembly {
            if iszero(call(gas(), caller(), amount, 0, 0, 0, 0)) {
                if and(
                    iszero(iszero(returndatasize())),
                    lt(returndatasize(), 0xffff)
                ) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }

                // CallFailed()
                mstore(0, 0x3204506f)
                revert(0x1c, 0x04)
            }
        }

        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @dev Ratifies an order with the specified offer, consideration, and
     *      optional context (supplied as extraData).
     *
     * @custom:param offer         The offer items.
     * @custom:param consideration The consideration items.
     * @custom:param context       Additional context of the order.
     * @custom:param orderHashes   The hashes to ratify.
     * @custom:param contractNonce The nonce of the contract.
     *
     * @return ratifyOrderMagicValue The magic value returned by the contract
     *                               offerer.
     */
    function ratifyOrder(
        SpentItem[] calldata /* offer */,
        ReceivedItem[] calldata /* consideration */,
        bytes calldata /* context */, // encoded based on the schemaID
        bytes32[] calldata /* orderHashes */,
        uint256 /* contractNonce */
    ) external pure override returns (bytes4) {
        assembly {
            // return RatifyOrder magic value.
            mstore(0, 0xf4dd92ce)
            return(0x1c, 0x04)
        }
    }

    /**
     * @dev View function to preview an order generated in response to a minimum
     *      set of received items, maximum set of spent items, and context
     *      (supplied as extraData).
     *
     * @custom:param caller      The address of the caller (e.g. Seaport).
     * @custom:paramfulfiller    The address of the fulfiller (e.g. the account
     *                           calling Seaport).
     * @custom:param minReceived The minimum items that the caller is willing to
     *                           receive.
     * @custom:param maxSpent    The maximum items caller is willing to spend.
     * @custom:param context     Additional context of the order.
     *
     * @return offer         A tuple containing the offer items.
     * @return consideration A tuple containing the consideration items.
     */
    function previewOrder(
        address,
        address,
        SpentItem[] calldata,
        SpentItem[] calldata,
        bytes calldata
    )
        external
        pure
        override
        returns (SpentItem[] memory, ReceivedItem[] memory)
    {
        revert NotImplemented();
    }

    /**
     * @dev Gets the metadata for this contract offerer.
     *
     * @return name    The name of the contract offerer.
     * @return schemas The schemas supported by the contract offerer.
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
        schemas = new Schema[](0);
        return ("WethConverter", schemas);
    }

    function _wrapIfNecessary(uint256 requiredAmount) internal {
        // Retrieve the current wrapped balance.
        uint256 currentWrappedBalance = _WETH.balanceOf(address(this));

        // Wrap if native balance is insufficient.
        if (requiredAmount > currentWrappedBalance) {
            // Retrieve the native token balance.
            uint256 currentNativeBalance;
            assembly {
                currentNativeBalance := selfbalance()
            }

            // Derive the amount to wrap, targeting eventual 50/50 split.
            uint256 amountToWrap = (currentNativeBalance +
                currentWrappedBalance +
                requiredAmount) / 2;

            // Reduce the amount to wrap if it exceeds the native balance.
            if (amountToWrap > currentNativeBalance) {
                amountToWrap = currentNativeBalance;
            }

            // Perform the wrap.
            address weth = address(_WETH);
            assembly {
                if iszero(call(gas(), weth, amountToWrap, 0, 0, 0, 0)) {
                    // CallFailed()
                    mstore(0, 0x3204506f)
                    revert(0x1c, 0x04)
                }
            }
        }
    }

    function _unwrapIfNecessary(uint256 requiredAmount) internal {
        // Retrieve the native token balance.
        uint256 currentNativeBalance;
        assembly {
            currentNativeBalance := selfbalance()
        }

        // Unwrap if native balance is insufficient.
        if (requiredAmount > currentNativeBalance) {
            // Retrieve the wrapped token balance.
            uint256 currentWrappedBalance = _WETH.balanceOf(address(this));

            // Derive the amount to unwrap, targeting eventual 50/50 split.
            uint256 amountToUnwrap = (currentNativeBalance +
                currentWrappedBalance +
                requiredAmount) / 2;

            // Reduce the amount to unwrap if it exceeds the wrapped balance.
            if (amountToUnwrap > currentWrappedBalance) {
                amountToUnwrap = currentWrappedBalance;
            }

            // Perform the unwrap.
            _WETH.withdraw(amountToUnwrap);
        }
    }

    function _filterUnavailable(
        uint256 amount,
        bytes calldata context
    ) internal pure returns (uint256 reducedAmount) {
        // TODO: decode and process context if provided
        context;

        reducedAmount = amount;
    }

    /**
     * @dev Internal pure function to cast a `bool` value to a `uint256` value.
     *
     * @param b The `bool` value to cast.
     *
     * @return u The `uint256` value.
     */
    function _cast(bool b) internal pure returns (uint256 u) {
        assembly {
            u := b
        }
    }

    /**
     * @dev Copies a spent item from calldata and converts into a received item,
     *      applying address(this) as the recipient.
     *
     * @param spentItem The spent item.
     * @param amount    The amount on the item.
     *
     * @return receivedItem The received item.
     */
    function _copySpentAsReceivedToSelf(
        SpentItem calldata spentItem,
        uint256 amount
    ) internal view returns (ReceivedItem memory receivedItem) {
        assembly {
            calldatacopy(receivedItem, spentItem, 0x60)
            mstore(add(receivedItem, 0x60), amount)
            mstore(add(receivedItem, 0x80), address())
        }
    }
}
