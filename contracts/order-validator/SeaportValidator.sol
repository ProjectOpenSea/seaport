// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { ItemType } from "./ConsiderationEnums.sol";
import {
    Order,
    OrderParameters,
    BasicOrderParameters,
    OfferItem,
    ConsiderationItem
} from "./ConsiderationStructs.sol";
import { ConsiderationTypeHashes } from "./ConsiderationTypeHashes.sol";
import {
    ConsiderationInterface
} from "../interfaces/ConsiderationInterface.sol";
import {
    ConduitControllerInterface
} from "../interfaces/ConduitControllerInterface.sol";
import {
    SeaportValidatorInterface
} from "../interfaces/SeaportValidatorInterface.sol";
import { ZoneInterface } from "../interfaces/ZoneInterface.sol";
import {
    IERC721
} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {
    IERC1155
} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {
    IERC20
} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IERC2981 } from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {
    ErrorsAndWarnings,
    ErrorsAndWarningsLib
} from "./ErrorsAndWarnings.sol";
import { SafeStaticCall } from "./SafeStaticCall.sol";
import { Murky } from "./Murky.sol";
import {
    CreatorFeeEngineInterface
} from "../interfaces/CreatorFeeEngineInterface.sol";
import {
    IssueParser,
    ValidationConfiguration,
    TimeIssue,
    StatusIssue,
    OfferIssue,
    ConsiderationIssue,
    PrimaryFeeIssue,
    ERC721Issue,
    ERC1155Issue,
    ERC20Issue,
    NativeIssue,
    ZoneIssue,
    ConduitIssue,
    CreatorFeeIssue,
    SignatureIssue,
    GenericIssue
} from "./SeaportValidatorTypes.sol";
import { SignatureVerification } from "./SignatureVerification.sol";

/**
 * @title SeaportValidator
 * @notice SeaportValidator provides advanced validation to seaport orders.
 */
contract SeaportValidator is
    SeaportValidatorInterface,
    ConsiderationTypeHashes,
    SignatureVerification,
    Murky
{
    using ErrorsAndWarningsLib for ErrorsAndWarnings;
    using SafeStaticCall for address;
    using IssueParser for *;

    /// @notice Cross-chain seaport address
    ConsiderationInterface public constant seaport =
        ConsiderationInterface(0x00000000006c3852cbEf3e08E8dF289169EdE581);
    /// @notice Cross-chain conduit controller Address
    ConduitControllerInterface public constant conduitController =
        ConduitControllerInterface(0x00000000F9490004C11Cef243f5400493c00Ad63);
    /// @notice Ethereum creator fee engine address
    CreatorFeeEngineInterface public immutable creatorFeeEngine;

    constructor() {
        address creatorFeeEngineAddress;
        if (block.chainid == 1) {
            creatorFeeEngineAddress = 0x0385603ab55642cb4Dd5De3aE9e306809991804f;
        } else if (block.chainid == 3) {
            // Ropsten
            creatorFeeEngineAddress = 0xFf5A6F7f36764aAD301B7C9E85A5277614Df5E26;
        } else if (block.chainid == 4) {
            // Rinkeby
            creatorFeeEngineAddress = 0x8d17687ea9a6bb6efA24ec11DcFab01661b2ddcd;
        } else if (block.chainid == 5) {
            // Goerli
            creatorFeeEngineAddress = 0xe7c9Cb6D966f76f3B5142167088927Bf34966a1f;
        } else if (block.chainid == 42) {
            // Kovan
            creatorFeeEngineAddress = 0x54D88324cBedfFe1e62c9A59eBb310A11C295198;
        } else if (block.chainid == 137) {
            // Polygon
            creatorFeeEngineAddress = 0x28EdFcF0Be7E86b07493466e7631a213bDe8eEF2;
        } else if (block.chainid == 80001) {
            // Mumbai
            creatorFeeEngineAddress = 0x0a01E11887f727D1b1Cd81251eeEE9BEE4262D07;
        } else {
            // No creator fee engine for this chain
            creatorFeeEngineAddress = address(0);
        }

        creatorFeeEngine = CreatorFeeEngineInterface(creatorFeeEngineAddress);
    }

    /**
     * @notice Conduct a comprehensive validation of the given order.
     *    `isValidOrder` validates simple orders that adhere to a set of rules defined below:
     *    - The order is either a listing or an offer order (one NFT to buy or one NFT to sell).
     *    - The first consideration is the primary consideration.
     *    - The order pays up to two fees in the fungible token currency. First fee is primary fee, second is creator fee.
     *    - In private orders, the last consideration specifies a recipient for the offer item.
     *    - Offer items must be owned and properly approved by the offerer.
     *    - There must be one offer item
     *    - Consideration items must exist.
     *    - The signature must be valid, or the order must be already validated on chain
     * @param order The order to validate.
     * @return errorsAndWarnings The errors and warnings found in the order.
     */
    function isValidOrder(
        Order calldata order
    ) external view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        return
            isValidOrderWithConfiguration(
                ValidationConfiguration(
                    address(0),
                    0,
                    false,
                    false,
                    30 minutes,
                    26 weeks
                ),
                order
            );
    }

    /**
     * @notice Same as `isValidOrder` but allows for more configuration related to fee validation.
     *    If `skipStrictValidation` is set order logic validation is not carried out: fees are not
     *       checked and there may be more than one offer item as well as any number of consideration items.
     */
    function isValidOrderWithConfiguration(
        ValidationConfiguration memory validationConfiguration,
        Order memory order
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = ErrorsAndWarnings(new uint16[](0), new uint16[](0));

        // Concatenates errorsAndWarnings with the returned errorsAndWarnings
        errorsAndWarnings.concat(
            validateTime(
                order.parameters,
                validationConfiguration.shortOrderDuration,
                validationConfiguration.distantOrderExpiration
            )
        );
        errorsAndWarnings.concat(validateOrderStatus(order.parameters));
        errorsAndWarnings.concat(validateOfferItems(order.parameters));
        errorsAndWarnings.concat(validateConsiderationItems(order.parameters));
        errorsAndWarnings.concat(isValidZone(order.parameters));
        errorsAndWarnings.concat(validateSignature(order));

        // Skip strict validation if requested
        if (!validationConfiguration.skipStrictValidation) {
            errorsAndWarnings.concat(
                validateStrictLogic(
                    order.parameters,
                    validationConfiguration.primaryFeeRecipient,
                    validationConfiguration.primaryFeeBips,
                    validationConfiguration.checkCreatorFee
                )
            );
        }
    }

    /**
     * @notice Checks if a conduit key is valid.
     * @param conduitKey The conduit key to check.
     * @return errorsAndWarnings The errors and warnings
     */
    function isValidConduit(
        bytes32 conduitKey
    ) external view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        (, errorsAndWarnings) = getApprovalAddress(conduitKey);
    }

    /**
     * @notice Gets the approval address for the given conduit key
     * @param conduitKey Conduit key to get approval address for
     * @return approvalAddress The address to use for approvals
     * @return errorsAndWarnings An ErrorsAndWarnings structs with results
     */
    function getApprovalAddress(
        bytes32 conduitKey
    )
        public
        view
        returns (address, ErrorsAndWarnings memory errorsAndWarnings)
    {
        errorsAndWarnings = ErrorsAndWarnings(new uint16[](0), new uint16[](0));

        // Zero conduit key corresponds to seaport
        if (conduitKey == 0) return (address(seaport), errorsAndWarnings);

        // Pull conduit info from conduitController
        (address conduitAddress, bool exists) = conduitController.getConduit(
            conduitKey
        );

        // Conduit does not exist
        if (!exists) {
            errorsAndWarnings.addError(ConduitIssue.KeyInvalid.parseInt());
            conduitAddress = address(0); // Don't return invalid conduit
        }

        return (conduitAddress, errorsAndWarnings);
    }

    /**
     * @notice Validates the signature for the order using the offerer's current counter
     * @dev Will also check if order is validated on chain.
     */
    function validateSignature(
        Order memory order
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        // Pull current counter from seaport
        uint256 currentCounter = seaport.getCounter(order.parameters.offerer);

        return validateSignatureWithCounter(order, currentCounter);
    }

    /**
     * @notice Validates the signature for the order using the given counter
     * @dev Will also check if order is validated on chain.
     */
    function validateSignatureWithCounter(
        Order memory order,
        uint256 counter
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = ErrorsAndWarnings(new uint16[](0), new uint16[](0));

        // Get current counter for context
        uint256 currentCounter = seaport.getCounter(order.parameters.offerer);

        if (currentCounter > counter) {
            // Counter strictly increases
            errorsAndWarnings.addError(SignatureIssue.LowCounter.parseInt());
            return errorsAndWarnings;
        } else if (counter > 2 && currentCounter < counter - 2) {
            // Will require significant input from offerer to validate, warn
            errorsAndWarnings.addWarning(SignatureIssue.HighCounter.parseInt());
        }

        bytes32 orderHash = _deriveOrderHash(order.parameters, counter);

        // Check if order is validated on chain
        (bool isValid, , , ) = seaport.getOrderStatus(orderHash);

        if (isValid) {
            // Shortcut success, valid on chain
            return errorsAndWarnings;
        }

        // Get signed digest
        bytes32 eip712Digest = _deriveEIP712Digest(orderHash);
        if (
            // Checks EIP712 and EIP1271
            !_isValidSignature(
                order.parameters.offerer,
                eip712Digest,
                order.signature
            )
        ) {
            if (
                order.parameters.consideration.length !=
                order.parameters.totalOriginalConsiderationItems
            ) {
                // May help diagnose signature issues
                errorsAndWarnings.addWarning(
                    SignatureIssue.OriginalConsiderationItems.parseInt()
                );
            }

            // Signature is invalid
            errorsAndWarnings.addError(SignatureIssue.Invalid.parseInt());
        }
    }

    /**
     * @notice Check the time validity of an order
     * @param orderParameters The parameters for the order to validate
     * @param shortOrderDuration The duration of which an order is considered short
     * @param distantOrderExpiration Distant order expiration delta in seconds.
     * @return errorsAndWarnings The errors and warnings
     */
    function validateTime(
        OrderParameters memory orderParameters,
        uint256 shortOrderDuration,
        uint256 distantOrderExpiration
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = ErrorsAndWarnings(new uint16[](0), new uint16[](0));

        if (orderParameters.endTime <= orderParameters.startTime) {
            // Order duration is zero
            errorsAndWarnings.addError(
                TimeIssue.EndTimeBeforeStartTime.parseInt()
            );
            return errorsAndWarnings;
        }

        if (orderParameters.endTime < block.timestamp) {
            // Order is expired
            errorsAndWarnings.addError(TimeIssue.Expired.parseInt());
            return errorsAndWarnings;
        } else if (
            orderParameters.endTime > block.timestamp + distantOrderExpiration
        ) {
            // Order expires in a long time
            errorsAndWarnings.addWarning(
                TimeIssue.DistantExpiration.parseInt()
            );
        }

        if (orderParameters.startTime > block.timestamp) {
            // Order is not active
            errorsAndWarnings.addWarning(TimeIssue.NotActive.parseInt());
        }

        if (
            orderParameters.endTime -
                (
                    orderParameters.startTime > block.timestamp
                        ? orderParameters.startTime
                        : block.timestamp
                ) <
            shortOrderDuration
        ) {
            // Order has a short duration
            errorsAndWarnings.addWarning(TimeIssue.ShortOrder.parseInt());
        }
    }

    /**
     * @notice Validate the status of an order
     * @param orderParameters The parameters for the order to validate
     * @return errorsAndWarnings  The errors and warnings
     */
    function validateOrderStatus(
        OrderParameters memory orderParameters
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = ErrorsAndWarnings(new uint16[](0), new uint16[](0));

        // Pull current counter from seaport
        uint256 currentOffererCounter = seaport.getCounter(
            orderParameters.offerer
        );
        // Derive order hash using orderParameters and currentOffererCounter
        bytes32 orderHash = _deriveOrderHash(
            orderParameters,
            currentOffererCounter
        );
        // Get order status from seaport
        (, bool isCancelled, uint256 totalFilled, uint256 totalSize) = seaport
            .getOrderStatus(orderHash);

        if (isCancelled) {
            // Order is cancelled
            errorsAndWarnings.addError(StatusIssue.Cancelled.parseInt());
        }

        if (totalSize > 0 && totalFilled == totalSize) {
            // Order is fully filled
            errorsAndWarnings.addError(StatusIssue.FullyFilled.parseInt());
        }
    }

    /**
     * @notice Validate all offer items for an order. Ensures that
     *    offerer has sufficient balance and approval for each item.
     * @dev Amounts are not summed and verified, just the individual amounts.
     * @param orderParameters The parameters for the order to validate
     * @return errorsAndWarnings  The errors and warnings
     */
    function validateOfferItems(
        OrderParameters memory orderParameters
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = ErrorsAndWarnings(new uint16[](0), new uint16[](0));

        // Iterate over each offer item and validate it
        for (uint256 i = 0; i < orderParameters.offer.length; i++) {
            errorsAndWarnings.concat(validateOfferItem(orderParameters, i));

            // Check for duplicate offer item
            OfferItem memory offerItem1 = orderParameters.offer[i];

            for (uint256 j = i + 1; j < orderParameters.offer.length; j++) {
                // Iterate over each remaining offer item
                // (previous items already check with this item)
                OfferItem memory offerItem2 = orderParameters.offer[j];

                // Check if token and id are the same
                if (
                    offerItem1.token == offerItem2.token &&
                    offerItem1.identifierOrCriteria ==
                    offerItem2.identifierOrCriteria
                ) {
                    errorsAndWarnings.addError(
                        OfferIssue.DuplicateItem.parseInt()
                    );
                }
            }
        }

        // You must have an offer item
        if (orderParameters.offer.length == 0) {
            errorsAndWarnings.addError(OfferIssue.ZeroItems.parseInt());
        }

        // Warning if there is more than one offer item
        if (orderParameters.offer.length > 1) {
            errorsAndWarnings.addWarning(OfferIssue.MoreThanOneItem.parseInt());
        }
    }

    /**
     * @notice Validates an offer item
     * @param orderParameters The parameters for the order to validate
     * @param offerItemIndex The index of the offerItem in offer array to validate
     * @return errorsAndWarnings An ErrorsAndWarnings structs with results
     */
    function validateOfferItem(
        OrderParameters memory orderParameters,
        uint256 offerItemIndex
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        // First validate the parameters (correct amount, contract, etc)
        errorsAndWarnings = validateOfferItemParameters(
            orderParameters,
            offerItemIndex
        );
        if (errorsAndWarnings.hasErrors()) {
            // Only validate approvals and balances if parameters are valid
            return errorsAndWarnings;
        }

        // Validate approvals and balances for the offer item
        errorsAndWarnings.concat(
            validateOfferItemApprovalAndBalance(orderParameters, offerItemIndex)
        );
    }

    /**
     * @notice Validates the OfferItem parameters. This includes token contract validation
     * @dev OfferItems with criteria are currently not allowed
     * @param orderParameters The parameters for the order to validate
     * @param offerItemIndex The index of the offerItem in offer array to validate
     * @return errorsAndWarnings An ErrorsAndWarnings structs with results
     */
    function validateOfferItemParameters(
        OrderParameters memory orderParameters,
        uint256 offerItemIndex
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = ErrorsAndWarnings(new uint16[](0), new uint16[](0));

        OfferItem memory offerItem = orderParameters.offer[offerItemIndex];

        // Check if start amount and end amount are zero
        if (offerItem.startAmount == 0 && offerItem.endAmount == 0) {
            errorsAndWarnings.addError(OfferIssue.AmountZero.parseInt());
            return errorsAndWarnings;
        }

        // Check that amount velocity is not too high.
        if (
            offerItem.startAmount != offerItem.endAmount &&
            orderParameters.endTime > orderParameters.startTime
        ) {
            // Assign larger and smaller amount values
            (uint256 maxAmount, uint256 minAmount) = offerItem.startAmount >
                offerItem.endAmount
                ? (offerItem.startAmount, offerItem.endAmount)
                : (offerItem.endAmount, offerItem.startAmount);

            uint256 amountDelta = maxAmount - minAmount;
            // delta of time that order exists for
            uint256 timeDelta = orderParameters.endTime -
                orderParameters.startTime;

            // Velocity scaled by 1e10 for precision
            uint256 velocity = (amountDelta * 1e10) / timeDelta;
            // gives velocity percentage in hundredth of a basis points per second in terms of larger value
            uint256 velocityPercentage = velocity / (maxAmount * 1e4);

            // 278 * 60 * 30 ~= 500,000
            if (velocityPercentage > 278) {
                // Over 50% change per 30 min
                errorsAndWarnings.addError(
                    OfferIssue.AmountVelocityHigh.parseInt()
                );
            }
            // Over 50% change per 30 min
            else if (velocityPercentage > 28) {
                // Over 5% change per 30 min
                errorsAndWarnings.addWarning(
                    OfferIssue.AmountVelocityHigh.parseInt()
                );
            }

            // Check for large amount steps
            if (minAmount <= 1e15) {
                errorsAndWarnings.addWarning(
                    OfferIssue.AmountStepLarge.parseInt()
                );
            }
        }

        if (offerItem.itemType == ItemType.ERC721) {
            // ERC721 type requires amounts to be 1
            if (offerItem.startAmount != 1 || offerItem.endAmount != 1) {
                errorsAndWarnings.addError(ERC721Issue.AmountNotOne.parseInt());
            }

            // Check the EIP165 token interface
            if (!checkInterface(offerItem.token, type(IERC721).interfaceId)) {
                errorsAndWarnings.addError(ERC721Issue.InvalidToken.parseInt());
            }
        } else if (offerItem.itemType == ItemType.ERC721_WITH_CRITERIA) {
            // Check the EIP165 token interface
            if (!checkInterface(offerItem.token, type(IERC721).interfaceId)) {
                errorsAndWarnings.addError(ERC721Issue.InvalidToken.parseInt());
            }

            if (offerItem.startAmount > 1 || offerItem.endAmount > 1) {
                // Require partial fill enabled. Even orderTypes are full
                if (uint8(orderParameters.orderType) % 2 == 0) {
                    errorsAndWarnings.addError(
                        ERC721Issue.CriteriaNotPartialFill.parseInt()
                    );
                }
            }
        } else if (
            offerItem.itemType == ItemType.ERC1155 ||
            offerItem.itemType == ItemType.ERC1155_WITH_CRITERIA
        ) {
            // Check the EIP165 token interface
            if (!checkInterface(offerItem.token, type(IERC1155).interfaceId)) {
                errorsAndWarnings.addError(
                    ERC1155Issue.InvalidToken.parseInt()
                );
            }
        } else if (offerItem.itemType == ItemType.ERC20) {
            // ERC20 must have `identifierOrCriteria` be zero
            if (offerItem.identifierOrCriteria != 0) {
                errorsAndWarnings.addError(
                    ERC20Issue.IdentifierNonZero.parseInt()
                );
            }

            // Validate contract, should return an uint256 if its an ERC20
            if (
                !offerItem.token.safeStaticCallUint256(
                    abi.encodeWithSelector(
                        IERC20.allowance.selector,
                        address(seaport),
                        address(seaport)
                    ),
                    0
                )
            ) {
                errorsAndWarnings.addError(ERC20Issue.InvalidToken.parseInt());
            }
        } else {
            // Must be native
            // NATIVE must have `token` be zero address
            if (offerItem.token != address(0)) {
                errorsAndWarnings.addError(NativeIssue.TokenAddress.parseInt());
            }

            // NATIVE must have `identifierOrCriteria` be zero
            if (offerItem.identifierOrCriteria != 0) {
                errorsAndWarnings.addError(
                    NativeIssue.IdentifierNonZero.parseInt()
                );
            }
        }
    }

    /**
     * @notice Validates the OfferItem approvals and balances
     * @param orderParameters The parameters for the order to validate
     * @param offerItemIndex The index of the offerItem in offer array to validate
     * @return errorsAndWarnings An ErrorsAndWarnings structs with results
     */
    function validateOfferItemApprovalAndBalance(
        OrderParameters memory orderParameters,
        uint256 offerItemIndex
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        // Note: If multiple items are of the same token, token amounts are not summed for validation

        errorsAndWarnings = ErrorsAndWarnings(new uint16[](0), new uint16[](0));

        // Get the approval address for the given conduit key
        (
            address approvalAddress,
            ErrorsAndWarnings memory ew
        ) = getApprovalAddress(orderParameters.conduitKey);

        errorsAndWarnings.concat(ew);

        if (ew.hasErrors()) {
            // Approval address is invalid
            return errorsAndWarnings;
        }

        OfferItem memory offerItem = orderParameters.offer[offerItemIndex];

        if (offerItem.itemType == ItemType.ERC721) {
            IERC721 token = IERC721(offerItem.token);

            // Check that offerer owns token
            if (
                !address(token).safeStaticCallAddress(
                    abi.encodeWithSelector(
                        IERC721.ownerOf.selector,
                        offerItem.identifierOrCriteria
                    ),
                    orderParameters.offerer
                )
            ) {
                errorsAndWarnings.addError(ERC721Issue.NotOwner.parseInt());
            }

            // Check for approval via `getApproved`
            if (
                !address(token).safeStaticCallAddress(
                    abi.encodeWithSelector(
                        IERC721.getApproved.selector,
                        offerItem.identifierOrCriteria
                    ),
                    approvalAddress
                )
            ) {
                // Fallback to `isApprovalForAll`
                if (
                    !address(token).safeStaticCallBool(
                        abi.encodeWithSelector(
                            IERC721.isApprovedForAll.selector,
                            orderParameters.offerer,
                            approvalAddress
                        ),
                        true
                    )
                ) {
                    // Not approved
                    errorsAndWarnings.addError(
                        ERC721Issue.NotApproved.parseInt()
                    );
                }
            }
        } else if (
            offerItem.itemType == ItemType.ERC721_WITH_CRITERIA
        ) {} else if (offerItem.itemType == ItemType.ERC1155) {
            IERC1155 token = IERC1155(offerItem.token);

            // Check for approval
            if (
                !address(token).safeStaticCallBool(
                    abi.encodeWithSelector(
                        IERC721.isApprovedForAll.selector,
                        orderParameters.offerer,
                        approvalAddress
                    ),
                    true
                )
            ) {
                errorsAndWarnings.addError(ERC1155Issue.NotApproved.parseInt());
            }

            // Get min required balance (max(startAmount, endAmount))
            uint256 minBalance = offerItem.startAmount < offerItem.endAmount
                ? offerItem.startAmount
                : offerItem.endAmount;

            // Check for sufficient balance
            if (
                !address(token).safeStaticCallUint256(
                    abi.encodeWithSelector(
                        IERC1155.balanceOf.selector,
                        orderParameters.offerer,
                        offerItem.identifierOrCriteria
                    ),
                    minBalance
                )
            ) {
                // Insufficient balance
                errorsAndWarnings.addError(
                    ERC1155Issue.InsufficientBalance.parseInt()
                );
            }
        } else if (
            offerItem.itemType == ItemType.ERC1155_WITH_CRITERIA
        ) {} else if (offerItem.itemType == ItemType.ERC20) {
            IERC20 token = IERC20(offerItem.token);

            // Get min required balance and approval (max(startAmount, endAmount))
            uint256 minBalanceAndAllowance = offerItem.startAmount <
                offerItem.endAmount
                ? offerItem.startAmount
                : offerItem.endAmount;

            // Check allowance
            if (
                !address(token).safeStaticCallUint256(
                    abi.encodeWithSelector(
                        IERC20.allowance.selector,
                        orderParameters.offerer,
                        approvalAddress
                    ),
                    minBalanceAndAllowance
                )
            ) {
                errorsAndWarnings.addError(
                    ERC20Issue.InsufficientAllowance.parseInt()
                );
            }

            // Check balance
            if (
                !address(token).safeStaticCallUint256(
                    abi.encodeWithSelector(
                        IERC20.balanceOf.selector,
                        orderParameters.offerer
                    ),
                    minBalanceAndAllowance
                )
            ) {
                errorsAndWarnings.addError(
                    ERC20Issue.InsufficientBalance.parseInt()
                );
            }
        } else {
            // Must be native
            // Get min required balance (max(startAmount, endAmount))
            uint256 minBalance = offerItem.startAmount < offerItem.endAmount
                ? offerItem.startAmount
                : offerItem.endAmount;

            // Check for sufficient balance
            if (orderParameters.offerer.balance < minBalance) {
                errorsAndWarnings.addError(
                    NativeIssue.InsufficientBalance.parseInt()
                );
            }

            // Native items can not be pulled so warn
            errorsAndWarnings.addWarning(OfferIssue.NativeItem.parseInt());
        }
    }

    /**
     * @notice Validate all consideration items for an order
     * @param orderParameters The parameters for the order to validate
     * @return errorsAndWarnings  The errors and warnings
     */
    function validateConsiderationItems(
        OrderParameters memory orderParameters
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = ErrorsAndWarnings(new uint16[](0), new uint16[](0));

        if (orderParameters.consideration.length == 0) {
            errorsAndWarnings.addWarning(
                ConsiderationIssue.ZeroItems.parseInt()
            );
            return errorsAndWarnings;
        }

        // Iterate over each consideration item
        for (uint256 i = 0; i < orderParameters.consideration.length; i++) {
            // Validate consideration item
            errorsAndWarnings.concat(
                validateConsiderationItem(orderParameters, i)
            );

            ConsiderationItem memory considerationItem1 = orderParameters
                .consideration[i];

            for (
                uint256 j = i + 1;
                j < orderParameters.consideration.length;
                j++
            ) {
                // Iterate over each remaining offer item
                // (previous items already check with this item)

                ConsiderationItem memory considerationItem2 = orderParameters
                    .consideration[j];

                // Check if itemType, token, id, and recipient are the same
                if (
                    considerationItem2.itemType ==
                    considerationItem1.itemType &&
                    considerationItem2.token == considerationItem1.token &&
                    considerationItem2.identifierOrCriteria ==
                    considerationItem1.identifierOrCriteria &&
                    considerationItem2.recipient == considerationItem1.recipient
                ) {
                    errorsAndWarnings.addWarning(
                        // Duplicate consideration item, warning
                        ConsiderationIssue.DuplicateItem.parseInt()
                    );
                }
            }
        }
    }

    /**
     * @notice Validate a consideration item
     * @param orderParameters The parameters for the order to validate
     * @param considerationItemIndex The index of the consideration item to validate
     * @return errorsAndWarnings  The errors and warnings
     */
    function validateConsiderationItem(
        OrderParameters memory orderParameters,
        uint256 considerationItemIndex
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = ErrorsAndWarnings(new uint16[](0), new uint16[](0));

        errorsAndWarnings.concat(
            validateConsiderationItemParameters(
                orderParameters,
                considerationItemIndex
            )
        );
    }

    /**
     * @notice Validates the parameters of a consideration item including contract validation
     * @param orderParameters The parameters for the order to validate
     * @param considerationItemIndex The index of the consideration item to validate
     * @return errorsAndWarnings  The errors and warnings
     */
    function validateConsiderationItemParameters(
        OrderParameters memory orderParameters,
        uint256 considerationItemIndex
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = ErrorsAndWarnings(new uint16[](0), new uint16[](0));

        ConsiderationItem memory considerationItem = orderParameters
            .consideration[considerationItemIndex];

        // Check if startAmount and endAmount are zero
        if (
            considerationItem.startAmount == 0 &&
            considerationItem.endAmount == 0
        ) {
            errorsAndWarnings.addError(
                ConsiderationIssue.AmountZero.parseInt()
            );
            return errorsAndWarnings;
        }

        // Check if the recipient is the null address
        if (considerationItem.recipient == address(0)) {
            errorsAndWarnings.addError(
                ConsiderationIssue.NullRecipient.parseInt()
            );
        }

        if (
            considerationItem.startAmount != considerationItem.endAmount &&
            orderParameters.endTime > orderParameters.startTime
        ) {
            // Check that amount velocity is not too high.
            // Assign larger and smaller amount values
            (uint256 maxAmount, uint256 minAmount) = considerationItem
                .startAmount > considerationItem.endAmount
                ? (considerationItem.startAmount, considerationItem.endAmount)
                : (considerationItem.endAmount, considerationItem.startAmount);

            uint256 amountDelta = maxAmount - minAmount;
            // delta of time that order exists for
            uint256 timeDelta = orderParameters.endTime -
                orderParameters.startTime;

            // Velocity scaled by 1e10 for precision
            uint256 velocity = (amountDelta * 1e10) / timeDelta;
            // gives velocity percentage in hundredth of a basis points per second in terms of larger value
            uint256 velocityPercentage = velocity / (maxAmount * 1e4);

            // 278 * 60 * 30 ~= 500,000
            if (velocityPercentage > 278) {
                // Over 50% change per 30 min
                errorsAndWarnings.addError(
                    ConsiderationIssue.AmountVelocityHigh.parseInt()
                );
            }
            // 28 * 60 * 30 ~= 50,000
            else if (velocityPercentage > 28) {
                // Over 5% change per 30 min
                errorsAndWarnings.addWarning(
                    ConsiderationIssue.AmountVelocityHigh.parseInt()
                );
            }

            // Check for large amount steps
            if (minAmount <= 1e15) {
                errorsAndWarnings.addWarning(
                    ConsiderationIssue.AmountStepLarge.parseInt()
                );
            }
        }

        if (considerationItem.itemType == ItemType.ERC721) {
            // ERC721 type requires amounts to be 1
            if (
                considerationItem.startAmount != 1 ||
                considerationItem.endAmount != 1
            ) {
                errorsAndWarnings.addError(ERC721Issue.AmountNotOne.parseInt());
            }

            // Check EIP165 interface
            if (
                !checkInterface(
                    considerationItem.token,
                    type(IERC721).interfaceId
                )
            ) {
                errorsAndWarnings.addError(ERC721Issue.InvalidToken.parseInt());
                return errorsAndWarnings;
            }

            // Check that token exists
            if (
                !considerationItem.token.safeStaticCallUint256(
                    abi.encodeWithSelector(
                        IERC721.ownerOf.selector,
                        considerationItem.identifierOrCriteria
                    ),
                    1
                )
            ) {
                // Token does not exist
                errorsAndWarnings.addError(
                    ERC721Issue.IdentifierDNE.parseInt()
                );
            }
        } else if (
            considerationItem.itemType == ItemType.ERC721_WITH_CRITERIA
        ) {
            // Check EIP165 interface
            if (
                !checkInterface(
                    considerationItem.token,
                    type(IERC721).interfaceId
                )
            ) {
                // Does not implement required interface
                errorsAndWarnings.addError(ERC721Issue.InvalidToken.parseInt());
            }
        } else if (
            considerationItem.itemType == ItemType.ERC1155 ||
            considerationItem.itemType == ItemType.ERC1155_WITH_CRITERIA
        ) {
            // Check EIP165 interface
            if (
                !checkInterface(
                    considerationItem.token,
                    type(IERC1155).interfaceId
                )
            ) {
                // Does not implement required interface
                errorsAndWarnings.addError(
                    ERC1155Issue.InvalidToken.parseInt()
                );
            }
        } else if (considerationItem.itemType == ItemType.ERC20) {
            // ERC20 must have `identifierOrCriteria` be zero
            if (considerationItem.identifierOrCriteria != 0) {
                errorsAndWarnings.addError(
                    ERC20Issue.IdentifierNonZero.parseInt()
                );
            }

            // Check that it is an ERC20 token. ERC20 will return a uint256
            if (
                !considerationItem.token.safeStaticCallUint256(
                    abi.encodeWithSelector(
                        IERC20.allowance.selector,
                        address(seaport),
                        address(seaport)
                    ),
                    0
                )
            ) {
                // Not an ERC20 token
                errorsAndWarnings.addError(ERC20Issue.InvalidToken.parseInt());
            }
        } else {
            // Must be native
            // NATIVE must have `token` be zero address
            if (considerationItem.token != address(0)) {
                errorsAndWarnings.addError(NativeIssue.TokenAddress.parseInt());
            }
            // NATIVE must have `identifierOrCriteria` be zero
            if (considerationItem.identifierOrCriteria != 0) {
                errorsAndWarnings.addError(
                    NativeIssue.IdentifierNonZero.parseInt()
                );
            }
        }
    }

    /**
     * @notice Strict validation operates under tight assumptions. It validates primary
     *    fee, creator fee, private sale consideration, and overall order format.
     * @dev Only checks first fee recipient provided by CreatorFeeEngine.
     *    Order of consideration items must be as follows:
     *    1. Primary consideration
     *    2. Primary fee
     *    3. Creator Fee
     *    4. Private sale consideration
     * @param orderParameters The parameters for the order to validate.
     * @param primaryFeeRecipient The primary fee recipient. Set to null address for no primary fee.
     * @param primaryFeeBips The primary fee in BIPs.
     * @param checkCreatorFee Should check for creator fee. If true, creator fee must be present as
     *    according to creator fee engine. If false, must not have creator fee.
     * @return errorsAndWarnings The errors and warnings.
     */
    function validateStrictLogic(
        OrderParameters memory orderParameters,
        address primaryFeeRecipient,
        uint256 primaryFeeBips,
        bool checkCreatorFee
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = ErrorsAndWarnings(new uint16[](0), new uint16[](0));

        // Check that order matches the required format (listing or offer)
        {
            bool canCheckFee = true;
            // Single offer item and at least one consideration
            if (
                orderParameters.offer.length != 1 ||
                orderParameters.consideration.length == 0
            ) {
                // Not listing or offer, can't check fees
                canCheckFee = false;
            } else if (
                // Can't have both items be fungible
                isPaymentToken(orderParameters.offer[0].itemType) &&
                isPaymentToken(orderParameters.consideration[0].itemType)
            ) {
                // Not listing or offer, can't check fees
                canCheckFee = false;
            } else if (
                // Can't have both items be non-fungible
                !isPaymentToken(orderParameters.offer[0].itemType) &&
                !isPaymentToken(orderParameters.consideration[0].itemType)
            ) {
                // Not listing or offer, can't check fees
                canCheckFee = false;
            }
            if (!canCheckFee) {
                // Does not match required format
                errorsAndWarnings.addError(
                    GenericIssue.InvalidOrderFormat.parseInt()
                );
                return errorsAndWarnings;
            }
        }

        // Validate secondary consideration items (fees)
        (
            uint256 tertiaryConsiderationIndex,
            ErrorsAndWarnings memory errorsAndWarningsLocal
        ) = _validateSecondaryConsiderationItems(
                orderParameters,
                primaryFeeRecipient,
                primaryFeeBips,
                checkCreatorFee
            );

        errorsAndWarnings.concat(errorsAndWarningsLocal);

        // Validate tertiary consideration items if not 0 (0 indicates error).
        // Only if no prior errors
        if (tertiaryConsiderationIndex != 0) {
            errorsAndWarnings.concat(
                _validateTertiaryConsiderationItems(
                    orderParameters,
                    tertiaryConsiderationIndex
                )
            );
        }
    }

    function _validateSecondaryConsiderationItems(
        OrderParameters memory orderParameters,
        address primaryFeeRecipient,
        uint256 primaryFeeBips,
        bool checkCreatorFee
    )
        internal
        view
        returns (
            uint256 tertiaryConsiderationIndex,
            ErrorsAndWarnings memory errorsAndWarnings
        )
    {
        errorsAndWarnings = ErrorsAndWarnings(new uint16[](0), new uint16[](0));

        // non-fungible item address
        address itemAddress;
        // non-fungible item identifier
        uint256 itemIdentifier;
        // fungible item start amount
        uint256 transactionAmountStart;
        // fungible item end amount
        uint256 transactionAmountEnd;

        // Consideration item to hold expected creator fee info
        ConsiderationItem memory creatorFeeConsideration;

        if (isPaymentToken(orderParameters.offer[0].itemType)) {
            // Offer is an offer. oOffer item is fungible and used for fees
            creatorFeeConsideration.itemType = orderParameters
                .offer[0]
                .itemType;
            creatorFeeConsideration.token = orderParameters.offer[0].token;
            transactionAmountStart = orderParameters.offer[0].startAmount;
            transactionAmountEnd = orderParameters.offer[0].endAmount;

            // Set non-fungible information for calculating creator fee
            itemAddress = orderParameters.consideration[0].token;
            itemIdentifier = orderParameters
                .consideration[0]
                .identifierOrCriteria;
        } else {
            // Offer is an offer. Consideration item is fungible and used for fees
            creatorFeeConsideration.itemType = orderParameters
                .consideration[0]
                .itemType;
            creatorFeeConsideration.token = orderParameters
                .consideration[0]
                .token;
            transactionAmountStart = orderParameters
                .consideration[0]
                .startAmount;
            transactionAmountEnd = orderParameters.consideration[0].endAmount;

            // Set non-fungible information for calculating creator fees
            itemAddress = orderParameters.offer[0].token;
            itemIdentifier = orderParameters.offer[0].identifierOrCriteria;
        }

        // Store flag if primary fee is present
        bool primaryFeePresent = false;
        {
            // Calculate primary fee start and end amounts
            uint256 primaryFeeStartAmount = (transactionAmountStart *
                primaryFeeBips) / 10000;
            uint256 primaryFeeEndAmount = (transactionAmountEnd *
                primaryFeeBips) / 10000;

            // Check if primary fee check is desired. Skip if calculated amount is zero.
            if (
                primaryFeeRecipient != address(0) &&
                (primaryFeeStartAmount > 0 || primaryFeeEndAmount > 0)
            ) {
                // Ensure primary fee is present
                if (orderParameters.consideration.length < 2) {
                    errorsAndWarnings.addError(
                        PrimaryFeeIssue.Missing.parseInt()
                    );
                    return (0, errorsAndWarnings);
                }
                primaryFeePresent = true;

                ConsiderationItem memory primaryFeeItem = orderParameters
                    .consideration[1];

                // Check item type
                if (
                    primaryFeeItem.itemType != creatorFeeConsideration.itemType
                ) {
                    errorsAndWarnings.addError(
                        PrimaryFeeIssue.ItemType.parseInt()
                    );
                    return (0, errorsAndWarnings);
                }
                // Check token
                if (primaryFeeItem.token != creatorFeeConsideration.token) {
                    errorsAndWarnings.addError(
                        PrimaryFeeIssue.Token.parseInt()
                    );
                }
                // Check start amount
                if (primaryFeeItem.startAmount < primaryFeeStartAmount) {
                    errorsAndWarnings.addError(
                        PrimaryFeeIssue.StartAmount.parseInt()
                    );
                }
                // Check end amount
                if (primaryFeeItem.endAmount < primaryFeeEndAmount) {
                    errorsAndWarnings.addError(
                        PrimaryFeeIssue.EndAmount.parseInt()
                    );
                }
                // Check recipient
                if (primaryFeeItem.recipient != primaryFeeRecipient) {
                    errorsAndWarnings.addError(
                        PrimaryFeeIssue.Recipient.parseInt()
                    );
                }
            }
        }

        // Check creator fee
        (
            creatorFeeConsideration.recipient,
            creatorFeeConsideration.startAmount,
            creatorFeeConsideration.endAmount
        ) = getCreatorFeeInfo(
            itemAddress,
            itemIdentifier,
            transactionAmountStart,
            transactionAmountEnd
        );

        // Flag indicating if creator fee is present in considerations
        bool creatorFeePresent = false;

        // Determine if should check for creator fee
        if (
            creatorFeeConsideration.recipient != address(0) &&
            checkCreatorFee &&
            (creatorFeeConsideration.startAmount > 0 ||
                creatorFeeConsideration.endAmount > 0)
        ) {
            // Calculate index of creator fee consideration item
            uint16 creatorFeeConsiderationIndex = primaryFeePresent ? 2 : 1; // 2 if primary fee, ow 1

            // Check that creator fee consideration item exists
            if (
                orderParameters.consideration.length - 1 <
                creatorFeeConsiderationIndex
            ) {
                errorsAndWarnings.addError(CreatorFeeIssue.Missing.parseInt());
                return (0, errorsAndWarnings);
            }

            ConsiderationItem memory creatorFeeItem = orderParameters
                .consideration[creatorFeeConsiderationIndex];
            creatorFeePresent = true;

            // Check type
            if (creatorFeeItem.itemType != creatorFeeConsideration.itemType) {
                errorsAndWarnings.addError(CreatorFeeIssue.ItemType.parseInt());
                return (0, errorsAndWarnings);
            }
            // Check token
            if (creatorFeeItem.token != creatorFeeConsideration.token) {
                errorsAndWarnings.addError(CreatorFeeIssue.Token.parseInt());
            }
            // Check start amount
            if (
                creatorFeeItem.startAmount < creatorFeeConsideration.startAmount
            ) {
                errorsAndWarnings.addError(
                    CreatorFeeIssue.StartAmount.parseInt()
                );
            }
            // Check end amount
            if (creatorFeeItem.endAmount < creatorFeeConsideration.endAmount) {
                errorsAndWarnings.addError(
                    CreatorFeeIssue.EndAmount.parseInt()
                );
            }
            // Check recipient
            if (creatorFeeItem.recipient != creatorFeeConsideration.recipient) {
                errorsAndWarnings.addError(
                    CreatorFeeIssue.Recipient.parseInt()
                );
            }
        }

        // Calculate index of first tertiary consideration item
        tertiaryConsiderationIndex =
            1 +
            (primaryFeePresent ? 1 : 0) +
            (creatorFeePresent ? 1 : 0);
    }

    /**
     * @notice Fetches the on chain creator fees.
     * @dev Uses the creatorFeeEngine when available, otherwise fallback to `IERC2981`.
     * @param token The token address
     * @param tokenId The token identifier
     * @param transactionAmountStart The transaction start amount
     * @param transactionAmountEnd The transaction end amount
     * @return recipient creator fee recipient
     * @return creatorFeeAmountStart creator fee start amount
     * @return creatorFeeAmountEnd creator fee end amount
     */
    function getCreatorFeeInfo(
        address token,
        uint256 tokenId,
        uint256 transactionAmountStart,
        uint256 transactionAmountEnd
    )
        public
        view
        returns (
            address payable recipient,
            uint256 creatorFeeAmountStart,
            uint256 creatorFeeAmountEnd
        )
    {
        // Check if creator fee engine is on this chain
        if (address(creatorFeeEngine) != address(0)) {
            // Creator fee engine may revert if no creator fees are present.
            try
                creatorFeeEngine.getRoyaltyView(
                    token,
                    tokenId,
                    transactionAmountStart
                )
            returns (
                address payable[] memory creatorFeeRecipients,
                uint256[] memory creatorFeeAmountsStart
            ) {
                if (creatorFeeRecipients.length != 0) {
                    // Use first recipient and amount
                    recipient = creatorFeeRecipients[0];
                    creatorFeeAmountStart = creatorFeeAmountsStart[0];
                }
            } catch {
                // Creator fee not found
            }

            // If fees found for start amount, check end amount
            if (recipient != address(0)) {
                // Creator fee engine may revert if no creator fees are present.
                try
                    creatorFeeEngine.getRoyaltyView(
                        token,
                        tokenId,
                        transactionAmountEnd
                    )
                returns (
                    address payable[] memory,
                    uint256[] memory creatorFeeAmountsEnd
                ) {
                    creatorFeeAmountEnd = creatorFeeAmountsEnd[0];
                } catch {}
            }
        } else {
            // Fallback to ERC2981
            {
                // Static call to token using ERC2981
                (bool success, bytes memory res) = token.staticcall(
                    abi.encodeWithSelector(
                        IERC2981.royaltyInfo.selector,
                        tokenId,
                        transactionAmountStart
                    )
                );
                // Check if call succeeded
                if (success) {
                    // Ensure 64 bytes returned
                    if (res.length == 64) {
                        // Decode result and assign recipient and start amount
                        (recipient, creatorFeeAmountStart) = abi.decode(
                            res,
                            (address, uint256)
                        );
                    }
                }
            }

            // Only check end amount if start amount found
            if (recipient != address(0)) {
                // Static call to token using ERC2981
                (bool success, bytes memory res) = token.staticcall(
                    abi.encodeWithSelector(
                        IERC2981.royaltyInfo.selector,
                        tokenId,
                        transactionAmountEnd
                    )
                );
                // Check if call succeeded
                if (success) {
                    // Ensure 64 bytes returned
                    if (res.length == 64) {
                        // Decode result and assign end amount
                        (, creatorFeeAmountEnd) = abi.decode(
                            res,
                            (address, uint256)
                        );
                    }
                }
            }
        }
    }

    /**
     * @notice Internal function for validating all consideration items after the fee items.
     *    Only additional acceptable consideration is private sale.
     */
    function _validateTertiaryConsiderationItems(
        OrderParameters memory orderParameters,
        uint256 considerationItemIndex
    ) internal pure returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = ErrorsAndWarnings(new uint16[](0), new uint16[](0));

        if (orderParameters.consideration.length <= considerationItemIndex) {
            // No more consideration items
            return errorsAndWarnings;
        }

        ConsiderationItem memory privateSaleConsideration = orderParameters
            .consideration[considerationItemIndex];

        // Check if offer is payment token. Private sale not possible if so.
        if (isPaymentToken(orderParameters.offer[0].itemType)) {
            errorsAndWarnings.addError(
                ConsiderationIssue.ExtraItems.parseInt()
            );
            return errorsAndWarnings;
        }

        // Check if private sale to self
        if (privateSaleConsideration.recipient == orderParameters.offerer) {
            errorsAndWarnings.addError(
                ConsiderationIssue.PrivateSaleToSelf.parseInt()
            );
            return errorsAndWarnings;
        }

        // Ensure that private sale parameters match offer item.
        if (
            privateSaleConsideration.itemType !=
            orderParameters.offer[0].itemType ||
            privateSaleConsideration.token != orderParameters.offer[0].token ||
            orderParameters.offer[0].startAmount !=
            privateSaleConsideration.startAmount ||
            orderParameters.offer[0].endAmount !=
            privateSaleConsideration.endAmount ||
            orderParameters.offer[0].identifierOrCriteria !=
            privateSaleConsideration.identifierOrCriteria
        ) {
            // Invalid private sale, say extra consideration item
            errorsAndWarnings.addError(
                ConsiderationIssue.ExtraItems.parseInt()
            );
            return errorsAndWarnings;
        }

        errorsAndWarnings.addWarning(ConsiderationIssue.PrivateSale.parseInt());

        // Should not be any additional consideration items
        if (orderParameters.consideration.length - 1 > considerationItemIndex) {
            // Extra consideration items
            errorsAndWarnings.addError(
                ConsiderationIssue.ExtraItems.parseInt()
            );
            return errorsAndWarnings;
        }
    }

    /**
     * @notice Validates the zone call for an order
     * @param orderParameters The parameters for the order to validate
     * @return errorsAndWarnings An ErrorsAndWarnings structs with results
     */
    function isValidZone(
        OrderParameters memory orderParameters
    ) public view returns (ErrorsAndWarnings memory errorsAndWarnings) {
        errorsAndWarnings = ErrorsAndWarnings(new uint16[](0), new uint16[](0));

        // If not restricted, zone isn't checked
        if (uint8(orderParameters.orderType) < 2) {
            return errorsAndWarnings;
        }

        if (orderParameters.zone == address(0)) {
            // Zone is not set
            errorsAndWarnings.addError(ZoneIssue.NotSet.parseInt());
            return errorsAndWarnings;
        }

        // EOA zone is always valid
        if (address(orderParameters.zone).code.length == 0) {
            // Address is EOA. Valid order
            return errorsAndWarnings;
        }

        // Get counter to derive order hash
        uint256 currentOffererCounter = seaport.getCounter(
            orderParameters.offerer
        );

        // Call zone function `isValidOrder` with `msg.sender` as the caller
        if (
            !orderParameters.zone.safeStaticCallBytes4(
                abi.encodeWithSelector(
                    ZoneInterface.isValidOrder.selector,
                    _deriveOrderHash(orderParameters, currentOffererCounter),
                    msg.sender,
                    orderParameters.offerer,
                    orderParameters.zoneHash
                ),
                ZoneInterface.isValidOrder.selector
            )
        ) {
            errorsAndWarnings.addWarning(ZoneIssue.RejectedOrder.parseInt());
        }
    }

    /**
     * @notice Safely check that a contract implements an interface
     * @param token The token address to check
     * @param interfaceHash The interface hash to check
     */
    function checkInterface(
        address token,
        bytes4 interfaceHash
    ) public view returns (bool) {
        return
            token.safeStaticCallBool(
                abi.encodeWithSelector(
                    IERC165.supportsInterface.selector,
                    interfaceHash
                ),
                true
            );
    }

    function isPaymentToken(ItemType itemType) public pure returns (bool) {
        return itemType == ItemType.NATIVE || itemType == ItemType.ERC20;
    }

    /*//////////////////////////////////////////////////////////////
                        Merkle Helpers
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sorts an array of token ids by the keccak256 hash of the id. Required ordering of ids
     *    for other merkle operations.
     * @param includedTokens An array of included token ids.
     * @return sortedTokens The sorted `includedTokens` array.
     */
    function sortMerkleTokens(
        uint256[] memory includedTokens
    ) public pure returns (uint256[] memory sortedTokens) {
        // Sort token ids by the keccak256 hash of the id
        return _sortUint256ByHash(includedTokens);
    }

    /**
     * @notice Creates a merkle root for includedTokens.
     * @dev `includedTokens` must be sorting in strictly ascending order according to the keccak256 hash of the value.
     * @return merkleRoot The merkle root
     * @return errorsAndWarnings Errors and warnings from the operation
     */
    function getMerkleRoot(
        uint256[] memory includedTokens
    )
        public
        pure
        returns (bytes32 merkleRoot, ErrorsAndWarnings memory errorsAndWarnings)
    {
        (merkleRoot, errorsAndWarnings) = _getRoot(includedTokens);
    }

    /**
     * @notice Creates a merkle proof for the the targetIndex contained in includedTokens.
     * @dev `targetIndex` is referring to the index of an element in `includedTokens`.
     *    `includedTokens` must be sorting in ascending order according to the keccak256 hash of the value.
     * @return merkleProof The merkle proof
     * @return errorsAndWarnings Errors and warnings from the operation
     */
    function getMerkleProof(
        uint256[] memory includedTokens,
        uint256 targetIndex
    )
        public
        pure
        returns (
            bytes32[] memory merkleProof,
            ErrorsAndWarnings memory errorsAndWarnings
        )
    {
        (merkleProof, errorsAndWarnings) = _getProof(
            includedTokens,
            targetIndex
        );
    }

    /**
     * @notice Verifies a merkle proof for the value to prove and given root and proof.
     * @dev The `valueToProve` is hashed prior to executing the proof verification.
     * @param merkleRoot The root of the merkle tree
     * @param merkleProof The merkle proof
     * @param valueToProve The value to prove
     * @return whether proof is valid
     */
    function verifyMerkleProof(
        bytes32 merkleRoot,
        bytes32[] memory merkleProof,
        uint256 valueToProve
    ) public pure returns (bool) {
        bytes32 hashedValue = keccak256(abi.encode(valueToProve));

        return _verifyProof(merkleRoot, merkleProof, hashedValue);
    }
}
