#!/usr/bin/env bash
# Opt-in installer for Ryostore's local git hooks.
#
# Run this yourself, once, from a clone you trust:
#   tools/install-hooks.sh          (or: bash tools/install-hooks.sh)
#
# WHAT IT DOES — and why this shape matters for trust:
# The hooks screen contribution content with tools/security-screen.py against the
# security/exceptions.json policy. If the hooks ran those straight from the
# working tree, checking out a malicious branch or PR would swap the very scanner
# and policy meant to catch it. So this installer takes a SNAPSHOT of the
# reviewed hooks + scanner + policy and copies it into the repo's git-common-dir
# (inside .git, OUTSIDE the checked-out tree, untouched by `git checkout`), then
# points core.hooksPath at that snapshot. The hooks resolve their scanner and
# policy relative to their own installed location, so a work-tree swap cannot
# reach them.
#
# The hooks NEVER self-install: only this script enables them, and re-running it
# is the explicit, opt-in way to refresh the snapshot after pulling reviewed
# updates. It refuses to clobber an unrelated existing hooksPath.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

src_hooks=".githooks"
src_scanner="tools/security-screen.py"
src_policy="security/exceptions.json"

# Snapshot lives in the git-common-dir (shared across linked worktrees), absolute.
common_dir="$(git rev-parse --git-common-dir)"
common_dir="$(cd "$common_dir" && pwd)"
snap="$common_dir/ryostore-hooks"

# Never install a partial set, and never snapshot a missing scanner.
for h in pre-commit pre-push; do
  if [ ! -f "$src_hooks/$h" ]; then
    echo "install-hooks: missing $src_hooks/$h; refusing to install a partial hook set." >&2
    exit 1
  fi
done
if [ ! -f "$src_scanner" ]; then
  echo "install-hooks: missing $src_scanner; the scanner must be present to snapshot. Aborting." >&2
  exit 1
fi

# Refuse to overwrite an UNRELATED hooks path (someone else's custom hooks).
current="$(git config --local --get core.hooksPath || true)"
if [ -n "$current" ] && [ "$current" != "$snap" ]; then
  cat >&2 <<EOF
install-hooks: refusing to overwrite an existing hooks path.
  core.hooksPath is already set to: $current

Review whatever is there first. If you want Ryostore's hooks instead, clear it:
  git config --unset core.hooksPath
then re-run:
  tools/install-hooks.sh
EOF
  exit 1
fi

# (Re)build the snapshot from scratch — this is the explicit opt-in refresh.
rm -rf "$snap"
mkdir -p "$snap/scanner" "$snap/policy/security"
install -m 0755 "$src_hooks/pre-commit" "$snap/pre-commit"
install -m 0755 "$src_hooks/pre-push"   "$snap/pre-push"
install -m 0644 "$src_scanner"          "$snap/scanner/security-screen.py"
if [ -f "$src_policy" ]; then
  install -m 0644 "$src_policy" "$snap/policy/security/exceptions.json"
  policy_note="snapshotted $src_policy"
else
  policy_note="note: $src_policy absent — snapshotted an empty policy (no exceptions)"
fi

git config --local core.hooksPath "$snap"

cat <<EOF
Installed Ryostore git hooks from a trusted snapshot OUTSIDE the working tree.
  snapshot:        $snap
  core.hooksPath -> $snap
  policy:          $policy_note

  pre-commit  screens the exact staged tree (security-screen.py --staged)
  pre-push    screens each pushed ref tip     (security-screen.py --revision)

Because the scanner and policy are snapshotted, switching branches or checking
out a PR cannot substitute them. Re-run this installer to refresh the snapshot
after pulling reviewed updates to the hooks, scanner, or exception policy.

Uninstall with:
  git config --unset core.hooksPath
  rm -rf "$snap"
EOF
