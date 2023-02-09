// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface CreatorFeeEngineInterface {
    function getRoyaltyView(
        address tokenAddress,
        uint256 tokenId,
        uint256 value
    )
        external
        view
        returns (address payable[] memory recipients, uint256[] memory amounts);
}

import { IERC2981 } from "../../interfaces/IERC2981.sol";

/**
 * @title CreatorFeeHelper
 * @notice CreatorFeeHelper fetches creator fee information for specific tokens
 *         and tokenIds.
 */
contract CreatorFeeHelper {
    /// @notice Ethereum creator fee engine address
    CreatorFeeEngineInterface public immutable creatorFeeEngine;

    constructor() {
        address creatorFeeEngineAddress;
        if (block.chainid == 1) {
            creatorFeeEngineAddress = 0x0385603ab55642cb4Dd5De3aE9e306809991804f;
        } else if (block.chainid == 3) {
            // Ropsten
            creatorFeeEngineAddress = 0xFf5A6F7f36764aAD301B7C9E85A5277614Df5E26;
        } else if (block.chainid == 4) {
            // Rinkeby
            creatorFeeEngineAddress = 0x8d17687ea9a6bb6efA24ec11DcFab01661b2ddcd;
        } else if (block.chainid == 5) {
            // Goerli
            creatorFeeEngineAddress = 0xe7c9Cb6D966f76f3B5142167088927Bf34966a1f;
        } else if (block.chainid == 42) {
            // Kovan
            creatorFeeEngineAddress = 0x54D88324cBedfFe1e62c9A59eBb310A11C295198;
        } else if (block.chainid == 137) {
            // Polygon
            creatorFeeEngineAddress = 0x28EdFcF0Be7E86b07493466e7631a213bDe8eEF2;
        } else if (block.chainid == 80001) {
            // Mumbai
            creatorFeeEngineAddress = 0x0a01E11887f727D1b1Cd81251eeEE9BEE4262D07;
        } else {
            // No creator fee engine for this chain
            creatorFeeEngineAddress = address(0);
        }

        creatorFeeEngine = CreatorFeeEngineInterface(creatorFeeEngineAddress);
    }

    /**
     * @notice Fetches the on chain creator fees.
     * @dev Uses the creatorFeeEngine when available, otherwise fallback to `IERC2981`.
     * @param token The token address
     * @param tokenId The token identifier
     * @param transactionAmountStart The transaction start amount
     * @param transactionAmountEnd The transaction end amount
     * @return recipient creator fee recipient
     * @return creatorFeeAmountStart creator fee start amount
     * @return creatorFeeAmountEnd creator fee end amount
     */
    function getCreatorFeeInfo(
        address token,
        uint256 tokenId,
        uint256 transactionAmountStart,
        uint256 transactionAmountEnd
    )
        public
        view
        returns (
            address payable recipient,
            uint256 creatorFeeAmountStart,
            uint256 creatorFeeAmountEnd
        )
    {
        // Check if creator fee engine is on this chain
        if (address(creatorFeeEngine) != address(0)) {
            // Creator fee engine may revert if no creator fees are present.
            try
                creatorFeeEngine.getRoyaltyView(
                    token,
                    tokenId,
                    transactionAmountStart
                )
            returns (
                address payable[] memory creatorFeeRecipients,
                uint256[] memory creatorFeeAmountsStart
            ) {
                if (creatorFeeRecipients.length != 0) {
                    // Use first recipient and amount
                    recipient = creatorFeeRecipients[0];
                    creatorFeeAmountStart = creatorFeeAmountsStart[0];
                }
            } catch {
                // Creator fee not found
            }

            // If fees found for start amount, check end amount
            if (recipient != address(0)) {
                // Creator fee engine may revert if no creator fees are present.
                try
                    creatorFeeEngine.getRoyaltyView(
                        token,
                        tokenId,
                        transactionAmountEnd
                    )
                returns (
                    address payable[] memory,
                    uint256[] memory creatorFeeAmountsEnd
                ) {
                    creatorFeeAmountEnd = creatorFeeAmountsEnd[0];
                } catch {}
            }
        } else {
            // Fallback to ERC2981
            {
                // Static call to token using ERC2981
                (bool success, bytes memory res) = token.staticcall(
                    abi.encodeWithSelector(
                        IERC2981.royaltyInfo.selector,
                        tokenId,
                        transactionAmountStart
                    )
                );
                // Check if call succeeded
                if (success) {
                    // Ensure 64 bytes returned
                    if (res.length == 64) {
                        // Decode result and assign recipient and start amount
                        (recipient, creatorFeeAmountStart) = abi.decode(
                            res,
                            (address, uint256)
                        );
                    }
                }
            }

            // Only check end amount if start amount found
            if (recipient != address(0)) {
                // Static call to token using ERC2981
                (bool success, bytes memory res) = token.staticcall(
                    abi.encodeWithSelector(
                        IERC2981.royaltyInfo.selector,
                        tokenId,
                        transactionAmountEnd
                    )
                );
                // Check if call succeeded
                if (success) {
                    // Ensure 64 bytes returned
                    if (res.length == 64) {
                        // Decode result and assign end amount
                        (, creatorFeeAmountEnd) = abi.decode(
                            res,
                            (address, uint256)
                        );
                    }
                }
            }
        }
    }
}
