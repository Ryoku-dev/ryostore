# Local LLM Manager

Bar widget for local model servers. It finds every installed engine and its ready models by itself,
runs one model at a time, and gives each model its own port.

- **Glyph**: a chip icon (lit while a model runs) and the selected model's name. Click to open the panel.
- **Panel**: models grouped by engine, each with its port; the selected model's address; START / STOP.

## Engines and models (auto-detected)

| Engine | Found when | Models | Started as |
|---|---|---|---|
| Strata | `<Strata folder>/serve/server.py` exists | every `strata-<name>.json` in it (port from its `"port"`) | `<folder>/.venv/bin/python` (or `python3`) `serve/server.py --engine strata --config <json> --port <port> --lazy --idle-unload 900` |
| TabbyAPI | `<TabbyAPI folder>/run.sh` exists | every finished folder in its `models/` (EXL3) | `run.sh --port <port> --model-name <folder>` |
| llama.cpp | `llama-server` is on the PATH | every `*.gguf` in the GGUF folders (first shard; no mmproj/imatrix) | `llama-server -m <gguf> --host 127.0.0.1 --port <port> -c 16384` |

A model with no fixed port gets the next free one from 8081 (skipping ports in use) the first time it
is seen, kept in `ports` under the state dir so it never changes.

## Settings (QS Bar Settings > Community > Local LLM Manager, group "Paths")

| Setting | Default |
|---|---|
| Strata folder | `~/Strata` |
| TabbyAPI folder | `~/tabbyAPI` |
| GGUF folders (space-separated) | `~/models` |

## What it runs, reads, writes

- `bin/strata-models list` every 5 s (reads the folders above, `ss -ltn` when assigning a port) and
  `systemctl --user is-active strata-model.service`.
- On click: `use` writes `current`; `start` stops `strata-model.service` if it runs, then launches the
  selected model as that transient user unit with `systemd-run --user` (command lines above);
  `stop` stops it. Model servers you started by hand are left alone.
- Nothing to install: the unit is transient, nothing is enabled, nothing starts at login.
- Writes only under `$XDG_STATE_HOME/ryoku/plugins/strata/`. No privileged commands. Network: none
  itself; it only shows the local servers' `127.0.0.1` address.
