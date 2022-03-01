## About

This commit marks the start of the initial OpenZeppelin security review.

## Local Development

1. Installing Packages:
   `yarn install`

2. Running Tests:
   `REPORT_GAS=true npx hardhat test`

3. Other commands
   `npx hardhat coverage`
   `npx hardhat compile`
   `npx solhint 'contracts/**/*.sol'`
   `npx hardhat node`

## Deploying

`npx hardhat run scripts/deploy.ts`
