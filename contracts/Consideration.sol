// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {
    OrderType,
    AssetType,
    Side
} from "./Enums.sol";

import {
    AdditionalRecipient,
    BasicOrderParameters,
    OfferedAsset,
    ReceivedAsset,
    OrderParameters,
    OrderComponents,
    Fulfillment,
    FulfillmentComponent,
    Execution,
    Order,
    OrderStatus,
    CriteriaResolver
} from "./Structs.sol";

import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "./AbridgedTokenInterfaces.sol";

import {
    ProxyRegistryInterface,
    ProxyInterface
} from "./AbridgedProxyInterfaces.sol";

import { ConsiderationInterface } from "./ConsiderationInterface.sol";

contract Consideration is ConsiderationInterface {
    // TODO: batch 1155 transfers
    // TODO: support partial fills as part of matchOrders?

    string internal constant _NAME = "Consideration";
    string internal constant _VERSION = "1";

    uint256 internal constant _NOT_ENTERED = 1;
    uint256 internal constant _ENTERED = 2;
    uint256 internal constant _FULLY_FILLED = 1e18;

    // Precompute hashes, original chainId, and domain separator on deployment.
    bytes32 internal immutable _NAME_HASH;
    bytes32 internal immutable _VERSION_HASH;
    bytes32 internal immutable _EIP_712_DOMAIN_TYPEHASH;
    bytes32 internal immutable _OFFERED_ASSET_TYPEHASH;
    bytes32 internal immutable _RECEIVED_ASSET_TYPEHASH;
    bytes32 internal immutable _ORDER_HASH;
    uint256 internal immutable _CHAIN_ID;
    bytes32 internal immutable _DOMAIN_SEPARATOR;

    address internal immutable _REQUIRED_PROXY_IMPLEMENTATION;
    ProxyRegistryInterface internal immutable _LEGACY_PROXY_REGISTRY;

    // prevent reentrant calls on protected functions
    uint256 internal _reentrancyGuard;

    // track status of each order (validated, cancelled, and fraction filled)
    mapping (bytes32 => OrderStatus) internal _orderStatus;

    // offerer => facilitator => nonce (cancel offerer's orders with given facilitator)
    mapping (address => mapping (address => uint256)) internal _facilitatorNonces;

    constructor(
        address legacyProxyRegistry,
        address requiredProxyImplementation
    ) {
        _NAME_HASH = keccak256(bytes(_NAME));
        _VERSION_HASH = keccak256(bytes(_VERSION));
        _EIP_712_DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        _OFFERED_ASSET_TYPEHASH = keccak256("OfferedAsset(uint8 assetType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)");
        _RECEIVED_ASSET_TYPEHASH = keccak256("ReceivedAsset(uint8 assetType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address account)");
        _ORDER_HASH = keccak256("OrderComponents(address offerer,address facilitator,OfferedAsset[] offer,ReceivedAsset[] consideration,uint8 orderType,uint256 startTime,uint256 endTime,uint256 salt,uint256 nonce)OfferedAsset(uint8 assetType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)ReceivedAsset(uint8 assetType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address account)");
        _CHAIN_ID = block.chainid;
        _DOMAIN_SEPARATOR = _deriveDomainSeparator();

        // TODO: validate each of these based on expected codehash
        _LEGACY_PROXY_REGISTRY = ProxyRegistryInterface(legacyProxyRegistry);
        _REQUIRED_PROXY_IMPLEMENTATION = requiredProxyImplementation;

        _reentrancyGuard = _NOT_ENTERED;
    }

    function fulfillBasicEthForERC721Order(
        uint256 amount,
        BasicOrderParameters calldata parameters
    ) external payable override nonReentrant() returns (bool) {
        address payable offerer = parameters.offerer;
        (bytes32 orderHash, bool useOffererProxy) = _prepareBasicFulfillment(
            parameters,
            OfferedAsset(
                AssetType.ERC721,
                parameters.token,
                parameters.identifier,
                1,
                1
            ),
            ReceivedAsset(
                AssetType.ETH,
                address(0),
                0,
                amount,
                amount,
                offerer
            )
        );

        _transferERC721(
            parameters.token,
            offerer,
            msg.sender,
            parameters.identifier,
            useOffererProxy ? offerer : address(0)
        );

        return _transferETHAndFinalize(
            orderHash,
            amount,
            parameters
        );
    }

    function fulfillBasicEthForERC1155Order(
        uint256 amount,
        BasicOrderParameters calldata parameters
    ) external payable override nonReentrant() returns (bool) {
        address payable offerer = parameters.offerer;
        (bytes32 orderHash, bool useOffererProxy) = _prepareBasicFulfillment(
            parameters,
            OfferedAsset(
                AssetType.ERC1155,
                parameters.token,
                parameters.identifier,
                1,
                1
            ),
            ReceivedAsset(
                AssetType.ETH,
                address(0),
                0,
                amount,
                amount,
                offerer
            )
        );

        _transferERC1155(
            parameters.token,
            offerer,
            msg.sender,
            parameters.identifier,
            1,
            useOffererProxy ? offerer : address(0)
        );

        return _transferETHAndFinalize(
            orderHash,
            amount,
            parameters
        );
    }

    function fulfillBasicERC20ForERC721Order(
        address erc20Token,
        uint256 amount,
        BasicOrderParameters calldata parameters
    ) external override nonReentrant() returns (bool) {
        (bytes32 orderHash, bool useOffererProxy) = _prepareBasicFulfillment(
            parameters,
            OfferedAsset(
                AssetType.ERC721,
                parameters.token,
                parameters.identifier,
                1,
                1
            ),
            ReceivedAsset(
                AssetType.ERC20,
                erc20Token,
                0,
                amount,
                amount,
                parameters.offerer
            )
        );

        _transferERC721(
            parameters.token,
            parameters.offerer,
            msg.sender,
            parameters.identifier,
            useOffererProxy ? parameters.offerer : address(0)
        );

        return _transferERC20AndFinalize(
            msg.sender,
            parameters.offerer,
            orderHash,
            erc20Token,
            amount,
            parameters
        );
    }

    function fulfillBasicERC20ForERC1155Order(
        address erc20Token,
        uint256 amount,
        BasicOrderParameters calldata parameters
    ) external override nonReentrant() returns (bool) {
        (bytes32 orderHash, bool useOffererProxy) = _prepareBasicFulfillment(
            parameters,
            OfferedAsset(
                AssetType.ERC1155,
                parameters.token,
                parameters.identifier,
                1,
                1
            ),
            ReceivedAsset(
                AssetType.ERC20,
                erc20Token,
                0,
                amount,
                amount,
                parameters.offerer
            )
        );

        _transferERC1155(
            parameters.token,
            parameters.offerer,
            msg.sender,
            parameters.identifier,
            1,
            useOffererProxy ? parameters.offerer : address(0)
        );

        return _transferERC20AndFinalize(
            msg.sender,
            parameters.offerer,
            orderHash,
            erc20Token,
            amount,
            parameters
        );
    }

    function fulfillBasicERC721ForERC20Order(
        address erc20Token,
        uint256 amount,
        BasicOrderParameters calldata parameters
    ) external override nonReentrant() returns (bool) {
        address payable offerer = parameters.offerer;
        (bytes32 orderHash,) = _prepareBasicFulfillment(
            parameters,
            OfferedAsset(
                AssetType.ERC20,
                erc20Token,
                0,
                amount,
                amount
            ),
            ReceivedAsset(
                AssetType.ERC721,
                parameters.token,
                parameters.identifier,
                1,
                1,
                offerer
            )
        );

        _transferERC721(
            parameters.token,
            msg.sender,
            offerer,
            parameters.identifier,
            parameters.useFulfillerProxy ? msg.sender : address(0)
        );

        return _transferERC20AndFinalize(
            offerer,
            msg.sender,
            orderHash,
            erc20Token,
            amount,
            parameters
        );
    }

    function fulfillBasicERC1155ForERC20Order(
        address erc20Token,
        uint256 amount,
        BasicOrderParameters calldata parameters
    ) external override nonReentrant() returns (bool) {
        address payable offerer = parameters.offerer;
        (bytes32 orderHash,) = _prepareBasicFulfillment(
            parameters,
            OfferedAsset(
                AssetType.ERC20,
                erc20Token,
                0,
                amount,
                amount
            ),
            ReceivedAsset(
                AssetType.ERC1155,
                parameters.token,
                parameters.identifier,
                1,
                1,
                offerer
            )
        );

        _transferERC1155(
            parameters.token,
            msg.sender,
            offerer,
            parameters.identifier,
            1,
            parameters.useFulfillerProxy ? msg.sender : address(0)
        );

        return _transferERC20AndFinalize(
            offerer,
            msg.sender,
            orderHash,
            erc20Token,
            amount,
            parameters
        );
    }

    function fulfillOrder(
        Order memory order,
        bool useFulfillerProxy
    ) external payable override nonReentrant() returns (bool) {
        return _fulfillOrderWithCriteria(
            order,
            new CriteriaResolver[](0),
            useFulfillerProxy
        );
    }

    function fulfillOrderWithCriteria(
        Order calldata order,
        CriteriaResolver[] calldata criteriaResolvers,
        bool useFulfillerProxy
    ) external payable override nonReentrant() returns (bool) {
        return _fulfillOrderWithCriteria(
            order,
            criteriaResolvers,
            useFulfillerProxy
        );
    }

    function fulfillPartialOrder(
        Order memory order,
        uint120 numerator,
        uint120 denominator,
        bool useFulfillerProxy
    ) external payable override nonReentrant() returns (bool) {
        if (uint256(order.parameters.orderType) % 2 == 0) {
            revert PartialFillsNotEnabledForOrder();
        }

        (
            bytes32 orderHash,
            uint120 fillNumerator,
            uint120 fillDenominator,
            bool useOffererProxy
        ) = _validateOrderAndUpdateStatus(order, numerator, denominator);

        _adjustPricesForSingleOrder(order);

        unchecked {
            for (uint256 i = 0; i < order.parameters.consideration.length; ++i) {
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
                        msg.sender,
                        useFulfillerProxy
                    );
                }
            }

            for (uint256 i = 0; i < order.parameters.offer.length; ++i) {
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
                    order.parameters.offerer,
                    useOffererProxy
                );
            }
        }

        emit OrderFulfilled(
            orderHash,
            order.parameters.offerer,
            order.parameters.facilitator
        );
        return true;
    }

    function _validateOrdersAndApplyPartials(
        Order[] memory orders
    ) internal returns (bool[] memory) {
        bool[] memory useOffererProxyPerOrder = new bool[](orders.length);

        unchecked {
            for (uint256 i = 0; i < orders.length; ++i) {
                Order memory order = orders[i];

                (
                    bytes32 orderHash,
                    uint120 numerator,
                    uint120 denominator,
                    bool useOffererProxy
                ) = _validateOrderAndUpdateStatus(order, 1, 1);

                useOffererProxyPerOrder[i] = useOffererProxy;

                for (uint256 j = 0; j < order.parameters.offer.length; ++j) {
                    orders[i].parameters.offer[j].endAmount = _getFraction(
                        numerator,
                        denominator,
                        orders[i].parameters.offer[j].endAmount
                    );
                }

                for (uint256 j = 0; j < order.parameters.consideration.length; ++j) {
                    orders[i].parameters.consideration[j].endAmount = _getFraction(
                        numerator,
                        denominator,
                        orders[i].parameters.consideration[j].endAmount
                    );
                }

                emit OrderFulfilled(
                    orderHash,
                    orders[i].parameters.offerer,
                    orders[i].parameters.facilitator
                );
            }
        }

        return useOffererProxyPerOrder;
    }

    function matchOrders(
        Order[] calldata orders,
        CriteriaResolver[] calldata criteriaResolvers,
        Fulfillment[] calldata fulfillments
    ) external payable override nonReentrant() returns (Execution[] memory) {
        bool[] memory useOffererProxyPerOrder = _validateOrdersAndApplyPartials(orders);

        _adjustPrices(orders);

        _applyCriteriaResolvers(orders, criteriaResolvers);

        return _fulfillOrders(orders, fulfillments, useOffererProxyPerOrder);
    }

    function cancel(
        OrderComponents[] memory orders
    ) external override returns (bool ok) {
        unchecked {
            for (uint256 i = 0; i < orders.length; ++i) {
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
        }

        return true;
    }

    function validate(
        Order[] memory orders
    ) external override returns (bool ok) {
        unchecked {
            for (uint256 i = 0; i < orders.length; ++i) {
                Order memory order = orders[i];

                bytes32 orderHash = _getNoncedOrderHash(order.parameters);

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

        nonce = ++_facilitatorNonces[offerer][facilitator];

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
    ) external view override returns (bytes32) {
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
            revert NoReentrantCalls();
        }

        _reentrancyGuard = _ENTERED;

        _;

        _reentrancyGuard = _NOT_ENTERED;
    }

    function _fulfillOrderWithCriteria(
        Order memory order,
        CriteriaResolver[] memory criteriaResolvers,
        bool useFulfillerProxy
    ) internal returns (bool) {
        (
            bytes32 orderHash,
            uint120 numerator,
            uint120 denominator,
            bool useOffererProxy
        ) = _validateOrderAndUpdateStatus(order, 1, 1);

        _adjustPricesForSingleOrder(order);

        unchecked {
            for (uint256 i = 0; i < criteriaResolvers.length; ++i) {
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

            for (uint256 i = 0; i < order.parameters.consideration.length; ++i) {
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
                        msg.sender,
                        useFulfillerProxy
                    );
                }
            }

            for (uint256 i = 0; i < order.parameters.offer.length; ++i) {
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
                    order.parameters.offerer,
                    useOffererProxy
                );
            }
        }

        emit OrderFulfilled(
            orderHash,
            order.parameters.offerer,
            order.parameters.facilitator
        );
        return true;
    }

    function _fulfillOrders(
        Order[] memory orders,
        Fulfillment[] memory fulfillments,
        bool[] memory useOffererProxyPerOrder
    ) internal returns (Execution[] memory) {
        // allocate fulfillment and schedule execution
        Execution[] memory execution = new Execution[](fulfillments.length);
        unchecked {
            for (uint256 i = 0; i < fulfillments.length; ++i) {
                execution[i] = _applyFulfillment(
                    orders,
                    fulfillments[i],
                    useOffererProxyPerOrder
                );
            }

            // ensure that all considerations have been met
            for (uint256 i = 0; i < orders.length; ++i) {
                ReceivedAsset[] memory considerations = orders[i].parameters.consideration;
                for (uint256 j = 0; j < considerations.length; ++j) {
                    uint256 remainingAmount = considerations[j].endAmount;
                    if (remainingAmount != 0) {
                        revert ConsiderationNotMet(i, j, remainingAmount);
                    }
                }
            }

            // execute fulfillments
            for (uint256 i = 0; i < execution.length; ++i) {
                _fulfill(
                    execution[i].asset,
                    execution[i].offerer,
                    execution[i].useProxy
                );
            }
        }

        return execution;
    }

    function _applyFulfillment(
        Order[] memory orders,
        Fulfillment memory fulfillment,
        bool[] memory useOffererProxyPerOrder
    ) internal pure returns (
        Execution memory execution
    ) {
        if (fulfillment.offerComponents.length == 0) {
            revert NoOfferOnFulfillment();
        }

        uint256 currentOrderIndex = fulfillment.offerComponents[0].orderIndex;

        if (fulfillment.considerationComponents.length == 0) {
            revert NoConsiderationOnFulfillment();
        }

        if (currentOrderIndex >= orders.length) {
            revert FulfilledOrderIndexOutOfRange();
        }

        OrderParameters memory orderWithInitialOffer = orders[currentOrderIndex].parameters;
        bool useProxy = useOffererProxyPerOrder[currentOrderIndex];

        uint256 currentAssetIndex = fulfillment.offerComponents[0].assetIndex;

        if (currentAssetIndex >= orderWithInitialOffer.offer.length) {
            revert FulfilledOrderOfferIndexOutOfRange();
        }
        OfferedAsset memory offeredAsset = orderWithInitialOffer.offer[currentAssetIndex];

        orders[currentOrderIndex].parameters.offer[currentAssetIndex].endAmount = 0;

        for (uint256 i = 1; i < fulfillment.offerComponents.length;) {
            FulfillmentComponent memory offerComponent = fulfillment.offerComponents[i];
            currentOrderIndex = offerComponent.orderIndex;

            if (currentOrderIndex >= orders.length) {
                revert FulfilledOrderIndexOutOfRange();
            }
            OrderParameters memory subsequentOrder = orders[currentOrderIndex].parameters;
            currentAssetIndex = offerComponent.assetIndex;

            if (currentAssetIndex >= subsequentOrder.offer.length) {
                revert FulfilledOrderOfferIndexOutOfRange();
            }
            OfferedAsset memory additionalOfferedAsset = subsequentOrder.offer[currentAssetIndex];

            if (
                orderWithInitialOffer.offerer != subsequentOrder.offerer ||
                offeredAsset.assetType != additionalOfferedAsset.assetType ||
                offeredAsset.token != additionalOfferedAsset.token ||
                offeredAsset.identifierOrCriteria != additionalOfferedAsset.identifierOrCriteria
            ) {
                revert MismatchedFulfillmentOfferComponents();
            }

            offeredAsset.endAmount += additionalOfferedAsset.endAmount;
            orders[currentOrderIndex].parameters.offer[currentAssetIndex].endAmount = 0;

            unchecked {
                ++i;
            }
        }

        currentOrderIndex = fulfillment.considerationComponents[0].orderIndex;
        if (currentOrderIndex >= orders.length) {
            revert FulfillmentOrderIndexOutOfRange();
        }
        OrderParameters memory orderWithInitialConsideration = orders[currentOrderIndex].parameters;

        currentAssetIndex = fulfillment.considerationComponents[0].assetIndex;
        if (currentAssetIndex >= orderWithInitialConsideration.consideration.length) {
            revert FulfillmentOrderConsiderationIndexOutOfRange();
        }
        ReceivedAsset memory requiredConsideration = orderWithInitialConsideration.consideration[currentAssetIndex];

        orders[currentOrderIndex].parameters.consideration[currentAssetIndex].endAmount = 0;

        for (uint256 i = 1; i < fulfillment.considerationComponents.length;) {
            FulfillmentComponent memory considerationComponent = fulfillment.considerationComponents[i];
            currentOrderIndex = considerationComponent.orderIndex;

            if (currentOrderIndex >= orders.length) {
                revert FulfillmentOrderIndexOutOfRange();
            }
            OrderParameters memory subsequentOrder = orders[currentOrderIndex].parameters;
            currentAssetIndex = considerationComponent.assetIndex;

            if (currentAssetIndex >= subsequentOrder.consideration.length) {
                revert FulfillmentOrderConsiderationIndexOutOfRange();
            }
            ReceivedAsset memory additionalRequiredConsideration = subsequentOrder.consideration[currentAssetIndex];

            if (
                requiredConsideration.account != additionalRequiredConsideration.account ||
                requiredConsideration.assetType != additionalRequiredConsideration.assetType ||
                requiredConsideration.token != additionalRequiredConsideration.token ||
                requiredConsideration.identifierOrCriteria != additionalRequiredConsideration.identifierOrCriteria
            ) {
                revert MismatchedFulfillmentConsiderationComponents();
            }

            requiredConsideration.endAmount += additionalRequiredConsideration.endAmount;
            orders[currentOrderIndex].parameters.consideration[currentAssetIndex].endAmount = 0;

            unchecked {
                ++i;
            }
        }

        if (requiredConsideration.endAmount > offeredAsset.endAmount) {
            currentOrderIndex = fulfillment.considerationComponents.length - 1;
            orders[fulfillment.considerationComponents[currentOrderIndex].orderIndex].parameters.consideration[fulfillment.considerationComponents[currentOrderIndex].assetIndex].endAmount = requiredConsideration.endAmount - offeredAsset.endAmount;
            requiredConsideration.endAmount = offeredAsset.endAmount;
        } else {
            currentOrderIndex = fulfillment.offerComponents.length - 1;
            orders[fulfillment.offerComponents[currentOrderIndex].orderIndex].parameters.offer[fulfillment.offerComponents[currentOrderIndex].assetIndex].endAmount = offeredAsset.endAmount - requiredConsideration.endAmount;
        }

        return Execution(requiredConsideration, orderWithInitialOffer.offerer, useProxy);
    }

    function _prepareBasicFulfillment(
        BasicOrderParameters memory parameters,
        OfferedAsset memory offeredAsset,
        ReceivedAsset memory receivedAsset
    ) internal returns (bytes32 orderHash, bool useOffererProxy) {
        address payable offerer = parameters.offerer;
        address facilitator = parameters.facilitator;
        uint256 startTime = parameters.startTime;
        uint256 endTime = parameters.endTime;

        _ensureValidTime(startTime, endTime);

        OfferedAsset[] memory offer = new OfferedAsset[](1);
        ReceivedAsset[] memory consideration = new ReceivedAsset[](
            1 + parameters.additionalRecipients.length
        );

        offer[0] = offeredAsset;
        consideration[0] = receivedAsset;

        if (offeredAsset.assetType == AssetType.ERC20) {
            receivedAsset.assetType = AssetType.ERC20;
            receivedAsset.token = offeredAsset.token;
            receivedAsset.identifierOrCriteria = 0;
        }

        unchecked {
            for (uint256 i = 1; i < consideration.length; ++i) {
                AdditionalRecipient memory additionalRecipient = parameters.additionalRecipients[i - 1];
                receivedAsset.account = additionalRecipient.account;
                receivedAsset.startAmount = additionalRecipient.amount;
                receivedAsset.endAmount = additionalRecipient.amount;
                consideration[i] = receivedAsset;
            }
        }

        orderHash = _getNoncedOrderHash(
            OrderParameters(
                offerer,
                facilitator,
                parameters.orderType,
                startTime,
                endTime,
                parameters.salt,
                offer,
                consideration
            )
        );

        _validateBasicOrderAndUpdateStatus(
            orderHash,
            offerer,
            parameters.signature
        );

        uint256 orderTypeAsUint256 = uint256(parameters.orderType);

        useOffererProxy = orderTypeAsUint256 > 3;
        if (useOffererProxy) {
            unchecked {
                parameters.orderType = OrderType(uint8(orderTypeAsUint256) - 4);
            }
        }

        if (
            uint256(parameters.orderType) > 1 &&
            msg.sender != facilitator &&
            msg.sender != offerer
        ) {
            revert InvalidSubmitterOnRestrictedOrder();
        }

        return (orderHash, useOffererProxy);
    }

    function _validateOrderAndUpdateStatus(
        Order memory order,
        uint120 numerator,
        uint120 denominator
    ) internal returns (
        bytes32 orderHash,
        uint120 newNumerator,
        uint120 newDenominator,
        bool useOffererProxy
    ) {
        _ensureValidTime(order.parameters.startTime, order.parameters.endTime);

        if (numerator > denominator || numerator == 0 || denominator == 0) {
            revert BadFraction();
        }

        orderHash = _getNoncedOrderHash(order.parameters);

        uint256 orderTypeAsUint256 = uint256(order.parameters.orderType);

        useOffererProxy = orderTypeAsUint256 > 3;
        if (useOffererProxy) {
            unchecked {
                order.parameters.orderType = OrderType(
                    uint8(orderTypeAsUint256) - 4
                );
            }
        }

        if (
            uint256(order.parameters.orderType) > 1 &&
            msg.sender != order.parameters.facilitator &&
            msg.sender != order.parameters.offerer
        ) {
            revert InvalidSubmitterOnRestrictedOrder();
        }

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

        return (orderHash, numerator, denominator, useOffererProxy);
    }

    function _validateBasicOrderAndUpdateStatus(
        bytes32 orderHash,
        address offerer,
        bytes memory signature
    ) internal {
        OrderStatus memory orderStatus = _orderStatus[orderHash];

        if (orderStatus.isCancelled) {
            revert OrderIsCancelled(orderHash);
        }

        if (orderStatus.numerator != 0) {
            revert OrderNotUnused(orderHash);
        }

        if (!orderStatus.isValidated) {
            _verifySignature(offerer, orderHash, signature);
        }

        _orderStatus[orderHash] = OrderStatus(
            true,       // is validated
            false,      // not cancelled
            1,          // numerator of 1
            1           // denominator of 1
        );
    }

    function _adjustPrices(
        Order[] memory orders
    ) internal view {
        for (uint256 i = 0; i < orders.length;) {
            uint256 duration;
            uint256 elapsed;
            uint256 remaining;
            unchecked {
                duration = orders[i].parameters.endTime - orders[i].parameters.startTime;
                elapsed = block.timestamp - orders[i].parameters.startTime;
                remaining = duration - elapsed;
            }

            // adjust offer prices and round down
            for (uint256 j = 0; j < orders[i].parameters.offer.length;) {
                uint256 startAmount = orders[i].parameters.offer[j].startAmount;
                uint256 endAmount = orders[i].parameters.offer[j].endAmount;
                if (startAmount != endAmount) {
                    uint256 totalBeforeDivision = (startAmount * remaining) + (endAmount * elapsed);
                    uint256 newAmount;
                    assembly {
                        newAmount := div(totalBeforeDivision, duration)
                    }
                    orders[i].parameters.offer[j].endAmount = newAmount;
                }
                unchecked {
                    ++j;
                }
            }

            // adjust consideration prices and round up
            for (uint256 j = 0; j < orders[i].parameters.consideration.length;) {
                uint256 startAmount = orders[i].parameters.consideration[j].startAmount;
                uint256 endAmount = orders[i].parameters.consideration[j].endAmount;
                if (startAmount != endAmount) {
                    uint256 durationLessOne;
                    unchecked {
                        durationLessOne = duration - 1;
                    }
                    uint256 totalBeforeDivision = (startAmount * remaining) + (endAmount * elapsed) + durationLessOne;
                    uint256 newAmount;
                    assembly {
                        newAmount := div(totalBeforeDivision, duration)
                    }
                    orders[i].parameters.consideration[j].endAmount = newAmount;
                }
                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    function _adjustPricesForSingleOrder(
        Order memory order
    ) internal view {
        uint256 duration;
        uint256 elapsed;
        uint256 remaining;
        unchecked {
            duration = order.parameters.endTime - order.parameters.startTime;
            elapsed = block.timestamp - order.parameters.startTime;
            remaining = duration - elapsed;
        }

        // adjust offer prices and round down
        for (uint256 i = 0; i < order.parameters.offer.length;) {
            uint256 startAmount = order.parameters.offer[i].startAmount;
            uint256 endAmount = order.parameters.offer[i].endAmount;
            if (startAmount != endAmount) {
                uint256 totalBeforeDivision = (startAmount * remaining) + (endAmount * elapsed);
                uint256 newAmount;
                assembly {
                    newAmount := div(totalBeforeDivision, duration)
                }
                order.parameters.offer[i].endAmount = newAmount;
            }
            unchecked {
                ++i;
            }
        }

        // adjust consideration prices and round up
        for (uint256 i = 0; i < order.parameters.consideration.length;) {
            uint256 startAmount = order.parameters.consideration[i].startAmount;
            uint256 endAmount = order.parameters.consideration[i].endAmount;
            if (startAmount != endAmount) {
                uint256 durationLessOne;
                unchecked {
                    durationLessOne = duration - 1;
                }
                uint256 totalBeforeDivision = (startAmount * remaining) + (endAmount * elapsed) + durationLessOne;
                uint256 newAmount;
                assembly {
                    newAmount := div(totalBeforeDivision, duration)
                }
                order.parameters.consideration[i].endAmount = newAmount;
            }
            unchecked {
                ++i;
            }
        }
    }

    function _applyCriteriaResolvers(
        Order[] memory orders,
        CriteriaResolver[] memory criteriaResolvers
    ) internal pure {
        unchecked {
            for (uint256 i = 0; i < criteriaResolvers.length; ++i) {
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

                    orders[criteriaResolver.orderIndex].parameters.offer[criteriaResolver.index].assetType = (
                        offer.assetType == AssetType.ERC721_WITH_CRITERIA
                            ? AssetType.ERC721
                            : AssetType.ERC1155
                    );

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

                    orders[criteriaResolver.orderIndex].parameters.consideration[criteriaResolver.index].assetType = (
                        consideration.assetType == AssetType.ERC721_WITH_CRITERIA
                            ? AssetType.ERC721
                            : AssetType.ERC1155
                    );

                    orders[criteriaResolver.orderIndex].parameters.consideration[criteriaResolver.index].identifierOrCriteria = criteriaResolver.identifier;
                }
            }

            for (uint256 i = 0; i < orders.length; ++i) {
                Order memory order = orders[i];
                for (uint256 j = 0; j < order.parameters.consideration.length; ++j) {
                    if (uint256(order.parameters.consideration[j].assetType) > 3) {
                        revert UnresolvedConsiderationCriteria();
                    }
                }

                for (uint256 j = 0; j < order.parameters.offer.length; ++j) {
                    if (uint256(order.parameters.offer[j].assetType) > 3) {
                        revert UnresolvedOfferCriteria();
                    }
                }
            }
        }
    }

    function _transferETHAndFinalize(
        bytes32 orderHash,
        uint256 amount,
        BasicOrderParameters calldata parameters
    ) internal returns (bool) {
        unchecked {
            for (uint256 i = 0; i < parameters.additionalRecipients.length; ++i) {
                AdditionalRecipient memory additionalRecipient = parameters.additionalRecipients[i];
                _transferEth(
                    additionalRecipient.account,
                    additionalRecipient.amount
                );
            }
        }

        _transferEth(parameters.offerer, amount);

        emit OrderFulfilled(orderHash, parameters.offerer, parameters.facilitator);
        return true;
    }

    function _transferERC20AndFinalize(
        address from,
        address to,
        bytes32 orderHash,
        address erc20Token,
        uint256 amount,
        BasicOrderParameters calldata parameters
    ) internal returns (bool) {
        unchecked {
            for (uint256 i = 0; i < parameters.additionalRecipients.length; ++i) {
                AdditionalRecipient memory additionalRecipient = parameters.additionalRecipients[i];
                _transferERC20(
                    erc20Token,
                    from,
                    additionalRecipient.account,
                    additionalRecipient.amount
                );
            }
        }

        _transferERC20(erc20Token, from, to, amount);

        emit OrderFulfilled(orderHash, from, parameters.facilitator);
        return true;
    }

    function _fulfill(
        ReceivedAsset memory asset,
        address offerer,
        bool useProxy
    ) internal {
        if (asset.assetType == AssetType.ETH) {
            _transferEth(asset.account, asset.endAmount);
        } else if (asset.assetType == AssetType.ERC20) {
            _transferERC20(
                asset.token,
                offerer,
                asset.account,
                asset.endAmount
            );
        } else if (asset.assetType == AssetType.ERC721) {
            _transferERC721(
                asset.token,
                offerer,
                asset.account,
                asset.identifierOrCriteria,
                useProxy ? offerer : address(0)
            );
        } else if (asset.assetType == AssetType.ERC1155) {
            _transferERC1155(
                asset.token,
                offerer,
                asset.account,
                asset.identifierOrCriteria,
                asset.endAmount,
                useProxy ? offerer : address(0)
            );
        }
    }

    function _transferEth(address payable to, uint256 amount) internal {
        (bool ok, bytes memory data) = to.call{value: amount}("");
        if (!ok) {
            if (data.length != 0) {
                assembly {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            } else {
                revert EtherTransferGenericFailure(to, amount);
            }
        }
    }

    function _transferERC20(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(
                ERC20Interface.transferFrom.selector,
                from,
                to,
                amount
            )
        );
        if (!ok) {
            if (data.length != 0) {
                assembly {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            } else {
                revert ERC20TransferGenericFailure(token, from, amount);
            }
        }

        if (data.length == 0) {
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
                revert BadReturnValueFromERC20OnTransfer(token, from, amount);
            }
        }
    }

    function _callProxy(
        address proxyOwner,
        bytes memory callData
    ) internal returns (bool ok, bytes memory data) {
        // Retrieve the user proxy from the registry.
        address proxy = _LEGACY_PROXY_REGISTRY.proxies(proxyOwner);

        // Assert that the user proxy has the correct implementation.
        if (ProxyInterface(proxy).implementation() != _REQUIRED_PROXY_IMPLEMENTATION) {
            revert InvalidUserProxyImplementation();
        }

        // perform the call to the proxy.
        (ok, data) = proxy.call(callData);
    }

    function _transferERC721(
        address token,
        address from,
        address to,
        uint256 tokenId,
        address proxyOwner
    ) internal {
        (bool ok, bytes memory data) = (
            proxyOwner != address(0)
                ? _callProxy(
                    proxyOwner,
                    abi.encodeWithSelector(
                        ProxyInterface.transferERC721.selector,
                        token,
                        from,
                        to,
                        tokenId
                    )
                )
                : token.call(
                    abi.encodeWithSelector(
                        ERC721Interface.transferFrom.selector,
                        from,
                        to,
                        tokenId
                    )
                )
        );

        if (!ok) {
            if (data.length != 0) {
                assembly {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            } else {
                revert ERC721TransferGenericFailure(token, from, tokenId);
            }
        } else if (data.length == 0) {
            uint256 size;
            assembly {
                size := extcodesize(token)
            }
            if (size == 0) {
                revert ERC721TransferNoContract(token);
            }
        }
    }

    function _transferERC1155(
        address token,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        address proxyOwner
    ) internal {
        (bool ok, bytes memory data) = (
            proxyOwner != address(0)
                ? _callProxy(
                    proxyOwner,
                    abi.encodeWithSelector(
                        ProxyInterface.transferERC1155.selector,
                        token,
                        from,
                        to,
                        tokenId,
                        amount
                    )
                )
                : token.call(
                    abi.encodeWithSelector(
                        ERC1155Interface.safeTransferFrom.selector,
                        from,
                        to,
                        tokenId,
                        amount
                    )
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
                    token,
                    from,
                    tokenId,
                    amount
                );
            }
        } else if (data.length == 0) {
            uint256 size;
            assembly {
                size := extcodesize(token)
            }
            if (size == 0) {
                revert ERC1155TransferNoContract(token);
            }
        }
    }

    function _ensureValidTime(
        uint256 startTime,
        uint256 endTime
    ) internal view {
        if (startTime > block.timestamp || endTime < block.timestamp) {
            revert InvalidTime();
        }
    }

    function _verifySignature(
        address offerer,
        bytes32 orderHash,
        bytes memory signature
    ) internal view {
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

    function _domainSeparator() internal view returns (bytes32) {
        return block.chainid == _CHAIN_ID ? _DOMAIN_SEPARATOR : _deriveDomainSeparator();
    }

    function _deriveDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                address(this)
            )
        );
    }

    function _hashOfferedAsset(
        OfferedAsset memory offeredAsset
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _OFFERED_ASSET_TYPEHASH,
                offeredAsset.assetType,
                offeredAsset.token,
                offeredAsset.identifierOrCriteria,
                offeredAsset.startAmount,
                offeredAsset.endAmount
            )
        );
    }

    function _hashReceivedAsset(
        ReceivedAsset memory receivedAsset
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _RECEIVED_ASSET_TYPEHASH,
                receivedAsset.assetType,
                receivedAsset.token,
                receivedAsset.identifierOrCriteria,
                receivedAsset.startAmount,
                receivedAsset.endAmount,
                receivedAsset.account
            )
        );
    }

    function _getNoncedOrderHash(
        OrderParameters memory orderParameters
    ) internal view returns (bytes32) {
        return _getOrderHash(
            orderParameters,
            _facilitatorNonces[orderParameters.offerer][orderParameters.facilitator]
        );
    }

    function _getOrderHash(
        OrderParameters memory orderParameters,
        uint256 nonce
    ) internal view returns (bytes32) {
        uint256 offerLength = orderParameters.offer.length;
        uint256 considerationLength = orderParameters.consideration.length;
        bytes32[] memory offerHashes = new bytes32[](offerLength);
        bytes32[] memory considerationHashes = new bytes32[](considerationLength);

        unchecked {
            for (uint256 i = 0; i < offerLength; ++i) {
                offerHashes[i] = _hashOfferedAsset(orderParameters.offer[i]);
            }

            for (uint256 i = 0; i < considerationLength; ++i) {
                considerationHashes[i] = _hashReceivedAsset(orderParameters.consideration[i]);
            }
        }

        return keccak256(
            abi.encode(
                _ORDER_HASH,
                orderParameters.offerer,
                orderParameters.facilitator,
                keccak256(abi.encodePacked(offerHashes)),
                keccak256(abi.encodePacked(considerationHashes)),
                orderParameters.orderType,
                orderParameters.startTime,
                orderParameters.endTime,
                orderParameters.salt,
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
    ) internal pure {
        bytes32 computedHash = bytes32(leaf);
        unchecked {
            for (uint256 i = 0; i < proof.length; ++i) {
                bytes32 proofElement = proof[i];
                if (computedHash <= proofElement) {
                    // Hash(current computed hash + current element of the proof)
                    computedHash = _efficientHash(computedHash, proofElement);
                } else {
                    // Hash(current element of the proof + current computed hash)
                    computedHash = _efficientHash(proofElement, computedHash);
                }
            }
        }
        if (computedHash != bytes32(root)) {
            revert InvalidProof();
        }
    }

    function _efficientHash(
        bytes32 a,
        bytes32 b
    ) internal pure returns (bytes32 value) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}
