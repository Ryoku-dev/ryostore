# Validation — Keymoji 0.3.1

19 Bun tests passed: catalogue integrity and complete sequences; accent-insensitive and bilingual/multi-term search; Unicode/exact emoji/typo ranking; favorites/recents; insertion target and input validation; named/wallpaper/fallback palette precedence; Bézier overshoot, inherited timings, reduce-motion and low-power behavior; grid columns, boundaries, partial rows and paging.

Qt rendered the interface at 528×590 and 320×480. The preview shows the active Ryoku palette. UI components use local Tabler SVGs with no icon-font download.

Live Ryoku/Wayland checks exercised automatic search focus, theme/motion resolution and dismissal. Three source cycles and three installed-package cycles confirmed search focus on open, empty input region and released search focus immediately on hide, and no mapped/backing surface after the exit animation. This specifically covers the invisible-layer regression fixed in 0.2.1.

Native synthetic-key checks exercised arrows, column-aware vertical movement, PageDown scrolling, Home/End, search editing, filtered results and dismissal from source. The installed 0.3.0 passed the arrow/paging sequence; later automation stopped through its focus guard during live interaction. Synthetic keyboards can collide with desktop Escape mappings through temporary keymaps, so reserve/release Escape when reproducing with wtype. Never inject test text without confirming Keymoji search owns focus.

Remaining manual interoperability matrix: insertion at a caret/selection in Qt/GTK editors, terminals, Firefox, Chromium/Electron, contenteditable and XWayland; multi-monitor placement and scale changes. This submission does not claim universal client acceptance of virtual-keyboard Unicode. Password fields and lock screens are unsupported.

The local Go-based plugin validator reports config-write for the literal shell.json path in Theme.qml. That FileView only reads and watches palette changes; it has no adapter, write method or external process. This is documented for explicit review; no scanner or exception-policy changes are included in the PR.

Motion follows persisted assignments: 1 speed unit is 100 ms. The curve editor's fixed 640 ms preview is not the per-animation duration. Custom Bézier y values above 1 are retained while opacity is clamped to 0..1. Desktop files are never modified by the keyboard.

## Native motion ownership

Opening and closing are now entirely compositor-owned: no QML reveal animation, fixed 24 px offset or duplicate fade is added. Closing immediately releases input and unmaps the client; the compositor owns its exit snapshot. Internal transitions load the effective registry through ryoku-hub desktop defaults at open and watched configuration changes, with no polling. Effective defaults can contain inherited leaf/fade assignments and named curves absent from desktop.json. The parser exposes geometry and layer fade channels separately.

Live checks distinguished layers=400 ms/ryokuRiceEase from fadeLayersIn/Out=700 ms/easeOutQuint in this session, and verified source=effective. Three native source cycles and installed-package cycles checked search focus and removal of pointer capture. The new unit regression verifies live registry precedence and the separate inherited fade channels. No compositor configuration was changed to force an animation.
