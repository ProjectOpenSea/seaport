// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

/// @notice A slim logging utility
contract XConsole {
    address constant CONSOLE_ADDRESS =
        address(0x000000000000000000636F6e736F6c652e6c6f67);

    function _sendLogPayload(bytes memory payload) private view {
        uint256 payloadLength = payload.length;
        address consoleAddress = CONSOLE_ADDRESS;
        assembly {
            let payloadStart := add(payload, 32)
            let r := staticcall(
                gas(),
                consoleAddress,
                payloadStart,
                payloadLength,
                0,
                0
            )
        }
    }

    function log() public view {
        _sendLogPayload(abi.encodeWithSignature("log()"));
    }

    function logInt(int256 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(int)", p0));
    }

    function logUint(uint256 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
    }

    function logString(string memory p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(string)", p0));
    }

    function logBool(bool p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
    }

    function logAddress(address p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(address)", p0));
    }

    function logBytes(bytes memory p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes)", p0));
    }

    function logBytes1(bytes1 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes1)", p0));
    }

    function logBytes2(bytes2 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes2)", p0));
    }

    function logBytes3(bytes3 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes3)", p0));
    }

    function logBytes4(bytes4 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes4)", p0));
    }

    function logBytes5(bytes5 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes5)", p0));
    }

    function logBytes6(bytes6 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes6)", p0));
    }

    function logBytes7(bytes7 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes7)", p0));
    }

    function logBytes8(bytes8 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes8)", p0));
    }

    function logBytes9(bytes9 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes9)", p0));
    }

    function logBytes10(bytes10 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes10)", p0));
    }

    function logBytes11(bytes11 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes11)", p0));
    }

    function logBytes12(bytes12 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes12)", p0));
    }

    function logBytes13(bytes13 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes13)", p0));
    }

    function logBytes14(bytes14 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes14)", p0));
    }

    function logBytes15(bytes15 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes15)", p0));
    }

    function logBytes16(bytes16 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes16)", p0));
    }

    function logBytes17(bytes17 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes17)", p0));
    }

    function logBytes18(bytes18 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes18)", p0));
    }

    function logBytes19(bytes19 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes19)", p0));
    }

    function logBytes20(bytes20 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes20)", p0));
    }

    function logBytes21(bytes21 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes21)", p0));
    }

    function logBytes22(bytes22 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes22)", p0));
    }

    function logBytes23(bytes23 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes23)", p0));
    }

    function logBytes24(bytes24 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes24)", p0));
    }

    function logBytes25(bytes25 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes25)", p0));
    }

    function logBytes26(bytes26 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes26)", p0));
    }

    function logBytes27(bytes27 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes27)", p0));
    }

    function logBytes28(bytes28 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes28)", p0));
    }

    function logBytes29(bytes29 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes29)", p0));
    }

    function logBytes30(bytes30 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes30)", p0));
    }

    function logBytes31(bytes31 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes31)", p0));
    }

    function logBytes32(bytes32 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes32)", p0));
    }

    function log(uint256 p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
    }

    function log(string memory p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(string)", p0));
    }

    function log(bool p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
    }

    function log(address p0) public view {
        _sendLogPayload(abi.encodeWithSignature("log(address)", p0));
    }

    function log(uint256 p0, uint256 p1) public view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint)", p0, p1));
    }

    function log(uint256 p0, string memory p1) public view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string)", p0, p1));
    }

    function log(uint256 p0, bool p1) public view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool)", p0, p1));
    }

    function log(uint256 p0, address p1) public view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address)", p0, p1));
    }

    function log(string memory p0, uint256 p1) public view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint)", p0, p1));
    }

    function log(string memory p0, string memory p1) public view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string)", p0, p1));
    }

    function log(string memory p0, bool p1) public view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool)", p0, p1));
    }

    function log(string memory p0, address p1) public view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address)", p0, p1));
    }

    function log(bool p0, uint256 p1) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint)", p0, p1));
    }

    function log(bool p0, string memory p1) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string)", p0, p1));
    }

    function log(bool p0, bool p1) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool)", p0, p1));
    }

    function log(bool p0, address p1) public view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address)", p0, p1));
    }

    function log(address p0, uint256 p1) public view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint)", p0, p1));
    }

    function log(address p0, string memory p1) public view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string)", p0, p1));
    }

    function log(address p0, bool p1) public view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool)", p0, p1));
    }

    function log(address p0, address p1) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(address,address)", p0, p1)
        );
    }

    function log(
        uint256 p0,
        uint256 p1,
        uint256 p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(uint,uint,uint)", p0, p1, p2)
        );
    }

    function log(
        uint256 p0,
        uint256 p1,
        string memory p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(uint,uint,string)", p0, p1, p2)
        );
    }

    function log(
        uint256 p0,
        uint256 p1,
        bool p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(uint,uint,bool)", p0, p1, p2)
        );
    }

    function log(
        uint256 p0,
        uint256 p1,
        address p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(uint,uint,address)", p0, p1, p2)
        );
    }

    function log(
        uint256 p0,
        string memory p1,
        uint256 p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(uint,string,uint)", p0, p1, p2)
        );
    }

    function log(
        uint256 p0,
        string memory p1,
        string memory p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(uint,string,string)", p0, p1, p2)
        );
    }

    function log(
        uint256 p0,
        string memory p1,
        bool p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(uint,string,bool)", p0, p1, p2)
        );
    }

    function log(
        uint256 p0,
        string memory p1,
        address p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(uint,string,address)", p0, p1, p2)
        );
    }

    function log(
        uint256 p0,
        bool p1,
        uint256 p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(uint,bool,uint)", p0, p1, p2)
        );
    }

    function log(
        uint256 p0,
        bool p1,
        string memory p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(uint,bool,string)", p0, p1, p2)
        );
    }

    function log(
        uint256 p0,
        bool p1,
        bool p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(uint,bool,bool)", p0, p1, p2)
        );
    }

    function log(
        uint256 p0,
        bool p1,
        address p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(uint,bool,address)", p0, p1, p2)
        );
    }

    function log(
        uint256 p0,
        address p1,
        uint256 p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(uint,address,uint)", p0, p1, p2)
        );
    }

    function log(
        uint256 p0,
        address p1,
        string memory p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(uint,address,string)", p0, p1, p2)
        );
    }

    function log(
        uint256 p0,
        address p1,
        bool p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(uint,address,bool)", p0, p1, p2)
        );
    }

    function log(
        uint256 p0,
        address p1,
        address p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(uint,address,address)", p0, p1, p2)
        );
    }

    function log(
        string memory p0,
        uint256 p1,
        uint256 p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(string,uint,uint)", p0, p1, p2)
        );
    }

    function log(
        string memory p0,
        uint256 p1,
        string memory p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(string,uint,string)", p0, p1, p2)
        );
    }

    function log(
        string memory p0,
        uint256 p1,
        bool p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(string,uint,bool)", p0, p1, p2)
        );
    }

    function log(
        string memory p0,
        uint256 p1,
        address p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(string,uint,address)", p0, p1, p2)
        );
    }

    function log(
        string memory p0,
        string memory p1,
        uint256 p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(string,string,uint)", p0, p1, p2)
        );
    }

    function log(
        string memory p0,
        string memory p1,
        string memory p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(string,string,string)", p0, p1, p2)
        );
    }

    function log(
        string memory p0,
        string memory p1,
        bool p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(string,string,bool)", p0, p1, p2)
        );
    }

    function log(
        string memory p0,
        string memory p1,
        address p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(string,string,address)", p0, p1, p2)
        );
    }

    function log(
        string memory p0,
        bool p1,
        uint256 p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(string,bool,uint)", p0, p1, p2)
        );
    }

    function log(
        string memory p0,
        bool p1,
        string memory p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(string,bool,string)", p0, p1, p2)
        );
    }

    function log(
        string memory p0,
        bool p1,
        bool p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(string,bool,bool)", p0, p1, p2)
        );
    }

    function log(
        string memory p0,
        bool p1,
        address p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(string,bool,address)", p0, p1, p2)
        );
    }

    function log(
        string memory p0,
        address p1,
        uint256 p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(string,address,uint)", p0, p1, p2)
        );
    }

    function log(
        string memory p0,
        address p1,
        string memory p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(string,address,string)", p0, p1, p2)
        );
    }

    function log(
        string memory p0,
        address p1,
        bool p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(string,address,bool)", p0, p1, p2)
        );
    }

    function log(
        string memory p0,
        address p1,
        address p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(string,address,address)", p0, p1, p2)
        );
    }

    function log(
        bool p0,
        uint256 p1,
        uint256 p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(bool,uint,uint)", p0, p1, p2)
        );
    }

    function log(
        bool p0,
        uint256 p1,
        string memory p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(bool,uint,string)", p0, p1, p2)
        );
    }

    function log(
        bool p0,
        uint256 p1,
        bool p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(bool,uint,bool)", p0, p1, p2)
        );
    }

    function log(
        bool p0,
        uint256 p1,
        address p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(bool,uint,address)", p0, p1, p2)
        );
    }

    function log(
        bool p0,
        string memory p1,
        uint256 p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(bool,string,uint)", p0, p1, p2)
        );
    }

    function log(
        bool p0,
        string memory p1,
        string memory p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(bool,string,string)", p0, p1, p2)
        );
    }

    function log(
        bool p0,
        string memory p1,
        bool p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(bool,string,bool)", p0, p1, p2)
        );
    }

    function log(
        bool p0,
        string memory p1,
        address p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(bool,string,address)", p0, p1, p2)
        );
    }

    function log(
        bool p0,
        bool p1,
        uint256 p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(bool,bool,uint)", p0, p1, p2)
        );
    }

    function log(
        bool p0,
        bool p1,
        string memory p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(bool,bool,string)", p0, p1, p2)
        );
    }

    function log(
        bool p0,
        bool p1,
        bool p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(bool,bool,bool)", p0, p1, p2)
        );
    }

    function log(
        bool p0,
        bool p1,
        address p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(bool,bool,address)", p0, p1, p2)
        );
    }

    function log(
        bool p0,
        address p1,
        uint256 p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(bool,address,uint)", p0, p1, p2)
        );
    }

    function log(
        bool p0,
        address p1,
        string memory p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(bool,address,string)", p0, p1, p2)
        );
    }

    function log(
        bool p0,
        address p1,
        bool p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(bool,address,bool)", p0, p1, p2)
        );
    }

    function log(
        bool p0,
        address p1,
        address p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(bool,address,address)", p0, p1, p2)
        );
    }

    function log(
        address p0,
        uint256 p1,
        uint256 p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(address,uint,uint)", p0, p1, p2)
        );
    }

    function log(
        address p0,
        uint256 p1,
        string memory p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(address,uint,string)", p0, p1, p2)
        );
    }

    function log(
        address p0,
        uint256 p1,
        bool p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(address,uint,bool)", p0, p1, p2)
        );
    }

    function log(
        address p0,
        uint256 p1,
        address p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(address,uint,address)", p0, p1, p2)
        );
    }

    function log(
        address p0,
        string memory p1,
        uint256 p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(address,string,uint)", p0, p1, p2)
        );
    }

    function log(
        address p0,
        string memory p1,
        string memory p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(address,string,string)", p0, p1, p2)
        );
    }

    function log(
        address p0,
        string memory p1,
        bool p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(address,string,bool)", p0, p1, p2)
        );
    }

    function log(
        address p0,
        string memory p1,
        address p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(address,string,address)", p0, p1, p2)
        );
    }

    function log(
        address p0,
        bool p1,
        uint256 p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(address,bool,uint)", p0, p1, p2)
        );
    }

    function log(
        address p0,
        bool p1,
        string memory p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(address,bool,string)", p0, p1, p2)
        );
    }

    function log(
        address p0,
        bool p1,
        bool p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(address,bool,bool)", p0, p1, p2)
        );
    }

    function log(
        address p0,
        bool p1,
        address p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(address,bool,address)", p0, p1, p2)
        );
    }

    function log(
        address p0,
        address p1,
        uint256 p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(address,address,uint)", p0, p1, p2)
        );
    }

    function log(
        address p0,
        address p1,
        string memory p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(address,address,string)", p0, p1, p2)
        );
    }

    function log(
        address p0,
        address p1,
        address p2
    ) public view {
        _sendLogPayload(
            abi.encodeWithSignature("log(address,address,address)", p0, p1, p2)
        );
    }
}
