# Chroma bar for Ryoku

This folder ports the visual language of `aethctl/chroma-shell`'s Chroma bar onto
Ryoku's bar-style API.

The port deliberately does **not** carry Chroma Shell's old runtime, theme engine,
settings store, notification server, MPRIS picker, CAVA process or window-manager
config.
Ryoku already owns those jobs. The bar binds to `shell.services` instead:

- `Theme` / `Scheme` for live Matugen and named-theme colours
- the shell's window-manager facade (`Ryoku.Ui.Singletons` -> `Wm`) for workspace state
- `Media` for MPRIS
- `AudioBars` for the playback spectrum
- `Notifs`, `Network`, `Audio`, and `Battery` for status
- `ShellState` for launcher and Ryoku menu surfaces

That keeps Chroma a bar style rather than a second shell embedded inside Ryoku.
