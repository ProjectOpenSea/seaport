import glob
import json
from typing import List
from web3 import Web3


def calculateSelector(sig):
    result = Web3.keccak(text=sig)
    selector = (Web3.toHex(result))[:10]
    return selector

def getTypeFromInput(ipt: dict) -> str:
    components: List[dict] | None = ipt.get('components')
    if components:
        return f"({','.join([getTypeFromInput(c) for c in components])})"
    return ipt['type']
    

for fname in glob.glob("out/*/*.json"):
    print(fname)
    with open(fname, "r") as f:
        js = json.loads(f.read())
    abi = js["abi"]
    abi = [x for x in abi if x.get('name')]
    for sig in abi:
        name = sig['name']
        inputs = sig.get('inputs')
        signature = f"{name}({','.join([getTypeFromInput(x) for x in inputs])})"
        selector = calculateSelector(signature)
        print(signature, selector)  