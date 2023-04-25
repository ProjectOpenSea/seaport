// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import {
    EnumerableSet
} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {
    EnumerableMap
} from "openzeppelin-contracts/contracts/utils/structs/EnumerableMap.sol";

import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

import {
    IERC721
} from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";

import {
    IERC1155
} from "openzeppelin-contracts/contracts/interfaces/IERC1155.sol";

import { LibString } from "solady/src/utils/LibString.sol";

import { withLabel } from "./Labeler.sol";

import { Execution, ReceivedItem } from "seaport-sol/SeaportStructs.sol";

import { ItemType } from "seaport-sol/SeaportEnums.sol";
import { pureAssertEq } from "./VmUtils.sol";

struct AccountBalanceDump {
    address account;
    uint256 expected;
    uint256 original;
    int256 expectedDiff;
    int256 realDiff;
}

struct ERC20TokenDump {
    address token;
    AccountBalanceDump[] accounts;
    // AccountBalanceDump[] accounts;
    // address[] accounts;
    // uint256[] balances;
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
    // ERC1155IdentifierDump[] identifiers;
}

struct ERC1155TokenDump {
    address token;
    ERC1155AccountDump[] accounts;
    // address[] accounts;
    // uint256[][] accountIdentifiers;
    // uint256[][] accountBalances;
    // ERC1155AccountDump[] accounts;
}

struct ExpectedBalancesDump {
    ERC20TokenDump[] erc20;
    ERC721TokenDump[] erc721;
    ERC1155TokenDump[] erc1155;
}

function getDeltaString(
    uint256 expected,
    uint256 actual
) pure returns (string memory) {
    if (actual > expected) {
        return string.concat(" (+", LibString.toString(actual - expected), ")");
    }
    return string.concat(" (-", LibString.toString(expected - actual), ")");
}

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
                "\n actual:   ",
                LibString.toString(actual),
                getDeltaString(expected, actual),
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
                "\n actual:   ",
                LibString.toString(actual),
                getDeltaString(expected, actual),
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
        uint256 missing = amount - balance;
        return
            string.concat(
                prefix,
                "\n from: ",
                withLabel(account),
                derived ? "\n balance (derived): " : "\n balance (actual):  ",
                LibString.toString(balance),
                "\n transfer amount:   ",
                LibString.toString(amount),
                "\n to:                ",
                withLabel(recipient),
                "\n missing:           ",
                LibString.toString(missing),
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

abstract contract BalancesConfig {
    function treatAccountBalanceAsMaximum(
        address
    ) internal view virtual returns (bool);

    function treatBalancesAsMinMax() internal view virtual returns (bool);
}

abstract contract NativeBalances is BalancesConfig {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    EnumerableMap.AddressToUintMap private accountsMap;
    mapping(address => uint256) private originalBalances;

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
            originalBalances[from] = fromBalance;
        }
        accountsMap.set(from, sub(from, to, fromBalance, amount, fromExists));

        (bool toExists, uint256 toBalance) = accountsMap.tryGet(to);
        if (!toExists) {
            toBalance = to.balance;
            originalBalances[to] = toBalance;
        }
        accountsMap.set(to, toBalance + amount);
    }

    function checkNativeBalances() internal view {
        address[] memory accounts = accountsMap.keys();
        // uint256 accountsLength = accounts.length;
        for (uint256 j; j < accounts.length; j++) {
            // address account = accounts[j];
            // uint256 expectedBalance = accountsMap.get(account);
            // uint256 actualBalance = account.balance;
            if (treatBalancesAsMinMax()) {
                if (treatAccountBalanceAsMaximum(accounts[j])) {
                    /* require(
                        expectedBalance >= actualBalance,
                        BalanceErrorMessages.nativeUnexpectedBalance(
                            account,
                            expectedBalance,
                            actualBalance
                        )
                    ); */
                } else {
                    pureAssertEq(
                        accountsMap.get(accounts[j]) <= accounts[j].balance,
                        true,
                        BalanceErrorMessages.nativeUnexpectedBalance(
                            accounts[j],
                            accountsMap.get(accounts[j]),
                            accounts[j].balance
                        )
                    );
                }
            } else if (accountsMap.get(accounts[j]) != accounts[j].balance) {
                revert(
                    BalanceErrorMessages.nativeUnexpectedBalance(
                        accounts[j],
                        accountsMap.get(accounts[j]),
                        accounts[j].balance
                    )
                );
            }
        }
    }

    function dumpNativeBalances()
        public
        view
        returns (AccountBalanceDump[] memory accountBalances)
    {
        address[] memory accounts = accountsMap.keys();
        accountBalances = new AccountBalanceDump[](accounts.length);
        for (uint256 i; i < accounts.length; i++) {
            address account = accounts[i];
            accountBalances[i] = AccountBalanceDump({
                account: account,
                expected: accountsMap.get(account),
                original: originalBalances[account],
                expectedDiff: int256(accountsMap.get(account)) -
                    int256(originalBalances[account]),
                realDiff: int256(account.balance) -
                    int256(originalBalances[account])
            });
        }
    }
}

abstract contract ERC20Balances is BalancesConfig {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private tokens;
    mapping(address => EnumerableMap.AddressToUintMap) private tokenAccounts;
    mapping(address => mapping(address => uint256)) private originalBalances;

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
            originalBalances[token][from] = fromBalance;
        }
        accounts.set(
            from,
            sub(token, from, to, fromBalance, amount, fromExists)
        );

        (bool toExists, uint256 toBalance) = accounts.tryGet(to);
        if (!toExists) {
            toBalance = IERC20(token).balanceOf(to);
            originalBalances[token][to] = toBalance;
        }
        accounts.set(to, toBalance + amount);
    }

    function checkERC20Balances() internal view {
        // uint256 length = tokens.length();
        for (uint256 i; i < tokens.length(); i++) {
            // address token = tokens.at(i);
            EnumerableMap.AddressToUintMap storage accountsMap = tokenAccounts[
                tokens.at(i)
            ];
            address[] memory accounts = accountsMap.keys();
            // uint256 accountsLength = accounts.length;
            for (uint256 j; j < accounts.length; j++) {
                // address account = accounts[j];
                // uint256 expectedBalance = accountsMap.get(account);
                // uint256 actualBalance = IERC20(token).balanceOf(account);
                if (treatBalancesAsMinMax()) {
                    if (treatAccountBalanceAsMaximum(accounts[j])) {
                        /* require(
                            expectedBalance >= actualBalance,
                            BalanceErrorMessages.erc20UnexpectedBalance(
                                token,
                                account,
                                expectedBalance,
                                actualBalance
                            )
                        ); */
                    } else {
                        pureAssertEq(
                            accountsMap.get(accounts[j]) <=
                                IERC20(tokens.at(i)).balanceOf(accounts[j]),
                            true,
                            BalanceErrorMessages.erc20UnexpectedBalance(
                                tokens.at(i),
                                accounts[j],
                                accountsMap.get(accounts[j]),
                                IERC20(tokens.at(i)).balanceOf(accounts[j])
                            )
                        );
                    }
                } else if (
                    accountsMap.get(accounts[j]) !=
                    IERC20(tokens.at(i)).balanceOf(accounts[j])
                ) {
                    revert(
                        BalanceErrorMessages.erc20UnexpectedBalance(
                            tokens.at(i),
                            accounts[j],
                            accountsMap.get(accounts[j]),
                            IERC20(tokens.at(i)).balanceOf(accounts[j])
                        )
                    );
                }
            }
        }
    }

    function dumpERC20Balance(
        address token,
        address account
    ) public view returns (AccountBalanceDump memory) {
        EnumerableMap.AddressToUintMap storage accountsMap = tokenAccounts[
            token
        ];
        return
            AccountBalanceDump({
                account: account,
                expected: accountsMap.get(account),
                original: originalBalances[token][account],
                expectedDiff: int256(accountsMap.get(account)) -
                    int256(originalBalances[token][account]),
                realDiff: int256(account.balance) -
                    int256(originalBalances[token][account])
            });
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
                accounts: new AccountBalanceDump[](accounts.length)
            });
            tokenDumps[i] = tokenDump;
            for (uint256 j; j < accounts.length; j++) {
                address account = accounts[j];
                tokenDump.accounts[j] = dumpERC20Balance(token, account);
            }
        }
    }
}

abstract contract ERC721Balances is BalancesConfig {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    struct TokenData721 {
        // EnumerableSet.AddressSet accounts;
        mapping(address => EnumerableSet.UintSet) accountIdentifiers;
        EnumerableSet.UintSet touchedIdentifiers;
        EnumerableMap.AddressToUintMap accountBalances;
    }
    /* 
    mapping(address => EnumerableMap.AddressToUintMap) private tokenAccounts; */
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
            pureAssertEq(
                IERC721(token).ownerOf(identifier),
                from,
                "ExpectedBalances: sender does not own token"
            );
        } else {
            pureAssertEq(
                tokenData.accountIdentifiers[from].remove(identifier),
                true,
                "ExpectedBalances: sender does not own token"
            );
        }

        pureAssertEq(
            tokenData.accountIdentifiers[to].add(identifier),
            true,
            "ExpectedBalances: receiver already owns token"
        );
    }

    function checkERC721Balances() internal view {
        address[] memory tokensArray = tokens.values();

        // uint256 length = tokensArray.length;

        // bool minMax = treatBalancesAsMinMax();

        for (uint256 i; i < tokensArray.length; i++) {
            // address token = tokensArray[i];

            TokenData721 storage tokenData = tokenDatas[tokensArray[i]];

            address[] memory accounts = tokenData.accountBalances.keys();

            // uint256 accountsLength = accounts.length;

            for (uint256 j; j < accounts.length; j++) {
                // address account = accounts[j];
                // bool accountMax = treatAccountBalanceAsMaximum(accounts[j]);

                {
                    // uint256 expectedBalance = tokenData.accountBalances.get(
                    //     account
                    // );
                    // uint256 actualBalance = IERC721(tokensArray[i]).balanceOf(account);
                    if (treatBalancesAsMinMax()) {
                        if (treatAccountBalanceAsMaximum(accounts[j])) {
                            /* require(
                                expectedBalance >= actualBalance,
                                BalanceErrorMessages.erc721UnexpectedBalance(
                                    token,
                                    account,
                                    expectedBalance,
                                    actualBalance
                                )
                            ); */
                        } else {
                            pureAssertEq(
                                tokenData.accountBalances.get(accounts[j]) <=
                                    IERC721(tokensArray[i]).balanceOf(
                                        accounts[j]
                                    ),
                                true,
                                BalanceErrorMessages.erc721UnexpectedBalance(
                                    tokensArray[i],
                                    accounts[j],
                                    tokenData.accountBalances.get(accounts[j]),
                                    IERC721(tokensArray[i]).balanceOf(
                                        accounts[j]
                                    )
                                )
                            );
                        }
                    } else if (
                        IERC721(tokensArray[i]).balanceOf(accounts[j]) !=
                        tokenData.accountBalances.get(accounts[j])
                    ) {
                        revert(
                            BalanceErrorMessages.erc721UnexpectedBalance(
                                tokensArray[i],
                                accounts[j],
                                tokenData.accountBalances.get(accounts[j]),
                                IERC721(tokensArray[i]).balanceOf(accounts[j])
                            )
                        );
                    }
                }

                if (!treatBalancesAsMinMax()) {
                    uint256[] memory identifiers = tokenData
                        .accountIdentifiers[accounts[j]]
                        .values();

                    // uint256 identifiersLength = identifiers.length;

                    for (uint256 k; k < identifiers.length; k++) {
                        pureAssertEq(
                            IERC721(tokensArray[i]).ownerOf(identifiers[k]),
                            accounts[j],
                            "ExpectedBalances: account does not own expected token"
                        );
                    }
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
        // uint256 accountsLength = dump.accounts.length;

        //new ERC721AccountDump[](accountsLength);
        dump.token = token;
        for (uint256 i; i < dump.accounts.length; i++) {
            // address account = dump.accounts[i];

            dump.accountIdentifiers[i] = tokenData
                .accountIdentifiers[dump.accounts[i]]
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

abstract contract ERC1155Balances is BalancesConfig {
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
        // pureAssertEq()
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
        // address[] memory tokensArray = tokens.values();

        // uint256 length = tokensArray.length;

        // For each token...
        for (uint256 i; i < tokens.values().length; i++) {
            // address token = tokensArray[i];

            TokenData1155 storage tokenData = tokenDatas[tokens.values()[i]];

            address[] memory accounts = tokenData.accounts.values();

            // For each account that has interacted with the token...
            for (uint256 j; j < accounts.length; j++) {
                // address account = accounts[j];

                EnumerableMap.UintToUintMap
                    storage accountIdentifiers = tokenData.accountIdentifiers[
                        accounts[j]
                    ];

                uint256[] memory identifiers = accountIdentifiers.keys();

                // uint256 identifiersLength = identifiers.length;

                // For each identifier the account has interacted with,
                // assert their balance matches the expected balance.
                for (uint256 k; k < identifiers.length; k++) {
                    // uint256 identifier = identifiers[k];
                    // uint256 expectedBalance = accountIdentifiers.get(
                    //   identifiers[k]
                    // );
                    // uint256 actualBalance = IERC1155(tokens.values()[i])
                    //     .balanceOf(accounts[j], identifiers[k]);
                    if (treatBalancesAsMinMax()) {
                        if (treatAccountBalanceAsMaximum(accounts[j])) {
                            /* require(
                                accountIdentifiers.get(identifiers[k]) >=
                                    actualBalance,
                                BalanceErrorMessages.erc1155UnexpectedBalance(
                                    token,
                                    accounts[j],
                                    identifiers[k],
                                    accountIdentifiers.get(identifiers[k]),
                                    actualBalance
                                )
                            ); */
                        } else {
                            pureAssertEq(
                                accountIdentifiers.get(identifiers[k]) <=
                                    IERC1155(tokens.values()[i]).balanceOf(
                                        accounts[j],
                                        identifiers[k]
                                    ),
                                true,
                                BalanceErrorMessages.erc1155UnexpectedBalance(
                                    tokens.values()[i],
                                    accounts[j],
                                    identifiers[k],
                                    accountIdentifiers.get(identifiers[k]),
                                    IERC1155(tokens.values()[i]).balanceOf(
                                        accounts[j],
                                        identifiers[k]
                                    )
                                )
                            );
                        }
                    } else if (
                        accountIdentifiers.get(identifiers[k]) !=
                        IERC1155(tokens.values()[i]).balanceOf(
                            accounts[j],
                            identifiers[k]
                        )
                    ) {
                        revert(
                            BalanceErrorMessages.erc1155UnexpectedBalance(
                                tokens.values()[i],
                                accounts[j],
                                identifiers[k],
                                accountIdentifiers.get(identifiers[k]),
                                IERC1155(tokens.values()[i]).balanceOf(
                                    accounts[j],
                                    identifiers[k]
                                )
                            )
                        );
                    }
                }
            }
        }
    }

    // function dumpERC1155Balances()
    //     public
    //     view
    //     returns (ERC1155TokenDump[] memory tokenDumps)
    // {
    //     address[] memory tokensArray = tokens.values();
    //     // uint256 length = tokensArray.length;
    //     tokenDumps = new ERC1155TokenDump[](tokensArray.length);

    //     // For each token...
    //     for (uint256 i; i < tokensArray.length; i++) {
    //         // address token = tokensArray[i];
    //         TokenData1155 storage tokenData = tokenDatas[tokensArray[i]];
    //         uint256 accountsLength = tokenData.accounts.length();

    //         ERC1155TokenDump memory tokenDump = ERC1155TokenDump({
    //             token: tokensArray[i],
    //             accounts: new ERC1155AccountDump[](accountsLength)
    //         });
    //         tokenDumps[i] = tokenDump;

    //         for (uint256 j; j < accountsLength; j++) {
    //             EnumerableMap.UintToUintMap
    //                 storage accountIdentifiers = tokenData.accountIdentifiers[
    //                     tokenData.accounts.at(j)
    //                 ];

    //             uint256[] memory identifiers = accountIdentifiers.keys();

    //             ERC1155AccountDump memory accountDump = ERC1155AccountDump({
    //                 account: tokenData.accounts.at(j),
    //                 identifiers: new uint256[](identifiers.length),
    //                 balances: new uint256[](identifiers.length)
    //             });
    //             tokenDump.accounts[j] = accountDump;

    //             for (uint256 k; k < identifiers.length; k++) {
    //                 uint256 identifier = identifiers[k];
    //                 accountDump.identifiers[k] = identifier;
    //                 accountDump.balances[k] = accountIdentifiers.get(
    //                     identifier
    //                 );
    //             }
    //         }
    //     }
    // }
}

contract ExpectedBalances is
    NativeBalances,
    ERC20Balances,
    ERC721Balances,
    ERC1155Balances
{
    bool internal useMinMax;
    mapping(address => bool) public treatAsMaximum;

    function treatAccountBalanceAsMaximum(
        address account
    ) internal view virtual override returns (bool) {
        return treatAsMaximum[account];
    }

    function treatBalancesAsMinMax()
        internal
        view
        virtual
        override
        returns (bool)
    {
        return useMinMax;
    }

    function markAccountBalanceAsMaximum(address account) external {
        useMinMax = true;
        treatAsMaximum[account] = true;
    }

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

    function checkBalances() external {
        checkNativeBalances();
        checkERC20Balances();
        checkERC721Balances();
        checkERC1155Balances();
    }

    //     function dumpBalances()
    //         external
    //         view
    //         returns (ExpectedBalancesDump memory balancesDump)
    //     {
    //         // balancesDump.erc20 = dumpERC20Balances();
    //         balancesDump.erc721 = dumpERC721Balances();
    //         // balancesDump.erc1155 = dumpERC1155Balances();
    //     }
}
