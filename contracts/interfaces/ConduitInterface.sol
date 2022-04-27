// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

// prettier-ignore
import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "./AbridgedTokenInterfaces.sol";

// prettier-ignore
import {
    ConduitTransfer,
    ConduitBatch1155Transfer
} from "../conduit/lib/ConduitStructs.sol";

/**
 * @title ConduitInterface
 */
interface ConduitInterface {
    error ChannelClosed();

    error InvalidItemType();

    error NoContract(address token);

    error BadReturnValueFromERC20OnTransfer(
        address token,
        address from,
        address to,
        uint256 amount
    );

    error InvalidERC721TransferAmount();

    error TokenTransferGenericFailure(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount
    );

    error ERC1155BatchTransferGenericFailure(
        address token,
        address from,
        address to,
        uint256[] identifiers,
        uint256[] amounts
    );

    error InvalidController();

    event ChannelUpdated(address channel, bool open);

    function updateChannel(address channel, bool isOpen) external;

    function execute(ConduitTransfer[] calldata transfers)
        external
        returns (bytes4 executeMagicValue);

    function executeWithBatch1155(
        ConduitTransfer[] calldata standardTransfers,
        ConduitBatch1155Transfer[] calldata batch1155Transfers
    ) external returns (bytes4 executeMagicValue);
}
