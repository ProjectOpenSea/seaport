// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import { FixedPointMathLib } from "solady/src/utils/FixedPointMathLib.sol";

import { ZoneInterface } from "seaport-types/src/interfaces/ZoneInterface.sol";

import {
    Schema,
    ZoneParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";

/**
 * @dev Zone whose authorizeOrder call reverts with no revert data, so Seaport
 *      has nothing to bubble up and must raise InvalidRestrictedOrder itself.
 */
contract NoRevertDataAuthorizeZone is ERC165, ZoneInterface {
    function authorizeOrder(ZoneParameters calldata)
        external
        pure
        returns (bytes4)
    {
        assembly {
            revert(0, 0)
        }
    }

    function validateOrder(ZoneParameters calldata)
        external
        pure
        returns (bytes4)
    {
        return ZoneInterface.validateOrder.selector;
    }

    function getSeaportMetadata()
        external
        pure
        override
        returns (string memory name, Schema[] memory schemas)
    {
        schemas = new Schema[](1);
        schemas[0].id = 3003;
        schemas[0].metadata = new bytes(0);

        return ("NoRevertDataAuthorizeZone", schemas);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165, ZoneInterface)
        returns (bool)
    {
        return interfaceId == type(ZoneInterface).interfaceId
            || super.supportsInterface(interfaceId);
    }
}

/**
 * @dev Token stand-in that answers every call (ERC20/ERC721 transferFrom,
 *      ERC1155 safeTransferFrom and safeBatchTransferFrom) by reverting with
 *      as much revert data as its remaining gas can pay for. The caller is
 *      left with roughly 1/64 of the gas it forwarded, which is far less than
 *      copying that returndata would cost, so TokenTransferrer must fall back
 *      to its generic error instead of bubbling the data up.
 */
contract HugeRevertDataToken {
    fallback() external {
        uint256 budget = gasleft();
        // Leave headroom for the square root and the revert itself.
        budget = budget > 10_000 ? budget - 10_000 : 0;

        // Memory for w words costs 3w + w^2 / 512 gas. Solve for the largest
        // w that fits the budget: w = (sqrt(1536^2 + 2048 * budget) - 1536) / 2.
        uint256 words =
            (FixedPointMathLib.sqrt(1536 * 1536 + 2048 * budget) - 1536) / 2;

        assembly {
            revert(0, shl(5, words))
        }
    }
}

/**
 * @dev ERC-1271 wallet that accepts a signature only from its owner and
 *      rejects any other with revert("BAD SIGNER"), so Seaport has a reason
 *      string to pass up. Stands in for the EIP1271Wallet mock the Hardhat
 *      suite used.
 */
contract RevertingEIP1271Wallet {
    address public immutable owner;

    constructor(address _owner) {
        owner = _owner;
    }

    function approve(address token, address operator) external {
        IApprovalForAll(token).setApprovalForAll(operator, true);
    }

    function isValidSignature(bytes32 digest, bytes calldata signature)
        external
        view
        returns (bytes4)
    {
        if (signature.length != 65) {
            revert("BAD SIGNATURE LENGTH");
        }
        bytes32 r = bytes32(signature[0:32]);
        bytes32 s = bytes32(signature[32:64]);
        uint8 v = uint8(signature[64]);
        if (ecrecover(digest, v, r, s) != owner) {
            revert("BAD SIGNER");
        }
        return this.isValidSignature.selector;
    }
}

interface IApprovalForAll {
    function setApprovalForAll(address operator, bool approved) external;
}
