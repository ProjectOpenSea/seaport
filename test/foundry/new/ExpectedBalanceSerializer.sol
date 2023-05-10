// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// import { vm } from "./VmUtils.sol"";

// import { ExpectedBalances } from  "./helpers/ExpectedBalances.sol";

// function tojsonAddress(
//     string memory objectKey,
//     string memory valueKey,
//     address value
// ) returns (string memory) {
//     return vm.serializeAddress(objectKey, valueKey, value);
// }

// function tojsonUint256(
//     string memory objectKey,
//     string memory valueKey,
//     uint256 value
// ) returns (string memory) {
//     return vm.serializeUint(objectKey, valueKey, value);
// }

// function tojsonERC20AccountDump(
//     string memory objectKey,
//     string memory valueKey,
//     ERC20AccountDump memory value
// ) returns (string memory) {
//     string memory obj = string.concat(objectKey, valueKey);
//     tojsonAddress(obj, "account", value.account);
//     string memory finalJson = tojsonUint256(obj, "balance", value.balance);
//     return vm.serializeString(objectKey, valueKey, finalJson);
// }

// function tojsonDynArrayERC20AccountDump(
//     string memory objectKey,
//     string memory valueKey,
//     ERC20AccountDump[] memory value
// ) returns (string memory) {
//     string memory obj = string.concat(objectKey, valueKey);
//     string memory out;
//     for (uint256 i; i < value.length; i++) {
//         out = tojsonERC20AccountDump(obj, vm.toString(i), value[i]);
//     }
//     return vm.serializeString(objectKey, valueKey, out);
// }

// function tojsonERC20TokenDump(
//     string memory objectKey,
//     string memory valueKey,
//     ERC20TokenDump memory value
// ) returns (string memory) {
//     string memory obj = string.concat(objectKey, valueKey);
//     tojsonAddress(obj, "token", value.token);
//     string memory finalJson = tojsonDynArrayERC20AccountDump(
//         obj,
//         "accounts",
//         value.accounts
//     );
//     return vm.serializeString(objectKey, valueKey, finalJson);
// }

// function tojsonDynArrayUint256(
//     string memory objectKey,
//     string memory valueKey,
//     uint256[] memory value
// ) returns (string memory) {
//     return vm.serializeUint(objectKey, valueKey, value);
// }

// function tojsonERC721AccountDump(
//     string memory objectKey,
//     string memory valueKey,
//     ERC721AccountDump memory value
// ) returns (string memory) {
//     string memory obj = string.concat(objectKey, valueKey);
//     tojsonAddress(obj, "account", value.account);
//     string memory finalJson = tojsonDynArrayUint256(
//         obj,
//         "identifiers",
//         value.identifiers
//     );
//     return vm.serializeString(objectKey, valueKey, finalJson);
// }

// function tojsonDynArrayERC721AccountDump(
//     string memory objectKey,
//     string memory valueKey,
//     ERC721AccountDump[] memory value
// ) returns (string memory) {
//     string memory obj = string.concat(objectKey, valueKey);
//     uint256 length = value.length;
//     string memory out;
//     for (uint256 i; i < length; i++) {
//         out = tojsonERC721AccountDump(obj, vm.toString(i), value[i]);
//     }
//     return vm.serializeString(objectKey, valueKey, out);
// }

// function tojsonERC721TokenDump(
//     string memory objectKey,
//     string memory valueKey,
//     ERC721TokenDump memory value
// ) returns (string memory) {
//     string memory obj = string.concat(objectKey, valueKey);
//     tojsonAddress(obj, "token", value.token);
//     string memory finalJson = tojsonDynArrayERC721AccountDump(
//         obj,
//         "accounts",
//         value.accounts
//     );
//     return vm.serializeString(objectKey, valueKey, finalJson);
// }

// function tojsonERC1155IdentifierDump(
//     string memory objectKey,
//     string memory valueKey,
//     ERC1155IdentifierDump memory value
// ) returns (string memory) {
//     string memory obj = string.concat(objectKey, valueKey);
//     tojsonUint256(obj, "identifier", value.identifier);
//     string memory finalJson = tojsonUint256(obj, "balance", value.balance);
//     return vm.serializeString(objectKey, valueKey, finalJson);
// }

// function tojsonDynArrayERC1155IdentifierDump(
//     string memory objectKey,
//     string memory valueKey,
//     ERC1155IdentifierDump[] memory value
// ) returns (string memory) {
//     string memory obj = string.concat(objectKey, valueKey);
//     uint256 length = value.length;
//     string memory out;
//     for (uint256 i; i < length; i++) {
//         out = tojsonERC1155IdentifierDump(obj, vm.toString(i), value[i]);
//     }
//     return vm.serializeString(objectKey, valueKey, out);
// }

// function tojsonERC1155AccountDump(
//     string memory objectKey,
//     string memory valueKey,
//     ERC1155AccountDump memory value
// ) returns (string memory) {
//     string memory obj = string.concat(objectKey, valueKey);
//     tojsonAddress(obj, "account", value.account);
//     string memory finalJson = tojsonDynArrayERC1155IdentifierDump(
//         obj,
//         "identifiers",
//         value.identifiers
//     );
//     return vm.serializeString(objectKey, valueKey, finalJson);
// }

// function tojsonDynArrayERC1155AccountDump(
//     string memory objectKey,
//     string memory valueKey,
//     ERC1155AccountDump[] memory value
// ) returns (string memory) {
//     string memory obj = string.concat(objectKey, valueKey);
//     uint256 length = value.length;
//     string memory out;
//     for (uint256 i; i < length; i++) {
//         out = tojsonERC1155AccountDump(obj, vm.toString(i), value[i]);
//     }
//     return vm.serializeString(objectKey, valueKey, out);
// }

// function tojsonERC1155TokenDump(
//     string memory objectKey,
//     string memory valueKey,
//     ERC1155TokenDump memory value
// ) returns (string memory) {
//     string memory obj = string.concat(objectKey, valueKey);
//     tojsonAddress(obj, "token", value.token);
//     string memory finalJson = tojsonDynArrayERC1155AccountDump(
//         obj,
//         "accounts",
//         value.accounts
//     );
//     return vm.serializeString(objectKey, valueKey, finalJson);
// }

// function tojsonDynArrayERC20TokenDump(
//     string memory objectKey,
//     string memory valueKey,
//     ERC20TokenDump[] memory value
// ) returns (string memory) {
//     string memory obj = string.concat(objectKey, valueKey);
//     uint256 length = value.length;
//     string memory out;
//     for (uint256 i; i < length; i++) {
//         out = tojsonERC20TokenDump(obj, vm.toString(i), value[i]);
//     }
//     return vm.serializeString(objectKey, valueKey, out);
// }

// function tojsonDynArrayERC721TokenDump(
//     string memory objectKey,
//     string memory valueKey,
//     ERC721TokenDump[] memory value
// ) returns (string memory) {
//     string memory obj = string.concat(objectKey, valueKey);
//     uint256 length = value.length;
//     string memory out;
//     for (uint256 i; i < length; i++) {
//         out = tojsonERC721TokenDump(obj, vm.toString(i), value[i]);
//     }
//     return vm.serializeString(objectKey, valueKey, out);
// }

// function tojsonDynArrayERC1155TokenDump(
//     string memory objectKey,
//     string memory valueKey,
//     ERC1155TokenDump[] memory value
// ) returns (string memory) {
//     string memory obj = string.concat(objectKey, valueKey);
//     uint256 length = value.length;
//     string memory out;
//     for (uint256 i; i < length; i++) {
//         out = tojsonERC1155TokenDump(obj, vm.toString(i), value[i]);
//     }
//     return vm.serializeString(objectKey, valueKey, out);
// }

// function tojsonExpectedBalancesDump(
//     string memory objectKey,
//     string memory valueKey,
//     ExpectedBalancesDump memory value
// ) returns (string memory) {
//     string memory obj = string.concat(objectKey, valueKey);
//     tojsonDynArrayERC20TokenDump(obj, "erc20", value.erc20);
//     tojsonDynArrayERC721TokenDump(obj, "erc721", value.erc721);
//     string memory finalJson = tojsonDynArrayERC1155TokenDump(
//         obj,
//         "erc1155",
//         value.erc1155
//     );
//     return vm.serializeString(objectKey, valueKey, finalJson);
// }
