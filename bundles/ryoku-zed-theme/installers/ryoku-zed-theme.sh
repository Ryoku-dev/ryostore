#!/bin/bash
# SPDX-License-Identifier: MIT
# Reviewed source is mirrored in runtime/ and embedded here because Ryostore
# caches only the installer script before execution.
set -euo pipefail
version=1.0.0
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
source_dir="$data_home/ryoku/zed-theme"
marker="$source_dir/.ryostore-owned"
command_marker="$source_dir/.ryostore-command-owned"
command_path="$HOME/.local/bin/ryoku-zed-theme-sync-installed"
command -v bun >/dev/null || { echo "ryoku-zed-theme: install Bun first" >&2; exit 1; }
command -v systemctl >/dev/null || { echo "ryoku-zed-theme: systemctl is required" >&2; exit 1; }
if [[ -e "$source_dir" && ! -f "$marker" ]]; then echo "ryoku-zed-theme: refusing to overwrite unowned path: $source_dir" >&2; exit 1; fi
if [[ -e "$command_path" && ! -f "$command_marker" ]]; then echo "ryoku-zed-theme: refusing to overwrite unowned command: $command_path" >&2; exit 1; fi
install -d "$source_dir/scripts" "$source_dir/themes"
cat > "$source_dir/scripts/theme.ts" <<'RYOKU_THEME_TS'
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";

type Json = Record<string, any>;
const home = homedir();
const args = new Set(Bun.argv.slice(2));
const mode = args.has("--bootstrap") ? "bootstrap" : args.has("--verify-monochrome") ? "verify-monochrome" : "sync";
const root = resolve(import.meta.dir, "..");
const checkedIn = join(root, "themes", "ryoku.json");
const sourcePath = process.env.RYOKU_ZED_SOURCE ?? join(home, ".config/zed/themes/matugen.json");
const outputPath = process.env.RYOKU_ZED_OUTPUT ?? join(home, ".config/zed/themes/ryoku-dynamic.json");

const hex = (value: unknown): [number, number, number] | null => {
  if (typeof value !== "string") return null;
  const match = value.match(/^#?([\da-f]{6})(?:[\da-f]{2})?$/i);
  if (!match) return null;
  return [0, 2, 4].map((i) => Number.parseInt(match[1].slice(i, i + 2), 16)) as [number, number, number];
};
const luminance = (c: [number, number, number]) => {
  const linear = c.map((n) => {
    const v = n / 255;
    return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2];
};
const contrast = (a: string, b: string) => {
  const ca = hex(a), cb = hex(b);
  if (!ca || !cb) return null;
  const [hi, lo] = [luminance(ca), luminance(cb)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
};
type Oklch = { l: number; c: number; h: number };
const RYOKU_VIOLET_FALLBACK_HUE = 295;
const toLinear = (n: number) => {
  const v = n / 255;
  return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
};
const fromLinear = (n: number) => {
  const v = n <= 0.0031308 ? 12.92 * n : 1.055 * n ** (1 / 2.4) - 0.055;
  return Math.round(Math.max(0, Math.min(1, v)) * 255);
};

function toOklch(color: string): Oklch | null {
  const rgb = hex(color);
  if (!rgb) return null;
  const [r, g, b] = rgb.map(toLinear);
  const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  const L = 0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s;
  const a = 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s;
  const bb = 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s;
  return { l: L, c: Math.hypot(a, bb), h: ((Math.atan2(bb, a) * 180 / Math.PI) + 360) % 360 };
}

function fromOklch({ l: L, c: requestedC, h }: Oklch): string {
  const radians = h * Math.PI / 180;
  let low = 0, high = requestedC;
  let channels = [0, 0, 0];
  for (let attempt = 0; attempt < 24; attempt++) {
    const c = attempt === 0 ? requestedC : (low + high) / 2;
    const ca = c * Math.cos(radians), cb = c * Math.sin(radians);
    const l = (L + 0.3963377774 * ca + 0.2158037573 * cb) ** 3;
    const m = (L - 0.1055613458 * ca - 0.0638541728 * cb) ** 3;
    const s = (L - 0.0894841775 * ca - 1.291485548 * cb) ** 3;
    const linear = [
      4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
      -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s,
    ];
    if (linear.every((v) => v >= -1e-7 && v <= 1.0000001)) {
      channels = linear.map(fromLinear);
      low = c;
    } else {
      high = c;
    }
  }
  return `#${channels.map((v) => v.toString(16).padStart(2, "0")).join("")}`;
}

function makeReadable(color: string, background: string, minimum = 4.5): string {
  if ((contrast(color, background) ?? Infinity) >= minimum) return color;
  const bg = hex(background), fg = toOklch(color);
  if (!bg || !fg) return color;
  const brighten = luminance(bg) < 0.45;
  let low = brighten ? fg.l : 0, high = brighten ? 1 : fg.l;
  for (let i = 0; i < 24; i++) {
    const mid = (low + high) / 2;
    const candidate = fromOklch({ ...fg, l: mid });
    if ((contrast(candidate, background) ?? 0) >= minimum) {
      if (brighten) high = mid;
      else low = mid;
    } else if (brighten) low = mid;
    else high = mid;
  }
  return fromOklch({ ...fg, l: brighten ? high : low });
}

const syntaxHueOffsets: Record<string, number> = {
  "string.special.symbol": 40,
  "string.special": 35,
  "string.escape": 20,
  "string.regex": 50,
  "punctuation.special": 320,
  "variable.special": 0,
  "text.literal": 40,
  "emphasis.strong": 0,
  "constructor": 280,
  "boolean": 160,
  "constant": 120,
  "function": 0,
  "keyword": 200,
  "number": 80,
  "operator": 320,
  "string": 40,
  "tag": 240,
  "type": 240,
  "attribute": 240,
  "emphasis": 0,
};
const syntaxHueRules = Object.entries(syntaxHueOffsets).sort(([a], [b]) => b.length - a.length);

function distributeSyntax(style: Json) {
  const primary = style.syntax?.function?.color ?? style.accents?.[0];
  const sourceAnchor = typeof primary === "string" ? toOklch(primary) : null;
  if (!sourceAnchor) return;
  const monochrome = sourceAnchor.c < 0.025;
  const anchorHue = monochrome ? RYOKU_VIOLET_FALLBACK_HUE : sourceAnchor.h;
  const chromaFloor = monochrome ? 0.105 : Math.max(0.065, sourceAnchor.c * 1.15);
  const scopes = Object.entries(style.syntax ?? {}) as [string, Json][];
  for (const [scope, value] of scopes) {
    if (!value || typeof value.color !== "string") continue;
    const rule = syntaxHueRules.find(([prefix]) => scope === prefix || scope.startsWith(`${prefix}.`));
    if (!rule) continue;
    const source = toOklch(value.color);
    if (!source) continue;
    const chroma = Math.min(0.12, Math.max(source.c, chromaFloor));
    value.color = fromOklch({ l: source.l, c: chroma, h: (anchorHue + rule[1] + 360) % 360 });
  }
}

function improve(theme: Json) {
  const style = theme.style as Json;
  const bg = style["editor.background"] ?? style.background;
  if (!hex(bg)) throw new Error(`${theme.name}: missing hex editor background`);
  distributeSyntax(style);

  const uiTextKeys = [
    "text", "text.muted", "text.placeholder", "text.disabled", "text.accent",
    "icon", "icon.muted", "icon.placeholder", "icon.disabled", "icon.accent",
    "editor.foreground", "editor.line_number", "editor.active_line_number",
    "terminal.foreground", "terminal.bright_foreground", "terminal.dim_foreground",
  ];
  const uiRatios: number[] = [];
  for (const key of uiTextKeys) {
    if (!style[key]) continue;
    const surface = key.startsWith("editor.") ? style["editor.background"] :
      key.startsWith("terminal.") ? style["terminal.background"] ?? bg : style.background ?? bg;
    style[key] = makeReadable(style[key], surface);
    const ratio = contrast(style[key], surface);
    if (ratio !== null) uiRatios.push(ratio);
  }
  for (const key of Object.keys(style).filter((name) => name.startsWith("terminal.ansi."))) {
    const surface = style["terminal.background"] ?? bg;
    style[key] = makeReadable(style[key], surface);
    const ratio = contrast(style[key], surface);
    if (ratio !== null) uiRatios.push(ratio);
  }
  for (const key of ["error", "warning", "success", "info", "hint", "created", "modified", "deleted"]) {
    if (!style[key]) continue;
    const surface = style[`${key}.background`] ?? bg;
    style[key] = makeReadable(style[key], surface);
    const ratio = contrast(style[key], surface);
    if (ratio !== null) uiRatios.push(ratio);
  }

  // Syntax tokens share the opaque editor surface, so enforce WCAG AA contrast.
  for (const [scope, value] of Object.entries(style.syntax ?? {}) as [string, Json][]) {
    if (value && typeof value.color === "string") value.color = makeReadable(value.color, bg);
  }

  const ratios = Object.entries(style.syntax ?? {})
    .map(([scope, value]: [string, any]) => [scope, contrast(value?.color, bg)] as const)
    .filter((entry): entry is readonly [string, number] => typeof entry[1] === "number");
  const min = Math.min(...ratios.map(([, ratio]) => ratio));
  if (min < 4.49) throw new Error(`${theme.name}: syntax contrast floor is ${min.toFixed(2)}:1`);
  const uiMin = Math.min(...uiRatios);
  if (uiMin < 4.49) throw new Error(`${theme.name}: UI text contrast floor is ${uiMin.toFixed(2)}:1`);
  const syntaxSamples: Record<string, string> = {};
  for (const scope of ["keyword", "function", "type", "constructor", "string", "number", "constant", "boolean", "operator", "variable.special"]) {
    const color = style.syntax?.[scope]?.color;
    if (typeof color === "string") syntaxSamples[scope] = color;
  }
  return { min, count: ratios.length, uiMin, uiCount: uiRatios.length, syntaxSamples };
}

async function readJson(path: string): Promise<Json> {
  try { return JSON.parse(await readFile(path, "utf8")); }
  catch (error) { throw new Error(`Cannot read ${path}: ${error instanceof Error ? error.message : error}`); }
}

function syntheticMonochromeVariants(fallback: Json): Json[] {
  return (fallback.themes as Json[]).map((original) => {
    const theme = structuredClone(original);
    const dark = theme.appearance === "dark";
    const surface = dark ? "#1b1b1b" : "#fafafa";
    const ink = dark ? "#dedede" : "#393939";
    theme.name = `Monochrome ${dark ? "Dark" : "Light"}`;
    const style = theme.style as Json;
    style.background = surface;
    style["editor.background"] = surface;
    style["editor.gutter.background"] = surface;
    style["terminal.background"] = surface;
    style["editor.foreground"] = ink;
    style.accents = ["#888888", "#999999", "#777777"];
    style.syntax = Object.fromEntries(Object.entries(style.syntax ?? {}).map(([scope, value]) => [
      scope, { ...(value as Json), color: ink },
    ]));
    return theme;
  });
}

function checkHueSeparation(theme: Json) {
  const style = theme.style as Json;
  const categories = ["function", "string", "number", "constant", "boolean", "keyword", "type", "constructor", "operator"];
  const hues = categories.map((scope) => {
    const color = style.syntax?.[scope]?.color;
    const value = typeof color === "string" ? toOklch(color) : null;
    if (!value || value.c < 0.04) throw new Error(`${theme.name}: ${scope} remained visually achromatic (${color}).`);
    return value.h;
  }).sort((a, b) => a - b);
  const distances = hues.map((h, i) => (hues[(i + 1) % hues.length] - h + 360) % 360);
  const minimum = Math.min(...distances);
  if (minimum < 32) throw new Error(`${theme.name}: adjacent syntax accent hues are only ${minimum.toFixed(1)}° apart.`);
  return minimum;
}

let family: Json;
if (mode === "bootstrap") {
  family = await readJson(checkedIn);
} else if (mode === "verify-monochrome") {
  const fallback = await readJson(checkedIn);
  family = { ...fallback, themes: syntheticMonochromeVariants(fallback) };
} else {
  family = await readJson(sourcePath);
  if (!Array.isArray(family.themes) || !family.themes.some((t: Json) => t.appearance === "dark") ||
      !family.themes.some((t: Json) => t.appearance === "light"))
    throw new Error(`Expected a Ryoku Matugen theme family with dark and light variants: ${sourcePath}`);
  family.name = "Ryoku Dynamic";
  family.author = "Ryoku";
  family.themes = family.themes.map((theme: Json) => ({
    ...theme,
    name: `Ryoku Dynamic ${theme.appearance === "light" ? "Light" : "Dark"}`,
  }));
  family.$schema = "https://zed.dev/schema/themes/v0.2.0.json";
}

let report = "";
for (const theme of family.themes as Json[]) {
  const { min, count, uiMin, uiCount, syntaxSamples } = improve(theme);
  const hueGap = mode === "verify-monochrome" ? checkHueSeparation(theme) : undefined;
  const colors = Object.entries(syntaxSamples).map(([scope, color]) => `${scope}=${color}`).join(" ");
  report += `${theme.name}: syntax ${min.toFixed(2)}:1 (${count} scopes); UI text ${uiMin.toFixed(2)}:1 (${uiCount} colors)`;
  if (hueGap !== undefined) report += `; nearest semantic hue gap ${hueGap.toFixed(1)}°`;
  report += `\n  ${colors}\n`;
}

if (mode === "bootstrap") {
  await writeFile(checkedIn, `${JSON.stringify(family, null, 2)}\n`);
  console.log(`Wrote checked-in fallback theme: ${checkedIn}\n${report.trim()}`);
} else if (mode === "verify-monochrome") {
  console.log(`Synthetic monochrome dark/light validation passed.\n${report.trim()}`);
} else {
  await mkdir(dirname(outputPath), { recursive: true });
  await writeFile(outputPath, `${JSON.stringify(family, null, 2)}\n`);
  console.log(`Wrote ${outputPath}\n${report.trim()}`);
}
RYOKU_THEME_TS
cat > "$source_dir/scripts/install-sync.ts" <<'RYOKU_INSTALL_SYNC_TS'
import { copyFile, mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { constants } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";

const home = homedir();
const root = resolve(import.meta.dir, "..");
const systemd = join(home, ".config/systemd/user");
const serviceName = "ryoku-zed-theme-sync.service";
const pathName = "ryoku-zed-theme-sync.path";
const bun = process.execPath;
const initialSync = Bun.spawn([bun, "run", "theme:sync"], { cwd: root, stdout: "inherit", stderr: "inherit" });
const initialSyncCode = await initialSync.exited;
if (initialSyncCode !== 0) throw new Error(`Initial theme sync exited with ${initialSyncCode}; no watcher was installed.`);
await mkdir(systemd, { recursive: true });
const service = `[Unit]\nDescription=Sync the Ryoku palette into a Zed theme\n\n[Service]\nType=oneshot\nWorkingDirectory=${root}\nExecStart=${bun} run theme:sync\n`;
const path = `[Unit]\nDescription=Watch Ryoku's generated Zed Matugen theme\n\n[Path]\nPathChanged=${home}/.config/zed/themes/matugen.json\nUnit=${serviceName}\n\n[Install]\nWantedBy=default.target\n`;
const missing: Array<[string, string]> = [];
for (const [name, content] of [[serviceName, service], [pathName, path]] as const) {
  const destination = join(systemd, name);
  try {
    const current = await readFile(destination, "utf8");
    if (current !== content) throw new Error(`${destination} already exists with different content; move it aside before installing this watcher.`);
  } catch (error) {
    if (error instanceof Error && !("code" in error && error.code === "ENOENT")) throw error;
    missing.push([destination, content]);
  }
}
for (const [destination, content] of missing) await writeFile(destination, content, { flag: "wx" });

const reload = Bun.spawn(["systemctl", "--user", "daemon-reload"], { stdout: "inherit", stderr: "inherit" });
const reloadCode = await reload.exited;
if (reloadCode !== 0) throw new Error(`systemctl daemon-reload exited with ${reloadCode}`);
const proc = Bun.spawn(["systemctl", "--user", "enable", "--now", pathName], { stdout: "inherit", stderr: "inherit" });
const code = await proc.exited;
if (code !== 0) throw new Error(`systemctl exited with ${code}`);

const settings = join(home, ".config/zed/settings.json");
const currentSettings = await readFile(settings, "utf8");
const themeField = /^([\t ]*"theme"[\t ]*:[\t ]*)"(?:[^"\\]|\\.)*"([\t ]*,?)[\t ]*$/gm;
const matches = [...currentSettings.matchAll(themeField)];
if (matches.length !== 1) throw new Error(`Expected one string-valued theme setting in ${settings}; left it unchanged.`);
const selectedSettings = currentSettings.replace(themeField, `$1"Ryoku Dynamic Dark"$2`);
if (selectedSettings !== currentSettings) {
  const backup = `${settings}.ryoku-backup-${Date.now()}`;
  await copyFile(settings, backup, constants.COPYFILE_EXCL);
  const temp = `${settings}.ryoku-tmp-${Date.now()}`;
  await writeFile(temp, selectedSettings, { mode: 0o600, flag: "wx" });
  await rename(temp, settings);
  console.log(`Selected Ryoku Dynamic Dark in ${settings}; preserved the original as ${backup}.`);
} else {
  console.log(`Ryoku Dynamic Dark is already selected in ${settings}; left settings unchanged.`);
}
console.log("Installed the optional palette watcher. It writes ryoku-dynamic.json beside matugen.json and leaves Matugen untouched.");
RYOKU_INSTALL_SYNC_TS
cat > "$source_dir/themes/ryoku.json" <<'RYOKU_THEME_JSON'
{
  "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
  "name": "Ryoku",
  "author": "Ryoku contributors",
  "themes": [
    {
      "name": "Ryoku Dark",
      "appearance": "dark",
      "style": {
        "accents": [
          "#d8b9ff",
          "#cfc2e8",
          "#f4b8c2"
        ],
        "background": "#151218",
        "border": "#4a454e",
        "border.focused": "#d8b9ff",
        "border.selected": "#d8b9ff",
        "border.variant": "#958e98",
        "elevated_surface.background": "#2b2730",
        "surface.background": "#151218",
        "element.background": "#221e26",
        "element.hover": "#302b34",
        "element.active": "#39343d",
        "element.selected": "#49365e",
        "text": "#eee7f2",
        "text.muted": "#c8bfcc",
        "text.placeholder": "#a79daa",
        "text.disabled": "#827b87",
        "text.accent": "#e2c8ff",
        "icon": "#eee7f2",
        "icon.muted": "#c8bfcc",
        "icon.accent": "#e2c8ff",
        "status_bar.background": "#1e1a22",
        "title_bar.background": "#1e1a22",
        "toolbar.background": "#1e1a22",
        "tab_bar.background": "#221e26",
        "tab.active_background": "#302b34",
        "tab.inactive_background": "#1e1a22",
        "panel.background": "#1e1a22",
        "panel.focused_border": "#d8b9ff",
        "pane.focused_border": "#d8b9ff",
        "editor.background": "#1e1a22",
        "editor.foreground": "#eee7f2",
        "editor.gutter.background": "#1e1a22",
        "editor.line_number": "#b0a7b4",
        "editor.active_line_number": "#e2c8ff",
        "editor.active_line.background": "#302b3480",
        "editor.indent_guide": "#554e5c",
        "editor.indent_guide_active": "#a79daa",
        "editor.document_highlight.read_background": "#49365e80",
        "editor.document_highlight.write_background": "#4d405e80",
        "terminal.background": "#1e1a22",
        "terminal.foreground": "#eee7f2",
        "terminal.ansi.black": "#848286",
        "terminal.ansi.red": "#ffb4ab",
        "terminal.ansi.green": "#b8d9ad",
        "terminal.ansi.yellow": "#f1ca89",
        "terminal.ansi.blue": "#d8b9ff",
        "terminal.ansi.magenta": "#cfc2e8",
        "terminal.ansi.cyan": "#a9d4d4",
        "terminal.ansi.white": "#eee7f2",
        "terminal.ansi.bright_black": "#868289",
        "terminal.ansi.bright_red": "#ffb4ab",
        "terminal.ansi.bright_green": "#b8d9ad",
        "terminal.ansi.bright_yellow": "#f1ca89",
        "terminal.ansi.bright_blue": "#e2c8ff",
        "terminal.ansi.bright_magenta": "#ded0f5",
        "terminal.ansi.bright_cyan": "#c0e6e5",
        "terminal.ansi.bright_white": "#ffffff",
        "error": "#ffb4ab",
        "error.background": "#5d171b",
        "warning": "#f1ca89",
        "success": "#b8d9ad",
        "info": "#b9d5ff",
        "hint": "#e2c8ff",
        "created": "#b8d9ad",
        "modified": "#e2c8ff",
        "deleted": "#ffb4ab",
        "syntax": {
          "attribute": {
            "color": "#6eeede"
          },
          "boolean": {
            "color": "#dcd577"
          },
          "comment": {
            "color": "#bdb4c2",
            "font_style": "italic"
          },
          "constant": {
            "color": "#ffc38a"
          },
          "constructor": {
            "color": "#71d9ff"
          },
          "function": {
            "color": "#d8b9ff"
          },
          "keyword": {
            "color": "#99de9a"
          },
          "number": {
            "color": "#ffceca"
          },
          "operator": {
            "color": "#b6ceff"
          },
          "property": {
            "color": "#eee7f2"
          },
          "punctuation": {
            "color": "#c8bfcc"
          },
          "string": {
            "color": "#ffacdc"
          },
          "string.escape": {
            "color": "#fcc7ff"
          },
          "tag": {
            "color": "#61e3d3"
          },
          "type": {
            "color": "#6eeede"
          },
          "variable": {
            "color": "#eee7f2"
          },
          "variable.special": {
            "color": "#d8b9ff"
          }
        }
      }
    },
    {
      "name": "Ryoku Light",
      "appearance": "light",
      "style": {
        "accents": [
          "#68458b",
          "#625476",
          "#8b4551"
        ],
        "background": "#f8f5fa",
        "border": "#79717f",
        "border.focused": "#68458b",
        "border.selected": "#68458b",
        "border.variant": "#a39aa9",
        "elevated_surface.background": "#ffffff",
        "surface.background": "#f8f5fa",
        "element.background": "#efebf2",
        "element.hover": "#e8e2ec",
        "element.active": "#ded7e4",
        "element.selected": "#e9ddf6",
        "text": "#211d25",
        "text.muted": "#514956",
        "text.placeholder": "#625a67",
        "text.disabled": "#766e7c",
        "text.accent": "#593776",
        "icon": "#211d25",
        "icon.muted": "#514956",
        "icon.accent": "#593776",
        "status_bar.background": "#f0ecf3",
        "title_bar.background": "#f0ecf3",
        "toolbar.background": "#f0ecf3",
        "tab_bar.background": "#efebf2",
        "tab.active_background": "#ffffff",
        "tab.inactive_background": "#efebf2",
        "panel.background": "#f0ecf3",
        "panel.focused_border": "#68458b",
        "pane.focused_border": "#68458b",
        "editor.background": "#ffffff",
        "editor.foreground": "#211d25",
        "editor.gutter.background": "#ffffff",
        "editor.line_number": "#625a67",
        "editor.active_line_number": "#593776",
        "editor.active_line.background": "#e9ddf680",
        "editor.indent_guide": "#d0c8d5",
        "editor.indent_guide_active": "#79717f",
        "editor.document_highlight.read_background": "#e9ddf6",
        "editor.document_highlight.write_background": "#f3dfe3",
        "terminal.background": "#ffffff",
        "terminal.foreground": "#211d25",
        "terminal.ansi.black": "#211d25",
        "terminal.ansi.red": "#8b2632",
        "terminal.ansi.green": "#315a2a",
        "terminal.ansi.yellow": "#674b00",
        "terminal.ansi.blue": "#593776",
        "terminal.ansi.magenta": "#625476",
        "terminal.ansi.cyan": "#205b60",
        "terminal.ansi.white": "#787679",
        "terminal.ansi.bright_black": "#514956",
        "terminal.ansi.bright_red": "#7f1d29",
        "terminal.ansi.bright_green": "#294e22",
        "terminal.ansi.bright_yellow": "#5c4100",
        "terminal.ansi.bright_blue": "#4f2e6c",
        "terminal.ansi.bright_magenta": "#584a6c",
        "terminal.ansi.bright_cyan": "#1b5055",
        "terminal.ansi.bright_white": "#767676",
        "error": "#8b2632",
        "error.background": "#ffdad6",
        "warning": "#674b00",
        "success": "#315a2a",
        "info": "#264d78",
        "hint": "#593776",
        "created": "#315a2a",
        "modified": "#593776",
        "deleted": "#8b2632",
        "syntax": {
          "attribute": {
            "color": "#005550"
          },
          "boolean": {
            "color": "#565300"
          },
          "comment": {
            "color": "#514956",
            "font_style": "italic"
          },
          "constant": {
            "color": "#734400"
          },
          "constructor": {
            "color": "#006583"
          },
          "function": {
            "color": "#5b347b"
          },
          "keyword": {
            "color": "#1f6d30"
          },
          "number": {
            "color": "#89332c"
          },
          "operator": {
            "color": "#2f478d"
          },
          "property": {
            "color": "#211d25"
          },
          "punctuation": {
            "color": "#514956"
          },
          "string": {
            "color": "#8d3e6b"
          },
          "string.escape": {
            "color": "#753775"
          },
          "tag": {
            "color": "#006d66"
          },
          "type": {
            "color": "#005550"
          },
          "variable": {
            "color": "#211d25"
          },
          "variable.special": {
            "color": "#5b347b"
          }
        }
      }
    }
  ]
}
RYOKU_THEME_JSON
cat > "$source_dir/extension.toml" <<'RYOKU_EXTENSION_TOML'
id = "ryoku-zed-theme"
name = "Ryoku"
version = "0.1.0"
schema_version = 1
authors = ["Ryoku contributors"]
description = "A high-contrast Zed theme in Ryoku's Material You palette."
RYOKU_EXTENSION_TOML
cat > "$source_dir/package.json" <<'RYOKU_PACKAGE_JSON'
{
  "name": "ryoku-zed-theme",
  "private": true,
  "type": "module",
  "scripts": {
    "theme:bootstrap": "bun scripts/theme.ts --bootstrap",
    "theme:verify-monochrome": "bun scripts/theme.ts --verify-monochrome",
    "theme:sync": "bun scripts/theme.ts --sync",
    "install:sync": "bun scripts/install-sync.ts"
  }
}
RYOKU_PACKAGE_JSON
printf '%s\n' "$version" > "$marker"
cd "$source_dir"
bun scripts/install-sync.ts
install -d "$HOME/.local/bin"
cat > "$command_path" <<'RYOKU_COMMAND'
#!/bin/bash
exec bun "${XDG_DATA_HOME:-$HOME/.local/share}/ryoku/zed-theme/scripts/theme.ts" --sync "$@"
RYOKU_COMMAND
chmod 0755 "$command_path"
printf '%s\n' "$version" > "$command_marker"
echo "ryoku-zed-theme: installed; choose Ryoku Dynamic Dark or Light in Zed"
