// SPDX-License-Identifier: MIT

pragma solidity >=0.8.13;

import { BaseConsiderationTest } from "./utils/BaseConsiderationTest.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";

import { OrderParameters } from "../../contracts/lib/ConsiderationStructs.sol";
import { ConsiderationInterface } from "../../contracts/interfaces/ConsiderationInterface.sol";
import { Test } from "forge-std/Test.sol";

import { GettersAndDerivers } from "../../contracts/lib/GettersAndDerivers.sol";
import { DigestHelper } from  "../../contracts/helpers/DigestHelper.sol";
import { OrderHashHelper } from  "../../contracts/helpers/OrderHashHelper.sol";

interface GetterAndDeriver {
    function deriveOrderHash(
        OrderParameters memory orderParameters,
        uint256 counter
    ) external returns (bytes32 orderHash);

    function domainSeparator() external returns (bytes32);

    function deriveEIP712Digest(bytes32 _domainSeparator_, bytes32 orderHash)
        external
        returns (bytes32 value);
}

contract GettersAndDeriversImpl is GetterAndDeriver, GettersAndDerivers {
    constructor(address conduitController)
        GettersAndDerivers(conduitController)
    {}

    function _nameString() internal pure override returns (string memory) {
        // Return the name of the contract.
        return "Seaport";
    }

    function deriveOrderHash(
        OrderParameters memory orderParameters,
        uint256 counter
    ) public view returns (bytes32 orderHash) {
        return _deriveOrderHash(orderParameters, counter);
    }

    function domainSeparator() public view returns (bytes32) {
        return _domainSeparator();
    }

    function deriveEIP712Digest(bytes32 _domainSeparator_, bytes32 orderHash)
        public
        pure
        returns (bytes32 value)
    {
        return _deriveEIP712Digest(_domainSeparator_, orderHash);
    }
}

contract OrderDigestHelper is BaseOrderTest, OrderHashHelper, DigestHelper {
    GetterAndDeriver getterAndDeriver;

    constructor(
        GetterAndDeriver _getterAndDeriver,
        ConsiderationInterface _consideration
    ) DigestHelper(address(_getterAndDeriver)) {
        getterAndDeriver = _getterAndDeriver;
        vm.label(address(getterAndDeriver), "getterAndDeriver");
        consideration = _consideration;
    }

    function testOrderHash() public {
        // configure baseOrderParameters with null address as offerer
        configureOrderParameters(alice);
        uint256 counter = consideration.getCounter(alice);
        _configureOrderComponents(counter);
        bytes32 orderHash = consideration.getOrderHash(
            baseOrderComponents
        );
        bytes32 helperOrderHash = OrderHashHelper.deriveOrderHash(
            baseOrderParameters, 
            counter
        );
        assertEq(orderHash, helperOrderHash);
    }

    function testDigest() public {
        // create order where alice is offerer
        configureOrderParameters(alice);
        _configureOrderComponents(consideration.getCounter(alice));
        bytes32 orderHash = consideration.getOrderHash(baseOrderComponents);

        bytes32 domainSeparator = getterAndDeriver.domainSeparator();
        bytes32 digest = getterAndDeriver.deriveEIP712Digest(
            domainSeparator,
            orderHash
        );

        bytes32 helperDigest = deriveEIP712Digest(orderHash);
        assertEq(digest, helperDigest);
    }
}

contract OrderDigestHelperTest is BaseOrderTest {
    function test(function() external fn) internal {
        try fn() {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testDigest() public {
        GetterAndDeriver getterAndDeriver = GetterAndDeriver(
            new GettersAndDeriversImpl(address(conduitController))
        );
        OrderDigestHelper logic = new OrderDigestHelper(
            getterAndDeriver,
            consideration
        );
        logic.testDigest();
    }

    function testOrderHash() public {
        GetterAndDeriver getterAndDeriver = GetterAndDeriver(
            new GettersAndDeriversImpl(address(conduitController))
        );
        OrderDigestHelper logic = new OrderDigestHelper(
            getterAndDeriver,
            consideration
        );
        logic.testOrderHash();
    }
}
