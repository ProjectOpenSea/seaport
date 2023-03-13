// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import {
    ReceivedItem,
    Schema,
    SpentItem
} from "../../../lib/ConsiderationStructs.sol";
import { ItemType } from "../../../lib/ConsiderationEnums.sol";
import {
    ContractOffererInterface
} from "../../../interfaces/ContractOffererInterface.sol";

interface IWETH {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

contract Faucet is ContractOffererInterface {
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address immutable ADAPTER;
    address immutable SIDECAR;

    error NotImplemented();

    event FaucetEvent(
        address fulfiller,
        SpentItem[] minimumReceived,
        SpentItem[] maximumSpent,
        bytes context // encoded based on the schemaID
    );

    constructor(address adapter, address sidecar) {
        ADAPTER = adapter;
        SIDECAR = sidecar;
    }

    function generateOrder(
        address fulfiller,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata context // encoded based on the schemaID
    )
        external
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        uint256 price = abi.decode(context, (uint256));

        payable(SIDECAR).transfer(price);

        // Send some ETH to ProOrdersAdapter
        // if (minimumReceived[0].itemType == ItemType.NATIVE) {
        //     // NOTE: Although it's not recomended to use `transfer` we know for sure that
        //     //       we won't use more gas than supplied by `transfer`.
        //     payable(ADAPTER).transfer(minimumReceived[0].amount);
        // } else if (minimumReceived[0].token == WETH) {
        //     IERC20(WETH).transferFrom(
        //         address(this),
        //         ADAPTER,
        //         minimumReceived[0].amount
        //     );
        // }

        ReceivedItem[] memory receivedItem = new ReceivedItem[](1);
        receivedItem[0] = ReceivedItem(
            maximumSpent[0].itemType,
            maximumSpent[0].token,
            maximumSpent[0].identifier,
            maximumSpent[0].amount,
            payable(address(this))
        );

        return (minimumReceived, receivedItem);
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
        // Perform ETH <> WETH conversion to maintain a balance in the faucet

        // Utilize assembly to efficiently return the ratifyOrder magic value.
        assembly {
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
        return ("Faucet", schemas);
    }
}
