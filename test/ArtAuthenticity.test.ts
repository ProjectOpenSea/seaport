import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract } from "ethers";

describe("ArtAuthenticity Tests", function () {
  let artAuthenticity: Contract;
  let owner: SignerWithAddress;
  let artist: SignerWithAddress;
  let curator: SignerWithAddress;
  let buyer: SignerWithAddress;
  const MINIMUM_CURATOR_STAKE = ethers.utils.parseEther("1.0");
  const CONTENT_HASH = "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco";
  const METADATA_HASH = "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco";
  const CHAIN_ID = "ethereum";

  beforeEach(async function () {
    [owner, artist, curator, buyer] = await ethers.getSigners();

    const ArtAuthenticity = await ethers.getContractFactory("ArtAuthenticity");
    artAuthenticity = await ArtAuthenticity.deploy(MINIMUM_CURATOR_STAKE);
    await artAuthenticity.deployed();

    // Setup: Add curator and support chain
    await artAuthenticity.addCurator(curator.address, MINIMUM_CURATOR_STAKE);
    await artAuthenticity.setChainSupport(CHAIN_ID, true);
  });

  describe("Artwork Registration", function () {
    it("should allow artist to register artwork", async function () {
      await expect(
        artAuthenticity.connect(artist).registerArtwork(
          CONTENT_HASH,
          METADATA_HASH,
          CHAIN_ID
        )
      ).to.emit(artAuthenticity, "ArtworkRegistered")
        .withArgs(CONTENT_HASH, artist.address, CHAIN_ID, METADATA_HASH);
    });

    it("should prevent duplicate registration", async function () {
      await artAuthenticity.connect(artist).registerArtwork(
        CONTENT_HASH,
        METADATA_HASH,
        CHAIN_ID
      );

      await expect(
        artAuthenticity.connect(artist).registerArtwork(
          CONTENT_HASH,
          METADATA_HASH,
          CHAIN_ID
        )
      ).to.be.revertedWith("Artwork already registered");
    });

    it("should prevent registration on unsupported chain", async function () {
      await expect(
        artAuthenticity.connect(artist).registerArtwork(
          CONTENT_HASH,
          METADATA_HASH,
          "unsupported"
        )
      ).to.be.revertedWith("Chain not supported");
    });
  });

  describe("Artwork Verification", function () {
    beforeEach(async function () {
      await artAuthenticity.connect(artist).registerArtwork(
        CONTENT_HASH,
        METADATA_HASH,
        CHAIN_ID
      );
    });

    it("should allow verification request", async function () {
      await expect(
        artAuthenticity.connect(artist).requestVerification(
          CONTENT_HASH,
          METADATA_HASH,
          CHAIN_ID,
          { value: MINIMUM_CURATOR_STAKE }
        )
      ).to.emit(artAuthenticity, "VerificationRequested")
        .withArgs(1, CONTENT_HASH, artist.address, CHAIN_ID);
    });

    it("should allow curator to verify artwork", async function () {
      await artAuthenticity.connect(artist).requestVerification(
        CONTENT_HASH,
        METADATA_HASH,
        CHAIN_ID,
        { value: MINIMUM_CURATOR_STAKE }
      );

      await expect(
        artAuthenticity.connect(curator).verifyArtwork(
          1,
          true,
          "Original artwork verified"
        )
      ).to.emit(artAuthenticity, "ArtworkVerified")
        .withArgs(CONTENT_HASH, curator.address, "Original artwork verified");
    });

    it("should prevent non-curator from verifying", async function () {
      await artAuthenticity.connect(artist).requestVerification(
        CONTENT_HASH,
        METADATA_HASH,
        CHAIN_ID,
        { value: MINIMUM_CURATOR_STAKE }
      );

      await expect(
        artAuthenticity.connect(buyer).verifyArtwork(
          1,
          true,
          "Original artwork verified"
        )
      ).to.be.revertedWith("Not a curator");
    });
  });

  describe("Originality Check", function () {
    it("should correctly identify original artwork", async function () {
      await artAuthenticity.connect(artist).registerArtwork(
        CONTENT_HASH,
        METADATA_HASH,
        CHAIN_ID
      );

      await artAuthenticity.connect(artist).requestVerification(
        CONTENT_HASH,
        METADATA_HASH,
        CHAIN_ID,
        { value: MINIMUM_CURATOR_STAKE }
      );

      await artAuthenticity.connect(curator).verifyArtwork(
        1,
        true,
        "Original artwork verified"
      );

      expect(await artAuthenticity.isOriginal(CONTENT_HASH, CHAIN_ID))
        .to.be.true;
    });

    it("should identify unverified artwork as not original", async function () {
      await artAuthenticity.connect(artist).registerArtwork(
        CONTENT_HASH,
        METADATA_HASH,
        CHAIN_ID
      );

      expect(await artAuthenticity.isOriginal(CONTENT_HASH, CHAIN_ID))
        .to.be.false;
    });
  });

  describe("Curator Management", function () {
    it("should allow owner to add curator", async function () {
      await expect(
        artAuthenticity.addCurator(buyer.address, MINIMUM_CURATOR_STAKE)
      ).to.emit(artAuthenticity, "CuratorAdded")
        .withArgs(buyer.address, MINIMUM_CURATOR_STAKE);
    });

    it("should allow owner to remove curator", async function () {
      await expect(
        artAuthenticity.removeCurator(curator.address)
      ).to.emit(artAuthenticity, "CuratorRemoved")
        .withArgs(curator.address);
    });

    it("should prevent non-owner from managing curators", async function () {
      await expect(
        artAuthenticity.connect(artist).addCurator(
          buyer.address,
          MINIMUM_CURATOR_STAKE
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Chain Support", function () {
    it("should allow owner to add supported chain", async function () {
      await expect(
        artAuthenticity.setChainSupport("polygon", true)
      ).to.emit(artAuthenticity, "ChainSupported")
        .withArgs("polygon", true);
    });

    it("should prevent registration on unsupported chain", async function () {
      await expect(
        artAuthenticity.connect(artist).registerArtwork(
          CONTENT_HASH,
          METADATA_HASH,
          "polygon"
        )
      ).to.be.revertedWith("Chain not supported");
    });
  });

  describe("Artwork Details", function () {
    it("should return correct artwork details", async function () {
      await artAuthenticity.connect(artist).registerArtwork(
        CONTENT_HASH,
        METADATA_HASH,
        CHAIN_ID
      );

      const details = await artAuthenticity.getArtworkDetails(CONTENT_HASH);
      expect(details.metadataHash).to.equal(METADATA_HASH);
      expect(details.creator).to.equal(artist.address);
      expect(details.isVerified).to.be.false;
    });

    it("should return creator's artworks", async function () {
      await artAuthenticity.connect(artist).registerArtwork(
        CONTENT_HASH,
        METADATA_HASH,
        CHAIN_ID
      );

      const artworks = await artAuthenticity.getCreatorArtworks(artist.address);
      expect(artworks).to.include(CONTENT_HASH);
    });
  });
}); 