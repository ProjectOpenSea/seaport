import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract } from "ethers";

describe("IP Violation Tests", function () {
    let marketplace: Contract;
    let nftContract: Contract;
    let owner: SignerWithAddress;
    let seller: SignerWithAddress;
    let buyer: SignerWithAddress;
    let ipEnforcer: SignerWithAddress;
    let reporter: SignerWithAddress;
    const TOKEN_ID = 1;
    const PRICE = ethers.utils.parseEther("1.0");

    beforeEach(async function () {
        [owner, seller, buyer, ipEnforcer, reporter] = await ethers.getSigners();

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
        const listingId = event.args.listingId;

        // Set up IP enforcer
        await marketplace.setIPEnforcer(ipEnforcer.address, true);
    });

    describe("IP Violation Reporting", function () {
        it("should allow anyone to report IP violation", async function () {
            const listingId = await marketplace.listings(0);
            await expect(
                marketplace.connect(reporter).reportIPViolation(
                    listingId,
                    "Copyright violation"
                )
            ).to.emit(marketplace, "IPViolationReported")
                .withArgs(listingId, reporter.address, "Copyright violation");
        });

        it("should not allow reporting on non-existent listing", async function () {
            const nonExistentListingId = ethers.utils.keccak256(
                ethers.utils.defaultAbiCoder.encode(
                    ["address", "uint32", "uint96", "uint256"],
                    [nftContract.address, TOKEN_ID + 1, PRICE, 0]
                )
            );

            await expect(
                marketplace.connect(reporter).reportIPViolation(
                    nonExistentListingId,
                    "Copyright violation"
                )
            ).to.be.revertedWith("Listing not active");
        });
    });

    describe("Token Burning", function () {
        it("should allow IP enforcer to burn token", async function () {
            await expect(
                marketplace.connect(ipEnforcer).burnTokenForIPViolation(
                    nftContract.address,
                    TOKEN_ID,
                    "Confirmed copyright violation"
                )
            ).to.emit(marketplace, "TokenBurned")
                .withArgs(nftContract.address, TOKEN_ID, ipEnforcer.address, "Confirmed copyright violation");

            // Verify token is burned
            expect(await marketplace.isTokenBurned(nftContract.address, TOKEN_ID))
                .to.be.true;
        });

        it("should not allow non-IP enforcer to burn token", async function () {
            await expect(
                marketplace.connect(reporter).burnTokenForIPViolation(
                    nftContract.address,
                    TOKEN_ID,
                    "Copyright violation"
                )
            ).to.be.revertedWith("Not authorized IP enforcer");
        });

        it("should not allow burning already burned token", async function () {
            // First burn
            await marketplace.connect(ipEnforcer).burnTokenForIPViolation(
                nftContract.address,
                TOKEN_ID,
                "First burn"
            );

            // Attempt second burn
            await expect(
                marketplace.connect(ipEnforcer).burnTokenForIPViolation(
                    nftContract.address,
                    TOKEN_ID,
                    "Second burn"
                )
            ).to.be.revertedWith("Token already burned");
        });

        it("should cancel active listing when token is burned", async function () {
            const listingId = await marketplace.listings(0);

            // Burn token
            await marketplace.connect(ipEnforcer).burnTokenForIPViolation(
                nftContract.address,
                TOKEN_ID,
                "Copyright violation"
            );

            // Verify listing is cancelled
            const listing = await marketplace.listings(listingId);
            expect(listing.isActive).to.be.false;
        });
    });

    describe("IP Enforcer Management", function () {
        it("should allow owner to add IP enforcer", async function () {
            await expect(
                marketplace.setIPEnforcer(reporter.address, true)
            ).to.not.be.reverted;

            expect(await marketplace.ipEnforcers(reporter.address)).to.be.true;
        });

        it("should allow owner to remove IP enforcer", async function () {
            // First add enforcer
            await marketplace.setIPEnforcer(reporter.address, true);

            // Then remove
            await expect(
                marketplace.setIPEnforcer(reporter.address, false)
            ).to.not.be.reverted;

            expect(await marketplace.ipEnforcers(reporter.address)).to.be.false;
        });

        it("should not allow non-owner to manage IP enforcers", async function () {
            await expect(
                marketplace.connect(reporter).setIPEnforcer(buyer.address, true)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });
}); 