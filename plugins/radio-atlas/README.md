# Radio Atlas (Ryoku port)

Live radio on a rotatable globe from the QS Bar. Click a station signal to play
it, or click a country to browse its stations. Playback runs in `mpv`, with an
MPRIS bridge so the desktop media controls work.

Ported from `akshar.radio-atlas` 0.1.9 (Omarchy bar widget, by Akshar Patel) to
the Ryoku plugin contract. The player, the directory client, the sandbox and the
MPRIS bridge are the upstream code; the only changes are the runtime paths and
the plugin/host API surface.

## What it does

- **Widget** (`content/Widget.qml`): a globe glyph with the playing station or
  the volume. Left click opens the globe, middle click tunes a random station,
  right click stops or resumes, the wheel changes volume.
- **Panel** (`content/Panel.qml`): the globe — drag to spin, wheel to zoom,
  click a signal to play, click a country to browse. Below it: search, the
  station list, favourites and recent, the player (play/pause/stop/next/previous,
  volume, mute), and an audio-output picker.
- **Service** (`service/Main.qml`): the saved state (favourites, history,
  volume, audio output) and the station directory.

## What it runs, reads, writes

- Runs: `bin/radio-fetch` (the Radio Browser directory), `bin/radio-player`
  (mpv plus its MPRIS bridge), `bin/radio-state` (saved state),
  `bin/radio-session` + `bin/radio-sandbox` + `bin/radio-mpris` + `bin/radio-proxy`
  (the player's network sandbox and media bridge), `bin/radio-status.lua` (mpv's
  own status script), and `bin/radio-favicon` (station logos). Every command is
  declared in `dependencies.commands`.
- Reads: nothing outside its own tree except the station directory over HTTPS.
- Writes: its own runtime dir (`$RADIO_ATLAS_RUNTIME_DIR`, default
  `$XDG_RUNTIME_DIR/ryoku-radio-atlas`) and its state dir
  (`$RADIO_ATLAS_STATE_DIR`, default `$XDG_DATA_HOME/radio-atlas`), plus the
  country caches under `$XDG_CACHE_HOME/ryoku/plugins/radio-atlas`.
- No sudo, doas or su. No pkexec. No downloaded code is executed.

## Capabilities

- **Network**: `all.api.radio-browser.info` and the Radio Browser mirrors, for
  the station directory and the station streams. Station favicons are fetched
  through `bin/radio-proxy`, which refuses non-public destinations, and pinned
  to validated addresses so DNS cannot change between check and use.
- **Audio**: playback through the PipeWire sink you choose, including RAOP
  (AirPlay) sinks.

## Removing it

Stop the player first, then remove the plugin:

```
radio-atlas stop          # or: ~/.local/share/ryoku/plugins/radio-atlas/bin/radio-player stop
ryoku plugin remove radio-atlas
```

Favourites, history and volume live in `~/.local/share/radio-atlas/state.json`
and come back on a reinstall; delete that file to clear them. The country and
logo caches are under `~/.cache/ryoku/plugins/radio-atlas/`.
