#!/usr/bin/env bash
# Usage: scripts/lint.sh [check|fix|freeze]
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
# Deployed contracts. Their source must stay identical to what was verified
# onchain, so CI checks it against scripts/frozen-contracts.sha256.
frozen=(contracts/Seaport.sol contracts/conduit contracts/helpers contracts/interfaces contracts/zones)

case "${1:-check}" in
check)
    shasum -a 256 --check --quiet scripts/frozen-contracts.sha256
    # shasum only verifies the files already listed, so also fail if a file
    # was added to or removed from the frozen set without running `freeze`.
    if ! diff \
        <(git ls-files "${frozen[@]}" | LC_ALL=C sort) \
        <(awk '{ print $2 }' scripts/frozen-contracts.sha256 | LC_ALL=C sort); then
        echo "error: frozen contracts do not match scripts/frozen-contracts.sha256" >&2
        echo "If this change is deliberate, run \`scripts/lint.sh freeze\`." >&2
        exit 1
    fi
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
freeze)
    # Only for a deliberate change to a deployed contract's source.
    git ls-files "${frozen[@]}" | xargs shasum -a 256 >scripts/frozen-contracts.sha256
    ;;
*)
    echo "Usage: scripts/lint.sh [check|fix|freeze]" >&2
    exit 1
    ;;
esac
