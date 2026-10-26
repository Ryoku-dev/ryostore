# 43PR extraction checks

Source is pinned in each product's `PROVENANCE.txt`. No upstream installer runs.

```sh
QT_QPA_PLATFORM=offscreen python3 -m unittest discover -s tests -p test_43pr.py -v
bash tests/validate-catalogue.sh
python3 tests/validate-store.py
python3 tools/security-screen.py --root . --format text
```

`test_43pr.py` checks registry/palette parity, contrast, terminal colors,
portable Fastfetch configuration and bar integration boundaries. With PySide6
installed it also renders the real lockscreen and exercises empty-password,
duplicate-submission, failure/retry and input-clearing behavior with a mock
authentication bridge. **These do not verify real PAM authentication.**

In a disposable Wayland session, with `QML_IMPORT_PATH` pointing at the installed
Ryoku Quickshell root, run `quickshell -p tests/43pr-bar.qml`. It exercises all
four edges and three styles, clock boundaries, and module placement. Use a
temporary `XDG_CACHE_HOME`, and require `43PR BAR CHECKS PASSED` with no QML
errors; the process intentionally stays running if an assertion fails.
The bar's workspace actions require Hyprland. Rendering on another compositor
does not verify those actions or the Hyprland toplevel-mapping protocol.

For installation tests, isolate **HOME and all XDG directories, including
XDG_RUNTIME_DIR**, set `RYOSTORE_BASE=file://<checkout>`, then install/remove/
reinstall `barstyles 43pr`, `fastfetch 43pr` and `lockscreens 43pr`. Compare every
installed file with the manifest hash and confirm preview files do not install.
Exercise the palette picker against the local catalog as well: a successful
`ryostore install colorschemes <id>` alone is not evidence that a daemon applied
a palette. Never test by overwriting the user's live Fastfetch or lock settings.

Previews are actual captures: the bar in a disposable nested Wayland session,
the Fastfetch output in kitty (cropped and centered on a 1280x720 frame), and
the actual lockscreen rendered at 1280x720. No upstream wallpaper or personal
avatar is redistributed. Generic named palettes already covered by the catalog
were omitted in favor of 13 distinct 43PR presets.
