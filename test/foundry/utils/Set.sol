// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

contract Set {
    mapping(bytes32 => bool) _includes;
    SetType public setType;
    bytes32[] public bytes32Elements;
    uint256[] public uintElements;
    address[] public addressElements;
    string[] public stringElements;
    bytes[] public bytesElements;

    enum SetType {
        UINT,
        ADDRESS,
        BYTES32,
        STRING,
        BYTES
    }

    constructor(SetType _setType) {
        setType = _setType;
    }

    function includes(bytes32 key) public view returns (bool) {
        return _includes[key];
    }

    function includes(uint256 key) public view returns (bool) {
        return _includes[keccak256(abi.encode(key))];
    }

    function includes(address key) public view returns (bool) {
        return _includes[keccak256(abi.encode(key))];
    }

    function includes(string memory key) public view returns (bool) {
        return _includes[keccak256(abi.encode(key))];
    }

    function includes(bytes memory key) public view returns (bool) {
        return _includes[keccak256(abi.encode(key))];
    }

    function add(bytes32 key) public {
        if (setType == SetType.BYTES32) {
            _includes[keccak256(abi.encode(key))] = true;
        } else {
            revert("Cannot add BYTES32 to a non-BYTES32 set");
        }
        bytes32Elements.push(key);
    }

    function add(uint256 key) public {
        if (setType == SetType.UINT) {
            _includes[keccak256(abi.encode(key))] = true;
        } else {
            revert("Cannot add UINT to a non-UINT set");
        }
        uintElements.push(key);
    }

    function add(address key) public {
        if (setType == SetType.ADDRESS) {
            _includes[keccak256(abi.encode(key))] = true;
        } else {
            revert("Cannot add ADDRESS to a non-ADDRESS set");
        }
        addressElements.push(key);
    }

    function add(string memory key) public {
        if (setType == SetType.STRING) {
            _includes[keccak256(abi.encode(key))] = true;
        } else {
            revert("Cannot add string to a non-string set");
        }
        stringElements.push(key);
    }

    function add(bytes memory key) public {
        if (setType == SetType.BYTES) {
            _includes[keccak256(abi.encode(key))] = true;
        } else {
            revert("Cannot add bytes to a non-bytes set");
        }
        bytesElements.push(key);
    }
}
