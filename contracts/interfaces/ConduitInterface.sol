// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

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
