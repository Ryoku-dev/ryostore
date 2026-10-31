#!/usr/bin/env bash
# ==============================================================================
# native-switcher: Automated Setup & Hyprland Integrator
# ==============================================================================
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPR_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/user.lua"

echo -e "${BOLD}${BLUE}==>${NC} ${BOLD}Installing Native Switcher plugin...${NC}"

# 1. Validate dependencies
command -v ryoku >/dev/null 2>&1 || {
    echo -e "${RED}[ERROR]${NC} 'ryoku' command not found. Ensure Ryoku desktop environment is installed." >&2
    exit 1
}

# 2. Validate and register plugin (if not already installed via Ryostore)
if command -v ryoku >/dev/null 2>&1 && ryoku plugin list 2>/dev/null | grep -q "native-switcher"; then
    echo -e "${GREEN}  ✓${NC} Native Switcher is already registered in Ryoku shell."
else
    echo -e "${BLUE}  ->${NC} Validating plugin manifest and sandbox constraints..."
    ryoku plugin validate "${SCRIPT_DIR}"

    echo -e "${BLUE}  ->${NC} Adding plugin to Ryoku shell..."
    ryoku plugin add "${SCRIPT_DIR}" --yes
fi

echo -e "${BLUE}  ->${NC} Ensuring correct plugin placement (centered popout host)..."
if command -v ryoku-plugins-place >/dev/null 2>&1; then
    ryoku-plugins-place native-switcher framePopout center center 0 0 || true
    ryoku-plugins-place native-switcher host framePopout || true
    ryoku-plugins-place native-switcher enabled true || true
fi

# 3. Configure Hyprland keybindings in user.lua
echo -e "${BLUE}  ->${NC} Checking Hyprland configuration in ${HYPR_CONF}..."
if [ -f "${HYPR_CONF}" ]; then
    if grep -q "native-switcher,next" "${HYPR_CONF}"; then
        echo -e "${GREEN}  ✓${NC} Hyprland bindings already present in ${HYPR_CONF} (skipping injection)."
    else
        BACKUP="${HYPR_CONF}.bak.$(date +%Y%m%d%H%M%S)"
        cp "${HYPR_CONF}" "${BACKUP}"
        echo -e "${YELLOW}  ✓${NC} Created backup of user.lua at ${BACKUP}"

        cat >> "${HYPR_CONF}" << 'EOF'

-- =============================================================================
-- Native Switcher: Event-driven resident window switcher
-- =============================================================================
hl.unbind("ALT + Tab")
hl.bind("ALT + Tab", hl.dsp.event("native-switcher,next"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.event("native-switcher,prev"))
hl.bind("ALT + SHIFT + ISO_Left_Tab", hl.dsp.event("native-switcher,prev"))

-- Physical key below Esc (code:49 / Grave / Tilde) — workspace-local switcher
hl.bind("ALT + code:49", hl.dsp.event("native-switcher,local-next"))
hl.bind("ALT + SHIFT + code:49", hl.dsp.event("native-switcher,local-prev"))

-- Physical Alt release listeners (Left Alt code:64, Right Alt code:108)
for _, key in ipairs({ "code:64", "code:108" }) do
    hl.bind(key, hl.dsp.event("native-switcher,release"), {
        release = true,
        transparent = true,
        ignore_mods = true,
        non_consuming = true,
    })
end

-- Suppress compositor animation on switcher layer; motion is rendered in QML
hl.layer_rule({
    name = "native-switcher-motion",
    match = { namespace = "^ryoku-native-switcher$" },
    no_anim = true,
})
-- =============================================================================
EOF
        echo -e "${GREEN}  ✓${NC} Successfully injected native-switcher bindings into ${HYPR_CONF}"
    fi

    if command -v hyprctl >/dev/null 2>&1; then
        echo -e "${BLUE}  ->${NC} Reloading Hyprland configuration..."
        hyprctl reload >/dev/null 2>&1 || true
        echo -e "${GREEN}  ✓${NC} Hyprland reloaded."
    fi
else
    echo -e "${YELLOW}[WARN]${NC} ${HYPR_CONF} not found. Please add the Hyprland bindings manually."
fi

echo -e "\n${BOLD}${GREEN}✔ Native Switcher is successfully installed and active!${NC}"
echo -e "Press ${BOLD}Alt+Tab${NC} to switch windows globally, or ${BOLD}Alt+\`${NC} (Grave) for the current workspace.\n"
