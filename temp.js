const rawTx =
{
    nonce: "0x222",
    from: '0xff6b702a6b8032014aeb97a5b8e3d70d4c59a43a',
    to: '0x63f9e083a76e396c45b5f6fce41e6a91ea0a1400',
    gasPrice: "0xa",
    gasLimit: "0x30D40",
    gas: "0x1E8480",
    value: '0x0',
    data: "0xa22cb46500000000000000000000000000000000006c3852cbef3e08e8df289169ede5810000000000000000000000000000000000000000000000000000000000000001"
};

const tx = new Tx(rawTx, { 'chain': 'ropsten' });
tx.sign(privateKey);

var serializedTx = '0x' + tx.serialize().toString('hex');
web3.eth.sendSignedTransaction(serializedTx.toString('hex'), function (err, hash) {
    if (err) {
        reject(err);
    }
    else {
        resolve(hash);
    }
})