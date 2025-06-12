import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract } from "ethers";

describe("AI Similarity Detection Tests", function () {
    let artAuthenticity: Contract;
    let aiSimilarity: Contract;
    let owner: SignerWithAddress;
    let artist: SignerWithAddress;
    let aiProvider: SignerWithAddress;
    let buyer: SignerWithAddress;

    const MINIMUM_CURATOR_STAKE = ethers.utils.parseEther("1.0");
    const MIN_SIMILARITY_THRESHOLD = 80;
    const MAX_FEATURE_VECTOR_SIZE = 100;
    const CONTENT_HASH = "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco";
    const FEATURE_VECTOR = ["feature1", "feature2", "feature3"];

    beforeEach(async function () {
        [owner, artist, aiProvider, buyer] = await ethers.getSigners();

        // Deploy ArtAuthenticity contract
        const ArtAuthenticity = await ethers.getContractFactory("ArtAuthenticity");
        artAuthenticity = await ArtAuthenticity.deploy(MINIMUM_CURATOR_STAKE);
        await artAuthenticity.deployed();

        // Deploy AISimilarityDetection contract
        const AISimilarityDetection = await ethers.getContractFactory("AISimilarityDetection");
        aiSimilarity = await AISimilarityDetection.deploy(
            artAuthenticity.address,
            MIN_SIMILARITY_THRESHOLD,
            MAX_FEATURE_VECTOR_SIZE
        );
        await aiSimilarity.deployed();

        // Add AI provider
        await aiSimilarity.addAIProvider(aiProvider.address);
    });

    describe("Similarity Check Request", function () {
        it("should allow artist to request similarity check", async function () {
            await expect(
                aiSimilarity.connect(artist).requestSimilarityCheck(
                    CONTENT_HASH,
                    FEATURE_VECTOR
                )
            ).to.emit(aiSimilarity, "SimilarityCheckRequested")
                .withArgs(CONTENT_HASH, artist.address, await ethers.provider.getBlockNumber());
        });

        it("should prevent duplicate similarity checks", async function () {
            await aiSimilarity.connect(artist).requestSimilarityCheck(
                CONTENT_HASH,
                FEATURE_VECTOR
            );

            await expect(
                aiSimilarity.connect(artist).requestSimilarityCheck(
                    CONTENT_HASH,
                    FEATURE_VECTOR
                )
            ).to.be.revertedWith("Check already processed");
        });

        it("should prevent oversized feature vectors", async function () {
            const largeVector = Array(MAX_FEATURE_VECTOR_SIZE + 1).fill("feature");

            await expect(
                aiSimilarity.connect(artist).requestSimilarityCheck(
                    CONTENT_HASH,
                    largeVector
                )
            ).to.be.revertedWith("Feature vector too large");
        });
    });

    describe("Similarity Check Processing", function () {
        beforeEach(async function () {
            await aiSimilarity.connect(artist).requestSimilarityCheck(
                CONTENT_HASH,
                FEATURE_VECTOR
            );
        });

        it("should allow AI provider to process similarity check", async function () {
            const similarArtworks = ["similar1", "similar2"];

            await expect(
                aiSimilarity.connect(aiProvider).processSimilarityCheck(
                    CONTENT_HASH,
                    85,
                    similarArtworks
                )
            ).to.emit(aiSimilarity, "SimilarityCheckProcessed")
                .withArgs(CONTENT_HASH, 85, similarArtworks);
        });

        it("should prevent non-AI provider from processing", async function () {
            await expect(
                aiSimilarity.connect(buyer).processSimilarityCheck(
                    CONTENT_HASH,
                    85,
                    ["similar1"]
                )
            ).to.be.revertedWith("Not authorized AI provider");
        });

        it("should prevent invalid similarity scores", async function () {
            await expect(
                aiSimilarity.connect(aiProvider).processSimilarityCheck(
                    CONTENT_HASH,
                    101,
                    ["similar1"]
                )
            ).to.be.revertedWith("Invalid similarity score");
        });
    });

    describe("AI Provider Management", function () {
        it("should allow owner to add AI provider", async function () {
            await expect(
                aiSimilarity.addAIProvider(buyer.address)
            ).to.emit(aiSimilarity, "AIProviderAuthorized")
                .withArgs(buyer.address);
        });

        it("should allow owner to remove AI provider", async function () {
            await expect(
                aiSimilarity.removeAIProvider(aiProvider.address)
            ).to.emit(aiSimilarity, "AIProviderRemoved")
                .withArgs(aiProvider.address);
        });

        it("should prevent non-owner from managing AI providers", async function () {
            await expect(
                aiSimilarity.connect(artist).addAIProvider(buyer.address)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe("AI Configuration", function () {
        it("should allow owner to update AI config", async function () {
            await expect(
                aiSimilarity.updateAIConfig(90, 200, true)
            ).to.emit(aiSimilarity, "AIConfigUpdated")
                .withArgs(90, 200, true);
        });

        it("should prevent invalid similarity threshold", async function () {
            await expect(
                aiSimilarity.updateAIConfig(101, 200, true)
            ).to.be.revertedWith("Invalid threshold");
        });

        it("should prevent invalid feature vector size", async function () {
            await expect(
                aiSimilarity.updateAIConfig(90, 0, true)
            ).to.be.revertedWith("Invalid vector size");
        });
    });

    describe("Similarity Queries", function () {
        beforeEach(async function () {
            await aiSimilarity.connect(artist).requestSimilarityCheck(
                CONTENT_HASH,
                FEATURE_VECTOR
            );
            await aiSimilarity.connect(aiProvider).processSimilarityCheck(
                CONTENT_HASH,
                85,
                ["similar1"]
            );
        });

        it("should correctly identify similar artworks", async function () {
            expect(await aiSimilarity.isSimilarToExisting(CONTENT_HASH))
                .to.be.true;
        });

        it("should return correct similarity check details", async function () {
            const [isProcessed, score, similarArtworks, timestamp] =
                await aiSimilarity.getSimilarityCheck(CONTENT_HASH);

            expect(isProcessed).to.be.true;
            expect(score).to.equal(85);
            expect(similarArtworks).to.include("similar1");
            expect(timestamp).to.be.gt(0);
        });

        it("should return correct feature vector", async function () {
            const featureVector = await aiSimilarity.getFeatureVector(CONTENT_HASH);
            expect(featureVector).to.deep.equal(FEATURE_VECTOR);
        });
    });
}); 