// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import "./EchidnaOrderUtils.sol";
import "../contracts/interfaces/ConsiderationInterface.sol";
import { OrderType } from "../contracts/lib/ConsiderationEnums.sol";

import "./tokens/NoApprovalERC20.sol";
import "./tokens/NoApprovalERC721.sol";
import "./tokens/NoApprovalERC1155.sol";

interface IHevm {
    function sign(uint256 sk, bytes32 digest)
        external
        returns (
            uint8 v,
            bytes32 r,
            bytes32 s
        );
}

interface IEchidna {
    function testFulfillAdvancedOrder(
        bytes32 seed,
        uint120 numerator,
        uint120 denominator
    ) external payable;

    function testCancel() external;

    function testValidate(bytes32) external;

    function testIncrementNonce() external;
}

abstract contract EchidnaUtils is IEchidna, EchidnaOrderUtils {
    IHevm immutable vm = IHevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    NoApprovalERC20 immutable _erc20;
    NoApprovalERC721 immutable _erc721;
    NoApprovalERC1155 immutable _erc1155;

    event AssertionFailure(
        string functionName,
        uint256 params1,
        uint256 params2
    );

    constructor() {
        _erc20 = new NoApprovalERC20();
        _erc721 = new NoApprovalERC721();
        _erc1155 = new NoApprovalERC1155();
    }

    function one_to_max_uint64(uint256 random) internal pure returns (uint256) {
        return 1 + (random % (type(uint64).max - 1));
    }

    function emitAndFail(
        string memory message,
        uint256 num1,
        uint256 num2
    ) internal {
        emit AssertionFailure(message, num1, num2);
        assert(false);
    }

    function signOrder(bytes32 orderHash, bytes32 domainSeparator)
        internal
        returns (bytes memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            2,
            keccak256(
                abi.encodePacked(bytes2(0x1901), domainSeparator, orderHash)
            )
        );
        return abi.encodePacked(r, s, v);
    }

    function mintERC20(address who, uint256 amount) private {
        _erc20.mint(who, amount);
    }

    function mintERC721(address who, uint256 id) private {
        _erc721.mint(who, id);
    }

    function mintERC1155(
        address who,
        uint256 id,
        uint256 amount
    ) private {
        _erc1155.mint(who, id, amount);
    }

    function _assertFundsReceived(
        address seller,
        address buyer,
        uint256 route,
        uint256 totalTokens,
        uint256 totalItems,
        uint256 uid
    ) internal {
        if (route == 0) /*NATIVE TO ERC721*/
        {
            if (seller.balance < totalTokens) {
                emitAndFail(
                    "/*NATIVE TO ERC721*/ seller",
                    seller.balance,
                    totalTokens
                );
            }
            if (_erc721.balanceOf(buyer) < totalItems) {
                emitAndFail(
                    "/*NATIVE TO ERC721*/ buyer",
                    _erc721.balanceOf(buyer),
                    totalItems
                );
            }
        } else if (route == 1) /*NATIVE TO ERC1155*/
        {
            if (seller.balance < totalTokens) {
                emitAndFail(
                    "/*NATIVE TO ERC1155*/ seller",
                    seller.balance,
                    totalTokens
                );
            }
            if (_erc1155.balanceOf(buyer, uid) < totalTokens) {
                emitAndFail(
                    "/*NATIVE TO ERC1155*/ buyer",
                    _erc1155.balanceOf(buyer, uid),
                    totalTokens
                );
            }
        } else if (route == 2) /*ERC20 TO ERC721*/
        {
            if (_erc20.balanceOf(seller) < totalTokens) {
                emitAndFail(
                    "/*ERC721 TO ERC20 */ FAILED",
                    _erc20.balanceOf(seller),
                    totalTokens
                );
            }
            if (_erc721.balanceOf(buyer) < totalItems) {
                emitAndFail(
                    "/*ERC721 TO ERC20 */ FAILED",
                    _erc721.balanceOf(buyer),
                    totalItems
                );
            }
        } else if (route == 3) /*ERC20 TO ERC1155*/
        {
            if (_erc1155.balanceOf(buyer, uid) < totalTokens) {
                emitAndFail(
                    " /*ERC115 TO ERC20 */ buyer",
                    _erc1155.balanceOf(buyer, uid),
                    totalTokens
                );
            }
            if (_erc20.balanceOf(seller) < totalTokens) {
                emitAndFail(
                    " /*ERC115 TO ERC20 */ seller",
                    _erc20.balanceOf(seller),
                    totalTokens
                );
            }
        } else if (route == 4) /*ERC721 TO ERC20 */
        {
            if (_erc20.balanceOf(buyer) < totalTokens) {
                emitAndFail(
                    "/*ERC20 TO ERC721*/ FAILED",
                    _erc20.balanceOf(buyer),
                    totalTokens
                );
            }
            if (_erc721.balanceOf(seller) < totalItems) {
                emitAndFail(
                    "/*ERC20 TO ERC721*/ FAILED",
                    _erc721.balanceOf(seller),
                    totalItems
                );
            }
        } else if (route == 5) /*ERC115 TO ERC20 */
        {
            if (_erc1155.balanceOf(seller, uid) < totalTokens) {
                emitAndFail(
                    " /*ERC20 TO ERC1155*/ seller",
                    _erc1155.balanceOf(seller, uid),
                    totalTokens
                );
            }
            if (_erc20.balanceOf(buyer) < totalTokens) {
                emitAndFail(
                    " /*ERC20 TO ERC1155*/ buyer",
                    _erc20.balanceOf(buyer),
                    totalTokens
                );
            }
        }
    }

    function createOrderParameters(
        address payable seller,
        address payable buyer,
        bytes32 seed,
        uint256 route,
        bool isBasic
    )
        internal
        returns (
            OrderParameters memory orderParams,
            uint256 totalTokens,
            uint256 totalItems,
            uint256 uid
        )
    {
        uint256 amount = uint256(uint112(uint256(seed)));
        // Prevent MissingItemAmount revert
        require(amount != 0);
        // Unique id for ERC721 and ERC1155 ids
        uid = uint256(keccak256(abi.encode(seed)));

        // Note: currently unused.
        //uint256 sellForMax = one_to_max_uint64(amount);
        //uint256 sellForMin = one_to_max_uint64(amount / 2);

        // No. of offer/ consideration items
        // Bounded between 1 - 10 for advanced orders.
        // Set to 1 for basic orders.
        totalItems = isBasic ? 1 : (uint256(seed) % 10) + 1;
        OfferItem[] memory offer = new OfferItem[](totalItems);
        ConsiderationItem[] memory consideration = new ConsiderationItem[](
            totalItems
        );

        // The total number of tokens is used for fungible tokens:
        // ERC20, ERC1155, and Ether.
        // For each offer/ consideration item X amount is used.
        totalTokens = amount * totalItems;
        if (route == 0) /*ETH_TO_ERC721*/
        {
            // Sufficient ether for order
            require(msg.value >= totalTokens);
            for (uint256 i = 0; i < totalItems; i++) {
                offer[i] = createOfferItem(
                    ItemType.ERC721,
                    address(_erc721),
                    uid,
                    1,
                    1
                );
                require(_erc721.ownerOf(uid) == address(0));
                mintERC721(seller, uid);
                consideration[i] = createConsiderationItem(
                    ItemType.NATIVE,
                    address(0),
                    uint256(0),
                    amount,
                    amount,
                    seller
                );
                uid++;
            }
        } else if (route == 1) /*ETH_TO_ERC1155*/
        {
            // Sufficient ether for order
            require(msg.value >= totalTokens);
            mintERC1155(seller, uid, amount);
            for (uint256 i = 0; i < totalItems; i++) {
                offer[i] = createOfferItem(
                    ItemType.ERC1155,
                    address(_erc1155),
                    uid,
                    amount,
                    amount
                );
                consideration[i] = createConsiderationItem(
                    ItemType.NATIVE,
                    address(0),
                    uint256(0),
                    amount,
                    amount,
                    seller
                );
            }
        } else if (route == 2) /*ERC20_TO_ERC721*/
        {
            mintERC20(buyer, totalTokens);
            for (uint256 i = 0; i < totalItems; i++) {
                require(_erc721.ownerOf(uid) == address(0));
                mintERC721(seller, uid);
                offer[i] = createOfferItem(
                    ItemType.ERC721,
                    address(_erc721),
                    uid,
                    1,
                    1
                );
                consideration[i] = createConsiderationItem(
                    ItemType.ERC20,
                    address(_erc20),
                    0,
                    amount,
                    amount,
                    seller
                );
                uid++;
            }
        } else if (route == 3) /*ERC20_TO_ERC1155*/
        {
            mintERC20(buyer, totalTokens);
            mintERC1155(seller, uid, totalTokens);
            for (uint256 i = 0; i < totalItems; i++) {
                offer[i] = createOfferItem(
                    ItemType.ERC1155,
                    address(_erc1155),
                    uid,
                    amount,
                    amount
                );
                consideration[i] = createConsiderationItem(
                    ItemType.ERC20,
                    address(_erc20),
                    0,
                    amount,
                    amount,
                    seller
                );
            }
        } else if (route == 4) /*ERC721_TO_ERC20*/
        {
            mintERC20(seller, totalTokens);
            for (uint256 i = 0; i < totalItems; i++) {
                require(_erc721.ownerOf(uid) == address(0));
                mintERC721(buyer, uid);
                offer[i] = createOfferItem(
                    ItemType.ERC20,
                    address(_erc20),
                    uint256(0),
                    amount,
                    amount
                );
                consideration[i] = createConsiderationItem(
                    ItemType.ERC721,
                    address(_erc721),
                    uid,
                    1,
                    1,
                    seller
                );
                uid++;
            }
        } else if (route == 5) /*ERC1155_TO_ERC20*/
        {
            mintERC20(seller, totalTokens);
            mintERC1155(buyer, uid, totalTokens);
            for (uint256 i = 0; i < totalItems; i++) {
                offer[i] = createOfferItem(
                    ItemType.ERC20,
                    address(_erc20),
                    uint256(0),
                    amount,
                    amount
                );
                consideration[i] = createConsiderationItem(
                    ItemType.ERC1155,
                    address(_erc1155),
                    uid,
                    amount,
                    amount,
                    seller
                );
            }
        }
        orderParams = OrderParameters({
            offerer: seller,
            zone: address(0),
            offer: offer,
            consideration: consideration,
            orderType: OrderType(uint256(seed) % 2),
            startTime: uint256(block.timestamp),
            endTime: uint256(block.timestamp + (uint256(seed) % 365 days)),
            zoneHash: bytes32(0),
            salt: uint256(seed),
            conduitKey: bytes32(0),
            totalOriginalConsiderationItems: consideration.length
        });
    }
}
