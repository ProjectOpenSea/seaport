#!/usr/bin/env bash
# Installs the pinned formatting and linting tools into .tools/bin. Each
# download comes from the tool's GitHub release and is checked against the
# SHA-256 recorded below, so nothing is fetched from a package registry and a
# replaced release asset fails the install. Foundry is installed separately
# with foundryup.
#
# To bump a tool, change its version in the URLs and record the new hashes
# (`shasum -a 256 <file>`). Prefer releases that are at least two weeks old.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
bin="$root/.tools/bin"
mkdir -p "$bin"

case "$(uname -s)-$(uname -m)" in
Darwin-arm64) platform=darwin-arm64 ;;
Darwin-x86_64) platform=darwin-x64 ;;
Linux-aarch64 | Linux-arm64) platform=linux-arm64 ;;
Linux-x86_64) platform=linux-x64 ;;
*)
    echo "Unsupported platform: $(uname -s)-$(uname -m)" >&2
    exit 1
    ;;
esac

sha256() {
    if command -v sha256sum >/dev/null; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

# tool platform sha256 url
tools="
biome darwin-arm64 c158900ec63bd10332d34cc1fe6a6a571da5c65a4396087f87a2368111bd7ff7 https://github.com/biomejs/biome/releases/download/@biomejs%2Fbiome@2.6.3/biome-darwin-arm64
biome darwin-x64 c06a7b72d313e803f2e77b6eda16e5e57f3cb4f864fc2e2f079da3fc218a34ef https://github.com/biomejs/biome/releases/download/@biomejs%2Fbiome@2.6.3/biome-darwin-x64
biome linux-arm64 72eb52bfcbac58338fa507e394684c3ef74bbb49bcd5f78910e5f900e4610e25 https://github.com/biomejs/biome/releases/download/@biomejs%2Fbiome@2.6.3/biome-linux-arm64
biome linux-x64 1e5134625f00231035bfb14c12141cdc8fcab69b8275f354287808bb5d86d3ae https://github.com/biomejs/biome/releases/download/@biomejs%2Fbiome@2.6.3/biome-linux-x64
taplo darwin-arm64 713734314c3e71894b9e77513c5349835eefbd52908445a0d73b0c7dc469347d https://github.com/tamasfe/taplo/releases/download/0.10.0/taplo-darwin-aarch64.gz
taplo darwin-x64 898122cde3a0b1cd1cbc2d52d3624f23338218c91b5ddb71518236a4c2c10ef2 https://github.com/tamasfe/taplo/releases/download/0.10.0/taplo-darwin-x86_64.gz
taplo linux-arm64 033681d01eec8376c3fd38fa3703c79316f5e14bb013d859943b60a07bccdcc3 https://github.com/tamasfe/taplo/releases/download/0.10.0/taplo-linux-aarch64.gz
taplo linux-x64 8fe196b894ccf9072f98d4e1013a180306e17d244830b03986ee5e8eabeb6156 https://github.com/tamasfe/taplo/releases/download/0.10.0/taplo-linux-x86_64.gz
lefthook darwin-arm64 049c648578c056a180519c4d8c31d5436dbb9df74369b2e29611aae99d7e9b36 https://github.com/evilmartians/lefthook/releases/download/v2.2.2/lefthook_2.2.2_MacOS_arm64
lefthook darwin-x64 b02f6ee5e87b54de138ea532dfdb42c4b88400b5f8cfab0900e5155fc81c1713 https://github.com/evilmartians/lefthook/releases/download/v2.2.2/lefthook_2.2.2_MacOS_x86_64
lefthook linux-arm64 a4d4bf78d902af1a148bf0662af08e13b791061e46e6e2183b0660eed96b43f6 https://github.com/evilmartians/lefthook/releases/download/v2.2.2/lefthook_2.2.2_Linux_arm64
lefthook linux-x64 4fbf89eb7748c6aed84d833ee1a29edac48fae614468ca9a82896ec32f2800b6 https://github.com/evilmartians/lefthook/releases/download/v2.2.2/lefthook_2.2.2_Linux_x86_64
shellcheck darwin-arm64 56affdd8de5527894dca6dc3d7e0a99a873b0f004d7aabc30ae407d3f48b0a79 https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.darwin.aarch64.tar.xz
shellcheck darwin-x64 3c89db4edcab7cf1c27bff178882e0f6f27f7afdf54e859fa041fca10febe4c6 https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.darwin.x86_64.tar.xz
shellcheck linux-arm64 12b331c1d2db6b9eb13cfca64306b1b157a86eb69db83023e261eaa7e7c14588 https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.linux.aarch64.tar.xz
shellcheck linux-x64 8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198 https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.linux.x86_64.tar.xz
shfmt darwin-arm64 b7c872db63553ccffc7253aba3ed7d4885a27d83f1ba567b1138c6315a5847e5 https://github.com/mvdan/sh/releases/download/v3.14.1/shfmt_v3.14.1_darwin_arm64
shfmt darwin-x64 d33eee0da0f92835b3562e9767a05cee7e4eaeef47daa03bfd09da17b4b590a6 https://github.com/mvdan/sh/releases/download/v3.14.1/shfmt_v3.14.1_darwin_amd64
shfmt linux-arm64 5f2db09dae91fca848f7adbdd014632e921a383863a2ad7e0450ad3aba0c6489 https://github.com/mvdan/sh/releases/download/v3.14.1/shfmt_v3.14.1_linux_arm64
shfmt linux-x64 76e77641faa025814b77f153b29796b8e6fa2fca03e0c76a691608b86c7ea7bf https://github.com/mvdan/sh/releases/download/v3.14.1/shfmt_v3.14.1_linux_amd64
actionlint darwin-arm64 aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_darwin_arm64.tar.gz
actionlint darwin-x64 5b44c3bc2255115c9b69e30efc0fecdf498fdb63c5d58e17084fd5f16324c644 https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_darwin_amd64.tar.gz
actionlint linux-arm64 325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6 https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_linux_arm64.tar.gz
actionlint linux-x64 8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8 https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_linux_amd64.tar.gz
"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

while read -r tool tool_platform expected url; do
    [ "$tool_platform" = "$platform" ] || continue

    # Skip tools already installed from the same pinned asset.
    if [ -x "$bin/$tool" ] && [ "$(cat "$bin/.$tool.sha256" 2>/dev/null)" = "$expected" ]; then
        continue
    fi

    file="$tmp/${url##*/}"
    curl -sSfL --retry 3 -o "$file" "$url"
    actual="$(sha256 "$file")"
    if [ "$actual" != "$expected" ]; then
        echo "Checksum mismatch for $tool: expected $expected, got $actual" >&2
        exit 1
    fi

    # One command per line: set -e ignores a failure on the left of &&, which
    # would leave the old binary in place under the new checksum.
    case "$file" in
    *.tar.gz)
        tar -xzf "$file" -C "$tmp" "$tool"
        mv "$tmp/$tool" "$bin/$tool"
        ;;
    *.tar.xz)
        tar -xJf "$file" -C "$tmp"
        mv "$tmp"/shellcheck-*/shellcheck "$bin/$tool"
        ;;
    *.gz) gunzip -c "$file" >"$bin/$tool" ;;
    *) mv "$file" "$bin/$tool" ;;
    esac
    chmod +x "$bin/$tool"
    echo "$expected" >"$bin/.$tool.sha256"
    echo "Installed $tool"
done <<<"$tools"

echo "Tools are in $bin. Add it to PATH, or run scripts/lint.sh."
