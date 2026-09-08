# Provenance and licensing determination

This file records the upstream provenance evidence behind the plugin's license
(`GPL-3.0-only AND MIT`, conveyed as a whole under GPL-3.0). See `LICENSE`
(canonical GPL-3.0) and `NOTICE` (attribution + the contributor's MIT sub-grant).

## Summary

The submission originally declared `MIT` with author `Antigravity`. Review of the
vendored QML UI components found they are **derived from GPL-3.0 upstream code**,
which makes an MIT-only declaration incorrect for the redistributed whole. The
license was corrected to a grounded composite and the author was corrected to the
actual PR contributor.

## Evidence

### 1. The target shell is GPL-3.0
`/home/nero/Work/ryoku-arch/LICENSE` is the verbatim GNU GPL v3
(sha256 `3972dc97…b36986`). The plugin is styled for and ships against the Ryoku
shell, which is GPL-3.0.

### 2. The UI widgets are derived from end-4/dots-hyprland ("illogical-impulse")
Upstream repository: <https://github.com/end-4/dots-hyprland> — LICENSE is GNU
GPL v3. Widgets live under
`dots/.config/quickshell/ii/modules/common/widgets/`.

Direct source comparison (upstream `main` vs. this plugin's `content/`):

- **RippleButton.qml** — upstream exposes the exact, distinctive action API this
  plugin reuses: `downAction` / `releaseAction` / `altAction` /
  `middleClickAction`, plus `toggled`, `buttonText`, `buttonRadius` /
  `buttonRadiusPressed`, `rippleEnabled`, `pointingHandCursor`, and the
  `colBackground` / `colBackgroundHover` / `colBackgroundToggled` /
  `colBackgroundToggledHover` / `colRipple` / `colRippleToggled` colour set. The
  plugin copy adapts these (simplified internals, added `*Action` variants) — a
  derivative work, not an independent implementation.
- **MaterialSymbol.qml** — upstream and plugin share the same distinctive font
  construction: `renderType: Text.NativeRendering`,
  `font.hintingPreference: Font.PreferNoHinting`, family "Material Symbols
  Rounded", and `variableAxes` keyed on `FILL` + `opsz` driven by `iconSize`.
- Additional sibling widgets present upstream under the same `common/widgets/`
  directory and reused here: `GroupButton`, `MaterialShape`,
  `MaterialLoadingIndicator`, `StyledText`, `StyledFlickable`, `StyledListView`,
  `StyledScrollBar`, `StyledSwitch`, `StyledToolTip`,
  `FolderListModelWithHistory`, and the `Appearance` token singleton structure.

Note: the current Ryoku shell renames some of these (e.g. `MaterialIcon` rather
than `MaterialSymbol`, a `Theme` singleton rather than `Appearance`), so this
plugin vendored from the upstream illogical-impulse naming, confirming the
derivation path.

### 3. Contributor-original portions
The Gmail-specific work — the Python helpers under `bin/` and the `Email*`,
`AddressBar`, `RyokuDecor`, `Config`, `Directories`, `Translation`, `FileUtils`,
`Widget`, and `Main` QML files — is original to the contributor and carries the
MIT sub-grant in `NOTICE`.

## Determination

Under GPL-3.0 §5, combining GPL-3.0 components with other code into a single
program licenses the combined work as a whole under GPL-3.0. MIT is
GPL-compatible, so the contributor's original files may also be offered under MIT
in isolation, but the distributed plugin as a whole is GPL-3.0.

- SPDX (package): `GPL-3.0-only AND MIT`
- Effective redistribution license of the whole: **GPL-3.0-only**
- `LICENSE`: canonical GPL-3.0 text
- `NOTICE`: upstream GPL attribution + the contributor's MIT notice

## Author

Corrected from `Antigravity` to the actual PR #10 contributor:
**Yash Parmar** (GitHub `Zatch07`). GitHub exposes no public email for this
account, so the public contact used is the profile URL
<https://github.com/Zatch07> (no email was invented).
