// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";

import { StdCheats } from "forge-std/StdCheats.sol";

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import { MatchComponent } from "seaport-sol/src/SeaportSol.sol";

import { ItemType } from "seaport-sol/src/SeaportEnums.sol";

import {
    Amount,
    BasicOrderCategory,
    Criteria,
    TokenIndex
} from "seaport-sol/src/SpaceEnums.sol";

import { OfferItemSpace } from "seaport-sol/src/StructSpace.sol";

import { SeaportInterface } from "seaport-sol/src/SeaportInterface.sol";

import { EIP1271Offerer } from "./EIP1271Offerer.sol";

import {
    ConduitControllerInterface
} from "seaport-sol/src/ConduitControllerInterface.sol";

import { TestHelpers } from "./FuzzTestContextLib.sol";

import { TestERC20 } from "../../../../contracts/test/TestERC20.sol";

import { TestERC721 } from "../../../../contracts/test/TestERC721.sol";

import { TestERC1155 } from "../../../../contracts/test/TestERC1155.sol";

import {
    HashValidationZoneOfferer
} from "../../../../contracts/test/HashValidationZoneOfferer.sol";

import {
    HashCalldataContractOfferer
} from "../../../../contracts/test/HashCalldataContractOfferer.sol";

import { Conduit } from "seaport-core/src/conduit/Conduit.sol";

import {
    HashValidationZoneOfferer
} from "../../../../contracts/test/HashValidationZoneOfferer.sol";

import { setLabel } from "./Labeler.sol";

struct TestConduit {
    address addr;
    bytes32 key;
}

struct FuzzGeneratorContext {
    Vm vm;
    TestHelpers testHelpers;
    LibPRNG.PRNG prng;
    uint256 timestamp;
    SeaportInterface seaport;
    ConduitControllerInterface conduitController;
    HashValidationZoneOfferer validatorZone;
    HashCalldataContractOfferer contractOfferer;
    EIP1271Offerer eip1271Offerer;
    TestERC20[] erc20s;
    TestERC721[] erc721s;
    TestERC1155[] erc1155s;
    address self;
    address caller;
    StdCheats.Account alice;
    StdCheats.Account bob;
    StdCheats.Account carol;
    StdCheats.Account dillon;
    StdCheats.Account eve;
    StdCheats.Account frank;
    TestConduit[] conduits;
    uint256 starting721offerIndex;
    uint256 starting721considerationIndex;
    uint256[] potential1155TokenIds;
    BasicOrderCategory basicOrderCategory;
    OfferItemSpace basicOfferSpace;
    uint256 counter;
    uint256 contractOffererNonce;
}

library FuzzGeneratorContextLib {
    /**
     * @dev Create a new, empty FuzzGeneratorContext. This function is used
     *      mostly in tests. To create a usable context, use `from` instead.
     */
    function empty() internal returns (FuzzGeneratorContext memory) {
        LibPRNG.PRNG memory prng = LibPRNG.PRNG({ state: 0 });

        uint256[] memory potential1155TokenIds = new uint256[](3);
        potential1155TokenIds[0] = 1;
        potential1155TokenIds[1] = 2;
        potential1155TokenIds[2] = 3;

        TestHelpers testHelpers = TestHelpers(address(this));

        return
            FuzzGeneratorContext({
                vm: Vm(address(0)),
                seaport: SeaportInterface(address(0)),
                conduitController: ConduitControllerInterface(address(0)),
                erc20s: new TestERC20[](0),
                erc721s: new TestERC721[](0),
                erc1155s: new TestERC1155[](0),
                prng: prng,
                testHelpers: testHelpers,
                timestamp: block.timestamp,
                validatorZone: new HashValidationZoneOfferer(address(0)),
                contractOfferer: new HashCalldataContractOfferer(address(0)),
                eip1271Offerer: new EIP1271Offerer(),
                self: address(this),
                caller: address(this),
                alice: testHelpers.makeAccountWrapper("alice"),
                bob: testHelpers.makeAccountWrapper("bob"),
                carol: testHelpers.makeAccountWrapper("carol"),
                dillon: testHelpers.makeAccountWrapper("dillon"),
                eve: testHelpers.makeAccountWrapper("eve"),
                frank: testHelpers.makeAccountWrapper("frank"),
                conduits: new TestConduit[](2),
                starting721offerIndex: 0,
                starting721considerationIndex: 0,
                potential1155TokenIds: potential1155TokenIds,
                basicOrderCategory: BasicOrderCategory.NONE,
                basicOfferSpace: OfferItemSpace(
                    ItemType.NATIVE,
                    TokenIndex.ONE,
                    Criteria.MERKLE,
                    Amount.FIXED
                ),
                counter: 0,
                contractOffererNonce: 0
            });
    }

    /**
     * @dev Create a new FuzzGeneratorContext from the given parameters.
     */
    function from(
        Vm vm,
        SeaportInterface seaport,
        ConduitControllerInterface conduitController,
        TestERC20[] memory erc20s,
        TestERC721[] memory erc721s,
        TestERC1155[] memory erc1155s
    ) internal returns (FuzzGeneratorContext memory) {
        // Get a new PRNG lib.Account
        LibPRNG.PRNG memory prng = LibPRNG.PRNG({ state: 0 });

        // Create a list of potential 1155 token IDs.
        uint256[] memory potential1155TokenIds = new uint256[](3);
        potential1155TokenIds[0] = 1;
        potential1155TokenIds[1] = 2;
        potential1155TokenIds[2] = 3;

        // Create a new TestHelpers instance.  The helpers get passed around the
        // test suite through the context.
        TestHelpers testHelpers = TestHelpers(address(this));

        // Set up the conduits.
        TestConduit[] memory conduits = new TestConduit[](2);
        conduits[0] = _createConduit(conduitController, seaport, uint96(1));
        conduits[1] = _createConduit(conduitController, seaport, uint96(2));

        HashValidationZoneOfferer validatorZone = new HashValidationZoneOfferer(
            address(0)
        );
        HashCalldataContractOfferer contractOfferer = new HashCalldataContractOfferer(
                address(seaport)
            );
        EIP1271Offerer eip1271Offerer = new EIP1271Offerer();

        setLabel(address(validatorZone), "validatorZone");
        setLabel(address(contractOfferer), "contractOfferer");
        setLabel(address(eip1271Offerer), "eip1271Offerer");

        return
            FuzzGeneratorContext({
                vm: vm,
                seaport: seaport,
                conduitController: conduitController,
                erc20s: erc20s,
                erc721s: erc721s,
                erc1155s: erc1155s,
                prng: prng,
                testHelpers: testHelpers,
                timestamp: block.timestamp,
                validatorZone: validatorZone,
                contractOfferer: contractOfferer,
                eip1271Offerer: eip1271Offerer,
                self: address(this),
                caller: address(this),
                alice: testHelpers.makeAccountWrapper("alice"),
                bob: testHelpers.makeAccountWrapper("bob"),
                carol: testHelpers.makeAccountWrapper("carol"),
                dillon: testHelpers.makeAccountWrapper("dillon"),
                eve: testHelpers.makeAccountWrapper("eve"),
                frank: testHelpers.makeAccountWrapper("frank"),
                conduits: conduits,
                starting721offerIndex: 0,
                starting721considerationIndex: 0,
                potential1155TokenIds: potential1155TokenIds,
                basicOrderCategory: BasicOrderCategory.NONE,
                basicOfferSpace: OfferItemSpace(
                    ItemType.NATIVE,
                    TokenIndex.ONE,
                    Criteria.MERKLE,
                    Amount.FIXED
                ),
                counter: 0,
                contractOffererNonce: 0
            });
    }

    /**
     * @dev Internal helper used to create a new conduit based on the salt.
     */
    function _createConduit(
        ConduitControllerInterface conduitController,
        SeaportInterface seaport,
        uint96 conduitSalt
    ) internal returns (TestConduit memory) {
        bytes32 conduitKey = abi.decode(
            abi.encodePacked(address(this), conduitSalt),
            (bytes32)
        );
        Conduit conduit = Conduit(
            conduitController.createConduit(conduitKey, address(this))
        );
        conduitController.updateChannel(
            address(conduit),
            address(seaport),
            true
        );
        return TestConduit({ addr: address(conduit), key: conduitKey });
    }
}
