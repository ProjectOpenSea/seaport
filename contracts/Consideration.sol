// SPDX-License-Identifier: MIT
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

struct OfferedAsset {
    AssetType assetType;
    address token;
    uint256 identifierOrCriteria;
    uint256 startAmount;
    uint256 endAmount;
}

struct ReceivedAsset {
    AssetType assetType;
    address token;
    uint256 identifierOrCriteria;
    uint256 startAmount;
    uint256 endAmount;
    address payable account;
}

struct OrderParameters {
    address offerer;
    address facilitator;
    OrderType orderType;
    uint256 startTime;
    uint256 endTime;
    uint256 salt;
    OfferedAsset[] offer;
    ReceivedAsset[] consideration;
}

struct OrderComponents {
    address offerer;
    address facilitator;
    OrderType orderType;
    uint256 startTime;
    uint256 endTime;
    uint256 salt;
    OfferedAsset[] offer;
    ReceivedAsset[] consideration;
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

struct OrderStatus {
    bool isValidated;
    bool isCancelled;
    uint120 numerator;
    uint120 denominator;
}

struct CriteriaResolver {
    uint256 orderIndex;
    Side side;
    uint256 index;
    uint256 identifier;
    bytes32[] criteriaProof;
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

interface ConsiderationInterface {
    function fulfillOrder(Order memory order) external payable returns (bool);
    function fulfillOrderWithCriteria(
        Order memory order,
        CriteriaResolver[] memory criteriaResolvers
    ) external payable returns (bool);
    function fulfillPartialOrder(
        Order memory order,
        uint120 numerator,
        uint120 denominator
    ) external payable returns (bool);
    function matchOrders(
        Order[] memory orders,
        CriteriaResolver[] memory criteriaResolvers,
        Fulfillment[] memory fulfillments
    ) external payable returns (Execution[] memory);
    function cancel(
        OrderComponents[] memory orders
    ) external returns (bool ok);
    function validate(
        Order[] memory orders
    ) external returns (bool ok);
    function incrementFacilitatorNonce(
        address offerer,
        address facilitator
    ) external returns (uint256 nonce);

    function getOrderHash(
        OrderComponents memory order
    ) external view returns (bytes32);
    function name() external view returns (string memory);
    function version() external view returns (string memory);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function getOrderStatus(bytes32 orderHash) external view returns (OrderStatus memory);
    function facilitatorNonce(address offerer, address facilitator) external view returns (uint256);

    // TODO: decide what data is required here
    event OrderFulfilled(bytes32 orderHash, address indexed offerer, address facilitator);
    event OrderCancelled(bytes32 orderHash, address indexed offerer, address facilitator);
    event OrderValidated(bytes32 orderHash, address indexed offerer, address facilitator);
    event FacilitatorNonceIncremented(address indexed offerer, address facilitator, uint256 nonce);

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

    error PartialFillsNotEnabledForOrder();
    error OrderIsCancelled(bytes32);
    error OrderAlreadyValidated(bytes32);

    error OrderCriteriaResolverOutOfRange();
    error UnresolvedOfferCriteria();
    error UnresolvedConsiderationCriteria();
    error OfferCriteriaResolverOutOfRange();
    error ConsiderationCriteriaResolverOutOfRange();
    error CriteriaNotEnabledForOfferedAsset();
    error CriteriaNotEnabledForConsideredAsset();
    error InvalidProof();

    error OnlyOffererOrFacilitatorMayCancel();
    error OnlyOffererOrFacilitatorMayIncrementNonce();

    error BadFraction();
    error InexactFraction();
}

contract Consideration is ConsiderationInterface {
    string private constant _NAME = "Consideration";
    string private constant _VERSION = "1";

    // keccak256("OrderComponents(address offerer,address facilitator,uint8 offerType,uint256 startTime,uint256 endTime,uint256 salt,OfferedAsset[] offer,ReceivedAsset[] consideration,uint256 nonce)OfferedAsset(uint8 assetType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)ReceivedAsset(uint8 assetType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address account)")
    bytes32 private constant _ORDER_HASH = 0xe8e81a11c409c7f5760c344f9d9107e90ebc343953faba9ed8c073e24e357740;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private constant _FULLY_FILLED = 1e18;
    uint256 private constant _ENSURE_ROUND_UP = 999999999999999999;

    bytes32 private immutable _DOMAIN_SEPARATOR;
    uint256 private immutable _CHAIN_ID;

    uint256 private _reentrancyGuard;

    mapping (bytes32 => OrderStatus) private _orderStatus;

    // offerer => facilitator => nonce (cancel offerer's orders with given facilitator)
    mapping (address => mapping (address => uint256)) private _facilitatorNonces;

    constructor() {
        _DOMAIN_SEPARATOR = _deriveDomainSeparator();
        _CHAIN_ID = block.chainid;

        _reentrancyGuard = _NOT_ENTERED;
    }

    function fulfillOrder(
        Order memory order
    ) external payable override nonReentrant() returns (bool) {
        _assertBasicOrderValidity(order.parameters);

        (
            bytes32 orderHash,
            uint120 numerator,
            uint120 denominator
        ) = _validateOrderAndUpdateStatus(order, 1, 1);

        _adjustPricesForSingleOrder(order);

        for (uint256 i = 0; i < order.parameters.consideration.length; i++) {
            if (uint256(order.parameters.consideration[i].assetType) > 3) {
                revert NoConsiderationWithCriteriaOnBasicMatch();
            }
            if (order.parameters.consideration[i].account != msg.sender) {
                order.parameters.consideration[i].endAmount = _getFraction(
                    numerator,
                    denominator,
                    order.parameters.consideration[i].endAmount
                );

                _fulfill(
                    order.parameters.consideration[i],
                    msg.sender
                );
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
                    0,
                    _getFraction(
                        numerator,
                        denominator,
                        order.parameters.offer[i].endAmount
                    ),
                    payable(msg.sender)
                ),
                order.parameters.offerer
            );
        }

        emit OrderFulfilled(orderHash, order.parameters.offerer, order.parameters.facilitator);
        return true;
    }

    function fulfillOrderWithCriteria(
        Order memory order,
        CriteriaResolver[] memory criteriaResolvers
    ) external payable override nonReentrant() returns (bool) {
        _assertBasicOrderValidity(order.parameters);

        (bytes32 orderHash, uint120 numerator, uint120 denominator) = _validateOrderAndUpdateStatus(order, 1, 1);

        _adjustPricesForSingleOrder(order);

        for (uint256 i = 0; i < criteriaResolvers.length; i++) {
            CriteriaResolver memory criteriaResolver = criteriaResolvers[i];

            if (criteriaResolver.orderIndex >= 1) {
                revert OrderCriteriaResolverOutOfRange();
            }

            if (criteriaResolver.side == Side.OFFER) {
                if (criteriaResolver.index >= order.parameters.offer.length) {
                    revert OfferCriteriaResolverOutOfRange();
                }

                OfferedAsset memory offer = order.parameters.offer[criteriaResolver.index];
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
                order.parameters.consideration[i].endAmount = _getFraction(
                    numerator,
                    denominator,
                    order.parameters.consideration[i].endAmount
                );

                _fulfill(
                    order.parameters.consideration[i],
                    msg.sender
                );
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
                    0,
                    _getFraction(
                        numerator,
                        denominator,
                        order.parameters.offer[i].endAmount
                    ),
                    payable(msg.sender)
                ),
                order.parameters.offerer
            );
        }

        emit OrderFulfilled(orderHash, order.parameters.offerer, order.parameters.facilitator);
        return true;
    }

    function fulfillPartialOrder(
        Order memory order,
        uint120 numerator,
        uint120 denominator
    ) external payable override nonReentrant() returns (bool) {
        if (
            order.parameters.orderType != OrderType.PARTIAL_OPEN &&
            order.parameters.orderType != OrderType.PARTIAL_RESTRICTED
        ) {
            revert PartialFillsNotEnabledForOrder();
        }

        _assertBasicOrderValidity(order.parameters);

        (
            bytes32 orderHash,
            uint120 fillNumerator,
            uint120 fillDenominator
        ) = _validateOrderAndUpdateStatus(order, numerator, denominator);

        _adjustPricesForSingleOrder(order);

        for (uint256 i = 0; i < order.parameters.consideration.length; i++) {
            if (uint256(order.parameters.consideration[i].assetType) > 3) {
                revert NoConsiderationWithCriteriaOnBasicMatch();
            }
            if (order.parameters.consideration[i].account != msg.sender) {
                order.parameters.consideration[i].endAmount = _getFraction(
                    fillNumerator,
                    fillDenominator,
                    order.parameters.consideration[i].endAmount
                );
                _fulfill(
                    order.parameters.consideration[i],
                    msg.sender
                );
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
                    0,
                    _getFraction(
                        fillNumerator,
                        fillDenominator,
                        order.parameters.offer[i].endAmount
                    ),
                    payable(msg.sender)
                ),
                order.parameters.offerer
            );
        }

        emit OrderFulfilled(orderHash, order.parameters.offerer, order.parameters.facilitator);
        return true;
    }

    function matchOrders(
        Order[] memory orders,
        CriteriaResolver[] memory criteriaResolvers,
        Fulfillment[] memory fulfillments
    ) external payable override nonReentrant() returns (Execution[] memory) {
        // verify soundness of each order — either 712 signature/1271 or msg.sender
        for (uint256 i = 0; i < orders.length; i++) {
            Order memory order = orders[i];

            _assertBasicOrderValidity(order.parameters);

            (bytes32 orderHash, uint120 numerator, uint120 denominator) = _validateOrderAndUpdateStatus(order, 1, 1);

            for (uint256 j = 0; j < order.parameters.offer.length; j++) {
                orders[i].parameters.offer[j].endAmount = _getFraction(
                    numerator,
                    denominator,
                    orders[i].parameters.offer[j].endAmount
                );
            }

            for (uint256 j = 0; j < order.parameters.consideration.length; j++) {
                orders[i].parameters.consideration[j].endAmount = _getFraction(
                    numerator,
                    denominator,
                    orders[i].parameters.consideration[j].endAmount
                );
            }

            emit OrderFulfilled(orderHash, orders[i].parameters.offerer, orders[i].parameters.facilitator);
        }

        _adjustPrices(orders);

        _applyCriteriaResolvers(orders, criteriaResolvers);

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
            OfferedAsset memory offeredAsset = orders[fulfillment.offerComponents[0].orderIndex].parameters.offer[fulfillment.offerComponents[0].assetIndex];
            orders[fulfillment.offerComponents[0].orderIndex].parameters.offer[fulfillment.offerComponents[0].assetIndex].endAmount = 0;

            for (uint256 j = 1; j < fulfillment.offerComponents.length; j++) {
                FulfillmentComponent memory offerComponent = fulfillment.offerComponents[j];

                if (offerComponent.orderIndex >= orders.length) {
                    revert FulfilledOrderIndexOutOfRange();
                }

                if (offerComponent.assetIndex >= orders[offerComponent.orderIndex].parameters.offer.length) {
                    revert FulfilledOrderOfferIndexOutOfRange();
                }

                address additionalOfferer = orders[fulfillment.offerComponents[j].orderIndex].parameters.offerer;

                OfferedAsset memory additionalOfferedAsset = orders[fulfillment.offerComponents[j].orderIndex].parameters.offer[fulfillment.offerComponents[j].assetIndex];

                if (
                    offerer != additionalOfferer ||
                    offeredAsset.assetType != additionalOfferedAsset.assetType ||
                    offeredAsset.token != additionalOfferedAsset.token ||
                    offeredAsset.identifierOrCriteria != additionalOfferedAsset.identifierOrCriteria
                ) {
                    revert MismatchedFulfillmentOfferComponents();
                }

                offeredAsset.endAmount += additionalOfferedAsset.endAmount;
                orders[fulfillment.offerComponents[j].orderIndex].parameters.offer[fulfillment.offerComponents[j].assetIndex].endAmount = 0;
            }

            if (fulfillment.considerationComponents[0].orderIndex >= orders.length) {
                revert FulfillmentOrderIndexOutOfRange();
            }

            if (fulfillment.considerationComponents[0].assetIndex >= orders[fulfillment.considerationComponents[0].orderIndex].parameters.consideration.length) {
                revert FulfillmentOrderConsiderationIndexOutOfRange();
            }

            ReceivedAsset memory requiredConsideration = orders[fulfillment.considerationComponents[0].orderIndex].parameters.consideration[fulfillment.considerationComponents[0].assetIndex];
            orders[fulfillment.considerationComponents[0].orderIndex].parameters.consideration[fulfillment.considerationComponents[0].assetIndex].endAmount = 0;

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

                requiredConsideration.endAmount += additionalRequiredConsideration.endAmount;
                orders[fulfillment.considerationComponents[j].orderIndex].parameters.consideration[fulfillment.considerationComponents[j].assetIndex].endAmount = 0;
            }

            if (requiredConsideration.endAmount > offeredAsset.endAmount) {
                orders[fulfillment.considerationComponents[fulfillment.considerationComponents.length - 1].orderIndex].parameters.consideration[fulfillment.considerationComponents[fulfillment.considerationComponents.length - 1].assetIndex].endAmount = requiredConsideration.endAmount - offeredAsset.endAmount;
                requiredConsideration.endAmount = offeredAsset.endAmount;
            } else {
                orders[fulfillment.offerComponents[fulfillment.offerComponents.length - 1].orderIndex].parameters.offer[fulfillment.offerComponents[fulfillment.offerComponents.length - 1].assetIndex].endAmount = offeredAsset.endAmount - requiredConsideration.endAmount;
            }

            execution[i] = Execution(requiredConsideration, offerer);
        }

        // ensure that all considerations have been met
        for (uint256 i = 0; i < orders.length; i++) {
            ReceivedAsset[] memory considerations = orders[i].parameters.consideration;
            for (uint256 j = 0; j < considerations.length; j++) {
                if (considerations[j].endAmount != 0) {
                    revert ConsiderationNotMet(i, j, considerations[j].endAmount);
                }
            }
        }

        // execute fulfillments
        for (uint256 i = 0; i < execution.length; i++) {
            _fulfill(execution[i].asset, execution[i].offerer);
        }

        return execution;
    }

    function cancel(
        OrderComponents[] memory orders
    ) external override returns (bool ok) {
        for (uint256 i = 0; i < orders.length; i++) {
            OrderComponents memory order = orders[i];
            if (msg.sender != order.offerer && msg.sender != order.facilitator) {
                revert OnlyOffererOrFacilitatorMayCancel();
            }

            bytes32 orderHash = _getOrderHash(
                OrderParameters(
                    order.offerer,
                    order.facilitator,
                    order.orderType,
                    order.startTime,
                    order.endTime,
                    order.salt,
                    order.offer,
                    order.consideration
                ),
                order.nonce
            );

            _orderStatus[orderHash].isCancelled = true;

            emit OrderCancelled(orderHash, order.offerer, order.facilitator);
        }

        return true;
    }

    function validate(
        Order[] memory orders
    ) external override returns (bool ok) {
        for (uint256 i = 0; i < orders.length; i++) {
            Order memory order = orders[i];

            bytes32 orderHash = _getOrderHash(
                order.parameters,
                _facilitatorNonces[order.parameters.offerer][order.parameters.facilitator]
            );

            OrderStatus memory orderStatus = _orderStatus[orderHash];

            if (orderStatus.isCancelled) {
                revert OrderIsCancelled(orderHash);
            }

            if (
                orderStatus.numerator != 0 &&
                orderStatus.numerator >= orderStatus.denominator
            ) {
                revert OrderUsed(orderHash);
            }

            if (orderStatus.isValidated) {
                revert OrderAlreadyValidated(orderHash);
            }

            _verifySignature(
                order.parameters.offerer, orderHash, order.signature
            );

            _orderStatus[orderHash].isValidated = true;

            emit OrderValidated(
                orderHash,
                order.parameters.offerer,
                order.parameters.facilitator
            );
        }

        return true;
    }

    function incrementFacilitatorNonce(
        address offerer,
        address facilitator
    ) external override returns (uint256 nonce) {
        if (msg.sender != offerer && msg.sender != facilitator) {
            revert OnlyOffererOrFacilitatorMayIncrementNonce();
        }

        nonce = _facilitatorNonces[offerer][facilitator]++;

        emit FacilitatorNonceIncremented(offerer, facilitator, nonce);

        return nonce;
    }

    function getOrderStatus(
        bytes32 orderHash
    ) external view override returns (OrderStatus memory) {
        return _orderStatus[orderHash];
    }

    function facilitatorNonce(
        address offerer,
        address facilitator
    ) external view override returns (uint256) {
        return _facilitatorNonces[offerer][facilitator];
    }

    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparator();
    }

    function getOrderHash(
        OrderComponents memory order
    ) external pure override returns (bytes32) {
        return _getOrderHash(
            OrderParameters(
                order.offerer,
                order.facilitator,
                order.orderType,
                order.startTime,
                order.endTime,
                order.salt,
                order.offer,
                order.consideration
            ),
            order.nonce
        );
    }

    function name() external pure override returns (string memory) {
        return _NAME;
    }

    function version() external pure override returns (string memory) {
        return _VERSION;
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

    function _validateOrderAndUpdateStatus(
        Order memory order,
        uint120 numerator,
        uint120 denominator
    ) internal returns (
        bytes32 orderHash,
        uint120 newNumerator,
        uint120 newDenominator
    ) {
        if (numerator > denominator || numerator == 0 || denominator == 0) {
            revert BadFraction();
        }

        orderHash = _getOrderHash(
            order.parameters,
            _facilitatorNonces[order.parameters.offerer][order.parameters.facilitator]
        );

        OrderStatus memory orderStatus = _orderStatus[orderHash];

        if (orderStatus.isCancelled) {
            revert OrderIsCancelled(orderHash);
        }

        if (orderStatus.numerator != 0) {
            if (orderStatus.numerator >= orderStatus.denominator) {
                revert OrderUsed(orderHash);
            }
        } else if (!orderStatus.isValidated) {
            _verifySignature(
                order.parameters.offerer, orderHash, order.signature
            );
        }

        // denominator of zero: this is the first fill on this order
        if (orderStatus.denominator != 0) {
            if (denominator == 1) { // full fill — just scale up to current denominator
                numerator = orderStatus.denominator;
                denominator = orderStatus.denominator;
            } else if (orderStatus.denominator != denominator) { // different denominator
                orderStatus.numerator *= denominator;
                numerator *= orderStatus.denominator;
                denominator *= orderStatus.denominator;
            }

            if (orderStatus.numerator + numerator > denominator) {
                unchecked {
                    numerator = denominator - orderStatus.numerator; // adjust down
                }
            }

            unchecked {
                _orderStatus[orderHash] = OrderStatus(
                    true,       // is validated
                    false,      // not cancelled
                    orderStatus.numerator + numerator,
                    denominator
                );
            }
        } else {
            _orderStatus[orderHash] = OrderStatus(
                true,       // is validated
                false,      // not cancelled
                numerator,
                denominator
            );
        }

        return (orderHash, numerator, denominator);
    }

    function _adjustPrices(
        Order[] memory orders
    ) internal view {
        for (uint256 i = 0; i < orders.length; i++) {
            uint256 duration = orders[i].parameters.endTime - orders[i].parameters.startTime;
            uint256 elapsed = block.timestamp - orders[i].parameters.startTime;
            uint256 remaining = duration - elapsed;

            // adjust offer prices and round down
            for (uint256 j = 0; j < orders[i].parameters.offer.length; j++) {
                if (orders[i].parameters.offer[j].startAmount != orders[i].parameters.offer[j].endAmount) {
                    orders[i].parameters.offer[j].endAmount = (
                        (orders[i].parameters.offer[j].startAmount * remaining) + (orders[i].parameters.offer[j].endAmount * elapsed)
                    ) / duration;
                }
            }

            // adjust consideration prices and round up
            for (uint256 j = 0; j < orders[i].parameters.consideration.length; j++) {
                if (orders[i].parameters.consideration[j].startAmount != orders[i].parameters.consideration[j].endAmount) {
                    orders[i].parameters.consideration[j].endAmount = (
                        (orders[i].parameters.consideration[j].startAmount * remaining) + (orders[i].parameters.consideration[j].endAmount * elapsed) + (duration - 1)
                    ) / duration;
                }
            }
        }
    }

    function _adjustPricesForSingleOrder(
        Order memory order
    ) internal view {
        uint256 duration = order.parameters.endTime - order.parameters.startTime;
        uint256 elapsed = block.timestamp - order.parameters.startTime;
        uint256 remaining = duration - elapsed;

        // adjust offer prices and round down
        for (uint256 j = 0; j < order.parameters.offer.length; j++) {
            if (order.parameters.offer[j].startAmount != order.parameters.offer[j].endAmount) {
                order.parameters.offer[j].endAmount = (
                    (order.parameters.offer[j].startAmount * remaining) + (order.parameters.offer[j].endAmount * elapsed)
                ) / duration;
            }
        }

        // adjust consideration prices and round up
        for (uint256 j = 0; j < order.parameters.consideration.length; j++) {
            if (order.parameters.consideration[j].startAmount != order.parameters.consideration[j].endAmount) {
                order.parameters.consideration[j].endAmount = (
                    (order.parameters.consideration[j].startAmount * remaining) + (order.parameters.consideration[j].endAmount * elapsed) + (duration - 1)
                ) / duration;
            }
        }
    }

    function _applyCriteriaResolvers(
        Order[] memory orders,
        CriteriaResolver[] memory criteriaResolvers
    ) internal pure {
        for (uint256 i = 0; i < criteriaResolvers.length; i++) {
            CriteriaResolver memory criteriaResolver = criteriaResolvers[i];

            if (criteriaResolver.orderIndex >= orders.length) {
                revert OrderCriteriaResolverOutOfRange();
            }

            if (criteriaResolver.side == Side.OFFER) {
                if (criteriaResolver.index >= orders[criteriaResolver.orderIndex].parameters.offer.length) {
                    revert OfferCriteriaResolverOutOfRange();
                }

                OfferedAsset memory offer = orders[criteriaResolver.orderIndex].parameters.offer[criteriaResolver.index];
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
                    orders[criteriaResolver.orderIndex].parameters.offer[criteriaResolver.index].assetType = AssetType.ERC721;
                } else {
                    orders[criteriaResolver.orderIndex].parameters.offer[criteriaResolver.index].assetType = AssetType.ERC1155;
                }

                orders[criteriaResolver.orderIndex].parameters.offer[criteriaResolver.index].identifierOrCriteria = criteriaResolver.identifier;
            } else {
                if (criteriaResolver.index >= orders[criteriaResolver.orderIndex].parameters.consideration.length) {
                    revert ConsiderationCriteriaResolverOutOfRange();
                }

                ReceivedAsset memory consideration = orders[criteriaResolver.orderIndex].parameters.consideration[criteriaResolver.index];
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
                    orders[criteriaResolver.orderIndex].parameters.consideration[criteriaResolver.index].assetType = AssetType.ERC721;
                } else {
                    orders[criteriaResolver.orderIndex].parameters.consideration[criteriaResolver.index].assetType = AssetType.ERC1155;
                }

                orders[criteriaResolver.orderIndex].parameters.consideration[criteriaResolver.index].identifierOrCriteria = criteriaResolver.identifier;
            }
        }

        for (uint256 i = 0; i < orders.length; i++) {
            Order memory order = orders[i];
            for (uint256 j = 0; j < order.parameters.consideration.length; j++) {
                if (uint256(order.parameters.consideration[j].assetType) > 3) {
                    revert UnresolvedConsiderationCriteria();
                }
            }

            for (uint256 j = 0; j < order.parameters.offer.length; j++) {
                if (uint256(order.parameters.offer[j].assetType) > 3) {
                    revert UnresolvedOfferCriteria();
                }
            }
        }
    }

    function _fulfill(
        ReceivedAsset memory asset,
        address offerer
    ) private {
        bool ok;
        bytes memory data;
        if (asset.assetType == AssetType.ETH) {
            (ok, data) = asset.account.call{value: asset.endAmount}("");
            if (!ok) {
                if (data.length != 0) {
                    assembly {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                } else {
                    revert EtherTransferGenericFailure(asset.account, asset.endAmount);
                }
            }
        } else if (asset.assetType == AssetType.ERC20) {
            // Bubble up reverts on failed primary recipient transfers.
            (ok, data) = asset.token.call(
                abi.encodeWithSelector(
                    ERC20Interface.transferFrom.selector,
                    offerer,
                    asset.account,
                    asset.endAmount
                )
            );
            if (!ok) {
                if (data.length != 0) {
                    assembly {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                } else {
                    revert ERC20TransferGenericFailure(asset.token, asset.account, asset.endAmount);
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
                    revert BadReturnValueFromERC20OnTransfer(asset.token, asset.account, asset.endAmount);
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
                    asset.endAmount
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
                        asset.endAmount
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

    function _assertBasicOrderValidity(
        OrderParameters memory order
    ) private view {
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

    function _verifySignature(
        address offerer,
        bytes32 orderHash,
        bytes memory signature
    ) private view {
        if (offerer == msg.sender) {
            return;
        }

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", _domainSeparator(), orderHash)
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
        } else if (signer != offerer) {
            (bool success, bytes memory result) = offerer.staticcall(
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

    function _domainSeparator() private view returns (bytes32) {
        return block.chainid == _CHAIN_ID ? _DOMAIN_SEPARATOR : _deriveDomainSeparator();
    }

    function _deriveDomainSeparator() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f, // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
                0x64987f6373075400d7cbff689f2b7bc23753c7e6ce20688196489b8f5d9d7e6c, // keccak256("Consideration")
                0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6, // keccak256(bytes("1")) for versionId = 1
                block.chainid,
                address(this)
            )
        );
    }

    function _getOrderHash(
        OrderParameters memory orderParameters,
        uint256 nonce
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                _ORDER_HASH,
                orderParameters.offerer,
                orderParameters.facilitator,
                orderParameters.orderType,
                orderParameters.startTime,
                orderParameters.endTime,
                orderParameters.salt,
                keccak256(abi.encode(orderParameters.offer)),
                keccak256(abi.encode(orderParameters.consideration)),
                nonce
            )
        );
    }

    function _getFraction(
        uint120 numerator,
        uint120 denominator,
        uint256 value
    ) internal pure returns (uint256 newValue) {
        if (numerator == denominator) {
            return value;
        }

        bool inexact;
        uint256 valueTimesNumerator = value * uint256(numerator);

        assembly {
            newValue := div(valueTimesNumerator, denominator)
            inexact := iszero(iszero(mulmod(value, numerator, denominator)))
        }

        if (inexact) {
            revert InexactFraction();
        }
    }

    function _verifyProof(
        uint256 leaf,
        uint256 root,
        bytes32[] memory proof
    ) private pure {
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

    function _efficientHash(
        bytes32 a,
        bytes32 b
    ) private pure returns (bytes32 value) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}
