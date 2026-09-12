#!/bin/bash
# SPDX-License-Identifier: MIT
# Official source: https://github.com/Sipper1236/ryoku-palette-bridge
set -euo pipefail

commit=b1d13b2d93404570166dcce56ef640b7aac71f4c
upstream=https://github.com/Sipper1236/ryoku-palette-bridge.git
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
source_dir="$data_home/ryoku-palette-bridge"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

bridge_healthy() {
  command -v curl >/dev/null &&
    [[ $(curl -fsS http://127.0.0.1:47616/healthz 2>/dev/null) == ok ]]
}

canonical_service_active() {
  systemctl --user is-active --quiet ryoku-palette-bridge.service
}

if ryoku-cmd-present ryoku-palette-bridge && canonical_service_active && bridge_healthy; then
  echo "ryoku-palette-bridge: already installed and healthy"
  exit 0
fi

for command_name in git go curl systemctl; do
  command -v "$command_name" >/dev/null || {
    echo "ryoku-palette-bridge: missing required command: $command_name" >&2
    exit 1
  }
done

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

if [[ -e "$source_dir" ]]; then
  installed_commit=$(git -C "$source_dir" rev-parse HEAD 2>/dev/null || true)
  installed_upstream=$(git -C "$source_dir" remote get-url origin 2>/dev/null || true)
  if [[ ! -d "$source_dir/.git" || $installed_upstream != "$upstream" ||
        ! -x "$source_dir/install.sh" ]]; then
    echo "ryoku-palette-bridge: refusing unverified existing path: $source_dir" >&2
    exit 1
  fi
  if [[ -n $(git -C "$source_dir" status --porcelain --untracked-files=normal) ]]; then
    echo "ryoku-palette-bridge: refusing to overwrite local source changes: $source_dir" >&2
    exit 1
  fi
  if [[ $installed_commit != "$commit" ]]; then
    git -C "$source_dir" fetch -q --depth 1 origin "$commit"
    git -C "$source_dir" checkout -q --detach FETCH_HEAD
    [[ $(git -C "$source_dir" rev-parse HEAD) == "$commit" ]] || {
      echo "ryoku-palette-bridge: checkout did not reach pinned commit $commit" >&2
      exit 1
    }
  fi
else
  git -C "$work" init -q
  git -C "$work" remote add origin "$upstream"
  git -C "$work" fetch -q --depth 1 origin "$commit"
  git -C "$work" checkout -q --detach FETCH_HEAD

  install -d "$data_home"
  mv "$work" "$source_dir"
  trap - EXIT
fi

"$source_dir/install.sh"

integrations=()
if ryoku-cmd-present spicetify; then
  integrations+=(--spotify)
fi
if ryoku-cmd-present vesktop && ryoku-cmd-present jq; then
  integrations+=(--vesktop)
fi
if [[ -f "$config_home/zen/profiles.ini" ]]; then
  integrations+=(--zen)
fi

if (("${#integrations[@]}" > 0)); then
  "$source_dir/install-integrations.sh" "${integrations[@]}"
fi

ryoku-cmd-present ryoku-palette-bridge || {
  echo "ryoku-palette-bridge: installer completed but command is not on PATH" >&2
  exit 1
}

healthy=false
for _ in {1..20}; do
  if canonical_service_active && bridge_healthy; then
    healthy=true
    break
  fi
  sleep 0.25
done
if ! $healthy; then
  echo "ryoku-palette-bridge: service did not become healthy" >&2
  exit 1
fi

echo "ryoku-palette-bridge: installed"
echo "Run $source_dir/install-integrations.sh when you add another supported app."
echo "For Zen live updates, run $source_dir/setup-zen-signing.sh once."
