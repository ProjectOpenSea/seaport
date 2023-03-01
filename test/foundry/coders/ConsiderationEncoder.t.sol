// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";
import "../helpers/sol/BaseTest.sol";

import "../../../contracts/lib/ConsiderationConstants.sol";

import "../../../contracts/lib/ConsiderationStructs.sol";

import {
    ConsiderationEncoder
} from "../../../contracts/lib/ConsiderationEncoder.sol";

import {
    ContractOffererInterface
} from "../../../contracts/interfaces/ContractOffererInterface.sol";
import "../../../contracts/interfaces/ZoneInterface.sol";
import {
    ReferenceOrderValidator
} from "../../../reference/lib/ReferenceOrderValidator.sol";

import "./SpecialCases.sol";

contract ConduitControllerShim {
    function getConduitCodeHashes()
        external
        view
        returns (bytes32 creationCodeHash, bytes32 runtimeCodeHash)
    {}
}

function _convertToSpentAndReceived(
  OfferItem[] memory offer,
  ConsiderationItem[] memory consideration
) pure returns (SpentItem[] memory spent, ReceivedItem[] memory received) {
  spent = new SpentItem[](offer.length);
  received = new ReceivedItem[](consideration.length);
  for (uint256 i; i < offer.length; i++) {
    spent[i] = SpentItem({
        itemType: offer[i].itemType,
        token: offer[i].token,
        identifier: offer[i].identifierOrCriteria,
        amount: offer[i].startAmount
    });
  }
  for (uint256 i; i < consideration.length; i++) {
    received[i] = ReceivedItem({
          itemType: consideration[i].itemType,
          token: consideration[i].token,
          identifier:                 consideration[i].identifierOrCriteria,
          amount: consideration[i].startAmount,
          recipient: consideration[i].recipient
    });
  }
}

enum MemChange {
  None,
  SwapOffer,
  SwapConsideration
}

contract TestEncoder is ConsiderationEncoder, SpecialCases {
    function _returnBytes(MemoryPointer dst, uint256 size) internal pure {
        assembly {
            mstore(sub(dst, 32), size)
            mstore(sub(dst, 64), 0x20)
            return(sub(dst, 64), add(size, 0x40))
        }
    }

    function encodeGenerateOrder(
        OrderParameters memory orderParameters,
        bytes memory context
    ) external view returns (bytes memory) {
        (MemoryPointer dst, uint256 size) = _encodeGenerateOrder(
            orderParameters,
            context
        );
        _returnBytes(dst, size);
    }

    function encodeRatifyOrder(
        bytes32 orderHash, // e.g. shl(0x60, offerer) ^ contract nonce
        OrderParameters memory orderParameters,
        bytes memory context, // encoded based on the schemaID
        bytes32[] memory orderHashes,
        uint256 shiftedOfferer
    ) external view returns (bytes memory) {
        for (uint256 i; i < orderParameters.consideration.length; i++) {
            _setEndAmountRecipient(orderParameters.consideration[i]);
        }
        (MemoryPointer dst, uint256 size) = _encodeRatifyOrder(
            orderHash,
            orderParameters,
            context,
            orderHashes,
            shiftedOfferer
        );
        _returnBytes(dst, size);
    }

    function encodeValidateOrder(
        bytes32 orderHash,
        OrderParameters memory orderParameters,
        bytes memory extraData,
        bytes32[] memory orderHashes
    ) external view returns (bytes memory) {
        for (uint256 i; i < orderParameters.consideration.length; i++) {
            _setEndAmountRecipient(orderParameters.consideration[i]);
        }
        (MemoryPointer dst, uint256 size) = _encodeValidateOrder(
            orderHash,
            orderParameters,
            extraData,
            orderHashes
        );
        _returnBytes(dst, size);
    }
}

contract TestReferenceEncoder is
    ReferenceOrderValidator(address(new ConduitControllerShim()))
{
    function encodeGenerateOrder(
        OrderParameters memory orderParameters,
        bytes memory context
    ) external view returns (bytes memory) {
        (
            SpentItem[] memory originalOfferItems,
            SpentItem[] memory originalConsiderationItems
        ) = _convertToSpent(
                orderParameters.offer,
                orderParameters.consideration
            );

        return
            abi.encodeWithSelector(
                ContractOffererInterface.generateOrder.selector,
                msg.sender,
                originalOfferItems,
                originalConsiderationItems,
                context
            );
    }

    function encodeValidateOrder(
        bytes32 orderHash,
        OrderParameters memory orderParameters,
        bytes memory extraData,
        bytes32[] memory orderHashes
    ) external view returns (bytes memory) {
      (
        SpentItem[] memory spent,
        ReceivedItem[] memory received
    ) = _convertToSpentAndReceived(
            orderParameters.offer,
            orderParameters.consideration
        );
      return abi.encodeWithSelector(
        ZoneInterface.validateOrder.selector,
        ZoneParameters({
          orderHash: orderHash,
          fulfiller: msg.sender,
          offerer: orderParameters.offerer,
          offer: spent,
          consideration: received,
          extraData: extraData,
          orderHashes: orderHashes,
          startTime: orderParameters.startTime,
          endTime: orderParameters.endTime,
          zoneHash: orderParameters.zoneHash
        })
      );
    }

    function encodeRatifyOrder(
        bytes32 orderHash, // e.g. shl(0x60, offerer) ^ contract nonce
        OrderParameters memory orderParameters,
        bytes memory context, // encoded based on the schemaID
        bytes32[] memory orderHashes,
        uint256 shiftedOfferer
    ) external view returns (bytes memory) {
      (
        SpentItem[] memory spent,
        ReceivedItem[] memory received
    ) = _convertToSpentAndReceived(
            orderParameters.offer,
            orderParameters.consideration
        );

        return
            abi.encodeWithSelector(
                ContractOffererInterface.ratifyOrder.selector,
                spent,
                received,
                context,
                orderHashes,
                shiftedOfferer ^ uint256(orderHash)
            );
    }
}

contract ConsiderationEncoderTest is BaseTest {
    TestEncoder testEncoder;
    TestReferenceEncoder refEncoder;

    function setUp() public override {
        testEncoder = new TestEncoder();
        refEncoder = new TestReferenceEncoder();
    }

    function testEncodeGenerateOrder(
        OrderParametersBlob memory orderParametersBlob,
        bytes memory context
    ) external {
        // vm.assume(orderParametersBlob.offer.length > 0);
        // vm.assume(orderParametersBlob.consideration.length > 0);
        OrderParameters memory orderParameters = _fromBlob(orderParametersBlob);

        assertEq(
            testEncoder.encodeGenerateOrder(orderParameters, context),
            refEncoder.encodeGenerateOrder(orderParameters, context)
        );
    }

    function testEncodeRatifyOrder(
        bytes32 orderHash, // e.g. shl(0x60, offerer) ^ contract nonce
        OrderParametersBlob memory orderParametersBlob,
        bytes memory context, // encoded based on the schemaID
        bytes32[] memory orderHashes,
        uint256 shiftedOfferer
    ) external {
        // vm.assume(orderParametersBlob.offer.length > 0);
        // vm.assume(orderParametersBlob.consideration.length > 0);
        vm.assume(orderHashes.length > 0);
        // vm.assume(context.length > 0);
        OrderParameters memory orderParameters = _fromBlob(orderParametersBlob);

        assertEq(
            testEncoder.encodeRatifyOrder(
                orderHash,
                orderParameters,
                context,
                orderHashes,
                shiftedOfferer
            ),
            refEncoder.encodeRatifyOrder(
                orderHash,
                orderParameters,
                context,
                orderHashes,
                shiftedOfferer
            )
        );
    }

    function testEncodeValidateOrder(
        bytes32 orderHash,
        OrderParametersBlob memory orderParametersBlob,
        bytes memory extraData,
        bytes32[] memory orderHashes
    ) external {
        // vm.assume(orderParametersBlob.offer.length > 0);
        // vm.assume(orderParametersBlob.consideration.length > 0);
        vm.assume(orderHashes.length > 0);
        // vm.assume(context.length > 0);
        OrderParameters memory orderParameters = _fromBlob(orderParametersBlob);

        assertEq(
            testEncoder.encodeValidateOrder(
                orderHash,
                orderParameters,
                extraData,
                orderHashes
            ),
            refEncoder.encodeValidateOrder(
                orderHash,
                orderParameters,
                extraData,
                orderHashes
            )
        );
    }
}
