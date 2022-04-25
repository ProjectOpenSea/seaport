#!/bin/bash
set -e

export ETHCONSOLE_HARDHAT=true

echo "Starting ethprovider in env"
env

deployments_flag=".flags/ethprovider_deployments"
mkdir -p "$(dirname "$deployments_flag")"
rm -rf "$deployments_flag"

if [[ -n "$FORKED_PROVIDER" ]]
then
  if [[ -n "$FORKED_BLOCK" ]]
  then
    echo "Creating a local fork at block $FORKED_BLOCK from the provider at $FORKED_PROVIDER"
    hardhat node --hostname 0.0.0.0 --port 8545 --fork "$FORKED_PROVIDER" --fork-block-number "$FORKED_BLOCK" --no-deploy &
  else
    echo "Creating a local fork from the provider at $FORKED_PROVIDER"
    hardhat node --hostname 0.0.0.0 --port 8545 --fork "$FORKED_PROVIDER" --no-deploy &
  fi
  pid=$!
  echo "Waiting for localnet evm instance to wake up (pid=$pid)"
  wait-for -q -t 30 localhost:8545 2>&1 | sed '/nc: bad address/d'
  touch "$deployments_flag"
  wait $pid

else
  echo "Creating a new local node & deploying contracts to it.."

  hardhat node --config ops/hardhat.config.ts --hostname 0.0.0.0 --port 8545 --no-deploy &> /dev/stdout &
  pid=$!

  echo "Waiting for localnet evm instance to wake up (pid=$pid)"
  wait-for -q -t 30 localhost:8545 2>&1 | sed '/nc: bad address/d'

  hardhat --config ops/hardhat.config.ts --network localhost deploy --write true

  touch "$deployments_flag"

  wait $pid

fi
