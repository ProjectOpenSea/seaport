#!/usr/bin/env bash
# Usage: scripts/plot-metrics.sh [call-metrics.txt]
#
# Prints how often the fuzz engine called each Seaport function, from the
# metrics file the fuzz engine in test/foundry/new writes when
# SEAPORT_COLLECT_FUZZ_METRICS=true.
set -euo pipefail

file="${1:-call-metrics.txt}"

awk -F'|' '
    NF && $0 !~ /^[[:space:]]*$/ {
        split($1, parts, ":")
        count[parts[1]]++
        total++
    }
    END {
        for (call in count) {
            printf "%-40s %8d (%5.2f%%)\n", call, count[call], count[call] * 100 / total
        }
    }
' "$file" | sort
