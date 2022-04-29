// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../Consideration.sol";
import "../lib/ConsiderationStructs.sol";
import "../lib/ConsiderationEnums.sol";
import "../test/TestERC20.sol";
import "../test/TestERC721.sol";
import "../test/TestERC1155.sol";

enum HowToCall {
    Call,
    DelegateCall
}

interface IAuthenticatedProxy {
    function user() external returns (address);
    function registry() external returns (address);
    function revoked() external returns (bool);
    function initialize(address, address) external;
    function setRevoke(bool) external;
    function proxy(address, HowToCall, bytes calldata) external returns (bool);
    function proxyAssert(address, HowToCall, bytes calldata) external;
}

interface IProxyRegistry {
    function delegateProxyImplementation() external returns(address);
    function proxies(address) external returns(address);
    function pending(address) external returns(uint256);
    function contracts(address) external returns(bool);
    function DELAY_PERIOD() external returns(uint256);
    function startGrantAuthentication(address) external;
    function endGrantAuthentication(address) external;
    function revokeAuthentication(address) external;
    function registerProxy() external returns (address);
    function grantInitialAuthentication(address) external;
}

interface ITokenTransferProxy {
    function transferFrom(
        address,
        address,
        address,
        uint256
    ) external returns (bool);
}

interface FuzzyTests {
    function testFulfillBasicOrder(bytes32) external;
    function testFulfillOrder(bytes32 seed) external;
    function testFulfillAdvancedOrder(bytes32 seed) external;
    function testFulfillAvailableAdvancedOrders(bytes32 seed) external;
    function testMatchOrders(bytes32 seed) external;
    function testMatchAdvancedOrders(bytes32 seed) external;
    function testCancel(bytes32 seed) external;
    function testValidate(bytes32) external;
    function testIncrementNonce(bytes32 seed) external;
}

// echidna-test-2.0 . --contract Echidna --config ./contracts/crytic/e2e.yaml
contract Echidna is FuzzyTests {

    IAuthenticatedProxy private _proxyImplementation = IAuthenticatedProxy(
        0x1D7022f5B17d2F8B695918FB48fa1089C9f85401
    );
    IProxyRegistry private _registry = IProxyRegistry(
        0x1dC4c1cEFEF38a777b15aA20260a54E584b16C48
    );
    ITokenTransferProxy private _transferProxy = ITokenTransferProxy(
        0x871DD7C2B4b25E1Aa18728e9D5f2Af4C4e431f5c
    );
    Consideration private _opensea;
    TestERC20 private _erc20;
    TestERC721 private _erc721;
    TestERC1155 private _erc1155;

    constructor() {
        _opensea = new Consideration(
            address(_registry),
            address(_proxyImplementation),
            address(_transferProxy)
        );
        _erc20 = new TestERC20();
        _erc721 = new TestERC721();
        _erc1155 = new TestERC1155();
    }

    function testFulfillBasicOrder(bytes32 seed) public override {
        testValidate(seed);
        uint256 nftId = uint256(seed) % 10**6;
        uint256 sellForMax = uint256(seed);
        _erc20.mint(address(this), sellForMax);
        _erc20.approve(address(_opensea), sellForMax);
        AdditionalRecipient[] memory recipients = new AdditionalRecipient[](1);
        BasicOrderParameters memory basicOrderParams = BasicOrderParameters({
            considerationToken: address(_erc20),
            considerationIdentifier: uint256(0),
            considerationAmount: sellForMax,
            offerer: payable(address(this)),
            zone: address(0),
            offerToken: address(_erc721),
            offerIdentifier: nftId,
            offerAmount: uint256(1),
            basicOrderType: BasicOrderType.ERC721_TO_ERC20_FULL_OPEN,
            startTime: uint256(block.timestamp),
            endTime: uint256(block.timestamp + (60 * 60)),
            zoneHash: bytes32(0),
            salt: uint256(seed),
            offererConduit: address(0),
            fulfillerConduit: address(0),
            totalOriginalAdditionalRecipients: uint256(1),
            additionalRecipients: recipients,
            signature: abi.encodePacked(bytes32(0))
        });
        bool res = _opensea.fulfillBasicOrder(basicOrderParams);
        assert(res);
        // assert(false); // the test should fail if this is uncommented
    }

    function testFulfillOrder(bytes32 seed) public override {
        testValidate(seed);
        address payable seller = payable(address(this));
        uint256 nftId = uint256(seed) % 10**6;
        uint256 sellForMax = uint256(seed);
        uint256 sellForMin = uint256(seed) / 2;
        _erc20.mint(address(this), sellForMax);
        _erc20.approve(address(_opensea), sellForMax);
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem({
            itemType: ItemType.ERC721,
            token: address(_erc721),
            identifierOrCriteria: nftId,
            startAmount: uint256(1),
            endAmount: uint256(1)
        });
        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = ConsiderationItem({
            itemType: ItemType.ERC20,
            token: address(_erc20),
            identifierOrCriteria: uint256(0),
            startAmount: sellForMax,
            endAmount: sellForMin,
            recipient: seller
        });
        OrderParameters memory orderParams =
            OrderParameters({
                offerer: seller,
                zone: address(0),
                offer: offer,
                consideration: consideration,
                orderType: OrderType.FULL_OPEN,
                startTime: uint256(block.timestamp),
                endTime: uint256(block.timestamp + (60 * 60)),
                zoneHash: bytes32(0),
                salt: uint256(seed),
                conduit: address(0),
                totalOriginalConsiderationItems: uint256(1) // ???
            });
        Order memory order = Order({
            parameters: orderParams,
            signature: abi.encodePacked(bytes32(0))
        });
        bool res = _opensea.fulfillOrder(order, address(0));
        assert(res);
        // assert(false); // the test should fail if this is uncommented
    }

    function testFulfillAdvancedOrder(bytes32 seed) public override {
        testValidate(seed);
        address payable seller = payable(address(this));
        uint256 nftId = uint256(seed) % 10**6;
        uint256 sellForMax = uint256(seed);
        uint256 sellForMin = uint256(seed) / 2;
        _erc20.mint(address(this), sellForMax);
        _erc20.approve(address(_opensea), sellForMax);
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem({
            itemType: ItemType.ERC721,
            token: address(_erc721),
            identifierOrCriteria: nftId,
            startAmount: uint256(1),
            endAmount: uint256(1)
        });
        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = ConsiderationItem({
            itemType: ItemType.ERC20,
            token: address(_erc20),
            identifierOrCriteria: uint256(0),
            startAmount: sellForMax,
            endAmount: sellForMin,
            recipient: seller
        });
        OrderParameters memory orderParams =
            OrderParameters({
                offerer: seller,
                zone: address(0),
                offer: offer,
                consideration: consideration,
                orderType: OrderType.FULL_OPEN,
                startTime: uint256(block.timestamp),
                endTime: uint256(block.timestamp + (60 * 60)),
                zoneHash: bytes32(0),
                salt: uint256(seed),
                conduit: address(0),
                totalOriginalConsiderationItems: uint256(1) // ???
            });
        AdvancedOrder memory order = AdvancedOrder({
            parameters: orderParams,
            signature: abi.encodePacked(bytes32(0)),
            numerator: uint120(1),
            denominator: uint120(1),
            extraData: abi.encodePacked("")
        });
        CriteriaResolver[] memory resolvers = new CriteriaResolver[](0);
        bool res = _opensea.fulfillAdvancedOrder(order, resolvers, address(0));
        assert(res);
        // assert(false); // the test should fail if this is uncommented
    }

    function testFulfillAvailableAdvancedOrders(bytes32 seed) public override {}

    function testMatchOrders(bytes32 seed) public override {}

    function testMatchAdvancedOrders(bytes32 seed) public override {}

    function testCancel(bytes32 seed) public override {}

    function testValidate(bytes32 seed) public override {
        address payable seller = payable(address(this));
        uint256 nftId = uint256(seed) % 10**6;
        uint256 sellForMax = uint256(seed);
        uint256 sellForMin = uint256(seed) / 2;
        _erc721.mint(address(this), nftId);
        _erc721.approve(address(_opensea), nftId);
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem({
            itemType: ItemType.ERC721,
            token: address(_erc721),
            identifierOrCriteria: nftId,
            startAmount: uint256(1),
            endAmount: uint256(1)
        });
        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = ConsiderationItem({
            itemType: ItemType.ERC20,
            token: address(_erc20),
            identifierOrCriteria: uint256(0),
            startAmount: sellForMax,
            endAmount: sellForMin,
            recipient: seller
        });
        OrderParameters memory orderParams =
            OrderParameters({
                offerer: seller,
                zone: address(0),
                offer: offer,
                consideration: consideration,
                orderType: OrderType.FULL_OPEN,
                startTime: uint256(block.timestamp),
                endTime: uint256(block.timestamp + (60 * 60)),
                zoneHash: bytes32(0),
                salt: uint256(seed),
                conduit: address(0),
                totalOriginalConsiderationItems: uint256(1) // ???
            });
        Order[] memory orders = new Order[](1);
        orders[0] = Order({
            parameters: orderParams,
            signature: abi.encodePacked(bytes32(0))
        });
        bool res = _opensea.validate(orders);
        assert(res);
        // assert(false); // the test should fail if this is uncommented
    }

    function testIncrementNonce(bytes32 seed) public override {}
}
