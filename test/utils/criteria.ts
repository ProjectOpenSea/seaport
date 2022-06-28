import { ethers } from "ethers";

const { keccak256 } = ethers.utils;

type BufferElementPositionIndex = { [key: string]: number };

export const merkleTree = (tokenIds: ethers.BigNumber[]) => {
  const elements = tokenIds
    .map((tokenId) =>
      Buffer.from(tokenId.toHexString().slice(2).padStart(64, "0"), "hex")
    )
    .sort(Buffer.compare)
    .filter((el, idx, arr) => {
      return idx === 0 || !arr[idx - 1].equals(el);
    });

  const bufferElementPositionIndex = elements.reduce(
    (memo: BufferElementPositionIndex, el, index) => {
      memo["0x" + el.toString("hex")] = index;
      return memo;
    },
    {}
  );

  // Create layers
  const layers = getLayers(elements);

  const root = "0x" + layers[layers.length - 1][0].toString("hex");

  const proofs = Object.fromEntries(
    elements.map((el) => [
      ethers.BigNumber.from(el).toString(),
      getHexProof(el, bufferElementPositionIndex, layers),
    ])
  );

  const maxProofLength = Math.max(
    ...Object.values(proofs).map((i) => i.length)
  );

  return {
    root,
    proofs,
    maxProofLength,
  };
};

const getLayers = (elements: Buffer[]) => {
  if (elements.length === 0) {
    throw new Error("empty tree");
  }

  const layers = [];
  layers.push(elements.map((el) => Buffer.from(keccak256(el).slice(2), "hex")));

  // Get next layer until we reach the root
  while (layers[layers.length - 1].length > 1) {
    layers.push(getNextLayer(layers[layers.length - 1]));
  }

  return layers;
};

const getNextLayer = (elements: Buffer[]) => {
  return elements.reduce((layer: Buffer[], el, idx, arr) => {
    if (idx % 2 === 0) {
      // Hash the current element with its pair element
      layer.push(combinedHash(el, arr[idx + 1]));
    }

    return layer;
  }, []);
};

const combinedHash = (first: Buffer, second: Buffer) => {
  if (!first) {
    return second;
  }
  if (!second) {
    return first;
  }

  return Buffer.from(
    keccak256(Buffer.concat([first, second].sort(Buffer.compare))).slice(2),
    "hex"
  );
};

const getHexProof = (
  el: Buffer,
  bufferElementPositionIndex: BufferElementPositionIndex,
  layers: Buffer[][]
) => {
  let idx = bufferElementPositionIndex["0x" + el.toString("hex")];

  if (typeof idx !== "number") {
    throw new Error("Element does not exist in Merkle tree");
  }

  const proofBuffer = layers.reduce((proof: Buffer[], layer) => {
    const pairIdx = idx % 2 === 0 ? idx + 1 : idx - 1;
    const pairElement = pairIdx < layer.length ? layer[pairIdx] : null;

    if (pairElement) {
      proof.push(pairElement);
    }

    idx = Math.floor(idx / 2);

    return proof;
  }, []);

  return proofBuffer.map((el) => "0x" + el.toString("hex"));
};
