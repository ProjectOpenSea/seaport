#!/bin/bash

root=$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )

if [[ -f "./$1" ]]
then arg="--require ./$1"
fi

bash "$root/ops/start-ethprovider.sh"

cd "$root" || exit 1
node --version
node --no-deprecation --interactive --require "./ops/console.js" "$arg"
