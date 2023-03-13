// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { Merkle } from "murky/Merkle.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";

import { PausableZone } from "../../contracts/zones/PausableZone.sol";
import { SignedZone } from "../../contracts/zones/SignedZone.sol";

import {
    BasicOrderType,
    OrderType,
    ItemType,
    Side
} from "../../contracts/lib/ConsiderationEnums.sol";

import {
    ConsiderationInterface
} from "../../contracts/interfaces/ConsiderationInterface.sol";
import {
    SeaportInterface
} from "../../contracts/interfaces/SeaportInterface.sol";
import {
    ProOrdersAdapter
} from "../../contracts/offerer/pro-orders/ProOrdersAdapter.sol";
import { Faucet } from "../../contracts/offerer/pro-orders/faucet/Faucet.sol";

import {
    SpentItem,
    ReceivedItem,
    Fulfillment,
    AdditionalRecipient,
    AdvancedOrder,
    OfferItem,
    OrderParameters,
    ConsiderationItem,
    OrderComponents,
    FulfillmentComponent,
    CriteriaResolver,
    BasicOrderParameters
} from "../../contracts/lib/ConsiderationStructs.sol";

import { Seaport } from "../../contracts/Seaport.sol";

/**

- Zone needs to check if the server-side signature is valid.
- Zone needs to check if the order uses more gas price than allowed
- Zone needs to check if the order was fulfilled (eth budget check)
- Zone needs to check if the trade value is greater than or equal to the minEthPricePerItem
- Zone needs to check if the trade value is less than the minEthPricePerItem
- Zone needs to check if we the current trade (including the gas expense) will exceed the ethSpendLimit (only if ethSpendLimit > 0)

- Zone needs to track remainingSpendLimit (only if ethSpendLimit > 0)

----
zoneHash arguments:
- minEthPricePerItem
- maxEthPricePerItem
- ethSpendLimit

signature arguments:
- expectedFulfiller (address sending the trx)
- orderHash of pro order
- expiration of signature
- hash of ReceivedItem array

extraData arguments:
- minEthPricePerItem
- maxEthPricePerItem
- ethSpendLimit
- server signature
- fulfiller (address sending the trx)
- orderHash of pro order
- expiration of signature
- hash of ReceivedItem array

    - server signature
        - passed within extraData
    - server signature expiration timestamp
        - part of the SignedOrder struct (server sig)
        - passed within extraData
    - minEthPricePerItem check
        - part of zoneHash (pro order sig)
        - passed within extraData
    - maxEthPricePerItem check
        - part of zoneHash (pro order sig)
        - passed within extraData
    - ethSpendLimit check
        - part of zoneHash (pro order sig)
        - passed within extraData (pass 0 in case it's an item based order)

- signature validity is checked by making sure that the resolved 
    signer is an allowed signer
- there are a bunch of parameters in the signature; expiration will
    control when the signature will expire and other parameters make
    sure that the signature is not maliciously replayable.
- We'll verify (fulfiller, orderHash, expiration, hash of ReceivedItem array)
by hashing and recovering the signature signer.
- We'll verify the fulfiller by comparing it with the fulfiller from the 
zoneParameters.
- We'll verify the orderHash by checking if orderHashes[] from zoneParameters
includes orderHash
- We'll check if the current timestamp is greater than or equal to expiration.
- We'll hash the ReceivedItem[] (consideration) from zoneParameters and
compare that with hash of ReceivedItem array from extraData
----
- as we know that the zoneHash is valid, we will has 
(minEthPricePerItem, maxEthPricePerItem, ethSpendLimit) to check if that
matches the zoneHash.
- We'll calculate the price paid for the item bought; using offer and
consideration arrays from zoneParameters and make sure that the the price
lies within the (minEthPricePerItem, maxEthPricePerItem) range.
- If ethSpendLimit from extraData is greater than 0, then we'll update
the budgetTracker and after the update check if the budget is > 1 
(we'll consider orders with remaining budget of 1 as fulfilled)


budget: 10 ETH
maxPerItemPrice: 1 ETH

offer: 100 ETH
maxPerItemPrice: 1 ETH

denominator: 100
 */

interface IAdapter {
    function _SIDECAR() external returns (address);
}

contract TestPlayGround is Test {
    TestERC721 erc721;
    IERC721 apeERC721;
    IERC20 weth;
    SeaportInterface seaport;
    PausableZone pausableZone;
    SignedZone testZone;
    ProOrdersAdapter proOrdersAdapter;
    Faucet faucet;

    Merkle merkle = new Merkle();

    uint256 alicePk = 1;
    uint256 bobPk = 2;
    uint256 serverSignerPk = 3;
    address alice;
    address bob;
    address serverSigner;
    address vasa = address(0x073Ab1C0CAd3677cDe9BDb0cDEEDC2085c029579);
    address zone = address(0x004C00500000aD104D7DBd00e3ae0A5C00560C00);
    address conduit = address(0x1E0049783F008A0085193E00003D00cd54003c71);

    bytes32 conduitKey =
        0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000;
    bytes32 emptyZoneHash =
        0x0000000000000000000000000000000000000000000000000000000000000000;
    bytes32 emptyConduitKey =
        0x0000000000000000000000000000000000000000000000000000000000000000;

    struct LooksRareEthBuy {
        uint256 tokenId;
        uint256 price;
        uint256 nonce;
        uint256 startTime;
        uint256 endTime;
        uint256 minPercentageToAsk;
        uint256 amount;
        uint256 v;
        bytes32 r;
        bytes32 s;
        address collectionAddress;
        address signer;
        address strategy;
        bool isERC721;
    }

    struct ProOrderExtraData {
        address fulfiller;
        uint256 minEthPricePerItem;
        uint256 maxEthPricePerItem;
        uint256 ethSpendLimit;
        uint256 expiration;
        bytes32 orderHash;
        bytes32 considerationHash;
        bytes signature;
    }

    function getSignatureComponents(
        ConsiderationInterface _consideration,
        uint256 _pkOfSigner,
        bytes32 _orderHash
    ) internal view returns (bytes32, bytes32, uint8) {
        (, bytes32 domainSeparator, ) = _consideration.information();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _pkOfSigner,
            keccak256(
                abi.encodePacked(bytes2(0x1901), domainSeparator, _orderHash)
            )
        );
        return (r, s, v);
    }

    function signOrder(
        ConsiderationInterface _consideration,
        uint256 _pkOfSigner,
        bytes32 _orderHash
    ) internal view returns (bytes memory) {
        (bytes32 r, bytes32 s, uint8 v) = getSignatureComponents(
            _consideration,
            _pkOfSigner,
            _orderHash
        );
        return abi.encodePacked(r, s, v);
    }

    function _generateServerSideSignature(
        SignedZone signedZone,
        SignedZone.SignedOrder memory signedOrder,
        uint256 _pkOfSigner
    ) internal view returns (bytes memory) {
        bytes32 signedOrderHash = signedZone.hashSignedOrder(signedOrder);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_pkOfSigner, signedOrderHash);
        return abi.encodePacked(r, s, v);
    }

    function setUp() public {
        alice = vm.addr(alicePk);
        bob = vm.addr(bobPk);
        serverSigner = vm.addr(serverSignerPk);
        erc721 = new TestERC721();
        pausableZone = new PausableZone();
        testZone = new SignedZone("SignedZone");
        weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        seaport = SeaportInterface(0x00000000000001ad428e4906aE43D8F9852d0dD6);
        proOrdersAdapter = new ProOrdersAdapter(address(seaport));
        faucet = new Faucet(
            address(proOrdersAdapter),
            IAdapter(address(proOrdersAdapter))._SIDECAR()
        );
        apeERC721 = IERC721(0xD07e72b00431af84AD438CA995Fd9a7F0207542d);

        // set serverSigner as a signer for SignedZone
        address(testZone).call(
            abi.encodeWithSignature(
                "updateSigner(address,bool)",
                serverSigner,
                true
            )
        );

        vm.label(serverSigner, "ServerSigner");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(vasa, "Vasa");
    }

    // function testSigs() public {
    //     address carrol = vm.addr(3);
    //     bytes32 hash = keccak256("Signed by Carrol");
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(3, hash);
    //
    //     address signer = ecrecover(hash, v, r, s);
    //     assertEq(carrol, signer); // [PASS]
    // }

    // function testMint() public {
    //     erc721.mint(alice, 0);
    //
    //     address ownerOf0 = erc721.ownerOf(0);
    //     assertEq(ownerOf0, alice);
    //
    //     vm.startPrank(alice);
    //     erc721.transferFrom(alice, bob, 0);
    //
    //     ownerOf0 = erc721.ownerOf(0);
    //     assertEq(ownerOf0, bob);
    // }

    function testFulfillBasicOrder_ERC20_TO_ERC721_FULL_OPEN() public {
        // mint an ERC721
        erc721.mint(alice, 1);

        // approve the item to seaport
        vm.startPrank(alice);
        erc721.setApprovalForAll(conduit, true);
        vm.stopPrank();

        vm.startPrank(vasa);
        weth.approve(address(seaport), 10 ** 10);
        vm.stopPrank();

        uint256 counter = seaport.getCounter(alice);

        OfferItem[] memory offerItems = new OfferItem[](1);
        offerItems[0] = OfferItem(ItemType.ERC721, address(erc721), 1, 1, 1);

        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            1
        );
        considerationItems[0] = ConsiderationItem(
            ItemType.ERC20,
            address(weth),
            0,
            10 ** 10,
            10 ** 10,
            payable(alice)
        );

        OrderComponents memory orderComponents = OrderComponents(
            alice,
            address(testZone),
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            0,
            ~uint256(0),
            emptyZoneHash,
            0,
            conduitKey,
            counter
        );

        bytes32 orderHash = seaport.getOrderHash(orderComponents);
        bytes memory signature = signOrder(
            ConsiderationInterface(address(seaport)),
            alicePk,
            orderHash
        );

        emit log_bytes32(orderHash);
        // address signer = ecrecover(hash, v, r, s);
        // return;

        AdditionalRecipient[] memory additionalRecipients;

        // alice creates an order to buy ERC721 for some WETH
        BasicOrderParameters memory basicOrderParameters = BasicOrderParameters(
            // calldata offset
            address(weth), // 0x24
            0, // 0x44
            10 ** 10, // 0x64
            payable(alice), // 0x84
            address(testZone), // 0xa4
            address(erc721), // 0xc4
            1, // 0xe4
            1, // 0x104
            BasicOrderType.ERC20_TO_ERC721_FULL_OPEN, // 0x124
            0, // 0x144
            ~uint256(0), // 0x164
            emptyZoneHash, // 0x184
            0, // 0x1a4
            conduitKey, // 0x1c4
            emptyConduitKey, // 0x1e4
            0, // 0x204
            additionalRecipients, // 0x224
            signature // 0x244
            // Total length, excluding dynamic array data: 0x264 (580)
        );

        // We would want to send the trx on behalf of vasa
        vm.startPrank(vasa);

        seaport.fulfillBasicOrder_efficient_6GL6yc(basicOrderParameters);
    }

    function testFulfillBasicOrder_ETH_TO_ERC721_FULL_OPEN() public {
        // mint an ERC721
        erc721.mint(alice, 2);

        // fund vasa
        vm.deal(vasa, 1 ether);

        // approve the item to seaport
        vm.startPrank(alice);
        erc721.setApprovalForAll(conduit, true);
        vm.stopPrank();

        uint256 counter = seaport.getCounter(alice);

        OfferItem[] memory offerItems = new OfferItem[](1);
        offerItems[0] = OfferItem(ItemType.ERC721, address(erc721), 2, 1, 1);

        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            1
        );
        considerationItems[0] = ConsiderationItem(
            ItemType.NATIVE,
            address(0x0),
            0,
            10 ** 10,
            10 ** 10,
            payable(alice)
        );

        OrderComponents memory orderComponents = OrderComponents(
            alice,
            address(testZone),
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            0,
            ~uint256(0),
            emptyZoneHash,
            0,
            conduitKey,
            counter
        );

        bytes32 orderHash = seaport.getOrderHash(orderComponents);
        bytes memory signature = signOrder(
            ConsiderationInterface(address(seaport)),
            alicePk,
            orderHash
        );

        AdditionalRecipient[] memory additionalRecipients;

        // alice creates an order to buy ERC721 for some WETH
        BasicOrderParameters memory basicOrderParameters = BasicOrderParameters(
            // calldata offset
            address(0x0), // 0x24
            0, // 0x44
            10 ** 10, // 0x64
            payable(alice), // 0x84
            address(testZone), // 0xa4
            address(erc721), // 0xc4
            2, // 0xe4
            1, // 0x104
            BasicOrderType.ETH_TO_ERC721_FULL_OPEN, // 0x124
            0, // 0x144
            ~uint256(0), // 0x164
            emptyZoneHash, // 0x184
            0, // 0x1a4
            conduitKey, // 0x1c4
            emptyConduitKey, // 0x1e4
            0, // 0x204
            additionalRecipients, // 0x224
            signature // 0x244
            // Total length, excluding dynamic array data: 0x264 (580)
        );

        // We would want to send the trx on behalf of vasa
        vm.startPrank(vasa);

        seaport.fulfillBasicOrder_efficient_6GL6yc{ value: 10 ** 10 }(
            basicOrderParameters
        );
    }

    function testMatchAdvancedOrders_1() public {
        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](2);
        CriteriaResolver[] memory criteriaResolvers;
        Fulfillment[] memory fulfillments = new Fulfillment[](2);
        address recipient = vasa;

        // mint an ERC721
        erc721.mint(alice, 3);

        // approve the item to seaport
        vm.startPrank(alice);
        erc721.setApprovalForAll(conduit, true);
        vm.stopPrank();

        vm.startPrank(vasa);
        weth.approve(address(conduit), 10 ** 10);
        vm.stopPrank();

        {
            uint256 counter = seaport.getCounter(alice);

            OfferItem[] memory offerItems = new OfferItem[](1);
            offerItems[0] = OfferItem(
                ItemType.ERC721,
                address(erc721),
                3,
                1,
                1
            );

            ConsiderationItem[]
                memory considerationItems = new ConsiderationItem[](1);
            considerationItems[0] = ConsiderationItem(
                ItemType.ERC20,
                address(weth),
                0,
                10 ** 10,
                10 ** 10,
                payable(alice)
            );

            OrderComponents memory orderComponents = OrderComponents(
                alice,
                address(testZone),
                offerItems,
                considerationItems,
                OrderType.FULL_OPEN,
                0,
                ~uint256(0),
                emptyZoneHash,
                0,
                conduitKey,
                counter
            );

            bytes32 orderHash = seaport.getOrderHash(orderComponents);
            emit log_named_bytes32("alice orderHash: ", orderHash);

            bytes memory signature = signOrder(
                ConsiderationInterface(address(seaport)),
                alicePk,
                orderHash
            );

            OrderParameters memory orderParameters = OrderParameters(
                alice, // 0x00
                address(testZone), // 0x20
                offerItems, // 0x40
                considerationItems, // 0x60
                OrderType.FULL_OPEN, // 0x80
                0, // 0xa0
                ~uint256(0), // 0xc0
                emptyZoneHash, // 0xe0
                0, // 0x100
                conduitKey, // 0x120
                1 // 0x140
            );

            advancedOrders[0] = AdvancedOrder(
                orderParameters,
                1,
                1,
                signature,
                "0x"
            );
        }

        ///////////////////////////

        {
            // uint256 counter = seaport.getCounter(vasa);

            OfferItem[] memory offerItems = new OfferItem[](1);
            offerItems[0] = OfferItem(
                ItemType.ERC20,
                address(weth),
                0,
                10 ** 10,
                10 ** 10
            );

            ConsiderationItem[]
                memory considerationItems = new ConsiderationItem[](1);
            considerationItems[0] = ConsiderationItem(
                ItemType.ERC721,
                address(erc721),
                3,
                1,
                1,
                payable(vasa)
            );

            // OrderComponents memory orderComponents = OrderComponents(
            //     vasa,
            //     zone,
            //     offerItems,
            //     considerationItems,
            //     OrderType.FULL_OPEN,
            //     0,
            //     ~uint256(0),
            //     emptyZoneHash,
            //     0,
            //     conduitKey,
            //     counter
            // );

            OrderParameters memory orderParameters = OrderParameters(
                vasa, // 0x00
                address(testZone), // 0x20
                offerItems, // 0x40
                considerationItems, // 0x60
                OrderType.FULL_OPEN, // 0x80
                0, // 0xa0
                ~uint256(0), // 0xc0
                emptyZoneHash, // 0xe0
                0, // 0x100
                conduitKey, // 0x120
                1 // 0x140
            );

            advancedOrders[1] = AdvancedOrder(
                orderParameters,
                1,
                1,
                "0x",
                "0x"
            );
        }

        ////////////////////////////

        {
            FulfillmentComponent[]
                memory offerComponents = new FulfillmentComponent[](1);
            FulfillmentComponent[]
                memory considerationComponents = new FulfillmentComponent[](1);

            offerComponents[0] = FulfillmentComponent(0, 0);
            considerationComponents[0] = FulfillmentComponent(1, 0);

            fulfillments[0] = Fulfillment(
                offerComponents,
                considerationComponents
            );
        }

        {
            FulfillmentComponent[]
                memory offerComponents = new FulfillmentComponent[](1);
            FulfillmentComponent[]
                memory considerationComponents = new FulfillmentComponent[](1);

            offerComponents[0] = FulfillmentComponent(1, 0);
            considerationComponents[0] = FulfillmentComponent(0, 0);

            fulfillments[1] = Fulfillment(
                offerComponents,
                considerationComponents
            );
        }

        // We would want to send the trx on behalf of vasa
        vm.startPrank(vasa);

        seaport.matchAdvancedOrders(
            advancedOrders,
            criteriaResolvers,
            fulfillments,
            recipient
        );
    }

    function testMatchAdvancedOrders_2() public {
        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](2);
        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](1);
        Fulfillment[] memory fulfillments = new Fulfillment[](3);
        bytes32[] memory criteriaProof;
        address recipient = vasa;
        bytes32 root;

        // mint an ERC721
        erc721.mint(alice, 4);

        // approve the item to seaport
        vm.startPrank(alice);
        erc721.setApprovalForAll(conduit, true);
        vm.stopPrank();

        vm.startPrank(vasa);
        weth.transfer(bob, 10 ** 10);
        vm.stopPrank();

        vm.startPrank(bob);
        weth.approve(conduit, 10 ** 10);
        vm.stopPrank();

        {
            // create a new array to store bytes32 hashes of identifiers
            bytes32[] memory hashedIdentifiers = new bytes32[](10000);
            for (uint256 i = 0; i < 10000; i++) {
                // hash identifier and store to generate proof
                hashedIdentifiers[i] = keccak256(abi.encode(i));
            }

            root = merkle.getRoot(hashedIdentifiers);
            criteriaProof = merkle.getProof(hashedIdentifiers, 4);
        }

        {
            uint256 counter = seaport.getCounter(bob);

            OfferItem[] memory offerItems = new OfferItem[](1);
            offerItems[0] = OfferItem(
                ItemType.ERC20,
                address(weth),
                0,
                1000_000_000_000,
                1000_000_000_000
            );

            ConsiderationItem[]
                memory considerationItems = new ConsiderationItem[](2);
            considerationItems[0] = ConsiderationItem(
                ItemType.ERC721_WITH_CRITERIA,
                address(erc721),
                uint256(root),
                10,
                10,
                payable(bob)
            );
            considerationItems[1] = ConsiderationItem(
                ItemType.ERC20,
                address(weth),
                0,
                (1000_000_000_00 - 17) * 10,
                (1000_000_000_00 - 17) * 10,
                payable(bob)
            );

            ConsiderationItem[]
                memory orderComponentsConsiderationItems = new ConsiderationItem[](
                    1
                );
            orderComponentsConsiderationItems[0] = ConsiderationItem(
                ItemType.ERC721_WITH_CRITERIA,
                address(erc721),
                uint256(root),
                10,
                10,
                payable(bob)
            );

            OrderComponents memory orderComponents = OrderComponents(
                bob,
                address(testZone),
                offerItems,
                orderComponentsConsiderationItems,
                OrderType.PARTIAL_RESTRICTED,
                0,
                ~uint256(0),
                emptyZoneHash,
                0,
                conduitKey,
                counter
            );

            bytes32 orderHash = seaport.getOrderHash(orderComponents);

            bytes memory signature = signOrder(
                ConsiderationInterface(address(seaport)),
                bobPk,
                orderHash
            );

            OrderParameters memory orderParameters = OrderParameters(
                bob, // 0x00
                address(testZone), // 0x20
                offerItems, // 0x40
                considerationItems, // 0x60
                OrderType.PARTIAL_RESTRICTED, // 0x80
                0, // 0xa0
                ~uint256(0), // 0xc0
                emptyZoneHash, // 0xe0
                0, // 0x100
                conduitKey, // 0x120
                1 // 0x140
            );

            advancedOrders[0] = AdvancedOrder(
                orderParameters,
                1,
                10,
                signature,
                "0x" // hex"1010"
            );
        }

        ///////////////////////////

        {
            uint256 counter = seaport.getCounter(alice);

            OfferItem[] memory offerItems = new OfferItem[](1);
            offerItems[0] = OfferItem(
                ItemType.ERC721,
                address(erc721),
                4,
                1,
                1
            );

            ConsiderationItem[]
                memory considerationItems = new ConsiderationItem[](1);
            considerationItems[0] = ConsiderationItem(
                ItemType.ERC20,
                address(weth),
                0,
                17,
                17,
                payable(alice)
            );

            OrderComponents memory orderComponents = OrderComponents(
                alice,
                address(testZone),
                offerItems,
                considerationItems,
                OrderType.FULL_OPEN,
                0,
                ~uint256(0),
                emptyZoneHash,
                0,
                conduitKey,
                counter
            );

            bytes32 orderHash = seaport.getOrderHash(orderComponents);

            bytes memory signature = signOrder(
                ConsiderationInterface(address(seaport)),
                alicePk,
                orderHash
            );

            OrderParameters memory orderParameters = OrderParameters(
                alice, // 0x00
                address(testZone), // 0x20
                offerItems, // 0x40
                considerationItems, // 0x60
                OrderType.FULL_OPEN, // 0x80
                0, // 0xa0
                ~uint256(0), // 0xc0
                emptyZoneHash, // 0xe0
                0, // 0x100
                conduitKey, // 0x120
                1 // 0x140
            );

            advancedOrders[1] = AdvancedOrder(
                orderParameters,
                1,
                1,
                signature,
                "0x"
            );
        }

        ////////////////////////////

        {
            FulfillmentComponent[]
                memory offerComponents = new FulfillmentComponent[](1);
            FulfillmentComponent[]
                memory considerationComponents = new FulfillmentComponent[](1);

            offerComponents[0] = FulfillmentComponent(0, 0);
            considerationComponents[0] = FulfillmentComponent(1, 0);

            fulfillments[0] = Fulfillment(
                offerComponents,
                considerationComponents
            );
        }

        {
            FulfillmentComponent[]
                memory offerComponents = new FulfillmentComponent[](1);
            FulfillmentComponent[]
                memory considerationComponents = new FulfillmentComponent[](1);

            offerComponents[0] = FulfillmentComponent(1, 0);
            considerationComponents[0] = FulfillmentComponent(0, 0);

            fulfillments[1] = Fulfillment(
                offerComponents,
                considerationComponents
            );
        }

        {
            FulfillmentComponent[]
                memory offerComponents = new FulfillmentComponent[](1);
            FulfillmentComponent[]
                memory considerationComponents = new FulfillmentComponent[](1);

            offerComponents[0] = FulfillmentComponent(0, 0);
            considerationComponents[0] = FulfillmentComponent(0, 1);

            fulfillments[2] = Fulfillment(
                offerComponents,
                considerationComponents
            );
        }

        {
            criteriaResolvers[0] = CriteriaResolver(
                0,
                Side.CONSIDERATION,
                0,
                4,
                criteriaProof
            );
        }

        // We would want to send the trx on behalf of vasa
        vm.startPrank(vasa);

        seaport.matchAdvancedOrders(
            advancedOrders,
            criteriaResolvers,
            fulfillments,
            recipient
        );
    }

    function testMatchAdvancedOrders_3() public {
        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](2);
        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](1);
        Fulfillment[] memory fulfillments = new Fulfillment[](3);
        bytes32[] memory criteriaProof;
        uint256 tokenId = 1537;
        address recipient = vasa;
        bytes32 root;

        // mint an ERC721
        // erc721.mint(address(proOrdersAdapter), 4);

        // approve the item to seaport
        // vm.startPrank(address(proOrdersAdapter));
        // erc721.setApprovalForAll(address(seaport), true);
        // vm.stopPrank();

        vm.startPrank(vasa);
        weth.transfer(bob, 2000000000000000);
        vm.stopPrank();

        vm.startPrank(bob);
        weth.approve(conduit, type(uint256).max);
        weth.approve(address(proOrdersAdapter), type(uint256).max);
        vm.stopPrank();

        {
            // create a new array to store bytes32 hashes of identifiers
            bytes32[] memory hashedIdentifiers = new bytes32[](10000);
            for (uint256 i = 0; i < 10000; i++) {
                // hash identifier and store to generate proof
                hashedIdentifiers[i] = keccak256(abi.encode(i));
            }

            root = merkle.getRoot(hashedIdentifiers);
            criteriaProof = merkle.getProof(hashedIdentifiers, tokenId);
        }

        {
            uint256 counter = seaport.getCounter(bob);

            OfferItem[] memory offerItems = new OfferItem[](1);
            offerItems[0] = OfferItem(
                ItemType.ERC20,
                address(weth),
                0,
                2000000000000000,
                2000000000000000
            );

            ConsiderationItem[]
                memory considerationItems = new ConsiderationItem[](2);
            considerationItems[0] = ConsiderationItem(
                ItemType.ERC721_WITH_CRITERIA,
                address(apeERC721),
                uint256(root),
                2,
                2,
                payable(bob)
            );
            considerationItems[1] = ConsiderationItem(
                ItemType.ERC20,
                address(weth),
                0,
                (1000000000000000 - 500000000000000) * 2,
                (1000000000000000 - 500000000000000) * 2,
                payable(bob)
            );

            ConsiderationItem[]
                memory orderComponentsConsiderationItems = new ConsiderationItem[](
                    1
                );
            orderComponentsConsiderationItems[0] = ConsiderationItem(
                ItemType.ERC721_WITH_CRITERIA,
                address(apeERC721),
                uint256(root),
                2,
                2,
                payable(bob)
            );

            OrderComponents memory orderComponents = OrderComponents(
                bob,
                address(testZone),
                offerItems,
                orderComponentsConsiderationItems,
                OrderType.PARTIAL_RESTRICTED,
                0,
                ~uint256(0),
                emptyZoneHash,
                0,
                conduitKey,
                counter
            );

            bytes32 orderHash = seaport.getOrderHash(orderComponents);

            bytes memory signature = signOrder(
                ConsiderationInterface(address(seaport)),
                bobPk,
                orderHash
            );

            OrderParameters memory orderParameters = OrderParameters(
                bob, // 0x00
                address(testZone), // 0x20
                offerItems, // 0x40
                considerationItems, // 0x60
                OrderType.PARTIAL_RESTRICTED, // 0x80
                0, // 0xa0
                ~uint256(0), // 0xc0
                emptyZoneHash, // 0xe0
                0, // 0x100
                conduitKey, // 0x120
                1 // 0x140
            );

            advancedOrders[0] = AdvancedOrder(
                orderParameters,
                1,
                2,
                signature,
                "0x" // hex"1010"
            );
        }

        ///////////////////////////

        {
            uint256 counter = seaport.getCounter(address(proOrdersAdapter));

            OfferItem[] memory offerItems = new OfferItem[](1);
            offerItems[0] = OfferItem(
                ItemType.ERC721,
                address(apeERC721),
                tokenId,
                1,
                1
            );

            ConsiderationItem[]
                memory considerationItems = new ConsiderationItem[](1);
            considerationItems[0] = ConsiderationItem(
                ItemType.ERC20,
                address(weth),
                0,
                500000000000000,
                500000000000000,
                payable(address(proOrdersAdapter))
            );

            OrderComponents memory orderComponents = OrderComponents(
                address(proOrdersAdapter),
                address(testZone),
                offerItems,
                considerationItems,
                OrderType.CONTRACT,
                0,
                ~uint256(0),
                emptyZoneHash,
                0,
                emptyConduitKey,
                counter
            );

            bytes32 orderHash = seaport.getOrderHash(orderComponents);

            bytes memory signature = signOrder(
                ConsiderationInterface(address(seaport)),
                alicePk,
                orderHash
            );

            OrderParameters memory orderParameters = OrderParameters(
                address(proOrdersAdapter), // 0x00
                address(testZone), // 0x20
                offerItems, // 0x40
                considerationItems, // 0x60
                OrderType.CONTRACT, // 0x80
                0, // 0xa0
                ~uint256(0), // 0xc0
                emptyZoneHash, // 0xe0
                0, // 0x100
                emptyConduitKey, // 0x120
                1 // 0x140
            );

            advancedOrders[1] = AdvancedOrder(
                orderParameters,
                1,
                1,
                signature,
                "0x"
            );
        }

        ////////////////////////////

        {
            FulfillmentComponent[]
                memory offerComponents = new FulfillmentComponent[](1);
            FulfillmentComponent[]
                memory considerationComponents = new FulfillmentComponent[](1);

            offerComponents[0] = FulfillmentComponent(0, 0);
            considerationComponents[0] = FulfillmentComponent(1, 0);

            fulfillments[0] = Fulfillment(
                offerComponents,
                considerationComponents
            );
        }

        {
            FulfillmentComponent[]
                memory offerComponents = new FulfillmentComponent[](1);
            FulfillmentComponent[]
                memory considerationComponents = new FulfillmentComponent[](1);

            offerComponents[0] = FulfillmentComponent(1, 0);
            considerationComponents[0] = FulfillmentComponent(0, 0);

            fulfillments[1] = Fulfillment(
                offerComponents,
                considerationComponents
            );
        }

        {
            FulfillmentComponent[]
                memory offerComponents = new FulfillmentComponent[](1);
            FulfillmentComponent[]
                memory considerationComponents = new FulfillmentComponent[](1);

            offerComponents[0] = FulfillmentComponent(0, 0);
            considerationComponents[0] = FulfillmentComponent(0, 1);

            fulfillments[2] = Fulfillment(
                offerComponents,
                considerationComponents
            );
        }

        {
            criteriaResolvers[0] = CriteriaResolver(
                0,
                Side.CONSIDERATION,
                0,
                tokenId,
                criteriaProof
            );
        }

        // We would want to send the trx on behalf of vasa
        vm.startPrank(vasa);

        seaport.matchAdvancedOrders(
            advancedOrders,
            criteriaResolvers,
            fulfillments,
            address(0)
        );
    }

    function testMatchAdvancedOrders_4() public {
        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](3);
        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](1);
        Fulfillment[] memory fulfillments = new Fulfillment[](3);
        bytes32[] memory criteriaProof;
        uint256 tokenId = 1537;
        bytes32 root;

        // mint an ERC721
        // erc721.mint(address(proOrdersAdapter), 4);

        // approve the item to seaport
        // vm.startPrank(address(proOrdersAdapter));
        // erc721.setApprovalForAll(address(seaport), true);
        // vm.stopPrank();

        vm.startPrank(vasa);
        weth.transfer(bob, 2000000000000000);
        vm.stopPrank();

        vm.startPrank(bob);
        weth.approve(conduit, type(uint256).max);
        weth.approve(address(proOrdersAdapter), type(uint256).max);
        vm.stopPrank();

        vm.deal(address(faucet), 1 ether);

        {
            // create a new array to store bytes32 hashes of identifiers
            bytes32[] memory hashedIdentifiers = new bytes32[](10000);
            for (uint256 i = 0; i < 10000; i++) {
                // hash identifier and store to generate proof
                hashedIdentifiers[i] = keccak256(abi.encode(i));
            }

            root = merkle.getRoot(hashedIdentifiers);
            criteriaProof = merkle.getProof(hashedIdentifiers, tokenId);
        }

        {
            bytes32 zoneHash = keccak256(abi.encode(0, 1000000000000000, 0));

            OfferItem[] memory offerItems = new OfferItem[](1);
            offerItems[0] = OfferItem(
                ItemType.ERC20,
                address(weth),
                0,
                2000000000000000,
                2000000000000000
            );

            ConsiderationItem[]
                memory considerationItems = new ConsiderationItem[](2);
            considerationItems[0] = ConsiderationItem(
                ItemType.ERC721_WITH_CRITERIA,
                address(apeERC721),
                uint256(root),
                2,
                2,
                payable(bob)
            );
            considerationItems[1] = ConsiderationItem(
                ItemType.ERC20,
                address(weth),
                0,
                (1000000000000000 - 500000000000000) * 2,
                (1000000000000000 - 500000000000000) * 2,
                payable(bob)
            );

            ConsiderationItem[]
                memory orderComponentsConsiderationItems = new ConsiderationItem[](
                    1
                );
            orderComponentsConsiderationItems[0] = ConsiderationItem(
                ItemType.ERC721_WITH_CRITERIA,
                address(apeERC721),
                uint256(root),
                2,
                2,
                payable(bob)
            );

            bytes32 orderHash = seaport.getOrderHash(
                OrderComponents(
                    bob,
                    address(testZone),
                    offerItems,
                    orderComponentsConsiderationItems,
                    OrderType.PARTIAL_RESTRICTED,
                    0,
                    ~uint256(0),
                    zoneHash,
                    0,
                    conduitKey,
                    seaport.getCounter(bob)
                )
            );

            ReceivedItem[] memory receivedItems = new ReceivedItem[](2);
            receivedItems[0] = ReceivedItem(
                ItemType.ERC721,
                address(apeERC721),
                tokenId,
                1,
                payable(bob)
            );
            receivedItems[1] = ReceivedItem(
                ItemType.ERC20,
                address(weth),
                0,
                500000000000000,
                payable(bob)
            );

            bytes memory signature = signOrder(
                ConsiderationInterface(address(seaport)),
                bobPk,
                orderHash
            );

            bytes memory serverSideSignature = _generateServerSideSignature(
                testZone,
                SignedZone.SignedOrder(
                    vasa,
                    type(uint64).max,
                    orderHash,
                    keccak256(abi.encode(receivedItems))
                ),
                serverSignerPk
            );

            emit TestZoneSignerEvent(
                testZone.hashSignedOrder(
                    SignedZone.SignedOrder(
                        vasa,
                        type(uint64).max,
                        orderHash,
                        keccak256(abi.encode(receivedItems))
                    )
                ),
                serverSideSignature
            );
            bytes memory extraData = abi.encode(
                ProOrderExtraData(
                    vasa,
                    0,
                    1000000000000000,
                    0,
                    type(uint64).max,
                    orderHash,
                    keccak256(abi.encode(receivedItems)),
                    serverSideSignature
                )
            );

            advancedOrders[0] = AdvancedOrder(
                OrderParameters(
                    bob, // 0x00
                    address(testZone), // 0x20
                    offerItems, // 0x40
                    considerationItems, // 0x60
                    OrderType.PARTIAL_RESTRICTED, // 0x80
                    0, // 0xa0
                    ~uint256(0), // 0xc0
                    zoneHash, // 0xe0
                    0, // 0x100
                    conduitKey, // 0x120
                    1 // 0x140
                ),
                1,
                2,
                signature,
                extraData
            );
        }

        ////////////////////////////

        {
            uint256 counter = seaport.getCounter(address(faucet));
            uint256 price = 500000000000000;

            OfferItem[] memory offerItems = new OfferItem[](0);
            // offerItems[0] = OfferItem(
            //     ItemType.NATIVE,
            //     address(0),
            //     0,
            //     500000000000000,
            //     500000000000000
            // );

            ConsiderationItem[]
                memory considerationItems = new ConsiderationItem[](1);
            considerationItems[0] = ConsiderationItem(
                ItemType.ERC20,
                address(weth),
                0,
                price,
                price,
                payable(address(faucet))
            );

            OrderComponents memory orderComponents = OrderComponents(
                address(faucet),
                address(testZone),
                offerItems,
                considerationItems,
                OrderType.CONTRACT,
                0,
                ~uint256(0),
                emptyZoneHash,
                0,
                emptyConduitKey,
                counter
            );

            bytes32 orderHash = seaport.getOrderHash(orderComponents);

            OrderParameters memory orderParameters = OrderParameters(
                address(faucet), // 0x00
                address(testZone), // 0x20
                offerItems, // 0x40
                considerationItems, // 0x60
                OrderType.CONTRACT, // 0x80
                0, // 0xa0
                ~uint256(0), // 0xc0
                emptyZoneHash, // 0xe0
                0, // 0x100
                emptyConduitKey, // 0x120
                1 // 0x140
            );

            advancedOrders[1] = AdvancedOrder(
                orderParameters,
                1,
                1,
                hex"",
                abi.encodePacked(price)
            );
        }

        ///////////////////////////

        {
            uint256 counter = seaport.getCounter(address(proOrdersAdapter));
            uint256 price = 500000000000000;

            OfferItem[] memory offerItems = new OfferItem[](1);
            offerItems[0] = OfferItem(
                ItemType.ERC721,
                address(apeERC721),
                tokenId,
                1,
                1
            );

            ConsiderationItem[]
                memory considerationItems = new ConsiderationItem[](0);
            // considerationItems[0] = ConsiderationItem(
            //     ItemType.NATIVE,
            //     address(0),
            //     0,
            //     500000000000000,
            //     500000000000000,
            //     payable(address(proOrdersAdapter))
            // );

            OrderComponents memory orderComponents = OrderComponents(
                address(proOrdersAdapter),
                address(testZone),
                offerItems,
                considerationItems,
                OrderType.CONTRACT,
                0,
                ~uint256(0),
                emptyZoneHash,
                0,
                emptyConduitKey,
                counter
            );

            bytes32 orderHash = seaport.getOrderHash(orderComponents);

            bytes memory signature = signOrder(
                ConsiderationInterface(address(seaport)),
                alicePk,
                orderHash
            );

            OrderParameters memory orderParameters = OrderParameters(
                address(proOrdersAdapter), // 0x00
                address(testZone), // 0x20
                offerItems, // 0x40
                considerationItems, // 0x60
                OrderType.CONTRACT, // 0x80
                0, // 0xa0
                ~uint256(0), // 0xc0
                emptyZoneHash, // 0xe0
                0, // 0x100
                emptyConduitKey, // 0x120
                0 // 0x140
            );

            // LooksRareEthBuy memory looksRareEthBuy = LooksRareEthBuy(
            //     tokenId,
            //     price,
            //     262,
            //     1678202520,
            //     1680794498,
            //     9800,
            //     1,
            //     27,
            //     bytes32(
            //         0x2f781d90b279ea589f6fd867ca34f68687aa79ead3b5f5ed30bf8b141134ee26
            //     ),
            //     bytes32(
            //         0x45052e9e620e6fd5d3c8cffddabf9021e2306883d54bfb058e9a12849129b196
            //     ),
            //     address(apeERC721),
            //     0x073Ab1C0CAd3677cDe9BDb0cDEEDC2085c029579,
            //     0x579af6FD30BF83a5Ac0D636bc619f98DBdeb930c,
            //     true
            // );

            advancedOrders[2] = AdvancedOrder(
                orderParameters,
                1,
                1,
                signature,
                hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000059728544b08ab483533076417fbbb2fd0b17ce3a00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000001c6bf5263400000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000344b4e4b296000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a38d17ef017a314ccd72b8f199c0e108ef7ca04c0000000000000000000000000000000000000000000000000001c6bf526340000000000000000000000000000000000000000000000000000000000000000601000000000000000000000000000000000000000000000000000000000000264800000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000073ab1c0cad3677cde9bdb0cdeedc2085c029579000000000000000000000000d07e72b00431af84ad438ca995fd9a7f0207542d0000000000000000000000000000000000000000000000000001c6bf5263400000000000000000000000000000000000000000000000000000000000000006010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000579af6fd30bf83a5ac0d636bc619f98dbdeb930c000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000000000000000000106000000000000000000000000000000000000000000000000000000006407569800000000000000000000000000000000000000000000000000000000642ee38200000000000000000000000000000000000000000000000000000000000026480000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001b2f781d90b279ea589f6fd867ca34f68687aa79ead3b5f5ed30bf8b141134ee2645052e9e620e6fd5d3c8cffddabf9021e2306883d54bfb058e9a12849129b196000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
            );
        }

        ////////////////////////////

        {
            FulfillmentComponent[]
                memory offerComponents = new FulfillmentComponent[](1);
            FulfillmentComponent[]
                memory considerationComponents = new FulfillmentComponent[](1);

            offerComponents[0] = FulfillmentComponent(2, 0);
            considerationComponents[0] = FulfillmentComponent(0, 0);

            fulfillments[0] = Fulfillment(
                offerComponents,
                considerationComponents
            );
        }

        {
            FulfillmentComponent[]
                memory offerComponents = new FulfillmentComponent[](1);
            FulfillmentComponent[]
                memory considerationComponents = new FulfillmentComponent[](1);

            offerComponents[0] = FulfillmentComponent(0, 0);
            considerationComponents[0] = FulfillmentComponent(0, 1);

            fulfillments[1] = Fulfillment(
                offerComponents,
                considerationComponents
            );
        }

        {
            FulfillmentComponent[]
                memory offerComponents = new FulfillmentComponent[](1);
            FulfillmentComponent[]
                memory considerationComponents = new FulfillmentComponent[](1);

            offerComponents[0] = FulfillmentComponent(0, 0);
            considerationComponents[0] = FulfillmentComponent(1, 0);

            fulfillments[2] = Fulfillment(
                offerComponents,
                considerationComponents
            );
        }

        {
            criteriaResolvers[0] = CriteriaResolver(
                0,
                Side.CONSIDERATION,
                0,
                tokenId,
                criteriaProof
            );
        }

        // We would want to send the trx on behalf of vasa
        vm.startPrank(vasa);

        seaport.matchAdvancedOrders(
            advancedOrders,
            criteriaResolvers,
            fulfillments,
            address(0)
        );
    }

    event TestZoneSignerEvent(bytes32 hash, bytes signature);
}
