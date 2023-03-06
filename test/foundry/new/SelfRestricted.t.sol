// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "./BaseOrderTest.sol";
import { SeaportInterface } from "seaport-sol/SeaportInterface.sol";
import { OrderLib } from "seaport-sol/lib/SeaportStructLib.sol";
import "seaport-sol/SeaportStructs.sol";
import "seaport-sol/SeaportEnums.sol";

contract SelfRestrictedTest is BaseOrderTest {
    function setUp() public virtual override {
        super.setUp();
    }

    function testSelfFulfillRestricted() public {
        setUpSelfFulfillRestricted();
        test(this.execSelfFulfillRestricted, Context({ seaport: seaport }));
        test(
            this.execSelfFulfillRestricted,
            Context({ seaport: referenceSeaport })
        );
    }

    function setUpSelfFulfillRestricted() internal { }

    function execSelfFulfillRestricted(Context memory context)
        external
        stateless
    { }
}
