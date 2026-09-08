#!/bin/bash
# SPDX-License-Identifier: MIT
# Official source: https://github.com/Sipper1236/ryoku-palette-bridge
set -euo pipefail

if ryoku-cmd-present ryoku-palette-bridge; then
  echo "ryoku-palette-bridge: already installed"
  exit 0
fi

commit=8e6daccc30e3918f2c718bc6f36cdb7b544492a0
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
source_dir="$data_home/ryoku-palette-bridge"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

if [[ -e "$source_dir" ]]; then
  echo "ryoku-palette-bridge: refusing to replace existing path: $source_dir" >&2
  exit 1
fi

git -C "$work" init -q
git -C "$work" remote add origin https://github.com/Sipper1236/ryoku-palette-bridge.git
git -C "$work" fetch -q --depth 1 origin "$commit"
git -C "$work" checkout -q --detach FETCH_HEAD

install -d "$data_home"
mv "$work" "$source_dir"
trap - EXIT

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

echo "ryoku-palette-bridge: installed"
echo "Run $source_dir/install-integrations.sh when you add another supported app."
echo "For Zen live updates, run $source_dir/setup-zen-signing.sh once."
