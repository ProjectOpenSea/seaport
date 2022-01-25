import { ECSignature } from "wyvern-js/lib/types";
import * as ethUtil from "ethereumjs-util";

// Copied from opensea-js
export const parseSignatureHex = (signature: string): ECSignature => {
  // HACK: There is no consensus on whether the signatureHex string should be formatted as
  // v + r + s OR r + s + v, and different clients (even different versions of the same client)
  // return the signature params in different orders. In order to support all client implementations,
  // we parse the signature in both ways, and evaluate if either one is a valid signature.
  const validVParamValues = [27, 28];

  const ecSignatureRSV = _parseSignatureHexAsRSV(signature);
  if (validVParamValues.includes(ecSignatureRSV.v)) {
    return ecSignatureRSV;
  }

  // For older clients
  const ecSignatureVRS = _parseSignatureHexAsVRS(signature);
  if (validVParamValues.includes(ecSignatureVRS.v)) {
    return ecSignatureVRS;
  }

  throw new Error("Invalid signature");

  function _parseSignatureHexAsVRS(signatureHex: string) {
    const signatureBuffer: any = ethUtil.toBuffer(signatureHex);
    let v = signatureBuffer[0];
    if (v < 27) {
      v += 27;
    }
    const r = signatureBuffer.slice(1, 33);
    const s = signatureBuffer.slice(33, 65);
    const ecSignature = {
      v,
      r: ethUtil.bufferToHex(r),
      s: ethUtil.bufferToHex(s),
    };
    return ecSignature;
  }

  function _parseSignatureHexAsRSV(signatureHex: string) {
    const { v, r, s } = ethUtil.fromRpcSig(signatureHex);
    const ecSignature = {
      v,
      r: ethUtil.bufferToHex(r),
      s: ethUtil.bufferToHex(s),
    };
    return ecSignature;
  }
};
