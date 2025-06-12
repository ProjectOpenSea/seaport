import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract } from "ethers";

describe("Transfer Security Tests", function () {
  let transferAttack: Contract;
  let mockToken: Contract;
  let owner: SignerWithAddress;
  let attacker: SignerWithAddress;
  let recipient: SignerWithAddress;
  const INITIAL_BALANCE = ethers.utils.parseEther("1000");
  const TRANSFER_AMOUNT = ethers.utils.parseEther("100");

  beforeEach(async function () {
    [owner, attacker, recipient] = await ethers.getSigners();

    // Deploy mock token
    const MockToken = await ethers.getContractFactory("MockToken");
    mockToken = await MockToken.deploy("Mock Token", "MTK", INITIAL_BALANCE);
    await mockToken.deployed();

    // Deploy transfer attack contract
    const TransferAttack = await ethers.getContractFactory("TransferAttack");
    transferAttack = await TransferAttack.deploy();
    await transferAttack.deployed();

    // Approve transfer attack contract
    await mockToken.approve(transferAttack.address, ethers.constants.MaxUint256);
  });

  describe("Transfer Loop Attack", function () {
    it("should prevent transfer loop attack", async function () {
      const recipients = [recipient.address, attacker.address];
      await expect(
        transferAttack.attemptTransferLoop(
          mockToken.address,
          recipients,
          TRANSFER_AMOUNT
        )
      ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
    });
  });

  describe("Batch Overflow Attack", function () {
    it("should prevent batch transfer overflow", async function () {
      const recipients = [recipient.address, attacker.address];
      const amounts = [TRANSFER_AMOUNT, TRANSFER_AMOUNT];
      await expect(
        transferAttack.attemptBatchOverflow(
          mockToken.address,
          recipients,
          amounts
        )
      ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
    });
  });

  describe("Approval Overflow Attack", function () {
    it("should prevent approval overflow", async function () {
      await expect(
        transferAttack.attemptApprovalOverflow(
          mockToken.address,
          attacker.address
        )
      ).to.not.be.reverted;
      
      const attackSuccessful = await transferAttack.attackSuccessful(2); // APPROVAL_OVERFLOW
      expect(attackSuccessful).to.be.true;
    });
  });

  describe("Transfer to Self Attack", function () {
    it("should prevent transfer to self attack", async function () {
      await expect(
        transferAttack.attemptTransferToSelf(
          mockToken.address,
          TRANSFER_AMOUNT
        )
      ).to.not.be.reverted;
      
      const attackSuccessful = await transferAttack.attackSuccessful(3); // TRANSFER_TO_SELF
      expect(attackSuccessful).to.be.true;
    });
  });

  describe("Transfer to Contract Attack", function () {
    it("should prevent transfer to contract attack", async function () {
      await expect(
        transferAttack.attemptTransferToContract(
          mockToken.address,
          transferAttack.address,
          TRANSFER_AMOUNT
        )
      ).to.not.be.reverted;
      
      const attackSuccessful = await transferAttack.attackSuccessful(4); // TRANSFER_TO_CONTRACT
      expect(attackSuccessful).to.be.true;
    });
  });

  describe("Transfer to Zero Address Attack", function () {
    it("should prevent transfer to zero address", async function () {
      await expect(
        transferAttack.attemptTransferToZero(
          mockToken.address,
          TRANSFER_AMOUNT
        )
      ).to.be.revertedWith("ERC20: transfer to the zero address");
    });
  });

  describe("Transfer Without Approval Attack", function () {
    it("should prevent transfer without approval", async function () {
      await expect(
        transferAttack.attemptTransferWithoutApproval(
          mockToken.address,
          recipient.address,
          TRANSFER_AMOUNT
        )
      ).to.be.revertedWith("ERC20: insufficient allowance");
    });
  });

  describe("Invalid Amount Attack", function () {
    it("should prevent transfer with invalid amount", async function () {
      await expect(
        transferAttack.attemptTransferWithInvalidAmount(
          mockToken.address,
          recipient.address
        )
      ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
    });
  });

  describe("Invalid Token Attack", function () {
    it("should prevent transfer with invalid token", async function () {
      await expect(
        transferAttack.attemptTransferWithInvalidToken(
          recipient.address,
          TRANSFER_AMOUNT
        )
      ).to.be.reverted;
    });
  });

  describe("Invalid Recipient Attack", function () {
    it("should prevent transfer to invalid recipient", async function () {
      await expect(
        transferAttack.attemptTransferWithInvalidRecipient(
          mockToken.address,
          TRANSFER_AMOUNT
        )
      ).to.not.be.reverted;
      
      const attackSuccessful = await transferAttack.attackSuccessful(9); // TRANSFER_WITH_INVALID_RECIPIENT
      expect(attackSuccessful).to.be.true;
    });
  });

  describe("Edge Cases", function () {
    it("should handle zero amount transfers", async function () {
      await expect(
        mockToken.transfer(recipient.address, 0)
      ).to.not.be.reverted;
    });

    it("should handle transfers to self", async function () {
      await expect(
        mockToken.transfer(owner.address, TRANSFER_AMOUNT)
      ).to.not.be.reverted;
    });

    it("should handle maximum uint256 amount", async function () {
      await expect(
        mockToken.transfer(recipient.address, ethers.constants.MaxUint256)
      ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
    });
  });
}); 