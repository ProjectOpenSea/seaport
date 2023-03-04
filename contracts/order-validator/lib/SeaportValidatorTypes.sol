// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

struct ValidationConfiguration {
    /// @notice Recipient for primary fee payments.
    address primaryFeeRecipient;
    /// @notice Bips for primary fee payments.
    uint256 primaryFeeBips;
    /// @notice Should creator fees be checked?
    bool checkCreatorFee;
    /// @notice Should strict validation be skipped?
    bool skipStrictValidation;
    /// @notice Short order duration in seconds
    uint256 shortOrderDuration;
    /// @notice Distant order expiration delta in seconds. Warning if order expires in longer than this.
    uint256 distantOrderExpiration;
}

enum GenericIssue {
    InvalidOrderFormat // 100
}

enum ERC20Issue {
    IdentifierNonZero, // 200
    InvalidToken, // 201
    InsufficientAllowance, // 202
    InsufficientBalance // 203
}

enum ERC721Issue {
    AmountNotOne, // 300
    InvalidToken, // 301
    IdentifierDNE, // 302
    NotOwner, // 303
    NotApproved, // 304
    CriteriaNotPartialFill // 305
}

enum ERC1155Issue {
    InvalidToken, // 400
    NotApproved, // 401
    InsufficientBalance // 402
}

enum ConsiderationIssue {
    AmountZero, // 500
    NullRecipient, // 501
    ExtraItems, // 502
    PrivateSaleToSelf, // 503
    ZeroItems, // 504
    DuplicateItem, // 505
    PrivateSale, // 506
    AmountVelocityHigh, // 507
    AmountStepLarge // 508
}

enum OfferIssue {
    ZeroItems, // 600
    AmountZero, // 601
    MoreThanOneItem, // 602
    NativeItem, // 603
    DuplicateItem, // 604
    AmountVelocityHigh, // 605
    AmountStepLarge // 606
}

enum PrimaryFeeIssue {
    Missing, // 700
    ItemType, // 701
    Token, // 702
    StartAmount, // 703
    EndAmount, // 704
    Recipient // 705
}

enum StatusIssue {
    Cancelled, // 800
    FullyFilled, // 801
    ContractOrder // 802
}

enum TimeIssue {
    EndTimeBeforeStartTime, // 900
    Expired, // 901
    DistantExpiration, // 902
    NotActive, // 903
    ShortOrder // 904
}

enum ConduitIssue {
    KeyInvalid, // 1000
    MissingCanonicalSeaportChannel // 1001
}

enum SignatureIssue {
    Invalid, // 1100
    ContractOrder, // 1101
    LowCounter, // 1102
    HighCounter, // 1103
    OriginalConsiderationItems // 1104
}

enum CreatorFeeIssue {
    Missing, // 1200
    ItemType, // 1201
    Token, // 1202
    StartAmount, // 1203
    EndAmount, // 1204
    Recipient // 1205
}

enum NativeIssue {
    TokenAddress, // 1300
    IdentifierNonZero, // 1301
    InsufficientBalance // 1302
}

enum ZoneIssue {
    InvalidZone, // 1400
    RejectedOrder, // 1401
    NotSet // 1402
}

enum MerkleIssue {
    SingleLeaf, // 1500
    Unsorted // 1501
}

enum ContractOffererIssue {
    InvalidContractOfferer // 1600
}

/**
 * @title IssueParser - parse issues into integers
 * @notice Implements a `parseInt` function for each issue type.
 *    offsets the enum value to place within the issue range.
 */
library IssueParser {
    function parseInt(GenericIssue err) internal pure returns (uint16) {
        return uint16(err) + 100;
    }

    function parseInt(ERC20Issue err) internal pure returns (uint16) {
        return uint16(err) + 200;
    }

    function parseInt(ERC721Issue err) internal pure returns (uint16) {
        return uint16(err) + 300;
    }

    function parseInt(ERC1155Issue err) internal pure returns (uint16) {
        return uint16(err) + 400;
    }

    function parseInt(ConsiderationIssue err) internal pure returns (uint16) {
        return uint16(err) + 500;
    }

    function parseInt(OfferIssue err) internal pure returns (uint16) {
        return uint16(err) + 600;
    }

    function parseInt(PrimaryFeeIssue err) internal pure returns (uint16) {
        return uint16(err) + 700;
    }

    function parseInt(StatusIssue err) internal pure returns (uint16) {
        return uint16(err) + 800;
    }

    function parseInt(TimeIssue err) internal pure returns (uint16) {
        return uint16(err) + 900;
    }

    function parseInt(ConduitIssue err) internal pure returns (uint16) {
        return uint16(err) + 1000;
    }

    function parseInt(SignatureIssue err) internal pure returns (uint16) {
        return uint16(err) + 1100;
    }

    function parseInt(CreatorFeeIssue err) internal pure returns (uint16) {
        return uint16(err) + 1200;
    }

    function parseInt(NativeIssue err) internal pure returns (uint16) {
        return uint16(err) + 1300;
    }

    function parseInt(ZoneIssue err) internal pure returns (uint16) {
        return uint16(err) + 1400;
    }

    function parseInt(MerkleIssue err) internal pure returns (uint16) {
        return uint16(err) + 1500;
    }

    function parseInt(ContractOffererIssue err) internal pure returns (uint16) {
        return uint16(err) + 1600;
    }
}
