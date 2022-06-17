// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { ERC721TokenReceiver } from "../../lib/solmate/src/tokens/ERC721.sol";

contract InvalidERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return 0xabcd0000;
    }
}
