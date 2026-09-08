# Ryoku Palette Bridge

One wallpaper change can now flow through the three apps that tend to stay open
all day: Zen Browser, Spotify, and Discord through Vesktop.

Ryoku Palette Bridge watches Matugen's active Ryoku palette and shares each
change over a local event stream. Every app uses the least disruptive way to
apply it:

- Zen updates its browser chrome through Firefox's native theme API.
- Spotify updates Spicetify and Encore colour tokens without stopping playback.
- Vesktop keeps Midnight loaded while Matugen changes only its QuickCSS
  variables, avoiding the flash back to Discord's stock theme.

Ryostore installs the bridge and automatically configures integrations for
compatible apps already present on the machine. The source is kept at
`~/.local/share/ryoku-palette-bridge`, so you can add another integration
later:

```bash
~/.local/share/ryoku-palette-bridge/install-integrations.sh --all
```

Zen's live extension must be signed by Mozilla. The repository includes a
guided setup:

```bash
~/.local/share/ryoku-palette-bridge/setup-zen-signing.sh
```

Source: <https://github.com/Sipper1236/ryoku-palette-bridge>

License: MIT. The bundled integration templates retain the third-party notices
included upstream.
