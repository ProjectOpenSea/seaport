#!/bin/bash

## Deploys contracts w old solc for use w/in echidna

########################################
echo "Setting up deploy env.."
root="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )";
summary="$root/init.json";
broken="$summary.broken"
rm -f "$summary" "$broken"

########################################
echo "Starting ethprovider in the background.."

echo "Starting etheno node.."
etheno --ganache --ganache-args "--deterministic --gasLimit 10000000" -x "$broken" &
pid=$!
sleep 5 # give etheno a sec to wake up..

########################################
echo "Running contract deployment.."
node "$root/deploy.js"
sleep 5 # give deploy a sec to run..


########################################
echo "Fixing broken json produced by etheno.."
echo "]" >> "$broken"
jq '
  map(select(.value == 0) | .value = "0") |
  map(select(.gas_price == 20000000000) | .gas_price = "20000000000")
' "$broken" > "$summary"
rm "$broken"


########################################
echo "Killing etheno.."
kill "$pid"
