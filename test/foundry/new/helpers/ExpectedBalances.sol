// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {
    EnumerableMap
} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";

import { IERC1155 } from "@openzeppelin/contracts/interfaces/IERC1155.sol";

import { LibString } from "solady/src/utils/LibString.sol";

import { withLabel } from "./Labeler.sol";

import { Execution, ReceivedItem } from "seaport-sol/src/SeaportStructs.sol";

import { ItemType } from "seaport-sol/src/SeaportEnums.sol";

struct NativeAccountDump {
    address account;
    uint256 balance;
}

/* struct ERC20AccountDump {
    address account;
    uint256 balance;
} */

struct ERC20TokenDump {
    address token;
    // ERC20AccountDump[] accounts;
    address[] accounts;
    uint256[] balances;
}

// struct ERC721AccountDump {
//     address account;
//     uint256[] identifiers;
// }

struct ERC721TokenDump {
    address token;
    address[] accounts;
    uint256[][] accountIdentifiers;
}

/* struct ERC1155IdentifierDump {
    uint256 identifier;
    uint256 balance;
}
 */
struct ERC1155AccountDump {
    address account;
    uint256[] identifiers;
    uint256[] balances;
}
// ERC1155IdentifierDump[] identifiers;

struct ERC1155TokenDump {
    address token;
    ERC1155AccountDump[] accounts;
}
// address[] accounts;
// uint256[][] accountIdentifiers;
// uint256[][] accountBalances;
// ERC1155AccountDump[] accounts;

struct ExpectedBalancesDump {
    ERC20TokenDump[] erc20;
    ERC721TokenDump[] erc721;
    ERC1155TokenDump[] erc1155;
}

/**
 * @dev Helper library for generating balance related error messages.
 */
library BalanceErrorMessages {
    function unexpectedAmountErrorMessage(
        string memory errorSummary,
        address token,
        address account,
        uint256 expected,
        uint256 actual
    ) internal pure returns (string memory) {
        return
            string.concat(
                errorSummary,
                "\n token: ",
                withLabel(token),
                "\n account: ",
                withLabel(account),
                "\n expected: ",
                LibString.toString(expected),
                "\n actual: ",
                LibString.toString(actual),
                "\n"
            );
    }

    function unexpectedAmountErrorMessage(
        string memory errorSummary,
        address token,
        uint256 identifier,
        address account,
        uint256 expected,
        uint256 actual
    ) internal pure returns (string memory) {
        return
            string.concat(
                errorSummary,
                "\n token: ",
                withLabel(token),
                "\n identifier: ",
                LibString.toString(identifier),
                "\n account: ",
                withLabel(account),
                "\n expected: ",
                LibString.toString(expected),
                "\n actual: ",
                LibString.toString(actual),
                "\n"
            );
    }

    function nativeUnexpectedBalance(
        address account,
        uint256 expectedBalance,
        uint256 actualBalance
    ) internal pure returns (string memory) {
        return
            unexpectedAmountErrorMessage(
                "ExpectedBalances: Unexpected native balance",
                address(0),
                account,
                expectedBalance,
                actualBalance
            );
    }

    function erc20UnexpectedBalance(
        address token,
        address account,
        uint256 expectedBalance,
        uint256 actualBalance
    ) internal pure returns (string memory) {
        return
            unexpectedAmountErrorMessage(
                "ExpectedBalances: Unexpected ERC20 balance",
                token,
                account,
                expectedBalance,
                actualBalance
            );
    }

    function erc721UnexpectedBalance(
        address token,
        address account,
        uint256 expectedBalance,
        uint256 actualBalance
    ) internal pure returns (string memory) {
        return
            unexpectedAmountErrorMessage(
                "ExpectedBalances: Unexpected ERC721 balance",
                token,
                account,
                expectedBalance,
                actualBalance
            );
    }

    function erc1155UnexpectedBalance(
        address token,
        address account,
        uint256 identifier,
        uint256 expectedBalance,
        uint256 actualBalance
    ) internal pure returns (string memory) {
        return
            unexpectedAmountErrorMessage(
                "ExpectedBalances: Unexpected ERC1155 balance for ID",
                token,
                identifier,
                account,
                expectedBalance,
                actualBalance
            );
    }

    function insufficientBalance(
        string memory prefix,
        address account,
        address recipient,
        uint256 balance,
        uint256 amount,
        bool derived
    ) internal pure returns (string memory) {
        return
            string.concat(
                prefix,
                "\n from: ",
                withLabel(account),
                derived ? "\n balance (derived): " : "\n balance (actual): ",
                LibString.toString(balance),
                "\n transfer amount: ",
                LibString.toString(amount),
                "\n to: ",
                withLabel(recipient),
                "\n"
            );
    }

    function insufficientNativeBalance(
        address account,
        address recipient,
        uint256 balance,
        uint256 amount,
        bool derived
    ) internal pure returns (string memory) {
        return
            insufficientBalance(
                "ExpectedBalances: Insufficient native balance for transfer",
                account,
                recipient,
                balance,
                amount,
                derived
            );
    }

    function insufficientERC20Balance(
        address token,
        address account,
        address recipient,
        uint256 balance,
        uint256 amount,
        bool derived
    ) internal pure returns (string memory) {
        return
            insufficientBalance(
                string.concat(
                    "ExpectedBalances: Insufficient ERC20 balance for transfer\n token: ",
                    withLabel(token)
                ),
                account,
                recipient,
                balance,
                amount,
                derived
            );
    }

    function insufficientERC1155Balance(
        address token,
        uint256 identifier,
        address account,
        address recipient,
        uint256 balance,
        uint256 amount,
        bool derived
    ) internal pure returns (string memory) {
        return
            insufficientBalance(
                string.concat(
                    "ExpectedBalances: Insufficient ERC1155 balance for transfer\n token: ",
                    withLabel(token),
                    "\n identifier: ",
                    LibString.toString(identifier)
                ),
                account,
                recipient,
                balance,
                amount,
                derived
            );
    }
}

contract Subtractor {
    string internal tokenKind;

    constructor(string memory _tokenKind) {
        tokenKind = _tokenKind;
    }
}

/**
 * @dev Helper contract for tracking, checking, and debugging native balances.
 */
contract NativeBalances {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    EnumerableMap.AddressToUintMap private accountsMap;

    function sub(
        address account,
        address recipient,
        uint256 balance,
        uint256 amount,
        bool derived
    ) private pure returns (uint256) {
        if (balance < amount) {
            revert(
                BalanceErrorMessages.insufficientNativeBalance(
                    account,
                    recipient,
                    balance,
                    amount,
                    derived
                )
            );
        }
        return balance - amount;
    }

    function addNativeTransfer(
        address from,
        address to,
        uint256 amount
    ) public {
        (bool fromExists, uint256 fromBalance) = accountsMap.tryGet(from);
        if (!fromExists) {
            fromBalance = from.balance;
        }
        accountsMap.set(from, sub(from, to, fromBalance, amount, fromExists));

        (bool toExists, uint256 toBalance) = accountsMap.tryGet(to);
        if (!toExists) {
            toBalance = to.balance;
        }
        accountsMap.set(to, toBalance + amount);
    }

    function checkNativeBalances() internal view {
        address[] memory accounts = accountsMap.keys();
        uint256 accountsLength = accounts.length;
        for (uint256 j; j < accountsLength; j++) {
            address account = accounts[j];
            uint256 expectedBalance = accountsMap.get(account);
            uint256 actualBalance = account.balance;
            if (expectedBalance != actualBalance) {
                revert(
                    BalanceErrorMessages.nativeUnexpectedBalance(
                        account,
                        expectedBalance,
                        actualBalance
                    )
                );
            }
        }
    }

    function dumpNativeBalances()
        public
        view
        returns (NativeAccountDump[] memory accountBalances)
    {
        address[] memory accounts = accountsMap.keys();
        accountBalances = new NativeAccountDump[](accounts.length);
        for (uint256 i; i < accounts.length; i++) {
            address account = accounts[i];
            accountBalances[i] = NativeAccountDump(
                account,
                accountsMap.get(account)
            );
        }
    }
}

/**
 * @dev Helper contract for tracking, checking, and debugging ERC20 balances.
 */
contract ERC20Balances {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private tokens;
    mapping(address => EnumerableMap.AddressToUintMap) private tokenAccounts;

    function sub(
        address token,
        address account,
        address recipient,
        uint256 balance,
        uint256 amount,
        bool derived
    ) private pure returns (uint256) {
        if (balance < amount) {
            revert(
                BalanceErrorMessages.insufficientERC20Balance(
                    token,
                    account,
                    recipient,
                    balance,
                    amount,
                    derived
                )
            );
        }
        return balance - amount;
    }

    function addERC20Transfer(
        address token,
        address from,
        address to,
        uint256 amount
    ) public {
        tokens.add(token);
        EnumerableMap.AddressToUintMap storage accounts = tokenAccounts[token];

        (bool fromExists, uint256 fromBalance) = accounts.tryGet(from);
        if (!fromExists) {
            fromBalance = IERC20(token).balanceOf(from);
        }
        accounts.set(
            from,
            sub(token, from, to, fromBalance, amount, fromExists)
        );

        (bool toExists, uint256 toBalance) = accounts.tryGet(to);
        if (!toExists) {
            toBalance = IERC20(token).balanceOf(to);
        }
        accounts.set(to, toBalance + amount);
    }

    function checkERC20Balances() internal view {
        uint256 length = tokens.length();
        for (uint256 i; i < length; i++) {
            address token = tokens.at(i);
            EnumerableMap.AddressToUintMap storage accountsMap = tokenAccounts[
                token
            ];
            address[] memory accounts = accountsMap.keys();
            uint256 accountsLength = accounts.length;
            for (uint256 j; j < accountsLength; j++) {
                address account = accounts[j];
                uint256 expectedBalance = accountsMap.get(account);
                uint256 actualBalance = IERC20(token).balanceOf(account);
                if (expectedBalance != actualBalance) {
                    revert(
                        BalanceErrorMessages.erc20UnexpectedBalance(
                            token,
                            account,
                            expectedBalance,
                            actualBalance
                        )
                    );
                }
            }
        }
    }

    function dumpERC20Balances()
        public
        view
        returns (ERC20TokenDump[] memory tokenDumps)
    {
        uint256 length = tokens.length();
        tokenDumps = new ERC20TokenDump[](length);
        for (uint256 i; i < length; i++) {
            address token = tokens.at(i);
            EnumerableMap.AddressToUintMap storage accountsMap = tokenAccounts[
                token
            ];
            address[] memory accounts = accountsMap.keys();
            ERC20TokenDump memory tokenDump = ERC20TokenDump({
                token: token,
                accounts: accounts,
                balances: new uint256[](accounts.length)
            });
            tokenDumps[i] = tokenDump;
            for (uint256 j; j < accounts.length; j++) {
                address account = accounts[j];
                tokenDump.balances[j] = accountsMap.get(account);
            }
        }
    }
}

/**
 * @dev Helper contract for tracking, checking, and debugging ERC721 balances.
 */
contract ERC721Balances {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    struct TokenData721 {
        mapping(address => EnumerableSet.UintSet) accountIdentifiers;
        EnumerableSet.UintSet touchedIdentifiers;
        EnumerableMap.AddressToUintMap accountBalances;
    }

    EnumerableSet.AddressSet private tokens;
    mapping(address => TokenData721) private tokenDatas;

    function addERC721Transfer(
        address token,
        address from,
        address to,
        uint256 identifier
    ) public {
        tokens.add(token);
        TokenData721 storage tokenData = tokenDatas[token];

        (bool fromExists, uint256 fromBalance) = tokenData
            .accountBalances
            .tryGet(from);
        if (!fromExists) {
            fromBalance = IERC721(token).balanceOf(from);
        }

        if (fromBalance == 0) {
            revert("ERC721Balances: sender does not have a balance");
        }

        tokenData.accountBalances.set(from, fromBalance - 1);

        (bool toExists, uint256 toBalance) = tokenData.accountBalances.tryGet(
            to
        );
        if (!toExists) {
            toBalance = IERC721(token).balanceOf(to);
        }
        tokenData.accountBalances.set(to, toBalance + 1);

        // If we have not seen the identifier before, assert that the sender owns it
        if (tokenData.touchedIdentifiers.add(identifier)) {
            require(
                IERC721(token).ownerOf(identifier) == from,
                "ExpectedBalances: sender does not own token"
            );
        } else {
            require(
                tokenData.accountIdentifiers[from].remove(identifier),
                "ExpectedBalances: sender does not own token"
            );
        }

        require(
            tokenData.accountIdentifiers[to].add(identifier),
            "ExpectedBalances: receiver already owns token"
        );
    }

    function checkERC721Balances() internal view {
        address[] memory tokensArray = tokens.values();

        uint256 length = tokensArray.length;

        for (uint256 i; i < length; i++) {
            address token = tokensArray[i];

            TokenData721 storage tokenData = tokenDatas[token];

            address[] memory accounts = tokenData.accountBalances.keys();

            uint256 accountsLength = accounts.length;

            for (uint256 j; j < accountsLength; j++) {
                address account = accounts[j];

                {
                    uint256 expectedBalance = tokenData.accountBalances.get(
                        account
                    );
                    uint256 actualBalance = IERC721(token).balanceOf(account);
                    if (actualBalance != expectedBalance) {
                        revert(
                            BalanceErrorMessages.erc721UnexpectedBalance(
                                token,
                                account,
                                expectedBalance,
                                actualBalance
                            )
                        );
                    }
                }

                uint256[] memory identifiers = tokenData
                    .accountIdentifiers[account]
                    .values();

                uint256 identifiersLength = identifiers.length;

                for (uint256 k; k < identifiersLength; k++) {
                    require(
                        IERC721(token).ownerOf(identifiers[k]) == account,
                        "ExpectedBalances: account does not own expected token"
                    );
                }
            }
        }
    }

    function dumpERC721Balances()
        public
        view
        returns (ERC721TokenDump[] memory tokenDumps)
    {
        address[] memory tokensArray;

        tokenDumps = new ERC721TokenDump[](tokensArray.length);

        for (uint256 i; i < tokensArray.length; i++) {
            tokenDumps[i] = dumpERC721Token(tokensArray[i]);
        }
    }

    function dumpERC721Token(
        address token
    ) internal view returns (ERC721TokenDump memory dump) {
        TokenData721 storage tokenData = tokenDatas[token];

        dump.accounts = tokenData.accountBalances.keys();
        uint256 accountsLength = dump.accounts.length;

        dump.token = token;
        for (uint256 i; i < accountsLength; i++) {
            address account = dump.accounts[i];

            dump.accountIdentifiers[i] = tokenData
                .accountIdentifiers[account]
                .values();
        }
    }
}

struct ERC1155TransferDetails {
    address token;
    address from;
    address to;
    uint256 identifier;
    uint256 amount;
}

/**
 * @dev Helper contract for tracking, checking, and debugging ERC721 balances.
 */
contract ERC1155Balances {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.UintToUintMap;

    struct TokenData1155 {
        EnumerableSet.AddressSet accounts;
        mapping(address => EnumerableMap.UintToUintMap) accountIdentifiers;
    }

    EnumerableSet.AddressSet private tokens;
    mapping(address => TokenData1155) private tokenDatas;

    function sub(
        ERC1155TransferDetails memory details,
        uint256 balance,
        bool derived
    ) private pure returns (uint256) {
        if (balance < details.amount) {
            revert(
                BalanceErrorMessages.insufficientERC1155Balance(
                    details.token,
                    details.identifier,
                    details.from,
                    details.to,
                    balance,
                    details.amount,
                    derived
                )
            );
        }
        return balance - details.amount;
    }

    function addERC1155Transfer(ERC1155TransferDetails memory details) public {
        tokens.add(details.token);

        TokenData1155 storage tokenData = tokenDatas[details.token];

        tokenData.accounts.add(details.from);
        tokenData.accounts.add(details.to);

        {
            EnumerableMap.UintToUintMap storage fromIdentifiers = tokenData
                .accountIdentifiers[details.from];
            (bool fromExists, uint256 fromBalance) = fromIdentifiers.tryGet(
                details.identifier
            );
            if (!fromExists) {
                fromBalance = IERC1155(details.token).balanceOf(
                    details.from,
                    details.identifier
                );
            }
            fromIdentifiers.set(
                details.identifier,
                sub(details, fromBalance, fromExists)
            );
        }

        {
            EnumerableMap.UintToUintMap storage toIdentifiers = tokenData
                .accountIdentifiers[details.to];
            (bool toExists, uint256 toBalance) = toIdentifiers.tryGet(
                details.identifier
            );
            if (!toExists) {
                toBalance = IERC1155(details.token).balanceOf(
                    details.to,
                    details.identifier
                );
            }
            toIdentifiers.set(details.identifier, toBalance + details.amount);
        }
    }

    function checkERC1155Balances() internal view {
        address[] memory tokensArray = tokens.values();

        uint256 length = tokensArray.length;

        // For each token...
        for (uint256 i; i < length; i++) {
            address token = tokensArray[i];

            TokenData1155 storage tokenData = tokenDatas[token];

            address[] memory accounts = tokenData.accounts.values();

            uint256 accountsLength = accounts.length;

            // For each account that has interacted with the token...
            for (uint256 j; j < accountsLength; j++) {
                address account = accounts[j];

                EnumerableMap.UintToUintMap
                    storage accountIdentifiers = tokenData.accountIdentifiers[
                        account
                    ];

                uint256[] memory identifiers = accountIdentifiers.keys();

                uint256 identifiersLength = identifiers.length;

                // For each identifier the account has interacted with,
                // assert their balance matches the expected balance.
                for (uint256 k; k < identifiersLength; k++) {
                    uint256 identifier = identifiers[k];
                    uint256 expectedBalance = accountIdentifiers.get(
                        identifier
                    );
                    uint256 actualBalance = IERC1155(token).balanceOf(
                        account,
                        identifier
                    );
                    if (expectedBalance != actualBalance) {
                        revert(
                            BalanceErrorMessages.erc1155UnexpectedBalance(
                                token,
                                account,
                                identifier,
                                expectedBalance,
                                actualBalance
                            )
                        );
                    }
                }
            }
        }
    }

    function dumpERC1155Balances()
        public
        view
        returns (ERC1155TokenDump[] memory tokenDumps)
    {
        address[] memory tokensArray = tokens.values();
        uint256 length = tokensArray.length;
        tokenDumps = new ERC1155TokenDump[](length);

        // For each token...
        for (uint256 i; i < length; i++) {
            address token = tokensArray[i];
            TokenData1155 storage tokenData = tokenDatas[token];
            uint256 accountsLength = tokenData.accounts.length();

            ERC1155TokenDump memory tokenDump = ERC1155TokenDump({
                token: token,
                accounts: new ERC1155AccountDump[](accountsLength)
            });
            tokenDumps[i] = tokenDump;

            for (uint256 j; j < accountsLength; j++) {
                address account = tokenData.accounts.at(j);

                EnumerableMap.UintToUintMap
                    storage accountIdentifiers = tokenData.accountIdentifiers[
                        account
                    ];

                uint256[] memory identifiers = accountIdentifiers.keys();

                uint256 identifiersLength = identifiers.length;

                ERC1155AccountDump memory accountDump = ERC1155AccountDump({
                    account: account,
                    identifiers: new uint256[](identifiersLength),
                    balances: new uint256[](identifiersLength)
                });
                tokenDump.accounts[j] = accountDump;

                for (uint256 k; k < identifiersLength; k++) {
                    uint256 identifier = identifiers[k];
                    accountDump.identifiers[k] = identifier;
                    accountDump.balances[k] = accountIdentifiers.get(
                        identifier
                    );
                }
            }
        }
    }
}

/**
 * @dev Combined helper contract for tracking and checking token balances.
 */
contract ExpectedBalances is
    NativeBalances,
    ERC20Balances,
    ERC721Balances,
    ERC1155Balances
{
    function addTransfer(Execution calldata execution) public {
        ReceivedItem memory item = execution.item;
        if (item.itemType == ItemType.NATIVE) {
            return
                addNativeTransfer(
                    execution.offerer,
                    item.recipient,
                    item.amount
                );
        }
        if (item.itemType == ItemType.ERC20) {
            return
                addERC20Transfer(
                    item.token,
                    execution.offerer,
                    item.recipient,
                    item.amount
                );
        }
        if (item.itemType == ItemType.ERC721) {
            return
                addERC721Transfer(
                    item.token,
                    execution.offerer,
                    item.recipient,
                    item.identifier
                );
        }
        if (item.itemType == ItemType.ERC1155) {
            return
                addERC1155Transfer(
                    ERC1155TransferDetails(
                        item.token,
                        execution.offerer,
                        item.recipient,
                        item.identifier,
                        item.amount
                    )
                );
        }
    }

    function addTransfers(Execution[] calldata executions) external {
        for (uint256 i; i < executions.length; i++) {
            addTransfer(executions[i]);
        }
    }

    function checkBalances() external view {
        checkNativeBalances();
        checkERC20Balances();
        checkERC721Balances();
        checkERC1155Balances();
    }
}
