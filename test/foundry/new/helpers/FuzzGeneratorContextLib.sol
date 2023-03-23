// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";
import { LibPRNG } from "solady/src/utils/LibPRNG.sol";
import "seaport-sol/SeaportSol.sol";

import { TestHelpers } from "./FuzzTestContextLib.sol";

import { Account } from "../BaseOrderTest.sol";
import { TestERC1155 } from "../../../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../../../contracts/test/TestERC20.sol";
import { TestERC721 } from "../../../../contracts/test/TestERC721.sol";
import {
    HashValidationZoneOfferer
} from "../../../../contracts/test/HashValidationZoneOfferer.sol";
import { Conduit } from "../../../../contracts/conduit/Conduit.sol";

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
    TestERC20[] erc20s;
    TestERC721[] erc721s;
    TestERC1155[] erc1155s;
    address self;
    address caller;
    Account offerer;
    Account alice;
    Account bob;
    Account carol;
    Account dillon;
    Account eve;
    Account frank;
    TestConduit[] conduits;
    uint256 starting721offerIndex;
    uint256 starting721considerationIndex;
    uint256[] potential1155TokenIds;
    bytes32[] orderHashes;
}

library FuzzGeneratorContextLib {
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
                self: address(this),
                caller: address(this), // TODO: read recipient from FuzzTestContext
                offerer: testHelpers.makeAccount("offerer"),
                alice: testHelpers.makeAccount("alice"),
                bob: testHelpers.makeAccount("bob"),
                carol: testHelpers.makeAccount("carol"),
                dillon: testHelpers.makeAccount("dillon"),
                eve: testHelpers.makeAccount("eve"),
                frank: testHelpers.makeAccount("frank"),
                conduits: new TestConduit[](2),
                starting721offerIndex: 0,
                starting721considerationIndex: 0,
                potential1155TokenIds: potential1155TokenIds,
                orderHashes: new bytes32[](0)
            });
    }

    function from(
        Vm vm,
        SeaportInterface seaport,
        ConduitControllerInterface conduitController,
        TestERC20[] memory erc20s,
        TestERC721[] memory erc721s,
        TestERC1155[] memory erc1155s
    ) internal returns (FuzzGeneratorContext memory) {
        LibPRNG.PRNG memory prng = LibPRNG.PRNG({ state: 0 });

        uint256[] memory potential1155TokenIds = new uint256[](3);
        potential1155TokenIds[0] = 1;
        potential1155TokenIds[1] = 2;
        potential1155TokenIds[2] = 3;

        TestHelpers testHelpers = TestHelpers(address(this));

        TestConduit[] memory conduits = new TestConduit[](2);
        conduits[0] = _createConduit(conduitController, seaport, uint96(1));
        conduits[1] = _createConduit(conduitController, seaport, uint96(2));

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
                validatorZone: new HashValidationZoneOfferer(address(0)),
                self: address(this),
                caller: address(this), // TODO: read recipient from FuzzTestContext
                offerer: testHelpers.makeAccount("offerer"),
                alice: testHelpers.makeAccount("alice"),
                bob: testHelpers.makeAccount("bob"),
                carol: testHelpers.makeAccount("carol"),
                dillon: testHelpers.makeAccount("dillon"),
                eve: testHelpers.makeAccount("eve"),
                frank: testHelpers.makeAccount("frank"),
                conduits: conduits,
                starting721offerIndex: 0,
                starting721considerationIndex: 0,
                potential1155TokenIds: potential1155TokenIds,
                orderHashes: new bytes32[](0)
            });
    }

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
