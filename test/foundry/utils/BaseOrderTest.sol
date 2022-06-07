// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { BaseConsiderationTest } from "./BaseConsiderationTest.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";
import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../../contracts/test/TestERC20.sol";
import { TestERC721 } from "../../../contracts/test/TestERC721.sol";
import { ERC721Recipient } from "./ERC721Recipient.sol";
import { ERC1155Recipient } from "./ERC1155Recipient.sol";
import { ProxyRegistry } from "../interfaces/ProxyRegistry.sol";
import { OwnableDelegateProxy } from "../interfaces/OwnableDelegateProxy.sol";
import { OrderType } from "../../../contracts/lib/ConsiderationEnums.sol";
import { StructCopier } from "./StructCopier.sol";
import { ConsiderationItem, AdditionalRecipient, OfferItem, Fulfillment, FulfillmentComponent, ItemType, OrderComponents, OrderParameters } from "../../../contracts/lib/ConsiderationStructs.sol";
import { ArithmeticUtil } from "./ArithmeticUtil.sol";
import { AmountDeriver } from "../../../contracts/lib/AmountDeriver.sol";

/// @dev base test class for cases that depend on pre-deployed token contracts
contract BaseOrderTest is
    StructCopier,
    BaseConsiderationTest,
    AmountDeriver,
    ERC721Recipient,
    ERC1155Recipient
{
    using stdStorage for StdStorage;
    using ArithmeticUtil for uint256;
    using ArithmeticUtil for uint128;
    using ArithmeticUtil for uint120;

    uint256 constant MAX_INT = ~uint256(0);

    uint256 internal alicePk = 0xa11ce;
    uint256 internal bobPk = 0xb0b;
    uint256 internal calPk = 0xca1;
    address payable internal alice = payable(vm.addr(alicePk));
    address payable internal bob = payable(vm.addr(bobPk));
    address payable internal cal = payable(vm.addr(calPk));

    TestERC20 internal token1;
    TestERC20 internal token2;
    TestERC20 internal token3;

    TestERC721 internal test721_1;
    TestERC721 internal test721_2;
    TestERC721 internal test721_3;

    TestERC1155 internal test1155_1;
    TestERC1155 internal test1155_2;
    TestERC1155 internal test1155_3;

    TestERC20[] erc20s;
    TestERC721[] erc721s;
    TestERC1155[] erc1155s;

    OrderParameters baseOrderParameters;
    OrderComponents baseOrderComponents;

    OfferItem offerItem;
    ConsiderationItem considerationItem;
    OfferItem[] offerItems;
    ConsiderationItem[] considerationItems;

    FulfillmentComponent[] offerComponents;
    FulfillmentComponent[] considerationComponents;

    FulfillmentComponent[][] offerComponentsArray;
    FulfillmentComponent[][] considerationComponentsArray;

    Fulfillment[] fulfillments;
    FulfillmentComponent firstOrderFirstItem;
    FulfillmentComponent firstOrderSecondItem;
    FulfillmentComponent secondOrderFirstItem;
    FulfillmentComponent secondOrderSecondItem;
    FulfillmentComponent[] firstOrderFirstItemArray;
    FulfillmentComponent[] firstOrderSecondItemArray;
    FulfillmentComponent[] secondOrderFirstItemArray;
    FulfillmentComponent[] secondOrderSecondItemArray;
    Fulfillment firstFulfillment;
    Fulfillment secondFulfillment;
    Fulfillment thirdFulfillment;
    Fulfillment fourthFulfillment;
    FulfillmentComponent fulfillmentComponent;
    FulfillmentComponent[] fulfillmentComponents;
    Fulfillment fulfillment;

    AdditionalRecipient[] additionalRecipients;

    uint256 internal globalTokenId;

    event Transfer(address indexed from, address indexed to, uint256 value);

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );

    struct RestoreERC20Balance {
        address token;
        address who;
    }

    modifier onlyPayable(address _addr) {
        {
            bool success;
            assembly {
                // Transfer the ETH and store if it succeeded or not.
                success := call(gas(), _addr, 1, 0, 0, 0, 0)
            }
            vm.assume(success);
            vm.deal(address(this), uint128(MAX_INT));
        }
        _;
    }

    function setUp() public virtual override {
        super.setUp();

        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(cal, "cal");
        vm.label(address(this), "testContract");

        _deployTestTokenContracts();
        erc20s = [token1, token2, token3];
        erc721s = [test721_1, test721_2, test721_3];
        erc1155s = [test1155_1, test1155_2, test1155_3];

        // allocate funds and tokens to test addresses
        allocateTokensAndApprovals(address(this), uint128(MAX_INT));
        allocateTokensAndApprovals(alice, uint128(MAX_INT));
        allocateTokensAndApprovals(bob, uint128(MAX_INT));
        allocateTokensAndApprovals(cal, uint128(MAX_INT));
    }

    function resetOfferComponents() internal {
        delete offerComponents;
    }

    function resetConsiderationComponents() internal {
        delete considerationComponents;
    }

    function _configureConsiderationItem(
        address payable recipient,
        ItemType itemType,
        uint256 identifier,
        uint256 amt
    ) internal {
        if (itemType == ItemType.NATIVE) {
            _configureEthConsiderationItem(recipient, amt);
        } else if (itemType == ItemType.ERC20) {
            _configureErc20ConsiderationItem(recipient, amt);
        } else if (itemType == ItemType.ERC1155) {
            _configureErc1155ConsiderationItem(recipient, identifier, amt);
        } else {
            _configureErc721ConsiderationItem(recipient, identifier);
        }
    }

    function _configureOfferItem(
        ItemType itemType,
        uint256 identifier,
        uint256 startAmount,
        uint256 endAmount
    ) internal {
        if (itemType == ItemType.NATIVE) {
            _configureEthOfferItem(startAmount, endAmount);
        } else if (itemType == ItemType.ERC20) {
            _configureERC20OfferItem(startAmount, endAmount);
        } else if (itemType == ItemType.ERC1155) {
            _configureERC1155OfferItem(identifier, startAmount, endAmount);
        } else {
            _configureERC721OfferItem(identifier);
        }
    }

    function _configureOfferItem(
        ItemType itemType,
        uint256 identifier,
        uint256 amt
    ) internal {
        _configureOfferItem(itemType, identifier, amt, amt);
    }

    function _configureERC721OfferItem(uint256 tokenId) internal {
        _configureOfferItem(ItemType.ERC721, address(test721_1), tokenId, 1, 1);
    }

    function _configureERC1155OfferItem(uint256 tokenId, uint256 amount)
        internal
    {
        _configureOfferItem(
            ItemType.ERC1155,
            address(test1155_1),
            tokenId,
            amount,
            amount
        );
    }

    function _configureERC20OfferItem(uint256 startAmount, uint256 endAmount)
        internal
    {
        _configureOfferItem(
            ItemType.ERC20,
            address(token1),
            0,
            startAmount,
            endAmount
        );
    }

    function _configureERC20OfferItem(uint256 amount) internal {
        _configureERC20OfferItem(amount, amount);
    }

    function _configureERC1155OfferItem(
        uint256 tokenId,
        uint256 startAmount,
        uint256 endAmount
    ) internal {
        _configureOfferItem(
            ItemType.ERC1155,
            address(test1155_1),
            tokenId,
            startAmount,
            endAmount
        );
    }

    function _configureEthOfferItem(uint256 startAmount, uint256 endAmount)
        internal
    {
        _configureOfferItem(
            ItemType.NATIVE,
            address(0),
            0,
            startAmount,
            endAmount
        );
    }

    function _configureEthOfferItem(uint256 paymentAmount) internal {
        _configureEthOfferItem(paymentAmount, paymentAmount);
    }

    function _configureEthConsiderationItem(
        address payable recipient,
        uint256 paymentAmount
    ) internal {
        _configureConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            paymentAmount,
            paymentAmount,
            recipient
        );
    }

    function _configureEthConsiderationItem(
        address payable recipient,
        uint256 startAmount,
        uint256 endAmount
    ) internal {
        _configureConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            startAmount,
            endAmount,
            recipient
        );
    }

    function _configureErc20ConsiderationItem(
        address payable receiver,
        uint256 startAmount,
        uint256 endAmount
    ) internal {
        _configureConsiderationItem(
            ItemType.ERC20,
            address(token1),
            0,
            startAmount,
            endAmount,
            receiver
        );
    }

    function _configureErc20ConsiderationItem(
        address payable receiver,
        uint256 paymentAmount
    ) internal {
        _configureErc20ConsiderationItem(
            receiver,
            paymentAmount,
            paymentAmount
        );
    }

    function _configureErc721ConsiderationItem(
        address payable recipient,
        uint256 tokenId
    ) internal {
        _configureConsiderationItem(
            ItemType.ERC721,
            address(test721_1),
            tokenId,
            1,
            1,
            recipient
        );
    }

    function _configureErc1155ConsiderationItem(
        address payable recipient,
        uint256 tokenId,
        uint256 amount
    ) internal {
        _configureConsiderationItem(
            ItemType.ERC1155,
            address(test1155_1),
            tokenId,
            amount,
            amount,
            recipient
        );
    }

    function _configureOfferItem(
        ItemType itemType,
        address token,
        uint256 identifier,
        uint256 startAmount,
        uint256 endAmount
    ) internal {
        offerItem.itemType = itemType;
        offerItem.token = token;
        offerItem.identifierOrCriteria = identifier;
        offerItem.startAmount = startAmount;
        offerItem.endAmount = endAmount;
        offerItems.push(offerItem);
    }

    function _configureConsiderationItem(
        ItemType itemType,
        address token,
        uint256 identifier,
        uint256 startAmount,
        uint256 endAmount,
        address payable recipient
    ) internal {
        considerationItem.itemType = itemType;
        considerationItem.token = token;
        considerationItem.identifierOrCriteria = identifier;
        considerationItem.startAmount = startAmount;
        considerationItem.endAmount = endAmount;
        considerationItem.recipient = recipient;
        considerationItems.push(considerationItem);
    }

    function _configureOrderParameters(
        address offerer,
        address zone,
        bytes32 zoneHash,
        uint256 salt,
        bool useConduit
    ) internal {
        bytes32 conduitKey = useConduit ? conduitKeyOne : bytes32(0);
        baseOrderParameters.offerer = offerer;
        baseOrderParameters.zone = zone;
        baseOrderParameters.offer = offerItems;
        baseOrderParameters.consideration = considerationItems;
        baseOrderParameters.orderType = OrderType.FULL_OPEN;
        baseOrderParameters.startTime = block.timestamp;
        baseOrderParameters.endTime = block.timestamp + 1;
        baseOrderParameters.zoneHash = zoneHash;
        baseOrderParameters.salt = salt;
        baseOrderParameters.conduitKey = conduitKey;
        baseOrderParameters.totalOriginalConsiderationItems = considerationItems
            .length;
    }

    function _configureOrderParametersSetEndTime(
        address offerer,
        address zone,
        uint256 endTime,
        bytes32 zoneHash,
        uint256 salt,
        bool useConduit
    ) internal {
        _configureOrderParameters(offerer, zone, zoneHash, salt, useConduit);
        baseOrderParameters.endTime = endTime;
    }

    /**
    @dev configures order components based on order parameters in storage and counter param
     */
    function _configureOrderComponents(uint256 counter) internal {
        baseOrderComponents.offerer = baseOrderParameters.offerer;
        baseOrderComponents.zone = baseOrderParameters.zone;
        baseOrderComponents.offer = baseOrderParameters.offer;
        baseOrderComponents.consideration = baseOrderParameters.consideration;
        baseOrderComponents.orderType = baseOrderParameters.orderType;
        baseOrderComponents.startTime = baseOrderParameters.startTime;
        baseOrderComponents.endTime = baseOrderParameters.endTime;
        baseOrderComponents.zoneHash = baseOrderParameters.zoneHash;
        baseOrderComponents.salt = baseOrderParameters.salt;
        baseOrderComponents.conduitKey = baseOrderParameters.conduitKey;
        baseOrderComponents.counter = counter;
    }

    /**
    @dev deploy test token contracts
     */
    function _deployTestTokenContracts() internal {
        token1 = new TestERC20();
        token2 = new TestERC20();
        token3 = new TestERC20();
        test721_1 = new TestERC721();
        test721_2 = new TestERC721();
        test721_3 = new TestERC721();
        test1155_1 = new TestERC1155();
        test1155_2 = new TestERC1155();
        test1155_3 = new TestERC1155();
        vm.label(address(token1), "token1");
        vm.label(address(test721_1), "test721_1");
        vm.label(address(test1155_1), "test1155_1");

        emit log("Deployed test token contracts");
    }

    /**
    @dev allocate amount of each token, 1 of each 721, and 1, 5, and 10 of respective 1155s 
    */
    function allocateTokensAndApprovals(address _to, uint128 _amount) internal {
        vm.deal(_to, _amount);
        for (uint256 i = 0; i < erc20s.length; i++) {
            erc20s[i].mint(_to, _amount);
        }
        emit log_named_address("Allocated tokens to", _to);
        _setApprovals(_to);
    }

    function _setApprovals(address _owner) internal {
        vm.startPrank(_owner);
        for (uint256 i = 0; i < erc20s.length; i++) {
            erc20s[i].approve(address(consideration), MAX_INT);
            erc20s[i].approve(address(referenceConsideration), MAX_INT);
            erc20s[i].approve(address(conduit), MAX_INT);
            erc20s[i].approve(address(referenceConduit), MAX_INT);
        }
        for (uint256 i = 0; i < erc721s.length; i++) {
            erc721s[i].setApprovalForAll(address(consideration), true);
            erc721s[i].setApprovalForAll(address(referenceConsideration), true);
            erc721s[i].setApprovalForAll(address(conduit), true);
            erc721s[i].setApprovalForAll(address(referenceConduit), true);
        }
        for (uint256 i = 0; i < erc1155s.length; i++) {
            erc1155s[i].setApprovalForAll(address(consideration), true);
            erc1155s[i].setApprovalForAll(
                address(referenceConsideration),
                true
            );
            erc1155s[i].setApprovalForAll(address(conduit), true);
            erc1155s[i].setApprovalForAll(address(referenceConduit), true);
        }

        vm.stopPrank();
        emit log_named_address(
            "Owner proxy approved for all tokens from",
            _owner
        );
        emit log_named_address(
            "Consideration approved for all tokens from",
            _owner
        );
    }

    function getMaxConsiderationValue() internal view returns (uint256) {
        uint256 value = 0;
        for (uint256 i = 0; i < considerationItems.length; i++) {
            uint256 amount = considerationItems[i].startAmount >
                considerationItems[i].endAmount
                ? considerationItems[i].startAmount
                : considerationItems[i].endAmount;
            value += amount;
        }
        return value;
    }

    /**
     * @dev return OrderComponents for a given OrderParameters and offerer counter
     */
    function getOrderComponents(
        OrderParameters memory parameters,
        uint256 counter
    ) internal pure returns (OrderComponents memory) {
        return
            OrderComponents(
                parameters.offerer,
                parameters.zone,
                parameters.offer,
                parameters.consideration,
                parameters.orderType,
                parameters.startTime,
                parameters.endTime,
                parameters.zoneHash,
                parameters.salt,
                parameters.conduitKey,
                counter
            );
    }

    receive() external payable virtual {}
}
