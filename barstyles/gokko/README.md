# Gokko (ごっこ)

A macOS-inspired Liquid Glass **barstyle/subshell** for Ryoku, with an app
menu, Spotlight search, Control Center, Dock and desktop widgets.

## Origin and licensing

Adapted from [0-ss/MacShell](https://github.com/0-ss/MacShell), pinned at
`d4f8500c41577ab7d056470a7931392786ed0300` (MIT). The port retains
upstream credits and licences. See `LICENSE`, `NOTICE.md`, and `PROVENANCE.txt`.

## Installation and compatibility

The Store item is `barstyles/gokko`, with `Scene.qml` as its entrypoint.
**It requires the matching Ryoku shell core integration** for hosted widgets,
bar-family lifecycle, and universal dock ownership. Until that core work is
merged and deployed, installing this package alone does not guarantee the
complete subshell. The core integration is maintained as a **separate Ryoku
PR**, never as an executable patch installed by RyoStore.

The original standalone `Installer.qml`, MacLock shell, and duplicate standalone
`upstream/shell.qml` are not part of the barstyle. Gokko's existing lockscreen
settings may refer to MacLock, which requires a separately installed upstream
component. Those controls are not part of Gokko's guaranteed feature set.

The widget bridge uses the Ryoku shell's own resident wallpaper surface.
Hyprland and Niri both need final on-machine validation. No Gokko installer
is permitted to edit compositor config or invoke a distribution package manager.

## Maintenance

Integration: aethctl. Users should report failures or security findings to the
maintainer. The maintainer is responsible for keeping the Store release and
companion core integration compatible.

## MacShell 1.0.5 Niri glass test

This candidate ports MacShell's output-snapshot concept to the existing Ryoku
WM bridge. Niri gets periodic wlr-screencopy frames while menus are closed,
frozen while menus are open. The old bar area is masked to prevent feedback.
Hyprland's existing live per-window capture is preserved. The Niri Dock still
uses its native compositor blur until its snapshot path can be tested safely.

Source: MacShell 0.3.7 / Ryoku MacShell 1.0.5, upstream commit
`bef9fc4d20cedd570c1a9a9fb72f548fe4571936`. This is not yet live-tested.

## Gokko 0.2.1 Niri follow-up (local test)

This test enables the Niri shader that 0.2.0 had accidentally gated off, removes
all tint and compositor blur from the menu bar strip (leaving its text adaptive),
tracks Ryogami's current wallpaper poster on bar and Dock, disables Spotlight's
wide background blur region, and routes the built-in wallpaper picker through
`ryogami wallpaper set` rather than `awww` or `swww`.

The Dock shader uses the current wallpaper but Niri live-window refraction
is not yet proven. Settings inactive-window opacity is not modified because
that may be a compositor window rule. This needs an actual Niri runtime test.

## Gokko 0.2.2 Niri glass probe (local)

This experimental patch directly binds the Dock wallpaper to the current
Ryogami source, routes the Bar's Niri output snapshot through its actual
offscreen glass-backdrop component, and logs snapshot and shader state.
The Settings window's compositor border and true Dock live-window refraction
remain separate unresolved issues. No general release claims are made.

## Gokko 0.2.3 Dock shader bundle (local experiment)

Adds a precompiled `dockglass.frag.qsb` and its matching source from the
user-supplied MacShell 1.0.5 package. On NixOS, `qsb` is often absent from PATH;
`MacDock.qml` already falls back to copying a sibling `.qsb` when compilation
is unavailable. This avoids a build-time `dockGlassState=failed` without
requiring a persistent compiler dependency or touching NixOS system packages.

The source/binary pair is carried together because Gokko's original shader
source has diverged. Runtime rendering, snapshot stability, and the native
Niri settings-window border are not validated by this static package test.

## Gokko 0.2.4: Ryogami ownership (Niri local test)

Gokko no longer exposes an independent wallpaper gallery inside hosted Ryoku.
The wallpaper settings entry opens `ryogami wallpaper ui`, and the legacy
wallpaper hotkey delegates to Ryogami. Gokko only reads the current poster via
MacRoot's Ryoku.Session wallpaper bridge. Bar, Dock, and widget refraction all
use the same source on Niri and never fall back to a stale saved MacShell
wallpaperPath. The last resolved poster stays visible during asynchronous
wallpaper changes to avoid a transient empty map. Spotlight's aggressive
Niri-only opaque tint and excessive blur are reduced to make refraction visible.

**Limit:** Ryogami may render live Wallpaper Engine/video frames while the
poster bridge supplies a static still. Correct real-time refraction of live
animated wallpaper requires a separate Niri screencopy pipeline for the Dock
and widget surfaces. This patch does not claim to implement that pipeline.
Niri settings-window focus-ring bleed is a compositor-side window rule and
is deliberately not addressed by mutating global Niri configuration here.

## Gokko 0.2.5: Niri Spotlight and Settings focus (local test)

Spotlight now owns a Niri whole-output ScreencopyView in its own PanelWindow.
It pre-captures while closed and freezes the background while open, preventing
cross-window ShaderEffectSource and recursive self-capture. A missing frame
uses GGlass fallback instead of sampling an empty texture.

On Niri the rounded Settings window frame is filled with an opaque sidebar
base colour before its semi-transparent layers are painted. This stops the
focus-ring background from tinting its contents. The original Hyprland design
is unchanged. If a line remains *outside* the Settings frame, a targeted Niri
`draw-border-with-background false` rule can remove that compositor-owned ring.

Still requires a real Quickshell 0.3.0 runtime test before PR. This package
contains no change to Ryogami wallpaper ownership, Dock or widgets.

## Gokko 0.2.6: Ryoku UI polish

- Removed nonfunctional Hyprland-only Help menu entries.
- Hidden obsolete Settings sidebar entries: Wallpaper, Lock Screen,
  Keyboard, Mouse, Trackpad. Removed only navigation, not supporting modules.
  Former wallpaper deep links open Ryogami; other hidden panes redirect to General.
- Removed the Menu Bar's blur/liquid selector, retaining the internal setting,
  shader fallback logic and independent Liquid Glass strip switch.
- About -> Configuration and Open folder now use ~/.config/ryoku. The
  MacDock private settings still save independently as before.
- Removed the inherited broad Reset MacShell action that changed global/input
  settings. About now credits Aethctl (port) and Feelyourwarmth (Liquid Glass
  and UI) with a working upstream link to https://github.com/0-ss/MacShell.
- About This Linux popup now labels the shell Gokko, drops stale MacShell 0.3.5
  and old distribution homepage link, and preserves Linux trademark notice.
- Removed the fake AppleCare UI and excessive padding from About.

Upstream authorship and licensing remain in LICENSE, NOTICE, PROVENANCE
and their original source files. Existing RyoStore install/update behaviour,
MacShell coexistence and all glass components remain unchanged.

## Gokko 0.2.7: reversible WhiteSur icon integration

- Loading Gokko activates WhiteSur-dark when available, on GTK and writable
  qt6ct user preferences. NixOS users without the icon theme get the Nixpkgs
  `whitesur-icon-theme` package via a persistent per-user Nix build link.
- No sudo, system-wide changes, Nix profile mutation or upstream shell installer.
- Prior GTK/qt6ct themes are recorded under ~/.local/state/ryoku/gokko-icons
  (or XDG_STATE_HOME) and restored when Gokko is deselected, provided those
  values still equal Gokko's theme. User changes are never overridden on exit.
- Existing WhiteSur theme directories, read-only/managed qt6ct configuration,
  and offline/no-Nix environments are left untouched. A missing icon package
  never prevents Gokko from rendering.
- On desktop session crashes, recovery is available by running
  `python3 <Gokko view>/upstream/gokko-icons.py restore` once Gokko is no longer
  selected. No automatic NixOS rebuild is performed.
- This is a separate icon-theme project: WhiteSur by vinceliuice, GPL-3.0-or-later,
  https://github.com/vinceliuice/WhiteSur-icon-theme . It is not bundled as
  proprietary artwork in RyoStore.

## Gokko 0.2.8: GTK fallback on minimal desktops

- If GSettings has no GNOME interface schema, Gokko temporarily updates only
  `gtk-icon-theme-name` under user GTK 3 and GTK 4 settings.ini instead.
- The prior values are recorded in the same Gokko icon session state, and
  restored when Gokko is deselected if unchanged by the user.
- An already-active 0.2.7 icon session is migrated without erasing its Qt or
  GSettings backup; icon selection remains optional on systems without WhiteSur.
- No system NixOS changes, sudo, Qt style changes or changes to glass assets.

## Gokko 0.2.9: live icon-theme resolution

- Gokko's Dock uses the Ryoku shell's `shell.services.Icons` singleton to resolve
  installed theme icon files instead of Qt's cached `Quickshell.iconPath`.
- Desktop-entry IDs and icon names are matched against the active theme, so
  WhiteSur can override even app icons supplied by absolute /nix/store paths.
- Custom paths remain a fallback; missing names fall back safely.
- Ryoku reindexes whenever the GTK 3 icon settings file changes. No shell
  restart, separate icon DB, extra fetches or changes to Liquid Glass code.
- This is unrelated to the Ryoku Hub backend's missing GSettings schema error,
  whose source fix requires its own binary rebuild.

## Gokko 0.2.10: direct WhiteSur icon canary

- Force known Gokko Dock apps (Firefox, Spotify, Steam, Kitty and VS Code)
  to the actual `~/.local/share/icons/WhiteSur-dark/apps/scalable` SVGs.
- Log `[gokko-icons-direct]` per changed icon source. This lets us prove that
  the currently running versioned view is the one being rendered.
- Keep the Ryoku icon resolver as fallback for unrecognized applications.
- This experiment changes no desktop-wide icon preference or glass code.

## Gokko 0.2.11: theme-index-backed Dock icons

- Query Ryoku's installed icon index once at startup and when GTK's chosen
  icon theme changes. No per-app subprocess, global theme reset or Qt QIcon cache.
- Prefer actual WhiteSur-themed files for apps including GNOME Files, Dolphin,
  Kitty, Firefox, Spotify, Steam and Discord/Vesktop, with safe alias matching.
- Trash resolves directly to an installed SVG rather than `image://icon/...`.
- Log `[gokko-icons]` index readiness and each Dock Image source; a load failure
  uses the bundled Gokko image rather than Qt's magenta missing-image pattern.
- Leaves the existing Liquid Glass, wallpaper, widgets and settings untouched.

## Gokko 0.3.0-rc1: Niri release tuning

- Spotlight: immediate text editing, 65ms result coalescing; report searches >40ms.
- Spotlight: stop continuous source/blur updates when Niri's captured image is frozen; refresh once on opening.
- Control Center: reduce two-pass preblur for legible refraction and improve glass rim/opacity on Niri tile mode.
- Preserve Game Mode's existing GPU-saving fallback, including animated wallpaper tradeoffs.
- No Dock, icon-resolution, wallpaper, settings, or non-Niri rendering code changes.

## Gokko 0.3.0-rc2: Spotlight responsiveness

- Only construct Applications results while the Apps panel is actually open.
- Limit active Apps search to the top 48 matches to avoid hundreds of icon delegates on short queries.
- Keep existing Home search debounce and Niri glass unchanged.
- Log QML main-thread stalls over 450ms as `[gokko-spotlight] UI event-loop stall`.
- No changes to Control Center, Dock, wallpapers, widgets, icons, or Game Mode.
