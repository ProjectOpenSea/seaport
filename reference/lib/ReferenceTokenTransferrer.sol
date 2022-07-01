// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "seaport/lib/ConsiderationConstants.sol";

// prettier-ignore
import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "seaport/interfaces/AbridgedTokenInterfaces.sol";

import { TokenTransferrerErrors } from "seaport/interfaces/TokenTransferrerErrors.sol";

contract ReferenceTokenTransferrer is TokenTransferrerErrors {
    /**
     * @dev Internal function to transfer ERC20 tokens from a given originator
     *      to a given recipient. Sufficient approvals must be set on the
     *      contract performing the transfer.
     *
     * @param token      The ERC20 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param amount     The amount to transfer.
     */
    function _performERC20Transfer(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        if (token.code.length == 0) {
            revert NoContract(token);
        }

        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(
                ERC20Interface.transferFrom.selector,
                from,
                to,
                amount
            )
        );

        // NOTE: revert reasons are not "bubbled up" at the moment
        if (!ok) {
            revert TokenTransferGenericFailure(token, from, to, 0, amount);
        }

        if (data.length != 0 && data.length >= 32) {
            if (!abi.decode(data, (bool))) {
                revert BadReturnValueFromERC20OnTransfer(
                    token,
                    from,
                    to,
                    amount
                );
            }
        }
    }

    /**
     * @dev Internal function to transfer an ERC721 token from a given
     *      originator to a given recipient. Sufficient approvals must be set on
     *      the contract performing the transfer.
     *
     * @param token      The ERC721 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param identifier The tokenId to transfer.
     */
    function _performERC721Transfer(
        address token,
        address from,
        address to,
        uint256 identifier
    ) internal {
        if (token.code.length == 0) {
            revert NoContract(token);
        }

        ERC721Interface(token).transferFrom(from, to, identifier);
    }

    /**
     * @dev Internal function to transfer ERC1155 tokens from a given
     *      originator to a given recipient. Sufficient approvals must be set on
     *      the contract performing the transfer and contract recipients must
     *      implement onReceived to indicate that they are willing to accept the
     *      transfer.
     *
     * @param token      The ERC1155 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param identifier The id to transfer.
     * @param amount     The amount to transfer.
     */
    function _performERC1155Transfer(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount
    ) internal {
        if (token.code.length == 0) {
            revert NoContract(token);
        }

        ERC1155Interface(token).safeTransferFrom(
            from,
            to,
            identifier,
            amount,
            ""
        );
    }

    /**
     * @dev Internal function to transfer ERC1155 tokens from a given
     *      originator to a given recipient. Sufficient approvals must be set on
     *      the contract performing the transfer and contract recipients must
     *      implement onReceived to indicate that they are willing to accept the
     *      transfer.
     *
     * @param token       The ERC1155 token to transfer in batch.
     * @param from        The originator of the transfer batch.
     * @param to          The recipient of the transfer batch.
     * @param identifiers The ids to transfer.
     * @param amounts     The amounts to transfer.
     */
    function _performERC1155BatchTransfer(
        address token,
        address from,
        address to,
        uint256[] memory identifiers,
        uint256[] memory amounts
    ) internal {
        if (token.code.length == 0) {
            revert NoContract(token);
        }

        ERC1155Interface(token).safeBatchTransferFrom(
            from,
            to,
            identifiers,
            amounts,
            ""
        );
    }
}
