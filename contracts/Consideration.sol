//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum OrderType {
    FULL_OPEN,         // no partial fills, anyone can execute
    PARTIAL_OPEN,      // partial fills supported, anyone can execute
    FULL_RESTRICTED,   // no partial fills, only offerer or facilitator can execute
    PARTIAL_RESTRICTED // partial fills supported, only offerer or facilitator can execute
}

enum AssetType {
    ETH,
    ERC20,
    ERC721,
    ERC1155,
    ERC721_WITH_CRITERIA,
    ERC1155_WITH_CRITERIA
}

enum Side {
    OFFER,
    CONSIDERATION
}

struct Asset {
    AssetType assetType;
    address token;
    uint256 identifierOrCriteria;
    uint256 amount;
}

struct ReceivedAsset {
    AssetType assetType;
    address token;
    uint256 identifierOrCriteria;
    uint256 amount;
    address payable account;
}

struct OrderParameters {
    OrderType orderType;
    Asset[] offer;
    ReceivedAsset[] consideration;
    uint256 startTime;
    uint256 endTime;
    address offerer;
    uint256 salt;
    address facilitator;
    uint256 nonce;
}

struct FulfillmentComponent {
    uint256 orderIndex;
    uint256 assetIndex;
}

struct Fulfillment {
    FulfillmentComponent[] offerComponents;
    FulfillmentComponent[] considerationComponents;
}

struct Execution {
    ReceivedAsset asset;
    address offerer;
}

struct Order {
    OrderParameters parameters;
    bytes signature;
}

struct CriteriaResolver {
    Side side;
    uint256 index;
    uint256 identifier;
    bytes32[] criteriaProof;
}

struct AdvancedAsset {
    AssetType assetType; // can be any valid enum
    address token;
    uint256 identifierOrCriteria; // criteria: merkle root of valid ids or null=>any
    uint256 startAmount;
    uint256 endAmount;
}

struct AdvancedReceivedAsset {
    AssetType assetType; // can be any valid enum
    address token;
    uint256 identifierOrCriteria; // criteria: merkle root of valid ids or null=>any
    uint256 startAmount;
    uint256 endAmount;
    address account;
}

struct AdvancedFulfillmentComponent {
    uint256 orderIndex;
    uint256 assetIndex;
    bytes32[] criteriaProof;
}

struct AdvancedFulfillment {
    uint256 identifier;
    AdvancedFulfillmentComponent[] offerComponents;
    AdvancedFulfillmentComponent[] considerationComponents;
}

struct AdvancedOrderParameters {
    AdvancedAsset[] offer;
    AdvancedReceivedAsset[] consideration;
    uint256 startTime;
    uint256 endTime;
    address offerer;
    uint256 salt;
    address facilitator;
    uint256 nonce;
}

struct AdvancedOrder {
    AdvancedOrderParameters parameters;
    bytes signature;
}


interface ERC20Interface {
    function transferFrom(address, address, uint256) external returns (bool);
}

interface ERC721Interface {
    function transferFrom(address, address, uint256) external;
}

interface ERC1155Interface {
    function safeTransferFrom(address, address, uint256, uint256) external;
}

contract Consideration {
    string public constant name = "Consideration";

    bytes32 public immutable DOMAIN_SEPARATOR;

    // keccak256("OrderParameters(Asset[] offer,ReceivedAsset[] consideration,uint256 startTime,uint256 endTime,address offerer,uint256 salt,address facilitator,uint256 nonce)Asset(uint8 assetType,address token,uint256 identifier,uint256 amount)ReceivedAsset(uint8 assetType,address token,uint256 identifier,uint256 amount,address account)")
    bytes32 internal constant ORDER_HASH = 0x900b0433e3177449dd2e6d48dfbbe46df9309e9adf1327887bf378dbc5f36b1d;

    // keccak256("AdvancedOrderParameters(AdvancedAsset[] offer,AdvancedReceivedAsset[] consideration,uint256 startTime,uint256 endTime,address offerer,uint256 salt,address facilitator,uint256 nonce)AdvancedAsset(uint8 assetType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)AdvancedReceivedAsset(uint8 assetType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address account)")
    bytes32 internal constant ADVANCED_ORDER_HASH = 0x418addaabd220f7e0798199c1dee87b4fd26b5ef7595dfbb8f3eef1ae9d5ff87;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private constant _FULLY_FILLED = 1e18;
    uint256 private constant _ENSURE_ROUND_UP = 999999999999999999;

    uint256 private _reentrancyGuard;

    mapping (bytes32 => uint256) public orderUsed; // 1e18 => 100%

    // offerer => facilitator => nonce (cancel offerer's orders with given facilitator)
    mapping (address => mapping (address => uint256)) public facilitatorNonces;

    error NoOffersWithCriteriaOnBasicMatch();
    error NoConsiderationWithCriteriaOnBasicMatch();
    error OrderUsed(bytes32);
    error InvalidTime();
    error InvalidSubmitterOnRestrictedOrder();

    error NoOfferOnFulfillment();
    error NoConsiderationOnFulfillment();
    error FulfilledOrderIndexOutOfRange();
    error FulfilledOrderOfferIndexOutOfRange();
    error FulfillmentOrderIndexOutOfRange();
    error FulfillmentOrderConsiderationIndexOutOfRange();

    error BadSignatureLength(uint256);
    error BadSignatureV(uint8);
    error MalleableSignatureS(uint256);
    error BadSignature();
    error InvalidSignature();
    error BadContractSignature();

    error MismatchedFulfillmentOfferComponents();
    error MismatchedFulfillmentConsiderationComponents();
    error ConsiderationNotMet(uint256 orderIndex, uint256 considerationIndex, uint256 shortfallAmount);

    error EtherTransferGenericFailure(address account, uint256 amount);
    error ERC20TransferGenericFailure(address token, address account, uint256 amount);
    error ERC721TransferGenericFailure(address token, address account, uint256 identifier);
    error ERC1155TransferGenericFailure(address token, address account, uint256 identifier, uint256 amount);
    error BadReturnValueFromERC20OnTransfer(address token, address account, uint256 amount);

    error ERC20TransferNoContract(address);
    error ERC721TransferNoContract(address);
    error ERC1155TransferNoContract(address);

    error Overfill();
    error PartialFillsNotEnabledForOrder();

    error UnresolvedOfferCriteria();
    error UnresolvedConsiderationCriteria();
    error OfferCriteriaResolverOutOfRange();
    error ConsiderationCriteriaResolverOutOfRange();
    error CriteriaNotEnabledForOfferedAsset();
    error CriteriaNotEnabledForConsideredAsset();
    error InvalidProof();

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f, // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
                0x64987f6373075400d7cbff689f2b7bc23753c7e6ce20688196489b8f5d9d7e6c, // keccak256("Consideration")
                0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6, // keccak256(bytes("1")) for versionId = 1
                block.chainid,
                address(this)
            )
        );

        _reentrancyGuard = _NOT_ENTERED;
    }

    function fulfillOrder(Order memory order) public payable nonReentrant() returns (bool) {
        _assertBasicOrderValidity(order.parameters);

        order.parameters.nonce = facilitatorNonces[order.parameters.offerer][order.parameters.facilitator];

        bytes32 orderHash = hash(order.parameters);
        uint256 orderFilledAmount = orderUsed[orderHash];
        if (orderFilledAmount != 0) {
            if (orderFilledAmount >= _FULLY_FILLED) {
                revert OrderUsed(orderHash);
            }

            uint256 leftToFill;
            unchecked {
                leftToFill = _FULLY_FILLED - orderFilledAmount;
            }

            for (uint256 i = 0; i < order.parameters.offer.length; i++) {
                // round offer amounts down (todo: div in assembly as we know it's not zero)
                order.parameters.offer[i].amount = (
                    order.parameters.offer[i].amount * leftToFill
                ) / _FULLY_FILLED;
            }

            for (uint256 i = 0; i < order.parameters.consideration.length; i++) {
                // round consideration amounts up (todo: div in assembly as we know it's not zero)
                order.parameters.consideration[i].amount = (
                    (order.parameters.consideration[i].amount * leftToFill) + _ENSURE_ROUND_UP
                ) / _FULLY_FILLED;
            }
        } else {
            _verifySignature(
                order.parameters.offerer, orderHash, order.signature
            );
        }

        orderUsed[orderHash] = _FULLY_FILLED;

        for (uint256 i = 0; i < order.parameters.consideration.length; i++) {
            if (uint256(order.parameters.consideration[i].assetType) > 3) {
                revert NoConsiderationWithCriteriaOnBasicMatch();
            }
            if (order.parameters.consideration[i].account != msg.sender) {
                _fulfill(order.parameters.consideration[i], msg.sender);
            }
        }

        for (uint256 i = 0; i < order.parameters.offer.length; i++) {
            if (uint256(order.parameters.offer[i].assetType) > 3) {
                revert NoOffersWithCriteriaOnBasicMatch();
            }
            _fulfill(
                ReceivedAsset(
                    order.parameters.offer[i].assetType,
                    order.parameters.offer[i].token,
                    order.parameters.offer[i].identifierOrCriteria,
                    order.parameters.offer[i].amount,
                    payable(msg.sender)
                ),
                order.parameters.offerer
            );
        }

        return true;
    }

    function fulfillOrderWithCriteria(
        Order memory order,
        CriteriaResolver[] memory criteriaResolvers
    ) public payable nonReentrant() returns (bool) {
        _assertBasicOrderValidity(order.parameters);

        order.parameters.nonce = facilitatorNonces[order.parameters.offerer][order.parameters.facilitator];

        bytes32 orderHash = hash(order.parameters);
        uint256 orderFilledAmount = orderUsed[orderHash];
        if (orderFilledAmount != 0) {
            if (orderFilledAmount >= _FULLY_FILLED) {
                revert OrderUsed(orderHash);
            }

            uint256 leftToFill;
            unchecked {
                leftToFill = _FULLY_FILLED - orderFilledAmount;
            }

            for (uint256 i = 0; i < order.parameters.offer.length; i++) {
                // round offer amounts down (todo: div in assembly as we know it's not zero)
                order.parameters.offer[i].amount = (
                    order.parameters.offer[i].amount * leftToFill
                ) / _FULLY_FILLED;
            }

            for (uint256 i = 0; i < order.parameters.consideration.length; i++) {
                // round consideration amounts up (todo: div in assembly as we know it's not zero)
                order.parameters.consideration[i].amount = (
                    (order.parameters.consideration[i].amount * leftToFill) + _ENSURE_ROUND_UP
                ) / _FULLY_FILLED;
            }
        } else {
            _verifySignature(
                order.parameters.offerer, orderHash, order.signature
            );
        }

        orderUsed[orderHash] = _FULLY_FILLED;

        for (uint256 i = 0; i < criteriaResolvers.length; i++) {
            CriteriaResolver memory criteriaResolver = criteriaResolvers[i];
            if (criteriaResolver.side == Side.OFFER) {
                if (criteriaResolver.index >= order.parameters.offer.length) {
                    revert OfferCriteriaResolverOutOfRange();
                }

                Asset memory offer = order.parameters.offer[criteriaResolver.index];
                if (
                    offer.assetType != AssetType.ERC721_WITH_CRITERIA &&
                    offer.assetType != AssetType.ERC1155_WITH_CRITERIA
                ) {
                    revert CriteriaNotEnabledForOfferedAsset();
                }

                // empty criteria signifies a collection-wide offer (sell any asset)
                if (offer.identifierOrCriteria != uint256(0)) {
                    _verifyProof(
                        criteriaResolver.identifier,
                        offer.identifierOrCriteria,
                        criteriaResolver.criteriaProof
                    );
                }

                if (offer.assetType == AssetType.ERC721_WITH_CRITERIA) {
                    order.parameters.offer[criteriaResolver.index].assetType = AssetType.ERC721;
                } else {
                    order.parameters.offer[criteriaResolver.index].assetType = AssetType.ERC1155;
                }

                order.parameters.offer[criteriaResolver.index].identifierOrCriteria = criteriaResolver.identifier;
            } else {
                if (criteriaResolver.index >= order.parameters.consideration.length) {
                    revert ConsiderationCriteriaResolverOutOfRange();
                }

                ReceivedAsset memory consideration = order.parameters.consideration[criteriaResolver.index];
                if (
                    consideration.assetType != AssetType.ERC721_WITH_CRITERIA &&
                    consideration.assetType != AssetType.ERC1155_WITH_CRITERIA
                ) {
                    revert CriteriaNotEnabledForConsideredAsset();
                }

                // empty criteria signifies a collection-wide consideration (buy any asset)
                if (consideration.identifierOrCriteria != uint256(0)) {
                    _verifyProof(
                        criteriaResolver.identifier,
                        consideration.identifierOrCriteria,
                        criteriaResolver.criteriaProof
                    );
                }

                if (consideration.assetType == AssetType.ERC721_WITH_CRITERIA) {
                    order.parameters.consideration[criteriaResolver.index].assetType = AssetType.ERC721;
                } else {
                    order.parameters.consideration[criteriaResolver.index].assetType = AssetType.ERC1155;
                }

                order.parameters.consideration[criteriaResolver.index].identifierOrCriteria = criteriaResolver.identifier;
            }
        }

        for (uint256 i = 0; i < order.parameters.consideration.length; i++) {
            if (uint256(order.parameters.consideration[i].assetType) > 3) {
                revert UnresolvedConsiderationCriteria();
            }
            if (order.parameters.consideration[i].account != msg.sender) {
                _fulfill(order.parameters.consideration[i], msg.sender);
            }
        }

        for (uint256 i = 0; i < order.parameters.offer.length; i++) {
            if (uint256(order.parameters.offer[i].assetType) > 3) {
                revert UnresolvedOfferCriteria();
            }
            _fulfill(
                ReceivedAsset(
                    order.parameters.offer[i].assetType,
                    order.parameters.offer[i].token,
                    order.parameters.offer[i].identifierOrCriteria,
                    order.parameters.offer[i].amount,
                    payable(msg.sender)
                ),
                order.parameters.offerer
            );
        }

        return true;
    }

    function fulfillPartialOrder(Order memory order, uint256 amountToFill) public payable nonReentrant() returns (bool) {
        if (
            order.parameters.orderType != OrderType.PARTIAL_OPEN &&
            order.parameters.orderType != OrderType.PARTIAL_RESTRICTED
        ) {
            revert PartialFillsNotEnabledForOrder();
        }

        if (amountToFill > _FULLY_FILLED) {
            revert Overfill();
        }

        _assertBasicOrderValidity(order.parameters);

        order.parameters.nonce = facilitatorNonces[order.parameters.offerer][order.parameters.facilitator];

        bytes32 orderHash = hash(order.parameters);
        uint256 orderFilledAmount = orderUsed[orderHash];
        if (orderFilledAmount != 0) {
            if (orderFilledAmount >= _FULLY_FILLED) {
                revert OrderUsed(orderHash);
            }

            if (orderFilledAmount + amountToFill > _FULLY_FILLED) {
                revert Overfill();
            }

            for (uint256 i = 0; i < order.parameters.offer.length; i++) {
                // round offer amounts down (todo: div in assembly as we know it's not zero)
                order.parameters.offer[i].amount = (
                    order.parameters.offer[i].amount * amountToFill
                ) / _FULLY_FILLED;
            }

            for (uint256 i = 0; i < order.parameters.consideration.length; i++) {
                // round consideration amounts up (todo: div in assembly as we know it's not zero)
                order.parameters.consideration[i].amount = (
                    (order.parameters.consideration[i].amount * amountToFill) + _ENSURE_ROUND_UP
                ) / _FULLY_FILLED;
            }
        } else {
            _verifySignature(
                order.parameters.offerer, orderHash, order.signature
            );
        }

        orderUsed[orderHash] = orderFilledAmount + amountToFill;

        for (uint256 i = 0; i < order.parameters.consideration.length; i++) {
            if (uint256(order.parameters.consideration[i].assetType) > 3) {
                revert NoConsiderationWithCriteriaOnBasicMatch();
            }
            if (order.parameters.consideration[i].account != msg.sender) {
                _fulfill(order.parameters.consideration[i], msg.sender);
            }
        }

        for (uint256 i = 0; i < order.parameters.offer.length; i++) {
            if (uint256(order.parameters.offer[i].assetType) > 3) {
                revert NoOffersWithCriteriaOnBasicMatch();
            }
            _fulfill(
                ReceivedAsset(
                    order.parameters.offer[i].assetType,
                    order.parameters.offer[i].token,
                    order.parameters.offer[i].identifierOrCriteria,
                    order.parameters.offer[i].amount,
                    payable(msg.sender)
                ),
                order.parameters.offerer
            );
        }

        return true;
    }

    function matchOrders(Order[] memory orders, Fulfillment[] memory fulfillments) public payable nonReentrant() returns (Execution[] memory) {
        // verify soundness of each order — either 712 signature/1271 or msg.sender
        for (uint256 i = 0; i < orders.length; i++) {
            OrderParameters memory order = orders[i].parameters;

            _assertBasicOrderValidity(order);

            order.nonce = facilitatorNonces[order.offerer][order.facilitator];

            for (uint256 j = 0; j < order.offer.length; j++) {
                Asset memory asset = order.offer[j];
                if (uint256(asset.assetType) > 3) {
                    revert NoOffersWithCriteriaOnBasicMatch();
                }
            }

            for (uint256 j = 0; j < order.consideration.length; j++) {
                ReceivedAsset memory asset = order.consideration[j];
                if (uint256(asset.assetType) > 3) {
                    revert NoConsiderationWithCriteriaOnBasicMatch();
                }
            }

            if (order.offerer != msg.sender && order.offer.length != 0) {
                bytes32 orderHash = hash(order);
                uint256 orderFilledAmount = orderUsed[orderHash];
                if (orderFilledAmount != 0) {
                    if (orderFilledAmount >= _FULLY_FILLED) {
                        revert OrderUsed(orderHash);
                    }

                    uint256 leftToFill;
                    unchecked {
                        leftToFill = _FULLY_FILLED - orderFilledAmount;
                    }

                    for (uint256 j = 0; j < order.offer.length; j++) {
                        // round offer amounts down (todo: div in assembly as we know it's not zero)
                        orders[i].parameters.offer[j].amount = (
                            order.offer[j].amount * leftToFill
                        ) / _FULLY_FILLED;
                    }

                    for (uint256 j = 0; j < order.consideration.length; j++) {
                        // round consideration amounts up (todo: div in assembly as we know it's not zero)
                        orders[i].parameters.consideration[j].amount = (
                            (order.consideration[j].amount * leftToFill) + _ENSURE_ROUND_UP
                        ) / _FULLY_FILLED;
                    }
                } else {
                    _verifySignature(order.offerer, orderHash, orders[i].signature);
                }

                orderUsed[orderHash] = _FULLY_FILLED;
            }
        }

        // allocate fulfillment and schedule execution
        Execution[] memory execution = new Execution[](fulfillments.length);
        for (uint256 i = 0; i < fulfillments.length; i++) {
            Fulfillment memory fulfillment = fulfillments[i];

            if (fulfillment.offerComponents.length == 0) {
                revert NoOfferOnFulfillment();
            }

            if (fulfillment.considerationComponents.length == 0) {
                revert NoConsiderationOnFulfillment();
            }

            if (fulfillment.offerComponents[0].orderIndex >= orders.length) {
                revert FulfilledOrderIndexOutOfRange();
            }

            if (fulfillment.offerComponents[0].assetIndex >= orders[fulfillment.offerComponents[0].orderIndex].parameters.offer.length) {
                revert FulfilledOrderOfferIndexOutOfRange();
            }

            address offerer = orders[fulfillment.offerComponents[0].orderIndex].parameters.offerer;
            Asset memory offeredAsset = orders[fulfillment.offerComponents[0].orderIndex].parameters.offer[fulfillment.offerComponents[0].assetIndex];
            orders[fulfillment.offerComponents[0].orderIndex].parameters.offer[fulfillment.offerComponents[0].assetIndex].amount = 0;

            for (uint256 j = 1; j < fulfillment.offerComponents.length; j++) {
                FulfillmentComponent memory offerComponent = fulfillment.offerComponents[j];

                if (offerComponent.orderIndex >= orders.length) {
                    revert FulfilledOrderIndexOutOfRange();
                }

                if (offerComponent.assetIndex >= orders[offerComponent.orderIndex].parameters.offer.length) {
                    revert FulfilledOrderOfferIndexOutOfRange();
                }

                address additionalOfferer = orders[fulfillment.offerComponents[j].orderIndex].parameters.offerer;

                Asset memory additionalOfferedAsset = orders[fulfillment.offerComponents[j].orderIndex].parameters.offer[fulfillment.offerComponents[j].assetIndex];

                if (
                    offerer != additionalOfferer ||
                    offeredAsset.assetType != additionalOfferedAsset.assetType ||
                    offeredAsset.token != additionalOfferedAsset.token ||
                    offeredAsset.identifierOrCriteria != additionalOfferedAsset.identifierOrCriteria
                ) {
                    revert MismatchedFulfillmentOfferComponents();
                }

                offeredAsset.amount += additionalOfferedAsset.amount;
                orders[fulfillment.offerComponents[j].orderIndex].parameters.offer[fulfillment.offerComponents[j].assetIndex].amount = 0;
            }

            if (fulfillment.considerationComponents[0].orderIndex >= orders.length) {
                revert FulfillmentOrderIndexOutOfRange();
            }

            if (fulfillment.considerationComponents[0].assetIndex >= orders[fulfillment.considerationComponents[0].orderIndex].parameters.consideration.length) {
                revert FulfillmentOrderConsiderationIndexOutOfRange();
            }

            ReceivedAsset memory requiredConsideration = orders[fulfillment.considerationComponents[0].orderIndex].parameters.consideration[fulfillment.considerationComponents[0].assetIndex];
            orders[fulfillment.considerationComponents[0].orderIndex].parameters.consideration[fulfillment.considerationComponents[0].assetIndex].amount = 0;

            for (uint256 j = 1; j < fulfillment.considerationComponents.length; j++) {
                FulfillmentComponent memory considerationComponent = fulfillment.considerationComponents[j];

                if (considerationComponent.orderIndex >= orders.length) {
                    revert FulfillmentOrderIndexOutOfRange();
                }

                if (considerationComponent.assetIndex >= orders[considerationComponent.orderIndex].parameters.consideration.length) {
                    revert FulfillmentOrderConsiderationIndexOutOfRange();
                }

                ReceivedAsset memory additionalRequiredConsideration = orders[fulfillment.considerationComponents[j].orderIndex].parameters.consideration[fulfillment.considerationComponents[j].assetIndex];

                if (
                    requiredConsideration.account != additionalRequiredConsideration.account ||
                    requiredConsideration.assetType != additionalRequiredConsideration.assetType ||
                    requiredConsideration.token != additionalRequiredConsideration.token ||
                    requiredConsideration.identifierOrCriteria != additionalRequiredConsideration.identifierOrCriteria
                ) {
                    revert MismatchedFulfillmentConsiderationComponents();
                }

                requiredConsideration.amount += additionalRequiredConsideration.amount;
                orders[fulfillment.considerationComponents[j].orderIndex].parameters.consideration[fulfillment.considerationComponents[j].assetIndex].amount = 0;
            }

            if (requiredConsideration.amount > offeredAsset.amount) {
                orders[fulfillment.considerationComponents[fulfillment.considerationComponents.length - 1].orderIndex].parameters.consideration[fulfillment.considerationComponents[fulfillment.considerationComponents.length - 1].assetIndex].amount = requiredConsideration.amount - offeredAsset.amount;
                requiredConsideration.amount = offeredAsset.amount;
            } else {
                orders[fulfillment.offerComponents[fulfillment.offerComponents.length - 1].orderIndex].parameters.offer[fulfillment.offerComponents[fulfillment.offerComponents.length - 1].assetIndex].amount = offeredAsset.amount - requiredConsideration.amount;
            }

            execution[i] = Execution(requiredConsideration, offerer);
        }

        // ensure that all considerations have been met
        for (uint256 i = 0; i < orders.length; i++) {
            ReceivedAsset[] memory considerations = orders[i].parameters.consideration;
            for (uint256 j = 0; j < considerations.length; j++) {
                if (considerations[j].amount != 0) {
                    revert ConsiderationNotMet(i, j, considerations[j].amount);
                }
            }
        }

        // execute fulfillments
        for (uint256 i = 0; i < execution.length; i++) {
            _fulfill(execution[i].asset, execution[i].offerer);
        }

        return execution;
    }

    function matchAdvancedOrders(AdvancedOrder[] memory orders, AdvancedFulfillment[] memory fulfillments) public payable nonReentrant() returns (Execution[] memory) {
        // ...
    }

    function cancel(Order[] memory orders) external returns (bool ok) {
        // ...
    }

    function hash(OrderParameters memory orderParameters) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ORDER_HASH,
                orderParameters.orderType,
                keccak256(abi.encode(orderParameters.offer)),
                keccak256(abi.encode(orderParameters.consideration)),
                orderParameters.startTime,
                orderParameters.endTime,
                orderParameters.nonce,
                orderParameters.offerer,
                orderParameters.salt,
                orderParameters.facilitator,
                orderParameters.nonce
            )
        );
    }

    function _assertBasicOrderValidity(OrderParameters memory order) internal view {
        if (order.startTime > block.timestamp || order.endTime < block.timestamp) {
            revert InvalidTime();
        }

        if (
            uint256(order.orderType) > 1 &&
            msg.sender != order.facilitator &&
            msg.sender != order.offerer
        ) {
            revert InvalidSubmitterOnRestrictedOrder();
        }
    }

    function _fulfill(ReceivedAsset memory asset, address offerer) internal {
        bool ok;
        bytes memory data;
        if (asset.assetType == AssetType.ETH) {
            (ok, data) = asset.account.call{value: asset.amount}("");
            if (!ok) {
                if (data.length != 0) {
                    assembly {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                } else {
                    revert EtherTransferGenericFailure(asset.account, asset.amount);
                }
            }
        } else if (asset.assetType == AssetType.ERC20) {
            // Bubble up reverts on failed primary recipient transfers.
            (ok, data) = asset.token.call(
                abi.encodeWithSelector(
                    ERC20Interface.transferFrom.selector,
                    offerer,
                    asset.account,
                    asset.amount
                )
            );
            if (!ok) {
                if (data.length != 0) {
                    assembly {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                } else {
                    revert ERC20TransferGenericFailure(asset.token, asset.account, asset.amount);
                }
            }

            if (data.length == 0) {
                address token = asset.token;
                uint256 size;
                assembly {
                    size := extcodesize(token)
                }
                if (size == 0) {
                    revert ERC20TransferNoContract(token);
                }
            } else {
                if (!(
                    data.length == 32 &&
                    abi.decode(data, (bool))
                )) {
                    revert BadReturnValueFromERC20OnTransfer(asset.token, asset.account, asset.amount);
                }
            }
        } else if (asset.assetType == AssetType.ERC721) {
            // Bubble up reverts on failed primary recipient transfers.
            (ok, data) = asset.token.call(
                abi.encodeWithSelector(
                    ERC721Interface.transferFrom.selector,
                    offerer,
                    asset.account,
                    asset.identifierOrCriteria
                )
            );
            if (!ok) {
                if (data.length != 0) {
                    assembly {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                } else {
                    revert ERC721TransferGenericFailure(asset.token, asset.account, asset.identifierOrCriteria);
                }
            } else if (data.length == 0) {
                address token = asset.token;
                uint256 size;
                assembly {
                    size := extcodesize(token)
                }
                if (size == 0) {
                    revert ERC721TransferNoContract(token);
                }
            }
        } else if (asset.assetType == AssetType.ERC1155) {
            // Bubble up reverts on failed primary recipient transfers.
            (ok, data) = asset.token.call(
                abi.encodeWithSelector(
                    ERC1155Interface.safeTransferFrom.selector,
                    offerer,
                    asset.account,
                    asset.identifierOrCriteria,
                    asset.amount
                )
            );
            if (!ok) {
                if (data.length != 0) {
                    assembly {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                } else {
                    revert ERC1155TransferGenericFailure(
                        asset.token,
                        asset.account,
                        asset.identifierOrCriteria,
                        asset.amount
                    );
                }
            } else if (data.length == 0) {
                address token = asset.token;
                uint256 size;
                assembly {
                    size := extcodesize(token)
                }
                if (size == 0) {
                    revert ERC1155TransferNoContract(token);
                }
            }
        }
    }

    function _verifySignature(
        address account,
        bytes32 orderHash,
        bytes memory signature
    ) internal view {
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, orderHash)
        );

        bytes32 r;
        bytes32 s;
        uint8 v;

        if (signature.length == 65) {
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
        } else if (signature.length == 64) {
            bytes32 vs;
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
                s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                v := add(shr(255, vs), 27)
            }
        } else {
            revert BadSignatureLength(signature.length);
        }

        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            revert MalleableSignatureS(uint256(s));
        }
        if (v != 27 && v != 28) {
            revert BadSignatureV(v);
        }

        address signer = ecrecover(digest, v, r, s);

        if (signer == address(0)) {
            revert InvalidSignature();
        } else if (signer != account) {
            (bool success, bytes memory result) = signer.staticcall(
                abi.encodeWithSelector(0x1626ba7e, digest, signature)
            );
            if (!success) {
                if (result.length != 0) {
                    assembly {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                } else {
                    revert BadContractSignature();
                }
            }

            if (
                result.length != 32 ||
                abi.decode(result, (bytes4)) != 0x1626ba7e
            ) {
                revert BadSignature();
            }
        }
    }

    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        if (_reentrancyGuard == _ENTERED) {
            revert("No reentrant calls");
        }

        _reentrancyGuard = _ENTERED;

        _;

        _reentrancyGuard = _NOT_ENTERED;
    }

    function _verifyProof(uint256 leaf, uint256 root, bytes32[] memory proof) internal pure {
        bytes32 computedHash = bytes32(leaf);
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = _efficientHash(computedHash, proofElement);
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = _efficientHash(proofElement, computedHash);
            }
        }
        if (computedHash != bytes32(root)) {
            revert InvalidProof();
        }
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}
