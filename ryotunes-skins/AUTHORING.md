# Authoring a Ryotunes skin for the Ryoku store

A **Ryotunes skin** is one file, `skin.json`, that names every colour, type
face, radius, duration and a couple of globals the Ryotunes music player reads.
Users install skins from the store; applying one lands it in a store-owned
directory and Ryotunes shows it in **Settings › Appearance** with a STORE badge.
The full format reference lives in the Ryotunes repo:
[`docs/SKINS.md`](https://github.com/ryoku-dev/ryotunes/blob/main/docs/SKINS.md),
and the machine-checkable schema is
[`skins/skin.schema.json`](https://raw.githubusercontent.com/ryoku-dev/ryotunes/main/skins/skin.schema.json).

Copy [`template/`](template) to start; it is a complete skin with every field
explained. For a skin derived from a known colour scheme, use the import tool
below instead.

## Layout

```
ryotunes-skins/
  registry.json         the catalogue (envelope: {"schema": 1, "ryotunes-skins": [...]})
  <id>/
    skin.json           the skin manifest (format 1), install true
    manifest.json       the product manifest (sizes + sha256 of every file)
    preview.png         800x500 capture of Ryotunes wearing the skin, install false
    LICENSE             the licence the skin ships under
    PROVENANCE.txt      where the palette / design came from, and how it was made
    fonts/              optional bundled faces (*.ttf|otf), install true
```

One folder per skin, named for its `id`. Nothing ships until it is listed in
`registry.json`.

## Where it installs, and how it is picked

Applying a skin copies the product into its own store directory:

```
~/.local/share/ryoku/ryotunes-skins/<id>/skin.json
```

Ryotunes searches that as the **store** source, after your own skins and before
the ones shipped in the package: dev > `~/.config/ryotunes/skins` > store >
shipped. Selecting a skin is Ryotunes' job — pick it in **Settings ›
Appearance**, or run `ryotunes-cli skin use <id>`, which writes `"skin": "<id>"`
into `~/.config/ryotunes/client.json`; Ryotunes watches that file and repaints
live. The store only installs and removes.

## skin.json

Everything is optional **except** `format: 1` and a `modes` object with at least
one mode carrying `paper` and `ink`. Any missing key falls back to Ryotunes'
built-in **Paper** skin, so a skin is a palette and a few globals, not a
stylesheet. The eight colour roles, per mode, are:

| Role | Is |
| --- | --- |
| `paper` | the base surface |
| `paperLift` | a slightly lifted surface |
| `ink` | primary text on paper |
| `inkDim` | secondary text on paper |
| `bone` | the inverse surface |
| `inkOnBone` | text on bone |
| `sun` | the primary / accent |
| `alert` | error / destructive |

`ryotunes-cli skin check` enforces WCAG contrast: `ink`/`paper` ≥ 4.5 and
`inkOnBone`/`bone` ≥ 4.5 are **errors**; `inkDim`/`paper` ≥ 3.0 and `sun`/`paper`
≥ 3.0 are warnings. Leave `type`, `shape`, `motion` and `decor` out to inherit
Paper's defaults, or set them; see `docs/SKINS.md` for every key.

## registry.json entry

Add a row to the `ryotunes-skins` array:

| field | meaning |
| --- | --- |
| `id` | kebab-case slug, matching the folder and `skin.json` |
| `name` | display name in Settings |
| `version` | product version, matching `skin.json` |
| `path` | `ryotunes-skins/<id>` |
| `author` | who made the skin (drives the store's provider grouping) |
| `summary` | one line for the card |
| `description` | what the skin looks like |
| `tags` | lowercase keywords, e.g. `["dark", "noctalia", "colorscheme"]` |
| `accent` | `#rrggbb`, **equal to the default mode's `sun`** |
| `surface` | `#rrggbb`, **equal to the default mode's `paper`** |
| `preview` | `preview.png` |
| `screenshots` | extra captures, usually `[]` |
| `manifest` | `manifest.json` |
| `manifestSha256` | sha256 of `manifest.json` (written by `pack-product.py`) |
| `lastUpdated` | `YYYY-MM-DD` |

`manifest.json` repeats `id`, `category: "ryotunes-skins"` and `version`, sets
`destination: "ryoku/ryotunes-skins/<id>"`, and lists every file with its size,
sha256, mode and `install` flag (`skin.json` install true, `preview.png` install
false). Regenerate it and the registry hash with:

```sh
tools/pack-product.py ryotunes-skins/<id>
```

## Deriving a skin from a colour scheme

Most store skins come straight from Ryoku's colour-scheme catalogue. To turn one
or more schemes in `colorschemes/registry.json` into skins:

```sh
tools/import-ryotunes-skins.py <scheme-id> [<scheme-id>...]
```

It maps each Noctalia palette onto the eight roles (`paper=mSurface`,
`ink=mOnSurface`, `sun=mPrimary`, …; the exact mapping is written into each
`PROVENANCE.txt`) and writes `skin.json`, `LICENSE` and `PROVENANCE.txt` plus the
registry entry. Then capture a preview and pack:

```sh
tools/pack-product.py ryotunes-skins/<id>
```

The import is idempotent: it preserves an existing entry's `manifestSha256` and
`lastUpdated`, so it never undoes a later pack.

## preview.png

The preview is a real capture of Ryotunes wearing the skin, never a mock-up:
exactly **800×500**, listed in the manifest with `install: false`. Shoot it with
the rig in the Ryotunes checkout, which brings up a headless client pinned to the
skin, navigates home, and crops to the window:

```sh
# from the ryotunes checkout; the skin dir's parent becomes RYOTUNES_SKIN_DIRS
scripts/dev/skin-preview.sh /path/to/ryostore/ryotunes-skins/<id> \
  /path/to/ryostore/ryotunes-skins/<id>/preview.png
```

Re-run `pack-product.py` afterwards so the manifest picks up the new `preview.png`.

## Test and submit

Validate the whole catalogue from the repo root:

```sh
python3 tests/validate-store.py
```

and check the skin itself against the Ryotunes rules (contrast, hex, ranges):

```sh
ryotunes-cli skin check ryotunes-skins/<id>
```

### PR checklist

- [ ] `skin.json` with `format: 1`, `id` equal to the folder name, a `modes`
      object with at least one `paper`+`ink` mode.
- [ ] `ryotunes-cli skin check` passes with **no errors**.
- [ ] `license` is `CC0-1.0` or `MIT`, and `LICENSE` carries the full text.
- [ ] `preview.png`, 800×500, a real capture from `skin-preview.sh`.
- [ ] `PROVENANCE.txt` names the source and, for derived skins, the mapping.
- [ ] Any bundled `fonts/` are freely redistributable — **no proprietary
      fonts**. Prefer naming a common family in `type` over bundling.
- [ ] `registry.json` entry with `accent`/`surface` equal to the default mode's
      `sun`/`paper`, and `manifestSha256` regenerated by `pack-product.py`.
- [ ] `python3 tests/validate-store.py` passes.
