// https://etherscan.io/tx/0xac80e2bde96927333e7f9706e109fab9f22db2b6173d7632516cd6b08d2174de
const obj = {
  "method": "fulfillBasicOrder",
  "types": [
    "(address,uint256,uint256,address,address,address,uint256,uint256,uint8,uint256,uint256,bytes32,uint256,bytes32,bytes32,uint256,tuple[],bytes)"
  ],
  "inputs": [
    [
      "0xbD115428DDe5827ECa3203E58A19f2F93169a6D2", // considerationToken
      {
        "type": "BigNumber",
        "hex": "0x26" // considerationIdentifier
      },
      {
        "type": "BigNumber",
        "hex": "0x01" // considerationAmount
      },
      "0x4d41232B0d963AFb52cd0354DA5819b259F133BD", // offerer
      "0x9B814233894Cd227f561B78Cc65891AA55C62Ad2", // zone
      "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", // offerToken
      {
        "type": "BigNumber",
        "hex": "0x00" // offerIdentifier
      },
      {
        "type": "BigNumber",
        "hex": "0x038d7ea4c68000" // offerAmount
      },
      16,
      {
        "type": "BigNumber",
        "hex": "0x00" // startTime
      },
      {
        "type": "BigNumber",
        "hex": "0x62a66ec3" // endTime
      },
      "0x0000000000000000000000000000000000000000000000000000000000000000", // zoneHash
      {
        "type": "BigNumber",
        "hex": "0x0127fc2aeef794f7" // salt
      },
      "0x939c8d89ebc11fa45e576215e2353673ad0ba18a71286b93e3954e004a000000", // offererConduitKey
      "0x939c8d89ebc11fa45e576215e2353673ad0ba18a71286b93e3954e004a000000", // fulfillerConduitKey
      {
        "type": "BigNumber",
        "hex": "0x01" // totalOriginalAdditionalRecipients
      },
      [
        [ // additionalRecipients
          {
            "type": "BigNumber",
            "hex": "0x16bcc41e9000"
          },
          "0x5b3256965e7C3cF26E11FCAf296DfC8807C01073"
        ]
      ],
      "0x5e4f19d3b55ffccaf0dadb7ff3c411a9b2d995bde468fda1134892a54bc4a02c0b66eb2ff5c81597ec05055f7ea4cbb5553dfc88654f05248edea4e8e9d493111b" // signature
    ]
  ],
  "names": [
    [
      "parameters",
      [
        "considerationToken",
        "considerationIdentifier",
        "considerationAmount",
        "offerer",
        "zone",
        "offerToken",
        "offerIdentifier",
        "offerAmount",
        "basicOrderType",
        "startTime",
        "endTime",
        "zoneHash",
        "salt",
        "offererConduitKey",
        "fulfillerConduitKey",
        "totalOriginalAdditionalRecipients",
        "additionalRecipients",
        "signature"
      ]
    ]
  ]
}