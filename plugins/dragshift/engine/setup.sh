#!/usr/bin/env bash
# engine/setup.sh - install or repair the DragShift engine this plugin drives.
#
#   engine/setup.sh [ENGINE_DIR]          default ~/.local/share/dragshift/engine
#
# Idempotent: safe to re-run any time. It clones DragShift if missing, checks out
# the exact commit in engine/PIN, builds .venv on a uv-managed Python 3.12 (so
# pacman's Python upgrades never touch it), installs requirements.lock with hash
# checking, then runs upstream's selftest and this plugin's tests. Run by you,
# never by the plugin.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
engine="${1:-$HOME/.local/share/dragshift/engine}"
pin="$(tr -d '[:space:]' < "$here/PIN")"

command -v uv >/dev/null || { echo "uv is required: install the uv package with pacman first" >&2; exit 1; }

if [ ! -d "$engine/.git" ]; then
    git clone https://github.com/llamaboi55/DragShift "$engine"
fi
if ! git -C "$engine" cat-file -e "$pin^{commit}" 2>/dev/null; then
    git -C "$engine" fetch --quiet origin
fi
git -C "$engine" checkout --quiet --detach "$pin"
echo "engine: $engine @ $(git -C "$engine" rev-parse --short HEAD)"

uv python install 3.12 >/dev/null
# Rebuild the venv unless its interpreter actually runs and is 3.12. A dangling
# python link (after `uv python uninstall` or a cache wipe) fails this check, and
# --clear replaces the old directory instead of refusing it.
if ! "$engine/.venv/bin/python" -c 'import sys; sys.exit(sys.version_info[:2] != (3, 12))' 2>/dev/null; then
    uv venv "$engine/.venv" --clear --python 3.12 --python-preference only-managed -q
fi
VIRTUAL_ENV="$engine/.venv" uv pip sync --require-hashes -q "$here/requirements.lock"

(cd "$engine" && QT_QPA_PLATFORM=offscreen .venv/bin/python run.py --selftest >/dev/null 2>&1) \
    || { echo "upstream selftest FAILED" >&2; exit 1; }
# the plugin's own tests ship with the source checkout, not every install
if [ -d "$here/../tests" ]; then
    DRAGSHIFT_ENGINE="$engine" "$engine/.venv/bin/python" -m pytest -q -p no:cacheprovider "$here/../tests"
fi
echo "DragShift engine ready."
