import { expect } from "chai";
import hre, { ethers, network } from "hardhat";
import { randomHex, toBN } from "../utils/encoding";
import { faucet } from "../utils/faucet";
import { VERSION } from "../utils/helpers";
import { create2FactoryFixture } from "../utils/fixtures/create2";
import type {
  ImmutableCreate2FactoryInterface,
  SignedZone,
  SignedZoneFactory,
  SignedZoneFactory__factory,
} from "../../typechain-types";

const deployConstants = require("../../constants/constants");

describe.only(`Zone - SignedZoneFactory (Seaport v${VERSION})`, function () {
  if (process.env.REFERENCE) return;

  const { provider } = ethers;
  const deployer = new ethers.Wallet(randomHex(32), provider);
  const invalidCreator = new ethers.Wallet(randomHex(32), provider);

  let signedZoneFactoryFactory: SignedZoneFactory__factory;
  let signedZoneFactory: SignedZoneFactory;
  let create2Factory: ImmutableCreate2FactoryInterface;

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    await faucet(deployer.address, provider);
    await faucet(invalidCreator.address, provider);

    // Deploy the create2 factory
    create2Factory = await create2FactoryFixture(deployer);

    // Deploy the signed Zone Factory through efficient create2 factory
    signedZoneFactoryFactory = await ethers.getContractFactory(
      "SignedZoneFactory",
      deployer
    );

    // Get the address of the signed zone factory
    const signedZoneFactoryAddress = await create2Factory.findCreate2Address(
      deployConstants.SIGNED_ZONE_FACTORY_CREATION_SALT,
      signedZoneFactoryFactory.bytecode
    );

    // Check the address of the signed zone factory
    expect(signedZoneFactoryAddress).to.eq(
      deployConstants.SIGNED_ZONE_FACTORY_ADDRESS
    );

    let { gasLimit } = await ethers.provider.getBlock("latest");

    if ((hre as any).__SOLIDITY_COVERAGE_RUNNING) {
      gasLimit = ethers.BigNumber.from(300_000_000);
    }

    // Deploy the signed Zone Factory through efficient create2 factory
    await create2Factory.safeCreate2(
      deployConstants.SIGNED_ZONE_FACTORY_CREATION_SALT,
      signedZoneFactoryFactory.bytecode,
      {
        gasLimit,
      }
    );

    // Attach to the signed zone factory
    signedZoneFactory = (await ethers.getContractAt(
      "SignedZoneFactory",
      signedZoneFactoryAddress,
      deployer
    )) as SignedZoneFactory;
  });

  beforeEach(async () => {});

  it("Create signed zone from Factory and check information", async () => {
    // Set the salt
    const salt =
      "0x0000000000000000000000000000000000000000000000000000000000000000";

    // Get the address of the signed zone
    const signedZoneAddress = await signedZoneFactory.getZone(
      "OpenSeaSignedZone",
      "https://api.opensea.io/api/v2/sign",
      salt
    );

    // Deploy the signed Zone using the factory
    await expect(
      signedZoneFactory.createZone(
        "OpenSeaSignedZone",
        "https://api.opensea.io/api/v2/sign",
        salt
      )
    )
      .to.emit(signedZoneFactory, "ZoneCreated")
      .withArgs(
        signedZoneAddress,
        "OpenSeaSignedZone",
        "https://api.opensea.io/api/v2/sign",
        salt
      );

    // Attach to the signed zone
    const signedZone = (await ethers.getContractAt(
      "SignedZone",
      signedZoneAddress,
      deployer
    )) as SignedZone;

    // Check the information of the signed zone
    const information = await signedZone.sip7Information();
    expect(information[0].length).to.eq(66);
    expect(information[1]).to.eq("https://api.opensea.io/api/v2/sign");

    // Check the metadata of the signed zone
    const seaportMetadata = await signedZone.getSeaportMetadata();
    expect(seaportMetadata[0]).to.eq("OpenSeaSignedZone");
    expect(seaportMetadata[1][0][0]).to.deep.eq(toBN(7));
  });
  it("Deploy a zone as with a protected creator", async () => {
    const salt = `0x${deployer.address.slice(2)}000000000000000000000000`;
    // Deploy the signed Zone using the factory
    await signedZoneFactory
      .connect(deployer)
      .createZone(
        "OpenSeaSignedZone",
        "https://api.opensea.io/api/v2/sign",
        salt
      );
  });
  it("Revert: Try to deploy an existing zone", async () => {
    const salt =
      "0x0000000000000000000000000000000000000000000000000000000000000001";
    // Deploy the signed Zone using the factory
    await signedZoneFactory.createZone(
      "OpenSeaSignedZone",
      "https://api.opensea.io/api/v2/sign",
      salt
    );

    // Get the address of the signed zone
    const signedZoneAddress = await signedZoneFactory.getZone(
      "OpenSeaSignedZone",
      "https://api.opensea.io/api/v2/sign",
      salt
    );

    // Try to redeploy the signed Zone using the factory
    await expect(
      signedZoneFactory.createZone(
        "OpenSeaSignedZone",
        "https://api.opensea.io/api/v2/sign",
        salt
      )
    )
      .to.be.revertedWithCustomError(signedZoneFactory, "ZoneAlreadyExists")
      .withArgs(signedZoneAddress);
  });
  it("Revert: Try to deploy a zone as an Invalid Creator", async () => {
    const salt = `0x${deployer.address.slice(2)}000000000000000000000001`;
    // Deploy the signed Zone using the factory
    await expect(
      signedZoneFactory
        .connect(invalidCreator)
        .createZone(
          "OpenSeaSignedZone",
          "https://api.opensea.io/api/v2/sign",
          salt
        )
    ).to.be.revertedWithCustomError(signedZoneFactory, "InvalidCreator");
  });
});
