// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TransferAttack
 * @dev Mock contract to test various transfer-related attacks
 */
contract TransferAttack {
    // Attack vectors for testing
    enum AttackType {
        TRANSFER_LOOP,
        BATCH_OVERFLOW,
        APPROVAL_OVERFLOW,
        TRANSFER_TO_SELF,
        TRANSFER_TO_CONTRACT,
        TRANSFER_TO_ZERO,
        TRANSFER_WITHOUT_APPROVAL,
        TRANSFER_WITH_INVALID_AMOUNT,
        TRANSFER_WITH_INVALID_TOKEN,
        TRANSFER_WITH_INVALID_RECIPIENT
    }

    // State variables for attack tracking
    mapping(AttackType => bool) public attackAttempted;
    mapping(AttackType => bool) public attackSuccessful;
    
    // Events for attack tracking
    event AttackAttempted(AttackType attackType, bool success);
    event TransferAttempted(address token, address from, address to, uint256 amount);

    /**
     * @dev Attempt transfer loop attack
     */
    function attemptTransferLoop(
        address token,
        address[] calldata recipients,
        uint256 amount
    ) external {
        attackAttempted[AttackType.TRANSFER_LOOP] = true;
        
        try IERC20(token).transferFrom(msg.sender, address(this), amount * recipients.length) {
            for (uint256 i = 0; i < recipients.length; i++) {
                IERC20(token).transfer(recipients[i], amount);
            }
            attackSuccessful[AttackType.TRANSFER_LOOP] = true;
        } catch {
            attackSuccessful[AttackType.TRANSFER_LOOP] = false;
        }
        
        emit AttackAttempted(AttackType.TRANSFER_LOOP, attackSuccessful[AttackType.TRANSFER_LOOP]);
    }

    /**
     * @dev Attempt batch transfer overflow attack
     */
    function attemptBatchOverflow(
        address token,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external {
        attackAttempted[AttackType.BATCH_OVERFLOW] = true;
        
        try IERC20(token).transferFrom(msg.sender, address(this), type(uint256).max) {
            for (uint256 i = 0; i < recipients.length; i++) {
                IERC20(token).transfer(recipients[i], amounts[i]);
            }
            attackSuccessful[AttackType.BATCH_OVERFLOW] = true;
        } catch {
            attackSuccessful[AttackType.BATCH_OVERFLOW] = false;
        }
        
        emit AttackAttempted(AttackType.BATCH_OVERFLOW, attackSuccessful[AttackType.BATCH_OVERFLOW]);
    }

    /**
     * @dev Attempt approval overflow attack
     */
    function attemptApprovalOverflow(
        address token,
        address spender
    ) external {
        attackAttempted[AttackType.APPROVAL_OVERFLOW] = true;
        
        try IERC20(token).approve(spender, type(uint256).max) {
            attackSuccessful[AttackType.APPROVAL_OVERFLOW] = true;
        } catch {
            attackSuccessful[AttackType.APPROVAL_OVERFLOW] = false;
        }
        
        emit AttackAttempted(AttackType.APPROVAL_OVERFLOW, attackSuccessful[AttackType.APPROVAL_OVERFLOW]);
    }

    /**
     * @dev Attempt transfer to self attack
     */
    function attemptTransferToSelf(
        address token,
        uint256 amount
    ) external {
        attackAttempted[AttackType.TRANSFER_TO_SELF] = true;
        
        try IERC20(token).transferFrom(msg.sender, address(this), amount) {
            IERC20(token).transfer(address(this), amount);
            attackSuccessful[AttackType.TRANSFER_TO_SELF] = true;
        } catch {
            attackSuccessful[AttackType.TRANSFER_TO_SELF] = false;
        }
        
        emit AttackAttempted(AttackType.TRANSFER_TO_SELF, attackSuccessful[AttackType.TRANSFER_TO_SELF]);
    }

    /**
     * @dev Attempt transfer to contract attack
     */
    function attemptTransferToContract(
        address token,
        address contractAddress,
        uint256 amount
    ) external {
        attackAttempted[AttackType.TRANSFER_TO_CONTRACT] = true;
        
        try IERC20(token).transferFrom(msg.sender, address(this), amount) {
            IERC20(token).transfer(contractAddress, amount);
            attackSuccessful[AttackType.TRANSFER_TO_CONTRACT] = true;
        } catch {
            attackSuccessful[AttackType.TRANSFER_TO_CONTRACT] = false;
        }
        
        emit AttackAttempted(AttackType.TRANSFER_TO_CONTRACT, attackSuccessful[AttackType.TRANSFER_TO_CONTRACT]);
    }

    /**
     * @dev Attempt transfer to zero address attack
     */
    function attemptTransferToZero(
        address token,
        uint256 amount
    ) external {
        attackAttempted[AttackType.TRANSFER_TO_ZERO] = true;
        
        try IERC20(token).transferFrom(msg.sender, address(this), amount) {
            IERC20(token).transfer(address(0), amount);
            attackSuccessful[AttackType.TRANSFER_TO_ZERO] = true;
        } catch {
            attackSuccessful[AttackType.TRANSFER_TO_ZERO] = false;
        }
        
        emit AttackAttempted(AttackType.TRANSFER_TO_ZERO, attackSuccessful[AttackType.TRANSFER_TO_ZERO]);
    }

    /**
     * @dev Attempt transfer without approval attack
     */
    function attemptTransferWithoutApproval(
        address token,
        address recipient,
        uint256 amount
    ) external {
        attackAttempted[AttackType.TRANSFER_WITHOUT_APPROVAL] = true;
        
        try IERC20(token).transferFrom(msg.sender, recipient, amount) {
            attackSuccessful[AttackType.TRANSFER_WITHOUT_APPROVAL] = true;
        } catch {
            attackSuccessful[AttackType.TRANSFER_WITHOUT_APPROVAL] = false;
        }
        
        emit AttackAttempted(
            AttackType.TRANSFER_WITHOUT_APPROVAL,
            attackSuccessful[AttackType.TRANSFER_WITHOUT_APPROVAL]
        );
    }

    /**
     * @dev Attempt transfer with invalid amount attack
     */
    function attemptTransferWithInvalidAmount(
        address token,
        address recipient
    ) external {
        attackAttempted[AttackType.TRANSFER_WITH_INVALID_AMOUNT] = true;
        
        try IERC20(token).transferFrom(msg.sender, address(this), type(uint256).max) {
            IERC20(token).transfer(recipient, type(uint256).max);
            attackSuccessful[AttackType.TRANSFER_WITH_INVALID_AMOUNT] = true;
        } catch {
            attackSuccessful[AttackType.TRANSFER_WITH_INVALID_AMOUNT] = false;
        }
        
        emit AttackAttempted(
            AttackType.TRANSFER_WITH_INVALID_AMOUNT,
            attackSuccessful[AttackType.TRANSFER_WITH_INVALID_AMOUNT]
        );
    }

    /**
     * @dev Attempt transfer with invalid token attack
     */
    function attemptTransferWithInvalidToken(
        address recipient,
        uint256 amount
    ) external {
        attackAttempted[AttackType.TRANSFER_WITH_INVALID_TOKEN] = true;
        
        try IERC20(address(0)).transfer(recipient, amount) {
            attackSuccessful[AttackType.TRANSFER_WITH_INVALID_TOKEN] = true;
        } catch {
            attackSuccessful[AttackType.TRANSFER_WITH_INVALID_TOKEN] = false;
        }
        
        emit AttackAttempted(
            AttackType.TRANSFER_WITH_INVALID_TOKEN,
            attackSuccessful[AttackType.TRANSFER_WITH_INVALID_TOKEN]
        );
    }

    /**
     * @dev Attempt transfer with invalid recipient attack
     */
    function attemptTransferWithInvalidRecipient(
        address token,
        uint256 amount
    ) external {
        attackAttempted[AttackType.TRANSFER_WITH_INVALID_RECIPIENT] = true;
        
        try IERC20(token).transferFrom(msg.sender, address(this), amount) {
            IERC20(token).transfer(address(0xdead), amount);
            attackSuccessful[AttackType.TRANSFER_WITH_INVALID_RECIPIENT] = true;
        } catch {
            attackSuccessful[AttackType.TRANSFER_WITH_INVALID_RECIPIENT] = false;
        }
        
        emit AttackAttempted(
            AttackType.TRANSFER_WITH_INVALID_RECIPIENT,
            attackSuccessful[AttackType.TRANSFER_WITH_INVALID_RECIPIENT]
        );
    }

    // Function to receive ETH
    receive() external payable {}
} 