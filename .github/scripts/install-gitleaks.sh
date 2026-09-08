#!/usr/bin/env bash
# Download, verify (sha256), and install a pinned gitleaks binary. Fail closed:
# any download failure or checksum mismatch aborts the script, so a scan is
# never silently skipped because the tool was unavailable or tampered with.
#
# Usage: install-gitleaks.sh [BINDIR]   (default: $HOME/.local/bin)
#
# Pins are maintained by hand -- Dependabot cannot track raw binary downloads.
# To re-pin, read the official checksums file and copy the linux_x64 digest:
#   https://github.com/gitleaks/gitleaks/releases/download/v<VER>/gitleaks_<VER>_checksums.txt
# then update VERSION and SHA256 below. Changes here require owner review
# (.github/CODEOWNERS).
set -euo pipefail

VERSION="8.30.1"
# sha256 of gitleaks_8.30.1_linux_x64.tar.gz (from the release checksums file).
SHA256="551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb"

bindir="${1:-$HOME/.local/bin}"
mkdir -p "$bindir"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

asset="gitleaks_${VERSION}_linux_x64.tar.gz"
url="https://github.com/gitleaks/gitleaks/releases/download/v${VERSION}/${asset}"

curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
     --retry 3 --retry-delay 2 -o "$tmp/$asset" "$url"
echo "${SHA256}  ${tmp}/${asset}" | sha256sum --check --strict -

tar -xzf "$tmp/$asset" -C "$tmp" gitleaks
install -m 0755 "$tmp/gitleaks" "$bindir/gitleaks"
"$bindir/gitleaks" version
echo "gitleaks ${VERSION} installed to ${bindir}"
