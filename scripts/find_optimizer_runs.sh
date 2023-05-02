#!/bin/bash
# h/t @DrakeEvansV1 & ChatGPT

TARGET_SIZE=24.576
MIN_RUNS=1
# NOTE that at time of writing, Etherscan does not support verifying contracts
# that specify more than 10,000,000 optimizer runs.
# Higher numbers do not always result in different bytecode output. If a
# higher number of runs is used, it may be possible verify by spoofing with a
# number that results in the same bytecode output. This is not guaranteed.
MAX_RUNS=$((2**32-1))
ENV_FILE=".env"
FOUND_RUNS=0

# Check if the optimizer is enabled
OPTIMIZER_STATUS=$(forge config | grep optimizer | head -n 1)
if [ "$OPTIMIZER_STATUS" != "optimizer = true" ]; then
    echo "Error: The optimizer is not enabled. Please enable it and try again."
    exit 1
fi

try_runs() {
    local RUNS=$1
    printf "Trying with FOUNDRY_OPTIMIZER_RUNS=%d\n" "$RUNS"
    RESULT=$(FOUNDRY_OPTIMIZER_RUNS=$RUNS forge build --sizes | grep Seaport | head -n 1)
    CONTRACT_SIZE=$(echo $RESULT | awk -F'|' '{print $3}' | awk '{print $1}')
    [ "$(echo "$CONTRACT_SIZE<=$TARGET_SIZE" | bc)" -eq 1 ]
}

if try_runs $MAX_RUNS; then
    FOUND_RUNS=$MAX_RUNS
else
    while [ $MIN_RUNS -le $MAX_RUNS ]; do
        MID_RUNS=$(( (MIN_RUNS + MAX_RUNS) / 2 ))
        
        if try_runs $MID_RUNS; then
            printf "Success with FOUNDRY_OPTIMIZER_RUNS=%d and contract size %.3fKB\n" "$MID_RUNS" "$CONTRACT_SIZE"
            MIN_RUNS=$((MID_RUNS + 1))
            FOUND_RUNS=$MID_RUNS
        else
            printf "Failure with FOUNDRY_OPTIMIZER_RUNS=%d and contract size %.3fKB\n" "$MID_RUNS" "$CONTRACT_SIZE"
            MAX_RUNS=$((MID_RUNS - 1))
        fi
    done
fi

printf "Highest FOUNDRY_OPTIMIZER_RUNS found: %d\n" "$FOUND_RUNS"

if [ -f "$ENV_FILE" ]; then
    if grep -q "^FOUNDRY_OPTIMIZER_RUNS=" "$ENV_FILE"; then
        awk -v runs="$FOUND_RUNS" '{gsub(/^FOUNDRY_OPTIMIZER_RUNS=.*/, "FOUNDRY_OPTIMIZER_RUNS="runs); print}' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
    else
        echo "FOUNDRY_OPTIMIZER_RUNS=$FOUND_RUNS" >> "$ENV_FILE"
    fi
    printf "Updated %s with FOUNDRY_OPTIMIZER_RUNS=%d\n" "$ENV_FILE" "$FOUND_RUNS"
else
    printf "Error: %s not found.\n" "$ENV_FILE"
fi
