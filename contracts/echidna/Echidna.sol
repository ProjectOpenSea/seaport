// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../Consideration.sol";
import "../conduit/Conduit.sol";
import "../conduit/ConduitController.sol";
import "./EchidnaUtils.sol";

//install echidna and crytic-compile
//rm -rf crytic-export artifacts &&  npx hardhat clean && npx hardhat compile && echidna . --contract Echidna --config ./contracts/echidna/echidna.conf.yaml
contract Echidna is ERC1155TokenReceiver, EchidnaUtils {
    address payable immutable _buyer = payable(address(this));
    address payable immutable _seller =
        payable(0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF); // used to sign with pk 2

    address _conduit;
    bytes32 _conduitKeyActive;
    bytes32 _conduitKeyCache;

    Consideration private _opensea;
    ConduitController private _conduitController;

    uint256 lastPartialOrderIndex;
    uint256 pendingPartialOrderIndex;
    mapping(uint256 => AdvancedOrder) pendingPartialOrders;
    mapping(uint256 => uint256) pendingPartialOrdersAmount;

    uint256 pendingCancelationIndex;
    uint256 lastCanceledIndex;
    mapping(uint256 => OrderComponents) pendingCancelation;

    constructor() EchidnaUtils() {
        _conduitController = new ConduitController();
        _opensea = new Consideration(address(_conduitController));
        _conduitKeyCache = bytes32(uint256(uint160(address(this))) << 96);
        _conduit = _conduitController.createConduit(
            _conduitKeyCache,
            address(this)
        );
        _conduitController.updateChannel(
            address(_conduit),
            address(_opensea),
            true
        );
        require(_conduit == deriveConduit(_conduitKeyCache));
    }

    receive() external payable {}

    function toggleConduit(bool toggle) external {
        if (toggle) {
            _conduitKeyActive = bytes32(0);
        } else {
            _conduitKeyActive = _conduitKeyCache;
        }
    }

    function testCancel() public {
        if (lastCanceledIndex < pendingCancelationIndex) {
            OrderComponents[] memory orderComponent = new OrderComponents[](1);
            orderComponent[0] = pendingCancelation[lastCanceledIndex++];
            bool res = _opensea.cancel(orderComponent);
            assert(res);
            bytes32 orderHash = _opensea.getOrderHash(orderComponent[0]);
            assert(orderHash != bytes32(0));
            // Canceled orders should not be valid
            (bool valid, bool canceled, uint256 filled, uint256 size) = _opensea
                .getOrderStatus(orderHash);
            assert(!valid);
            assert(canceled);
            assert(filled == size);
        }
    }

    function testPartialOrders() public {
        if (lastPartialOrderIndex < pendingPartialOrderIndex) {
            AdvancedOrder memory order = pendingPartialOrders[
                lastPartialOrderIndex
            ];
            uint256 remaining = pendingPartialOrdersAmount[
                lastPartialOrderIndex++
            ];
            order.numerator = 1;
            order.denominator = 1;
            CriteriaResolver[] memory resolvers = new CriteriaResolver[](0);
            bool res = _opensea.fulfillAdvancedOrder{
                value: address(this).balance
            }(order, resolvers, _conduitKeyActive);
            assert(res);
            uint256 nonce = _opensea.getNonce(_seller);
            OrderComponents
                memory orderComponent = convertOrderParametersToOrderComponents(
                    order.parameters,
                    nonce
                );
            bytes32 orderHash = _opensea.getOrderHash(orderComponent);
            assert(orderHash != bytes32(0));
            // Filled orders should be valid, not cancelled, and entirely filled.
            (bool valid, bool canceled, uint256 filled, uint256 size) = _opensea
                .getOrderStatus(orderHash);
            assert(valid);
            assert(!canceled);
            assert(filled != 0);
            assert(filled == size);
        }
    }

    function testFulfillAdvancedOrder(
        bytes32 seed,
        uint120 numerator,
        uint120 denominator
    ) public payable {
        // FULL_OPEN: 0, PARTIAL_OPEN: 1
        uint256 orderType = uint256(seed) % 2;

        // For partial orders we validate the fraction
        // to avoid BadFraction and InexactFraction reverts
        if (orderType == 1) {
            uint256 amount = uint256(uint112(uint256(seed)));
            require(numerator < denominator && numerator != 0);
            uint256 valueTimesNumerator = amount * numerator;
            bool exact;
            uint256 newValue;
            assembly {
                newValue := div(valueTimesNumerator, denominator)
                exact := iszero(mulmod(amount, numerator, denominator))
            }
            require(exact);
        }
        // Evenly distribute route between 0 and 5
        uint256 route = uint256(seed) % (6);
        (
            OrderParameters memory orderParams,
            uint256 totalTokens,
            uint256 totalItems,
            uint256 uniqueId
        ) = createOrderParameters(_seller, _buyer, seed, route, false);
        orderParams.conduitKey = _conduitKeyActive;

        // Sign order on behalf of seller
        uint256 nonce = _opensea.getNonce(_seller);
        bytes32 orderHash = _opensea.getOrderHash(
            convertOrderParametersToOrderComponents(orderParams, nonce)
        );
        (, bytes32 domainSeparator, ) = _opensea.information();
        bytes memory sig = signOrder(orderHash, domainSeparator);

        // Send entire balance for ether orders (should refund)
        uint256 offerItemType = uint256(orderParams.offer[0].itemType);
        uint256 value = offerItemType < 2 ? address(this).balance : 0;
        AdvancedOrder memory order;
        if (orderType == 0) /*FULL_OPEN*/
        {
            order = AdvancedOrder({
                parameters: orderParams,
                signature: sig,
                numerator: uint120(1),
                denominator: uint120(1),
                extraData: abi.encode(bytes32(0))
            });
        }
        /*PARTIAL_OPEN*/
        else {
            order = AdvancedOrder({
                parameters: orderParams,
                signature: sig,
                numerator: numerator,
                denominator: denominator,
                extraData: abi.encode(bytes32(0))
            });
            // Scale order to fill fractional amount
            uint256 remaining = totalTokens -
                ((totalTokens * numerator) / denominator);
            totalTokens -= remaining;
            pendingPartialOrders[pendingPartialOrderIndex] = order;
            pendingPartialOrdersAmount[pendingPartialOrderIndex++] = remaining;
        }
        // This has no effect without providing a merkle root
        CriteriaResolver[] memory resolvers = new CriteriaResolver[](0);
        try
            _opensea.fulfillAdvancedOrder{ value: value }(
                order,
                resolvers,
                _conduitKeyActive
            )
        returns (bool res) {
            assert(res);
        } catch Panic(uint256 reason) {
            emitAndFail("_opensea.fulfillAdvancedOrder FAILED", route, reason);
        }

        // Check that buyers and sellers received expected amounts
        _assertFundsReceived(
            _seller,
            _buyer,
            route,
            totalTokens,
            totalItems,
            uniqueId
        );
    }

    function testFulfillBasicOrder(bytes32 seed) public payable {
        uint256 route = uint256(seed) % 6;
        uint256 orderType = uint256(seed) % 2;
        BasicOrderType basicOrderType = BasicOrderType(orderType + (4 * route));
        (
            OrderParameters memory orderParams,
            uint256 totalTokens,
            uint256 totalItems,
            uint256 uniqueId
        ) = createOrderParameters(_seller, _buyer, seed, route, true);
        orderParams.conduitKey = _conduitKeyActive;

        // Sign order on behalf of seller
        uint256 nonce = _opensea.getNonce(_seller);
        bytes32 orderHash = _opensea.getOrderHash(
            convertOrderParametersToOrderComponents(orderParams, nonce)
        );
        (, bytes32 domainSeparator, ) = _opensea.information();
        bytes memory sig = signOrder(orderHash, domainSeparator);

        BasicOrderParameters
            memory basicOrder = convertOrderParametersToBasicOrder(
                orderParams,
                sig,
                basicOrderType
            );
        // Send entire balance for ether orders (should refund)
        uint256 value = uint256(basicOrderType) < 8 ? address(this).balance : 0;
        (bool success, ) = address(_opensea).call{ value: value }(
            abi.encodeWithSelector(
                Consideration.fulfillBasicOrder.selector,
                basicOrder
            )
        );
        if (!success) {
            emitAndFail("fulfillBasicOrder", orderParams.offer.length, route);
        }
        // totalItems will always be 1 for basic orders
        // and used for ERC721 balances only
        // otherwise InvalidERC721TransferAmount revert
        _assertFundsReceived(
            _seller,
            _buyer,
            route,
            totalTokens,
            totalItems,
            uniqueId
        );
    }

    function testValidate(bytes32 seed) public {
        Order[] memory orders = new Order[](1);
        uint256 route = uint256(seed) % 6;
        (OrderParameters memory param, , , ) = createOrderParameters(
            payable(address(this)),
            payable(address(this)),
            seed,
            route,
            false
        );
        // Don't sign these because to cancel them
        // the offerer must be msg.sender
        orders[0] = Order({
            parameters: param,
            signature: abi.encode(bytes32(0))
        });

        bool res = _opensea.validate(orders);
        assert(res);

        uint256 nonce = _opensea.getNonce(address(this));
        OrderComponents
            memory orderComponent = convertOrderParametersToOrderComponents(
                orders[0].parameters,
                nonce
            );
        bytes32 orderHash = _opensea.getOrderHash(orderComponent);
        assert(orderHash != bytes32(0));

        // Validated orders should be fillable and not canceled
        (bool valid, bool canceled, uint256 filled, uint256 size) = _opensea
            .getOrderStatus(orderHash);
        assert(valid);
        assert(!canceled);
        assert(filled == size);

        // Queue for cancelation test
        pendingCancelation[pendingCancelationIndex++] = orderComponent;
    }

    function testIncrementNonce() public {
        // Retrieve the old nonce
        uint256 oldNonce = _opensea.getNonce(address(this));
        // Try incrementing it
        (bool success, ) = address(_opensea).call(
            abi.encodeWithSelector(Consideration.incrementNonce.selector)
        );
        if (!success) {
            emitAndFail(
                "_opensea.incrementNonce() call failed",
                oldNonce,
                oldNonce
            );
        }
        // Retrieve the updated nonce
        uint256 newNonce = _opensea.getNonce(address(this));
        // oldNonce should never exceed or equal newNonce
        if (oldNonce > newNonce) {
            emitAndFail(
                "oldNonce > newNonce after incrementing",
                oldNonce,
                newNonce
            );
        } else if (oldNonce == newNonce) {
            emitAndFail("oldNonce is equal to newNonce", oldNonce, newNonce);
        }
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external override returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external override returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }

    function deriveConduit(bytes32 conduitKey)
        internal
        returns (address conduit)
    {
        bytes32 conduitCreationCodeHash = keccak256(type(Conduit).creationCode);
        address conduitController = address(_conduitController);
        assembly {
            let freeMemoryPointer := mload(0x40)
            mstore(
                0x00,
                or(
                    0x0000000000000000000000ff0000000000000000000000000000000000000000, // solhint-disable-line max-line-length
                    conduitController
                )
            )
            mstore(0x20, conduitKey)
            mstore(0x40, conduitCreationCodeHash)
            conduit := and(
                keccak256(0x0b, 0x55),
                0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff // solhint-disable-line max-line-length
            )
            mstore(0x40, freeMemoryPointer)
        }
    }
}
