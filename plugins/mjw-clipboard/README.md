# Clipboard

A Ryoku desktop widget ported from **Awe** (github.com/neur0map/MJ-widgets), released under BSL-1.0.

Polls `wl-paste -n` every couple of seconds and keeps the last eight distinct
clipboard entries; clicking one copies it back with `wl-copy`. The history is
persisted to `$XDG_STATE_HOME/ryoku/plugins/mjw-clipboard/state.json`.

Requires `wl-paste` and `wl-copy` (wl-clipboard). No network access.

See `LICENSE` for the full Boost Software License 1.0 text.
