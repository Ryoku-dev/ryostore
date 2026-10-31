# Utsuri for Ryoku

Start dragging files, tap **Shift**, and a liquid-glass radial menu opens under
the cursor. Drop on a slice: convert, compress, resize, strip metadata, split or
merge PDFs, or open one of Utsuri's editors (Crop, Edit, Annotate, Redact,
Add BG, Protect). Results are saved next to the originals. The originals are
never changed.

It is the Ryoku front end for [Utsuri](https://github.com/CratusGod/utsuri).
The desktop app's trigger reads global X11 input, which Wayland does not allow,
so Hyprland watches the left button and Shift instead (`hypr/trigger.lua`) and
opens the menu over IPC. The glass is Utsuri's `liquid.py` renderer ported to
GPU shaders (`service/shaders/`). Every action runs Utsuri's own `utsuri.cli`.

## Using it

1. Drag a file or folder (from Dolphin, a browser, anywhere) and tap **Shift**.
2. Hover a slice; the hub names it. Tap **Shift** again (or rest on the hub
   after visiting a slice) to flip between the rings (Convert, Tools, Archive).
3. Drop on a slice. Drop anywhere else, or press Esc, to cancel.

The drop is always a copy: Shift normally means "move" to a file manager, and
the menu refuses that so the original can never be deleted.

The menu never opens over a fullscreen window or a Steam/Proton/gamescope
game, so fire + Shift in a game is safe.

## What you can do

| Dropped | Convert to | Tools (one click) | Editors (own window) |
|---|---|---|---|
| Images (JPG PNG WEBP HEIC AVIF TIFF BMP GIF ICO) | any of those, or PDF; several images → one PDF | Compress, Under 500 KB, Half size, 1920 px, 1280 px, Remove location, Remove all metadata | Crop, Edit, Annotate, Redact, Add BG, Compress…, Resize…, Metadata |
| PDF | JPG, PNG (one per page), DOCX, TXT | Tools ring: Compress, Split pages, Rotate 90°, Extract images, Numbers, Gray, Flatten; Merge when you drop two or more. Pages ring: Halves, Chapters (one PDF per bookmark), Searchable (OCR for scanned pages) | Organize… (reorder, rotate, delete, duplicate, blank pages, extract a selection, cut into parts, merge several PDFs in your order), Watermark… (text or image stamp, live preview; text is drawn as a faded image so every viewer, LibreOffice included, shows the opacity, and it isn't selectable), Protect, Unlock…, Metadata |
| Word `.docx` | PDF, TXT | | |
| Text `.txt .md .csv …` | PDF, DOCX | | |
| Video `.mp4 .mov .mkv .webm .avi` | MP4, WEBM, GIF (first 15 s), MP3 (audio only) | Compress (≤1080p H.264) | |
| Audio `.mp3 .m4a .wav .flac .ogg .opus` | MP3, OPUS, WAV, FLAC | | |
| Folders | | Archive: ZIP, TAR.GZ, TAR.XZ. Images: → WEBP, → JPG, Shrink all (every image inside, into a new `<folder> WEBP` folder with the same layout) | |
| Archives `.zip .tar .tar.gz .tgz .tar.xz` | | Unpack (into a new folder) | |
| Text you highlighted in any app and dragged | | Text ring: **Translate** (in the [Oumu](https://github.com/CratusGod/oumu) app; without it, a card says how to get it), **Copy** | |

Every drop also gets an **Archive** ring (ZIP, TAR.GZ, TAR.XZ, Copy path) that
takes *everything* you dragged, whatever its kind. Several items become
`Archive.zip`. Images also get **Copy** (paste the image anywhere) and **Text**
(reads the text with tesseract, saves `<name> Text.txt` and copies it).

Archiving never follows symbolic links (they are left out and counted). Unpack
refuses archives with entries that point outside the new folder, links in ZIPs,
password-protected ZIPs, and archives larger than the free disk space; it
writes to a hidden temporary folder and renames it only when it is complete.

A glass card appears bottom-right with what changed (for example
"2.4 MB → 610 KB · 75% smaller"), a thumbnail, and **Open**, **Show in folder**
and **Undo** (moves the new files to the Trash, and says so if any couldn't be
moved). Undo moves a *folder* only if Utsuri made it (Unpack, batch); it keeps
a list of those, the last 100, in its state dir. It stays 6.5 s, pauses while hovered. Editors report into the same cards
when you save.

## Themes and options

Press **Super+Shift+U** (added with the Shift+drag trigger block, so re-run the
install command once after updating), or open the panel (⇄ in the bar) and press
**Customize**. The bar icon is not needed for either:

- **Theme:** Transparent (the original glass that adapts to what is behind it, and
  the default), Matugen (follows your wallpaper's colours through Ryoku's scheme),
  or a fixed colour: Midnight, Ocean, Forest, Rose, Ember, Graphite or Snow. The
  theme covers the Shift+drag menu and the result cards.
- **Menu options:** tap any option to turn it off; it leaves both the Shift+drag
  menu and the panel. The archive formats and Copy path are shared by every kind
  of file, so turning one off hides it everywhere. **Turn all back on** resets.

Both are saved in the plugin's state folder (`prefs.json`).

## How it is built to keep working

- **Pinned engine.** Utsuri is checked out at the exact commit in
  `engine/PIN` and never auto-updated. The plugin only
  moves when you run `engine/update.sh`, and only if every test passes.
- **Python that pacman can't break.** The engine's `.venv` runs on a
  uv-managed Python 3.12 (`~/.local/share/uv/python`), not the system Python,
  and installs `engine/requirements.lock` with hash checking. These are the same
  package versions Utsuri's CI tested at the pinned commit.
- **Nothing extra resident.** The menu lives inside the shell; no tray app,
  daemon or autostart. Each action runs one short process that answers with one
  JSON line and exits.
  Editors are detached processes, so a shell reload never kills an open editor.
- **Never stuck.** Each drop is its own job with its own card. A job silent for
  10 minutes gets SIGTERM, then SIGKILL, and reports. A menu that never receives
  a drag closes itself after 4 s; a failed screen capture still shows the menu.
- **Loud failures.** On load the plugin runs `bin/utsuri doctor`. If the
  engine is missing, broken or on the wrong commit, a red card names the one
  command that fixes it.
- **Tests.** `tests/` has 263 tests: every command, every format, filenames with
  spaces, unicode, `#` and `%20`, mixed and broken drops, honest Undo, cancel
  (SIGTERM) cleanup, signal forwarding to the engine, a real Crop save through Utsuri's own window, the
  drop-URL decoding, and menu parity (every slice is something the engine can do). `engine/update.sh` rollback was tested on failure and on
  SIGTERM mid-update; `engine/setup.sh` was tested repairing a venv whose Python vanished.

## Install

1. Install **Utsuri** from RyoStore (Ryoku Hub > Add-ons), or
   `ryoku plugin add <this repo> --bar --yes`.
2. Set up the engine once (needs `uv`: `sudo pacman -S uv`). Takes 2 to 5
   minutes and about 400 MB:

   ```bash
   ~/.local/share/ryoku/plugins/utsuri/engine/setup.sh
   ```

3. Turn on Shift+drag (Hyprland). The ⇄ bar icon's panel shows this same
   command with your plugin path filled in:

   ```bash
   sed -i '/^-- UTSURI-TRIGGER-BEGIN$/,/^-- UTSURI-TRIGGER-END$/d' ~/.config/hypr/user.lua; { echo; cat ~/.local/share/ryoku/plugins/utsuri/hypr/trigger.lua; } >> ~/.config/hypr/user.lua; ryoku wm act config.reload
   ```

4. Drag a file and tap Shift. After the first menu the ⇄ icon hides itself
   (Settings > Bar icon changes that). On niri or another compositor, keep
   using ⇄ as the drop target.

   Run the same command again after updating Utsuri: it replaces the old
   trigger block instead of adding a second one.

### Hyprland (`~/.config/hypr/user.lua`)

Install step 3 appends `hypr/trigger.lua`, one block between
`UTSURI-TRIGGER` markers. It holds the trigger (non-consuming binds on the
left button, Shift and Esc, so clicks and Shift still reach your apps), blur for
the result cards, and a rule that floats the editors (frameless Qt windows with
app_id `utsuri`). Delete the block to turn it all off.

Reload with `ryoku wm act config.reload`, check with `hyprctl configerrors`.

## What it runs, reads and writes

- **Runs** `bin/utsuri` (system `python3`, standard library only), which
  execs the engine venv's Python on `bin/utsuri.cli.py`. It also runs
  `git` (doctor reads the engine's commit), `gio trash` (Undo), `xdg-open`
  (Open), `dbus-send` to `org.freedesktop.FileManager1` (Show in folder) and
  `notify-send` (fallback when the shell is down), `stat` (the hub's file size),
  and, only when you pick those slices, `ffmpeg` (video/audio), `tesseract`
  (Text) and `wl-copy` (Copy, Copy path); `fc-match` (fontconfig) finds a font
  for non-Latin watermark text, which falls back to built-in fonts without it.
  A missing one is reported with the
  package that provides it; everything else keeps working
  and `qs ... ipc call utsuri` (editors report results; the Hyprland trigger
  opens the menu).
- **Talks to Oumu** (optional) over its socket `$XDG_RUNTIME_DIR/oumu.sock`,
  a local file only your user can open: Translate sends it `translate` plus
  the text. No program is started; without Oumu a card says how to get it.
- **Reads** the files and folders you drop, the text you drag, the engine
  checkout, and `engine/PIN`.
- **Writes** new files next to the files you dropped (or in a `Utsuri`
  subfolder beside them, see Settings), and nothing else. This is the one
  departure from rule R8 (stateDir only), and it is the plugin's purpose. It
  never overwrites: a clash gets `name (1).ext`.
- **Network:** none at runtime. `engine/setup.sh` and `engine/update.sh`
  contact github.com and PyPI (declared in `capabilities.network`), but only when
  you run them by hand.
- **Outside the state dir:** the engine lives in `~/.local/share/utsuri/engine`
  so removing or reinstalling the plugin never deletes it, and the setup command
  shown in the panel appends to `~/.config/hypr/user.lua` when *you* run it.
  These are the `outside-write` notes `ryoku plugin validate` prints.
- **Privileges:** none.

## Settings (QS Bar Settings > Community > Utsuri)

| key | type | default | description |
|---|---|---|---|
| engineDir | text | `~/.local/share/utsuri/engine` | where the engine checkout lives |
| output | choice | `next` | `next`: beside the original; `folder`: a `Utsuri` subfolder |
| barIcon | choice | `auto` | `auto`: show ⇄ until Shift+drag has worked once; `on`; `off` |
| ocrLang | text | `eng` | tesseract languages for Text, joined with `+` (e.g. `eng+vie`). Each needs its `tesseract-data-<code>` package |

## Updating the engine

```bash
cd <your plugin source checkout>
engine/update.sh            # list Utsuri commits newer than the pin
engine/update.sh <sha>      # try one; rolls back by itself on failure or Ctrl-C,
                            # and reinstalls the plugin on success
git commit -am "engine: <sha>"
```

To refresh the Python packages as well: edit `engine/requirements.in` if
needed, then run
`uv pip compile engine/requirements.in --python-version 3.12 --generate-hashes --upgrade -o engine/requirements.lock`,
then `engine/setup.sh`. If the tests fail,
`git checkout engine/requirements.lock && engine/setup.sh` puts the old set back.

## When something is wrong

1. Menu doesn't open: `qs -c shell ipc call utsuri shift 960 540` should show
   it. If it does, the trigger block in `user.lua` is missing or erroring
   (`hyprctl configerrors`). Errors from the engine show as red cards.
2. `~/.local/share/ryoku/plugins/utsuri/bin/utsuri doctor` prints the same as JSON.
3. `engine/setup.sh` repairs a missing or damaged engine. It is safe to re-run.
4. Shell-side errors: `ryoku-rashin logs quickshell`.

## Developing

```bash
~/.local/share/utsuri/engine/.venv/bin/python -m pytest tests 
ryoku plugin validate .
```

## Author

CratusGod. Community-made (`official` is false). MIT.
