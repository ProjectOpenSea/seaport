#!/usr/bin/env bash
# Usage: scripts/lint.sh [check|fix]
#
# Runs every formatter and linter CI runs. Tools come from .tools/bin
# (scripts/install-tools.sh), and Foundry from PATH.
set -euo pipefail

cd "$(dirname "$0")/.."
export PATH="$PWD/.tools/bin:$PATH"

# forge fmt output can differ between Foundry versions, so match CI's.
want="$(sed -n 's/^  FOUNDRY_VERSION: v//p' .github/workflows/test.yml)"
if ! forge --version | grep -q "Version: $want"; then
    echo "warning: CI uses Foundry $want; run \`foundryup --install v$want\`" >&2
fi
shell_scripts=(scripts/*.sh templates/*.sh)
# forge fmt only covers the profile's src, test, and script dirs by default.
sol_dirs=(contracts test script reference)

case "${1:-check}" in
check)
    forge fmt --check "${sol_dirs[@]}"
    forge lint --deny warnings
    biome ci .
    taplo fmt --check
    shellcheck "${shell_scripts[@]}"
    shfmt -d "${shell_scripts[@]}"
    actionlint
    ;;
fix)
    forge fmt "${sol_dirs[@]}"
    biome check --write .
    taplo fmt
    shfmt -w "${shell_scripts[@]}"
    ;;
*)
    echo "Usage: scripts/lint.sh [check|fix]" >&2
    exit 1
    ;;
esac
