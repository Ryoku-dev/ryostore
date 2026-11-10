# Validation — Keymoji 0.4.0

25 Bun tests passed: catalogue integrity and complete sequences; accent-insensitive and bilingual/multi-term search; Unicode/exact emoji/typo ranking; favorites/recents; insertion target and input validation; named/wallpaper/fallback palette precedence; Bézier overshoot, inherited timings, reduce-motion and low-power behavior; grid columns, boundaries, partial rows and paging.

Qt rendered the interface at 528×590 and 320×480. The preview shows the active Ryoku palette. UI components use local Tabler SVGs with no icon-font download.

Live Ryoku/Wayland checks exercised automatic search focus, theme/motion resolution and dismissal. Three source cycles and three installed-package cycles confirmed search focus on open, empty input region and released search focus immediately on hide, and no mapped/backing surface after the exit animation. This specifically covers the invisible-layer regression fixed in 0.2.1.

Native synthetic-key checks exercised arrows, column-aware vertical movement, PageDown scrolling, Home/End, search editing, filtered results and dismissal from source. The installed 0.3.0 passed the arrow/paging sequence; later automation stopped through its focus guard during live interaction. Synthetic keyboards can collide with desktop Escape mappings through temporary keymaps, so reserve/release Escape when reproducing with wtype. Never inject test text without confirming Keymoji search owns focus.

Remaining manual interoperability matrix: insertion at a caret/selection in Qt/GTK editors, terminals, Firefox, Chromium/Electron, contenteditable and XWayland; multi-monitor placement and scale changes. This submission does not claim universal client acceptance of virtual-keyboard Unicode. Password fields and lock screens are unsupported.

The local Go-based plugin validator reports config-write for the literal shell.json path in Theme.qml. That FileView only reads and watches palette changes; it has no adapter, write method or external process. This is documented for explicit review; no scanner or exception-policy changes are included in the PR.

Motion follows persisted assignments: 1 speed unit is 100 ms. The curve editor's fixed 640 ms preview is not the per-animation duration. Custom Bézier y values above 1 are retained while opacity is clamped to 0..1. Desktop files are never modified by the keyboard.

## Native motion ownership

Opening and closing are now entirely compositor-owned: no QML reveal animation, fixed 24 px offset or duplicate fade is added. Closing immediately releases input and unmaps the client; the compositor owns its exit snapshot. Internal transitions load the effective registry through ryoku-hub desktop defaults at open and watched configuration changes, with no polling. Effective defaults can contain inherited leaf/fade assignments and named curves absent from desktop.json. The parser exposes geometry and layer fade channels separately.

Live checks distinguished layers=400 ms/ryokuRiceEase from fadeLayersIn/Out=700 ms/easeOutQuint in this session, and verified source=effective. Three native source cycles and installed-package cycles checked search focus and removal of pointer capture. The new unit regression verifies live registry precedence and the separate inherited fade channels. No compositor configuration was changed to force an animation.

## Internationalization

25 unit tests also cover language precedence, POSIX/Qt locale normalization, English fallback, message-key and placeholder completeness, four CLDR dictionaries covering every sequence, localized ranking and accent/ligature folding. Native checks switched PT/EN/ES/FR, matched displayed emoji names to CLDR, verified override persistence across restart, restored Auto, and confirmed dismissal still removes input capture. An isolated test state directory kept the user preference unchanged. The compact French UI was rendered at 320×480; the standard preview shows Auto/PT under Ryoku.

The shell.json language reference in Localization.qml is read-only, like the palette lookup in Theme.qml. The standalone preference writer uses only stateDir/settings.json. Both read-only host references are disclosed for static-screen review; no policy exception is added by this contribution.

## Last-emoji paste and repeat

The Obsidian-specific pointer-only-opening change was reverted. The separate insert-last command uses a resident, windowless service: wl-copy followed by Ctrl+V, with target guards and a bounded, serialized repeat queue. The user shortcut is Super+Shift+period with compositor key repeat.

29 Bun tests passed. A disposable input in the running Obsidian received five complete emoji through the installed service, retained document focus, and recorded zero field blur events. The first cold invocation took 279 ms including launcher/service startup; four warm invocations took 174 ms total; the last service copy/paste operation took 11 ms. Synthetic wtype modifier chords did not reproduce the physical shortcut (they typed periods), so holding the physical chord is configured and its live bind is verified, but is not claimed as a successful synthetic chord test.

### Held-modifier paste correction

The user reported that the live shortcut reached the service but did not paste: 34 backend completions were not proof of application insertion. Added an optional external paste helper; the local user configuration selects a helper that sends Ctrl+V through the compositor instead of a virtual keyboard. Five sequential helper-backed pastes into the disposable Obsidian input preserved complete Unicode and focus; measured backend latency was 7 ms on the last request. The user then explicitly confirmed the physical shortcut works in the intended field. Compositor integration lives solely in user-owned local configuration/helper files.
