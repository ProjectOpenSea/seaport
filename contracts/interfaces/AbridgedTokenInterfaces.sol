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
     * @ param address The address of the owner.
     * @ param address The address of the recipient.
     * @ param uint256 The amount of tokens to transfer.
     */
    function transferFrom(address, address, uint256) external returns (bool);

    /**
     * @dev Allows an operator to approve a spender to transfer tokens on behalf
     *      of a user.
     *
     * @ param address The address of the user.
     * @ param address The address of the spender.
     * @ param uint256 The amount of tokens to approve.
     */
    function approve(address, uint256) external returns (bool);
}

/**
 * @title ERC721Interface
 * @notice Contains the minimum interfaces needed to interact with ERC721s.
 */
interface ERC721Interface {
    /**
     * @dev Allows an operator to transfer tokens on behalf of an owner.
     *
     * @ param address The address of the owner.
     * @ param address The address of the recipient.
     * @ param uint256 The ID of the token to transfer.
     */
    function transferFrom(address, address, uint256) external;

    /**
     * @dev Allows an owner to approve an operator to transfer all tokens on a
     *      contract on behalf of the owner.
     *
     * @ param address The address of the operator.
     * @ param bool    Whether the operator is approved.
     */
    function setApprovalForAll(address, bool) external;

    /**
     * @dev Returns the owner of a given token ID.
     *
     * @ param uint256 The token ID.
     *
     * @ return address The owner of the token.
     */
    function ownerOf(uint256) external view returns (address);
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
     * @ param address The address of the operator.
     * @ param bool    Whether the operator is approved.
     */
    function setApprovalForAll(address, bool) external;
}
