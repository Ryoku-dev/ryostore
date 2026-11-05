#!/usr/bin/env bash
# engine/update.sh - move the engine to a newer Utsuri commit, or roll back.
#
#   engine/update.sh                 show what Utsuri has that the pin doesn't
#   engine/update.sh SHA [ENGINE]    try SHA; keep it only if every test passes
#
# On any failure or interruption (Ctrl-C, SIGTERM, a closed terminal) the engine
# goes straight back to the old pin, so the bar plugin keeps working. On success
# it rewrites engine/PIN and reinstalls the plugin so the installed copy's pin
# matches; then commit engine/PIN in this repo.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
old="$(tr -d '[:space:]' < "$here/PIN")"
engine="${2:-$HOME/.local/share/utsuri/engine}"

git -C "$engine" fetch --quiet origin
if [ $# -eq 0 ]; then
    git -C "$engine" log --oneline "$old..origin/main"
    exit 0
fi
new="$(git -C "$engine" rev-parse "$1^{commit}")"

rolled_back=0
rollback() {
    [ "$rolled_back" = 1 ] && return
    rolled_back=1
    trap - ERR INT TERM HUP
    set +e
    echo "update FAILED or interrupted, rolling back to $old" >&2
    echo "  (if this step fails too, run by hand: git -C $engine checkout --detach $old;" >&2
    echo "   printf '%s\\n' $old > $here/PIN; $here/setup.sh $engine)" >&2
    printf '%s\n' "$old" > "$here/PIN"
    git -C "$engine" checkout --quiet --detach "$old" \
        && VIRTUAL_ENV="$engine/.venv" uv pip sync --require-hashes -q "$here/requirements.lock" \
        && echo "rolled back; the plugin is on $old again" >&2 \
        || echo "ROLLBACK INCOMPLETE: run the commands above" >&2
    exit 1
}
trap rollback ERR INT TERM HUP

printf '%s\n' "$new" > "$here/PIN"
git -C "$engine" checkout --quiet --detach "$new"
# setup.sh syncs the lock into the venv first, so the engine's tests run on the real deps
"$here/setup.sh" "$engine"
(cd "$engine" && QT_QPA_PLATFORM=offscreen .venv/bin/python -m pytest -q -p no:cacheprovider tests)
trap - ERR INT TERM HUP

# Reinstall so the installed plugin carries the new PIN (otherwise doctor flags it).
if command -v ryoku >/dev/null; then
    ryoku plugin remove utsuri >/dev/null 2>&1 || true
    ryoku plugin add "$(dirname "$here")" --bar --yes
fi
echo "engine now at ${new:0:12}. Commit engine/PIN in $(dirname "$here")."
