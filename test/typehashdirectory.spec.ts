import { expect } from "chai";
import { hexConcat } from "ethers/lib/utils";
import { ethers } from "hardhat";

import { deployContract } from "./utils/contracts";
import { getBulkOrderTypeHashes } from "./utils/eip712/bulk-orders";

// Reference contracts use storage for type hashes, not
// a lookup contract.
if (!process.env.REFERENCE) {
  describe("TypehashDirectory", () => {
    let address: string;
    before(async () => {
      address = (await deployContract("TypehashDirectory")).address;
    });

    it("Code is equal to concatenated type hashes for heights 1-24", async () => {
      const code = await ethers.provider.getCode(address);
      const typeHashes = getBulkOrderTypeHashes(24);
      expect(code).to.eq(hexConcat(["0xfe", ...typeHashes]));
    });
  });
}
