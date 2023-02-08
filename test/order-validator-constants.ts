import { BigNumber } from "ethers";

export const SEAPORT_CONTRACT_NAME = "Seaport";
export const SEAPORT_CONTRACT_VERSION = "1.1";
export const OPENSEA_CONDUIT_KEY =
  "0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000";
export const OPENSEA_CONDUIT_ADDRESS =
  "0x1E0049783F008A0085193E00003D00cd54003c71";
export const EIP_712_ORDER_TYPE = {
  OrderComponents: [
    { name: "offerer", type: "address" },
    { name: "zone", type: "address" },
    { name: "offer", type: "OfferItem[]" },
    { name: "consideration", type: "ConsiderationItem[]" },
    { name: "orderType", type: "uint8" },
    { name: "startTime", type: "uint256" },
    { name: "endTime", type: "uint256" },
    { name: "zoneHash", type: "bytes32" },
    { name: "salt", type: "uint256" },
    { name: "conduitKey", type: "bytes32" },
    { name: "counter", type: "uint256" },
  ],
  OfferItem: [
    { name: "itemType", type: "uint8" },
    { name: "token", type: "address" },
    { name: "identifierOrCriteria", type: "uint256" },
    { name: "startAmount", type: "uint256" },
    { name: "endAmount", type: "uint256" },
  ],
  ConsiderationItem: [
    { name: "itemType", type: "uint8" },
    { name: "token", type: "address" },
    { name: "identifierOrCriteria", type: "uint256" },
    { name: "startAmount", type: "uint256" },
    { name: "endAmount", type: "uint256" },
    { name: "recipient", type: "address" },
  ],
};

export enum OrderType {
  FULL_OPEN = 0, // No partial fills, anyone can execute
  PARTIAL_OPEN = 1, // Partial fills supported, anyone can execute
  FULL_RESTRICTED = 2, // No partial fills, only offerer or zone can execute
  PARTIAL_RESTRICTED = 3, // Partial fills supported, only offerer or zone can execute
}

export enum ItemType {
  NATIVE = 0,
  ERC20 = 1,
  ERC721 = 2,
  ERC1155 = 3,
  ERC721_WITH_CRITERIA = 4,
  ERC1155_WITH_CRITERIA = 5,
}

export enum Side {
  OFFER = 0,
  CONSIDERATION = 1,
}

export type NftItemType =
  | ItemType.ERC721
  | ItemType.ERC1155
  | ItemType.ERC721_WITH_CRITERIA
  | ItemType.ERC1155_WITH_CRITERIA;

export enum BasicOrderRouteType {
  ETH_TO_ERC721,
  ETH_TO_ERC1155,
  ERC20_TO_ERC721,
  ERC20_TO_ERC1155,
  ERC721_TO_ERC20,
  ERC1155_TO_ERC20,
}

export const MAX_INT = BigNumber.from(
  "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
);
export const ONE_HUNDRED_PERCENT_BP = 10000;
export const NO_CONDUIT =
  "0x0000000000000000000000000000000000000000000000000000000000000000";

// Supply here any known conduit keys as well as their conduits
export const KNOWN_CONDUIT_KEYS_TO_CONDUIT = {
  [OPENSEA_CONDUIT_KEY]: OPENSEA_CONDUIT_ADDRESS,
};

export const CROSS_CHAIN_SEAPORT_ADDRESS =
  "0x00000000006c3852cbEf3e08E8dF289169EdE581";

export const NULL_ADDRESS = "0x0000000000000000000000000000000000000000";
export const EMPTY_BYTES32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";

export enum TimeIssue {
  EndTimeBeforeStartTime = 900,
  Expired,
  DistantExpiration,
  NotActive,
  ShortOrder,
}

export enum StatusIssue {
  Cancelled = 800,
  FullyFilled,
}

export enum OfferIssue {
  ZeroItems = 600,
  AmountZero,
  MoreThanOneItem,
  NativeItem,
  DuplicateItem,
  AmountVelocityHigh,
  AmountStepLarge,
}

export enum ConsiderationIssue {
  AmountZero = 500,
  NullRecipient,
  ExtraItems,
  PrivateSaleToSelf,
  ZeroItems,
  DuplicateItem,
  PrivateSale,
  AmountVelocityHigh,
  AmountStepLarge,
}

export enum PrimaryFeeIssue {
  Missing = 700,
  ItemType,
  Token,
  StartAmount,
  EndAmount,
  Recipient,
}

export enum ERC721Issue {
  AmountNotOne = 300,
  InvalidToken,
  IdentifierDNE,
  NotOwner,
  NotApproved,
  CriteriaNotPartialFill,
}

export enum ERC1155Issue {
  InvalidToken = 400,
  NotApproved,
  InsufficientBalance,
}

export enum ERC20Issue {
  IdentifierNonZero = 200,
  InvalidToken,
  InsufficientAllowance,
  InsufficientBalance,
}

export enum NativeIssue {
  TokenAddress = 1300,
  IdentifierNonZero,
  InsufficientBalance,
}

export enum ZoneIssue {
  RejectedOrder = 1400,
  NotSet,
}

export enum ConduitIssue {
  KeyInvalid = 1000,
}

export enum CreatorFeeIssue {
  Missing = 1200,
  ItemType,
  Token,
  StartAmount,
  EndAmount,
  Recipient,
}

export enum SignatureIssue {
  Invalid = 1100,
  LowCounter,
  HighCounter,
  OriginalConsiderationItems,
}

export enum GenericIssue {
  InvalidOrderFormat = 100,
}

export enum MerkleIssue {
  SingleLeaf = 1500,
  Unsorted,
}

export const THIRTY_MINUTES = 30 * 60;
export const WEEKS_26 = 60 * 60 * 24 * 7 * 26;
