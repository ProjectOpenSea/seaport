// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableMap.sol";
import "../../../../contracts/lib/ConsiderationStructs.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC1155.sol";

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
    // ERC1155IdentifierDump[] identifiers;
}

struct ERC1155TokenDump {
    address token;
    address[] accounts;
    uint256[][] accountIdentifiers;
    uint256[][] accountBalances;
    // ERC1155AccountDump[] accounts;
}

struct ExpectedBalancesDump {
    ERC20TokenDump[] erc20;
    ERC721TokenDump[] erc721;
    ERC1155TokenDump[] erc1155;
}

contract NativeBalances {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    EnumerableMap.AddressToUintMap private accountsMap;

    function addNativeTransfer(
        address from,
        address to,
        uint256 amount
    ) public {
        (bool fromExists, uint256 fromBalance) = accountsMap.tryGet(from);
        if (!fromExists) {
            fromBalance = from.balance;
        }
        accountsMap.set(from, fromBalance - amount);

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
            require(
                accountsMap.get(account) == account.balance,
                "ExpectedBalances: Native balance does not match"
            );
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

contract ERC20Balances {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private tokens;
    mapping(address => EnumerableMap.AddressToUintMap) private tokenAccounts;

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
        accounts.set(from, fromBalance - amount);

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
                require(
                    accountsMap.get(account) ==
                        IERC20(token).balanceOf(account),
                    "ExpectedBalances: Token balance does not match"
                );
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

contract ERC721Balances {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    struct TokenData721 {
        EnumerableSet.AddressSet accounts;
        mapping(address => EnumerableSet.UintSet) accountIdentifiers;
        EnumerableSet.UintSet touchedIdentifiers;
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
        tokenData.accounts.add(from);
        tokenData.accounts.add(to);
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

            address[] memory accounts = tokenData.accounts.values();

            uint256 accountsLength = accounts.length;

            for (uint256 j; j < accountsLength; j++) {
                address account = accounts[j];

                uint256[] memory identifiers = tokenData
                    .accountIdentifiers[account]
                    .values();

                uint256 identifiersLength = identifiers.length;

                require(
                    IERC721(token).balanceOf(account) == identifiersLength,
                    "ExpectedBalances: account has more than expected # of tokens"
                );

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

        uint256 accountsLength = tokenData.accounts.length();

        dump.accounts = tokenData.accounts.values();
        //new ERC721AccountDump[](accountsLength);
        dump.token = token;
        for (uint256 j; j < accountsLength; j++) {
            address account = tokenData.accounts.at(j);

            dump.accountIdentifiers[j] = tokenData
                .accountIdentifiers[account]
                .values();
        }
    }
}

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

    function addERC1155Transfer(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount
    ) public {
        tokens.add(token);

        TokenData1155 storage tokenData = tokenDatas[token];

        tokenData.accounts.add(from);
        tokenData.accounts.add(to);

        {
            EnumerableMap.UintToUintMap storage fromIdentifiers = tokenData
                .accountIdentifiers[from];
            (bool fromExists, uint256 fromBalance) = fromIdentifiers.tryGet(
                identifier
            );
            if (!fromExists) {
                fromBalance = IERC1155(token).balanceOf(from, identifier);
            }
            fromIdentifiers.set(identifier, fromBalance - amount);
        }

        {
            EnumerableMap.UintToUintMap storage toIdentifiers = tokenData
                .accountIdentifiers[to];
            (bool toExists, uint256 toBalance) = toIdentifiers.tryGet(
                identifier
            );
            if (!toExists) {
                toBalance = IERC1155(token).balanceOf(to, identifier);
            }
            toIdentifiers.set(identifier, toBalance + amount);
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
                    require(
                        IERC1155(token).balanceOf(account, identifier) ==
                            accountIdentifiers.get(identifier),
                        "ExpectedBalances: account does not own expected balance for id"
                    );
                }
            }
        }
    }

    /*     function dumpERC1155Balances()
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
                    identifiers: new ERC1155IdentifierDump[](identifiersLength)
                });
                tokenDump.accounts[j] = accountDump;

                for (uint256 k; k < identifiersLength; k++) {
                    uint256 identifier = identifiers[k];
                    accountDump.identifiers[k] = ERC1155IdentifierDump({
                        identifier: identifier,
                        balance: accountIdentifiers.get(identifier)
                    });
                }
            }
        }
    } */
}

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
                    item.token,
                    execution.offerer,
                    item.recipient,
                    item.identifier,
                    item.amount
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
