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

enum TimeIssue {
    EndTimeBeforeStartTime,
    Expired,
    DistantExpiration,
    NotActive,
    ShortOrder
}

enum StatusIssue {
    Cancelled,
    FullyFilled
}

enum OfferIssue {
    ZeroItems,
    AmountZero,
    MoreThanOneItem,
    NativeItem,
    DuplicateItem,
    AmountVelocityHigh,
    AmountStepLarge
}

enum ConsiderationIssue {
    AmountZero,
    NullRecipient,
    ExtraItems,
    PrivateSaleToSelf,
    ZeroItems,
    DuplicateItem,
    PrivateSale,
    AmountVelocityHigh,
    AmountStepLarge
}

enum PrimaryFeeIssue {
    Missing,
    ItemType,
    Token,
    StartAmount,
    EndAmount,
    Recipient
}

enum ERC721Issue {
    AmountNotOne,
    InvalidToken,
    IdentifierDNE,
    NotOwner,
    NotApproved,
    CriteriaNotPartialFill
}

enum ERC1155Issue {
    InvalidToken,
    NotApproved,
    InsufficientBalance
}

enum ERC20Issue {
    IdentifierNonZero,
    InvalidToken,
    InsufficientAllowance,
    InsufficientBalance
}

enum NativeIssue {
    TokenAddress,
    IdentifierNonZero,
    InsufficientBalance
}

enum ZoneIssue {
    InvalidZone,
    RejectedOrder,
    NotSet
}

enum ContractOffererIssue {
    InvalidContractOfferer
}

enum ConduitIssue {
    KeyInvalid
}

enum CreatorFeeIssue {
    Missing,
    ItemType,
    Token,
    StartAmount,
    EndAmount,
    Recipient
}

enum SignatureIssue {
    Invalid,
    LowCounter,
    HighCounter,
    OriginalConsiderationItems
}

enum GenericIssue {
    InvalidOrderFormat
}

enum MerkleIssue {
    SingleLeaf,
    Unsorted
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
