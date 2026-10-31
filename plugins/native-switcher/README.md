# Native Switcher

Resident Ryoku/Quickshell window switcher, not a separate process. The service receives ordered custom compositor events and keeps a small event-driven MRU list. The UI is lazily created only after the quick-tap threshold and destroyed when dismissed.

## Capabilities
Reads window titles, classes, addresses and workspace metadata from Hyprland. Focuses/raises the explicitly selected window. Reads the shell theme and desktop-entry icons through public APIs. Reads the same icon index as the dock using `ryoku-shell icons` at startup and on application changes. No network, credentials, privileged actions, idle polling or file writes.

The resident service is loaded through the centered frame-popout plugin host, with no edge hover trigger. It reserves no bar slot; Alt+Tab opens the independent lazy panel. The centered layer-shell view uses the public plugin palette; imports no shell internals.

## Shortcuts
Alt+Tab cycles all ordinary windows. Alt+the physical key below Esc (`code:49`, grave on US keyboards) cycles only windows on the focused monitor's active workspace. Scope is captured when the chord begins; arrows and repeat presses keep that scope. Release Alt or press Enter to select; Escape cancels.

## Motion
Panel entry uses a short OutCubic fade, 2.5% scale and 5px settle; exit is 100ms, retaining the surface only until dismissal finishes. A dedicated namespace rule disables duplicate compositor animation. Quick taps bypass rendering and remain immediate. Selection uses one moving outline; hover is visual only, click has a subtle press response, and mouse wheel smoothly scrolls the horizontal list anywhere over the panel without changing selection. Focus is applied after unmapping, not while the keyboard layer is alive. All animations stop at rest; no animation polling.

## Settings
`delayMs`: 160 by default, 80–500.

## Testing
`node tests/model.test.cjs` checks filtering, MRU order and wrapping. Live end-to-end tests must inject real compositor keys with permission, assert target address and panel visibility, release keys and restore focus.

## Install
`ryoku plugin validate .` then `ryoku plugin add . --yes`. Enable with `ryoku-plugins-place native-switcher framePopout center center 0 0`, `ryoku-plugins-place native-switcher host framePopout`, and `ryoku-plugins-place native-switcher enabled true`. Bind `hl.dsp.event("native-switcher,next")`, `native-switcher,prev`, and a transparent non-consuming ignore-modifiers Alt release callback to `native-switcher,release`. Custom events avoid global-shortcut pressed-state loss when a plugin is hot-reinstalled. The previous standalone GTK service has been retired after user acceptance.

Community-made; author wolf1999h <doorman-bust-exile@duck.com>.
