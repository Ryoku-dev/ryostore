# Native Switcher

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Hyprland%20%2B%20Quickshell-8A2BE2.svg)](https://github.com/wolf1999h/native-switcher)
[![Architecture](https://img.shields.io/badge/Architecture-Event--Driven%20%7C%20Zero--Daemon-success.svg)](https://github.com/wolf1999h/native-switcher)

An ultra-responsive, event-driven window switcher plugin resident inside the **Ryoku** desktop environment (**Hyprland + Quickshell**).

Unlike traditional external window switchers (such as standalone GTK daemons, Rofi, or Wofi), **Native Switcher** runs directly inside the resident Quickshell process. It consumes ordered compositor custom events, maintains an accurate Most-Recently-Used (MRU) focus history, and employs a lazy Wayland layer-shell surface that only instantiates UI when explicitly needed.

---

## Architecture & Design Highlights

- **Zero Dedicated Daemon:** Operates within the resident shell runtime via Quickshell IPC, eliminating process spawn latency, duplicate IPC sockets, and background memory footprint.
- **Intelligent First-Run Notification:** Automatically detects whether required Hyprland shortcuts are configured on startup. If unconfigured, a polite desktop notification reminds the user with instructions to configure them or run `setup.sh`. Silences automatically once shortcuts are set.
- **Lazy Layer-Shell Surface:** Quick taps (`Alt+Tab` released within 160 ms) switch windows instantaneously without instantiating Wayland surfaces, graphics textures, or compositor animations. The visual card overlay is created only when `Alt` is held past the threshold.
- **Compositor Custom Events:** Listens to raw Hyprland events (`native-switcher,next`, `native-switcher,prev`, `native-switcher,local-next`, `native-switcher,local-prev`, `native-switcher,release`) dispatched directly from compositor keybinds.
- **Layout-Agnostic Physical Keycodes:** Uses XKB physical keycodes (`code:64` and `code:108` for Left/Right Alt; `code:49` for Grave/Tilde) to ensure deterministic release detection regardless of active keyboard layout (e.g., US, Persian, European variants).
- **Smooth Motion & Interaction:** Horizontal `ListView` with cubic easing, kinetic mouse-wheel scrolling across the entire panel, card hover glow and lift effects, and keyboard arrow/tab navigation.
- **Strict Sandbox Compliance:** Built against the official Ryoku PluginKit singletons (`Theme`, `DesktopEntries`, `Quickshell.Hyprland`). Does not import internal shell modules or execute unprivileged file writes.

---

## Keyboard Shortcuts

| Shortcut | Scope | Behavior |
| :--- | :--- | :--- |
| <kbd>Alt</kbd> + <kbd>Tab</kbd> | Global | Step forward in MRU order across all workspaces |
| <kbd>Alt</kbd> + <kbd>Shift</kbd> + <kbd>Tab</kbd> | Global | Step backward in MRU order |
| <kbd>Alt</kbd> + <kbd>`</kbd> (physical `code:49`) | Active Workspace | Step forward through windows on current workspace only |
| <kbd>Alt</kbd> + <kbd>Shift</kbd> + <kbd>`</kbd> | Active Workspace | Step backward through windows on current workspace only |
| <kbd>→</kbd> / <kbd>↓</kbd> or <kbd>←</kbd> / <kbd>↑</kbd> | Current Scope | Navigate selected card via arrow keys |
| Release <kbd>Alt</kbd> or press <kbd>Enter</kbd> | — | Focus and raise selected window |
| <kbd>Esc</kbd> | — | Cancel switching and restore previous focus |

---

## Automated Installation (1-Click)

A companion setup script is included in the repository. It validates the plugin, adds it to Ryoku shell, places it in the centered frame popout host, and safely injects the required Hyprland keybindings into `~/.config/hypr/user.lua` idempotently:

```bash
git clone https://github.com/wolf1999h/native-switcher.git ~/Projects/native-switcher
cd ~/Projects/native-switcher
./setup.sh
```

---

## Manual Installation & Hyprland Configuration

### 1. Register & Place the Plugin

```bash
# Validate manifest and sandbox constraints
ryoku plugin validate .

# Install into Ryoku plugin storage (~/.local/share/ryoku/plugins/native-switcher)
ryoku plugin add . --yes

# Configure placement (framePopout, centered, no edge hover trigger)
ryoku-plugins-place native-switcher framePopout center center 0 0
ryoku-plugins-place native-switcher host framePopout
ryoku-plugins-place native-switcher enabled true
```

### 2. Configure Hyprland (`~/.config/hypr/user.lua`)

Native Switcher requires specific custom event bindings in your Hyprland configuration. Add the following lines to `~/.config/hypr/user.lua`:

```lua
-- =============================================================================
-- Native Switcher: Event-driven resident window switcher
-- =============================================================================

-- Global Alt+Tab cycling
hl.unbind("ALT + Tab")
hl.bind("ALT + Tab", hl.dsp.event("native-switcher,next"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.event("native-switcher,prev"))
hl.bind("ALT + SHIFT + ISO_Left_Tab", hl.dsp.event("native-switcher,prev"))

-- Physical key below Esc (code:49 / Grave / Tilde) — workspace-local switcher
hl.bind("ALT + code:49", hl.dsp.event("native-switcher,local-next"))
hl.bind("ALT + SHIFT + code:49", hl.dsp.event("native-switcher,local-prev"))

-- Physical Alt release listeners (Left Alt code:64, Right Alt code:108)
-- transparent + non_consuming ensure normal modifier functionality is preserved
for _, key in ipairs({ "code:64", "code:108" }) do
    hl.bind(key, hl.dsp.event("native-switcher,release"), {
        release = true,
        transparent = true,
        ignore_mods = true,
        non_consuming = true,
    })
end

-- Suppress compositor animation on switcher layer; motion is handled inside QML
hl.layer_rule({
    name = "native-switcher-motion",
    match = { namespace = "^ryoku-native-switcher$" },
    no_anim = true,
})
```

After modifying `user.lua`, reload the compositor:

```bash
hyprctl reload
```

---

## Why Not an Automatic In-Plugin Shortcut Mutator?

A natural question is whether the plugin can automatically edit `~/.config/hypr/user.lua` when first loaded:

1. **Security & Sandbox Isolation (Ryoku Rule R8):** Ryoku plugins are strictly sandboxed. Writing to paths outside `$XDG_STATE_HOME/ryoku/plugins/<id>` triggers a blocking `config-write` security violation during `ryoku plugin validate`, immediately disqualifying the plugin from being published to the official **Ryostore** or loaded by the shell.
2. **Configuration Integrity:** Modifying the user's primary compositor configuration from a background QML thread without explicit user review is unsafe.
3. **The Solution (Smart Detection & Notification):** Native Switcher runs a lightweight verifier (`bin/check-bindings`) on desktop startup. If the compositor bindings are missing, a system notification alerts the user with directions. Users can inspect the transparent `setup.sh` script and execute it, or copy the configuration block directly into `~/.config/hypr/user.lua`. Once configured, the notification never appears again.

---

## Configuration & Settings

Configurable via **Ryoku Settings → Plugins → Native Switcher**:

| Key | Type | Default | Range | Description |
| :--- | :--- | :--- | :--- | :--- |
| `delayMs` | `int` | `160` | `80` – `500` | Threshold delay (in milliseconds) before the visual card overlay is presented. Fast taps below this threshold switch windows instantly without UI overhead. |

---

## Running Unit Tests

The test suite validates the MRU snapshot model, icon resolution, layout budgeting, motion dismissal lifetimes, and keyboard navigation:

```bash
# Run all test suites
for t in tests/*.test.cjs; do node "$t"; done
```

---

## Publishing to Ryostore (Ryoku Distro Store)

To submit Native Switcher to the official curated distro store:

```bash
# 1. Ensure all tests and manifest constraints pass validation
ryoku plugin validate .

# 2. Share and submit an upstream Pull Request to Ryostore
ryoku plugin share native-switcher
```

This packages the verified plugin and submits it to the official Ryoku Hub catalog for community distribution.

---

## License

Released under the [MIT License](LICENSE).  
Copyright © 2026 **wolf1999h** <doorman-bust-exile@duck.com>.
