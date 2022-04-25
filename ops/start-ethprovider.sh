#!/usr/bin/env bash
set -eu

root="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"
project="$(grep -m 1 '"name":' "$root/package.json" | cut -d '"' -f 4 | tr '-' '_')"

# make sure a network for this project has been created
docker swarm init 2> /dev/null || true
docker network create --attachable --driver overlay "$project" 2> /dev/null || true

# rebuild the ethprovider image
docker build --file "$root/ops/ethprovider/Dockerfile" --tag "${project}_ethprovider" "$root/ops/ethprovider"

name="${project}_ethprovider"

if grep -qs "$name" <<<"$(docker container ls)"
then echo "$name is already running" && exit
else echo "Launching $name"
fi

image="${project}_ethprovider:latest"

# Mount repo into ethprovider:/root to trigger migration at startup
docker run \
  --detach \
  --env "FORKED_PROVIDER=${FORKED_PROVIDER:-}" \
  --env "FORKED_BLOCK=${FORKED_BLOCK:-}" \
  --env "CHAIN_ID=${CHAIN_ID:-1337}" \
  --mount "type=bind,source=$root,target=/root" \
  --name "$name" \
  --network "$project" \
  --publish "8545:8545" \
  --rm \
  --tmpfs "/tmp" \
  "$image"

docker container logs "$name" &

while !  curl -q -s -k -s -X POST \
  -H "Content-Type: application/json" \
  --data '{"id":31415,"jsonrpc":"2.0","method":"eth_chainId","params":[]}' \
  http://localhost:8545 > /dev/null
do
  if grep -qs "$name" <<<"$(docker container ls)"
  then sleep 1
  else echo "Ethprovider failed to start up" && exit 1
  fi
done

while [[ ! -f ".flags/ethprovider_deployments" ]]
do
  if grep -qs "$name" <<<"$(docker container ls)"
  then sleep 1
  else echo "Ethprovider failed to initialize contract state" && exit 1
  fi
done

sleep 1
echo "Good morning, ethprovider!"
