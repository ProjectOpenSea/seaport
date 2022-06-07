// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

contract Reenterer {
    address public target;
    uint256 public msgValue;
    bytes public callData;

    event Reentered(bytes returnData);

    receive() external payable {
        (bool success, bytes memory returnData) = target.call{
            value: msgValue
        }(callData);

        if (!success) {
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        emit Reentered(returnData);
    }

    function prepare(
        address targetToUse,
        uint256 msgValueToUse,
        bytes calldata callDataToUse
    ) external {
        target = targetToUse;
        msgValue = msgValueToUse;
        callData = callDataToUse;
    }
}
