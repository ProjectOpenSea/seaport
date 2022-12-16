// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title SeaportRouterErrors
 */
interface SeaportRouterErrors {
    /**
     * @dev Revert with an error if a Seaport contract is not allowed
     *      to be used through the router.
     */
    error SeaportNotAllowed(address seaport);

    /**
     * @dev Revert with an error if a Seaport contract is already allowed
     *      in the router.
     */
    error SeaportAlreadyAdded(address seaport);

    /**
     * @dev Revert with an error if a Seaport contract is not present to remove
     *      in the router.
     */
    error SeaportNotPresent(address eaport);

    /**
     * @dev Revert with an error if an ether transfer back to the fulfiller
     *      fails.
     */
    error EtherReturnTransferFailed(
        address recipient,
        uint256 amount,
        bytes returnData
    );
}
