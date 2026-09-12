# Ryoku Palette Bridge

Ryoku Palette Bridge keeps Zen, Spotify, and Discord matched to your wallpaper.
Change the wallpaper and all three apps pick up its Ryoku colours automatically.

It works with the themes each app already supports:

- Zen's browser theme changes colour through Firefox's theme API.
- Spotify's Spicetify theme gets the same colours without stopping your music.
- Discord uses the Midnight theme in Vesktop, with its colours updated through
  QuickCSS so the stock Discord theme never flashes on screen.

This bundle is stored under `bundles/spiceflow` because the project started as
Spiceflow, a Spotify-only tool. The current project and its name in Ryostore are
Ryoku Palette Bridge because it now handles all three apps.

Ryostore installs the bridge and automatically configures integrations for
compatible apps already present on the machine. The source is kept at
`~/.local/share/ryoku-palette-bridge`, so you can add another integration
later:

```bash
~/.local/share/ryoku-palette-bridge/install-integrations.sh --all
```

Check the core service and published palette at any time:

```bash
ryoku-palette-bridge-doctor
```

Rerunning the bundle is safe: a healthy installation is left alone, while an
incomplete installation is repaired from the verified pinned source checkout.

Zen's live extension must be signed by Mozilla. The repository includes a
guided setup:

```bash
~/.local/share/ryoku-palette-bridge/setup-zen-signing.sh
```

Source: <https://github.com/Sipper1236/ryoku-palette-bridge>

License: MIT. The bundled integration templates retain the third-party notices
included upstream.
