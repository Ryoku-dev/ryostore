#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
installer="$repo_root/bundles/spiceflow/installers/ryoku-palette-bridge.sh"
expected_commit=$(sed -n 's/^commit=//p' "$installer")
test_root=$(mktemp -d /tmp/ryostore-palette-installer.XXXXXX)
trap 'rm -rf "$test_root"' EXIT
fake_bin="$test_root/bin"
repair_marker="$test_root/repaired"
canonical_marker="$test_root/canonical-service"
repair_log="$test_root/repair.log"
curl_log="$test_root/curl.log"
mkdir -p "$fake_bin" "$test_root/home"

cat > "$fake_bin/ryoku-cmd-present" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} == ryoku-palette-bridge ]]
EOF

cat > "$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
printf 'request\n' >> "$FAKE_CURL_LOG"
if [[ -f $REPAIR_MARKER ]]; then
  printf 'ok\n'
  exit 0
fi
exit 1
EOF

cat > "$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
if [[ $* == *'is-active --quiet ryoku-palette-bridge.service'* &&
      -f $CANONICAL_MARKER ]]; then
  exit 0
fi
exit 1
EOF

cat > "$fake_bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} == -C ]]
checkout=$2
case ${3:-} in
  init)
    mkdir -p "$checkout/.git"
    ;;
  checkout)
    printf '%s\n' "$EXPECTED_COMMIT" > "$checkout/.fake-head"
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      'set -euo pipefail' \
      'printf "run\\n" >> "$REPAIR_LOG"' \
      ': > "$REPAIR_MARKER"' \
      ': > "$CANONICAL_MARKER"' > "$checkout/install.sh"
    printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$checkout/install-integrations.sh"
    chmod +x "$checkout/install.sh" "$checkout/install-integrations.sh"
    ;;
  rev-parse)
    cat "$checkout/.fake-head"
    ;;
  remote)
    if [[ ${4:-} == get-url ]]; then
      printf '%s\n' 'https://github.com/Sipper1236/ryoku-palette-bridge.git'
    fi
    ;;
esac
EOF
chmod +x "$fake_bin/ryoku-cmd-present" "$fake_bin/curl" "$fake_bin/systemctl" "$fake_bin/git"

HOME="$test_root/home" \
XDG_CONFIG_HOME="$test_root/home/.config" \
XDG_DATA_HOME="$test_root/home/.local/share" \
REPAIR_MARKER="$repair_marker" \
CANONICAL_MARKER="$canonical_marker" \
REPAIR_LOG="$repair_log" \
FAKE_CURL_LOG="$curl_log" \
EXPECTED_COMMIT="$expected_commit" \
PATH="$fake_bin:$PATH" \
  "$installer"

test -f "$repair_marker"
test -f "$canonical_marker"
test -x "$test_root/home/.local/share/ryoku-palette-bridge/install.sh"
[[ $(wc -l < "$curl_log") -ge 1 ]]

mv "$canonical_marker" "$canonical_marker.first-run"
HOME="$test_root/home" \
XDG_CONFIG_HOME="$test_root/home/.config" \
XDG_DATA_HOME="$test_root/home/.local/share" \
REPAIR_MARKER="$repair_marker" \
CANONICAL_MARKER="$canonical_marker" \
REPAIR_LOG="$repair_log" \
FAKE_CURL_LOG="$curl_log" \
EXPECTED_COMMIT="$expected_commit" \
PATH="$fake_bin:$PATH" \
  "$installer"
test -f "$canonical_marker"
[[ $(wc -l < "$repair_log") == 2 ]]

printf '%s\n' 8e6daccc30e3918f2c718bc6f36cdb7b544492a0 \
  > "$test_root/home/.local/share/ryoku-palette-bridge/.fake-head"
mv "$canonical_marker" "$canonical_marker.second-run"
HOME="$test_root/home" \
XDG_CONFIG_HOME="$test_root/home/.config" \
XDG_DATA_HOME="$test_root/home/.local/share" \
REPAIR_MARKER="$repair_marker" \
CANONICAL_MARKER="$canonical_marker" \
REPAIR_LOG="$repair_log" \
FAKE_CURL_LOG="$curl_log" \
EXPECTED_COMMIT="$expected_commit" \
PATH="$fake_bin:$PATH" \
  "$installer"
grep -Fxq "$expected_commit" "$test_root/home/.local/share/ryoku-palette-bridge/.fake-head"
test -f "$canonical_marker"
[[ $(wc -l < "$repair_log") == 3 ]]

printf 'PASS: Ryostore repairs, migrates, and updates verified bridge installs\n'
