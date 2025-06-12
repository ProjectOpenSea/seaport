import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract } from "ethers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("SecureMarketplace Security Tests", function () {
    let marketplace: Contract;
    let nftContract: Contract;
    let owner: SignerWithAddress;
    let seller: SignerWithAddress;
    let buyer: SignerWithAddress;
    let attacker: SignerWithAddress;
    let listingId: string;
    const PRICE = ethers.utils.parseEther("1.0");
    const TOKEN_ID = 1;

    beforeEach(async function () {
        [owner, seller, buyer, attacker] = await ethers.getSigners();

        // Deploy mock NFT contract
        const MockNFT = await ethers.getContractFactory("MockNFT");
        nftContract = await MockNFT.deploy();
        await nftContract.deployed();

        // Deploy marketplace
        const SecureMarketplace = await ethers.getContractFactory("SecureMarketplace");
        marketplace = await SecureMarketplace.deploy();
        await marketplace.deployed();

        // Setup: Mint NFT to seller and approve marketplace
        await nftContract.mint(seller.address, TOKEN_ID);
        await nftContract.connect(seller).approve(marketplace.address, TOKEN_ID);

        // Create listing
        const tx = await marketplace.connect(seller).createListing(
            nftContract.address,
            TOKEN_ID,
            PRICE
        );
        const receipt = await tx.wait();
        const event = receipt.events.find((e: any) => e.event === "ListingCreated");
        listingId = event.args.listingId;
    });

    describe("Reentrancy Protection", function () {
        it("should prevent reentrancy attack during buyNFT", async function () {
            // Deploy malicious contract
            const MaliciousContract = await ethers.getContractFactory("MaliciousContract");
            const malicious = await MaliciousContract.deploy(marketplace.address);
            await malicious.deployed();

            // Fund malicious contract
            await owner.sendTransaction({
                to: malicious.address,
                value: ethers.utils.parseEther("2.0")
            });

            // Attempt reentrancy attack
            await expect(
                malicious.attack(listingId, { value: PRICE })
            ).to.be.revertedWith("ReentrancyGuard: reentrant call");
        });

        it("should prevent reentrancy attack during offer creation", async function () {
            const MaliciousContract = await ethers.getContractFactory("MaliciousContract");
            const malicious = await MaliciousContract.deploy(marketplace.address);
            await malicious.deployed();

            await owner.sendTransaction({
                to: malicious.address,
                value: ethers.utils.parseEther("2.0")
            });

            await expect(
                malicious.attackOffer(listingId, { value: PRICE })
            ).to.be.revertedWith("ReentrancyGuard: reentrant call");
        });
    });

    describe("Price Manipulation Protection", function () {
        it("should prevent price overflow attack", async function () {
            const MAX_PRICE = ethers.utils.parseEther("1000");
            await expect(
                marketplace.connect(seller).createListing(
                    nftContract.address,
                    TOKEN_ID + 1,
                    MAX_PRICE.add(1)
                )
            ).to.be.revertedWith("Price too high");
        });

        it("should handle zero price correctly", async function () {
            await expect(
                marketplace.connect(seller).createListing(
                    nftContract.address,
                    TOKEN_ID + 1,
                    0
                )
            ).to.not.be.reverted;
        });
    });

    describe("Access Control", function () {
        it("should prevent unauthorized listing cancellation", async function () {
            await expect(
                marketplace.connect(attacker).cancelListing(listingId)
            ).to.be.revertedWith("Not seller");
        });

        it("should prevent unauthorized offer acceptance", async function () {
            await marketplace.connect(buyer).createOffer(listingId, PRICE, {
                value: PRICE
            });

            await expect(
                marketplace.connect(attacker).acceptOffer(listingId, buyer.address)
            ).to.be.revertedWith("Not seller");
        });
    });

    describe("Transaction Replay Protection", function () {
        it("should prevent double execution of the same order", async function () {
            // First execution
            await marketplace.connect(buyer).buyNFT(listingId, {
                value: PRICE
            });

            // Attempt second execution
            await expect(
                marketplace.connect(attacker).buyNFT(listingId, {
                    value: PRICE
                })
            ).to.be.revertedWith("Order already executed");
        });
    });

    describe("Offer Expiration", function () {
        it("should prevent accepting expired offers", async function () {
            await marketplace.connect(buyer).createOffer(listingId, PRICE, {
                value: PRICE
            });

            // Fast forward time
            await time.increase(8 * 24 * 60 * 60); // 8 days

            await expect(
                marketplace.connect(seller).acceptOffer(listingId, buyer.address)
            ).to.be.revertedWith("Offer expired");
        });
    });

    describe("Payment Handling", function () {
        it("should handle exact payment correctly", async function () {
            await expect(
                marketplace.connect(buyer).buyNFT(listingId, {
                    value: PRICE
                })
            ).to.not.be.reverted;
        });

        it("should handle excess payment correctly", async function () {
            const excessAmount = PRICE.add(ethers.utils.parseEther("0.1"));
            const initialBalance = await buyer.getBalance();

            await marketplace.connect(buyer).buyNFT(listingId, {
                value: excessAmount
            });

            const finalBalance = await buyer.getBalance();
            expect(finalBalance).to.be.gt(initialBalance.sub(excessAmount));
        });

        it("should prevent insufficient payment", async function () {
            await expect(
                marketplace.connect(buyer).buyNFT(listingId, {
                    value: PRICE.sub(1)
                })
            ).to.be.revertedWith("Insufficient payment");
        });
    });

    describe("Emergency Functions", function () {
        it("should prevent operations when paused", async function () {
            await marketplace.pause();

            await expect(
                marketplace.connect(seller).createListing(
                    nftContract.address,
                    TOKEN_ID + 1,
                    PRICE
                )
            ).to.be.revertedWith("Pausable: paused");

            await expect(
                marketplace.connect(buyer).buyNFT(listingId, {
                    value: PRICE
                })
            ).to.be.revertedWith("Pausable: paused");
        });
    });

    describe("NFT Transfer Security", function () {
        it("should prevent transfer to zero address", async function () {
            const MaliciousContract = await ethers.getContractFactory("MaliciousContract");
            const malicious = await MaliciousContract.deploy(marketplace.address);
            await malicious.deployed();

            await expect(
                malicious.attackZeroAddress(listingId, { value: PRICE })
            ).to.be.revertedWith("ERC721: transfer to the zero address");
        });

        it("should prevent transfer without approval", async function () {
            // Create new listing without approval
            await nftContract.mint(seller.address, TOKEN_ID + 1);
            await expect(
                marketplace.connect(seller).createListing(
                    nftContract.address,
                    TOKEN_ID + 1,
                    PRICE
                )
            ).to.be.revertedWith("Not approved");
        });
    });

    describe("Front-running Protection", function () {
        it("should prevent front-running of listings", async function () {
            const nonce = await marketplace.nonces(seller.address);
            const listingId2 = ethers.utils.keccak256(
                ethers.utils.defaultAbiCoder.encode(
                    ["address", "uint32", "uint96", "uint256", "uint256"],
                    [nftContract.address, TOKEN_ID + 1, PRICE, await time.latest(), nonce]
                )
            );

            // Create listing
            await nftContract.mint(seller.address, TOKEN_ID + 1);
            await nftContract.connect(seller).approve(marketplace.address, TOKEN_ID + 1);
            await marketplace.connect(seller).createListing(
                nftContract.address,
                TOKEN_ID + 1,
                PRICE
            );

            // Attempt to create same listing again
            await expect(
                marketplace.connect(seller).createListing(
                    nftContract.address,
                    TOKEN_ID + 1,
                    PRICE
                )
            ).to.be.revertedWith("Listing already exists");
        });
    });
}); 