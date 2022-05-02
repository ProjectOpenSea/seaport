#!/bin/bash

root=$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )
project="$(grep -m 1 '"name":' "$root/package.json" | cut -d '"' -f 4 | tr '-' '_')"

name="${project}_ethprovider"

if [[ -f "./$1" ]]
then arg="--require ./$1"
fi

if grep -qs "$name" <<<"$(docker container ls)"
then echo "$name is running"
else bash "$root/ops/start-ethprovider.sh"
fi

echo "Launching interactive console"
echo

cd "$root" || exit 1
node --version
node --no-deprecation --interactive --require "./ops/console/entry.js" "$arg"
