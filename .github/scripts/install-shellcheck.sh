#!/usr/bin/env bash
# Download, verify (sha256), and install a pinned shellcheck binary. Fail closed:
# any download failure or checksum mismatch aborts, so the lint is never
# silently skipped because the tool was unavailable or tampered with.
#
# Usage: install-shellcheck.sh [BINDIR]   (default: $HOME/.local/bin)
#
# Pins are maintained by hand -- Dependabot cannot track raw binary downloads.
# To re-pin, read the release asset digest and update VERSION and SHA256:
#   https://api.github.com/repos/koalaman/shellcheck/releases/tags/v<VER>
#   (asset shellcheck-v<VER>.linux.x86_64.tar.xz -> .digest)
# Changes here require owner review (.github/CODEOWNERS).
set -euo pipefail

VERSION="0.11.0"
# sha256 of shellcheck-v0.11.0.linux.x86_64.tar.xz (from the release asset digest).
SHA256="8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198"

bindir="${1:-$HOME/.local/bin}"
mkdir -p "$bindir"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

asset="shellcheck-v${VERSION}.linux.x86_64.tar.xz"
url="https://github.com/koalaman/shellcheck/releases/download/v${VERSION}/${asset}"

curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
     --retry 3 --retry-delay 2 -o "$tmp/$asset" "$url"
echo "${SHA256}  ${tmp}/${asset}" | sha256sum --check --strict -

tar -xJf "$tmp/$asset" -C "$tmp"
install -m 0755 "$tmp/shellcheck-v${VERSION}/shellcheck" "$bindir/shellcheck"
"$bindir/shellcheck" --version
echo "shellcheck ${VERSION} installed to ${bindir}"
