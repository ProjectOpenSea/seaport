// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title ERC20Interface
 * @notice Contains the minimum interfaces needed to interact with ERC20s.
 */
interface ERC20Interface {
    /**
     * @dev Allows an operator to transfer tokens on behalf of an owner.
     *
     * @param from  The address of the owner.
     * @param to    The address of the recipient.
     * @param value The amount of tokens to transfer.
     *
     * @return success True if the transfer was successful.
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool success);

    /**
     * @dev Allows an operator to approve a spender to transfer tokens on behalf
     *      of a user.
     *
     * @param spender The address of the spender.
     * @param value   The amount of tokens to approve.
     *
     * @return success True if the approval was successful.
     */

    function approve(
        address spender,
        uint256 value
    ) external returns (bool success);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     *
     * @param account The address of the account to check the balance of.
     *
     * @return balance The amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title ERC721Interface
 * @notice Contains the minimum interfaces needed to interact with ERC721s.
 */
interface ERC721Interface {
    /**
     * @dev Allows an operator to transfer tokens on behalf of an owner.
     *
     * @param from    The address of the owner.
     * @param to      The address of the recipient.
     * @param tokenId The ID of the token to transfer.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Allows an owner to approve an operator to transfer all tokens on a
     *      contract on behalf of the owner.
     *
     * @param to       The address of the operator.
     * @param approved Whether the operator is approved.
     */
    function setApprovalForAll(address to, bool approved) external;

    /**
     * @dev Returns the owner of a given token ID.
     *
     * @param tokenId The token ID.
     *
     * @return owner The owner of the token.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

/**
 * @title ERC1155Interface
 * @notice Contains the minimum interfaces needed to interact with ERC1155s.
 */
interface ERC1155Interface {
    /**
     * @dev Allows an operator to transfer tokens on behalf of an owner.
     *
     * @param from   The address of the owner.
     * @param to     The address of the recipient.
     * @param id     The ID of the token(s) to transfer.
     * @param amount The amount of tokens to transfer.
     * @param data   Additional data.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    /**
     * @dev Allows an operator to transfer tokens on behalf of an owner.
     *
     * @param from    The address of the owner.
     * @param to      The address of the recipient.
     * @param ids     The IDs of the token(s) to transfer.
     * @param amounts The amounts of tokens to transfer.
     * @param data    Additional data.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;

    /**
     * @dev Allows an owner to approve an operator to transfer all tokens on a
     *      contract on behalf of the owner.
     *
     * @param to       The address of the operator.
     * @param approved Whether the operator is approved.
     */
    function setApprovalForAll(address to, bool approved) external;

    /**
     * @dev Returns the owner of a given token ID.
     *
     * @param account The address of the account to check the balance of.
     * @param id      The token ID.
     *
     * @return balance The balance of the token.
     */

    function balanceOf(
        address account,
        uint256 id
    ) external view returns (uint256);
}
