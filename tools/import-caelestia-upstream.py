#!/usr/bin/env python3

import argparse
import os
from pathlib import Path
import re
import subprocess

REVISION = "b51fdb35ca7a14ac5a49e0d94fc5de2d79756aed"
ROOTS = ("modules", "services", "components", "config", "utils")
EXCLUDED = ("modules/areapicker/", "modules/background/", "modules/lock/")
SEAM_FILES = {"components/misc/FocusGrab.qml"}
MODULES = {
    "Caelestia": "port/core",
    "Caelestia.Blobs": "Ryoku.Blobs",
    "Caelestia.Components": "port/components",
    "Caelestia.Config": "config",
    "Caelestia.I18n": "port/i18n",
    "Caelestia.Images": "port/images",
    "Caelestia.Models": "port/models",
    "Caelestia.Multimedia": "port/multimedia",
    "Caelestia.Services": "port/services",
    "Caelestia.Shaders": "port/shaders",
    "Caelestia.State": "port/state",
}
IMPORT_RE = re.compile(r"^(\s*)import\s+([^\s]+)(.*)$")
SCREEN_RE = re.compile(r"^\s*[\w.]+\.(?:Config|Tokens)\.screen\s*:.*(?:\n|$)")


def git(upstream: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(upstream), *args], text=True)


def relative_import(source: str, target: str) -> str:
    rel = os.path.relpath(target, Path(source).parent)
    return "." if rel == "." else rel


def rewrite(source: str, text: str) -> str:
    output = []
    for line in text.splitlines(keepends=True):
        match = IMPORT_RE.match(line.rstrip("\n"))
        if match:
            indent, module, suffix = match.groups()
            if module == "Caelestia.Blobs":
                line = f"{indent}import Ryoku.Blobs{suffix}\n"
            elif module == "M3Shapes":
                line = f'{indent}import "{relative_import(source, "port/shapes")}"{suffix}\n'
            elif module in MODULES:
                line = f'{indent}import "{relative_import(source, MODULES[module])}"{suffix}\n'
            elif module.startswith("qs."):
                target = module[3:].replace(".", "/")
                line = f'{indent}import "{relative_import(source, target)}"{suffix}\n'
        if not SCREEN_RE.match(line):
            output.append(line)
    text = "".join(output)
    text = re.sub(r"\b(?:root|dummy|contentItem)\.?(Config|Tokens)\b", r"\1", text)
    text = text.replace("Qalculator.eval(", "Qalculator.evaluate(")
    text = text.replace("FileSystemEntry", "var")
    text = text.replace("property transitionShader", "property var")
    text = re.sub(r"(\b[\w.]+)\.LazyListView\.", r"\1.", text)
    text = re.sub(r"\bLazyListView\.(preferredHeight|visibleHeight|trackViewport|removing|adding|animationsEnabled|ready|layoutY)\b", r"\1", text)
    text = re.sub(r"^(\s*)(preferredHeight|visibleHeight|trackViewport):", r"\1property var \2:", text, flags=re.MULTILINE)
    if source == "modules/bar/components/workspaces/Workspace.qml":
        text = text.replace(
            "    property string label\n",
            "    property string label\n"
            "    property bool adding: false\n"
            "    property bool removing: false\n"
            "    property bool animationsEnabled: true\n"
            "    property bool ready: true\n"
            "    property real layoutY: y\n"
        )
        text = text.replace(
            "                    required property int index // Needed, LazyListView will fail to set it if it doesn't exist\n",
            "                    required property int index // Needed, LazyListView will fail to set it if it doesn't exist\n"
            "                    property bool adding: false\n"
            "                    property bool removing: false\n"
            "                    property bool animationsEnabled: true\n",
        )
    elif source in {"modules/sidebar/NotifDockList.qml", "modules/sidebar/NotifGroupList.qml"}:
        text = text.replace(
            "            property int startY\n",
            "            property int startY\n"
            "            property bool adding: false\n"
            "            property bool removing: false\n"
            "            property bool animationsEnabled: true\n"
            "            property bool ready: true\n"
        )
    if source == "modules/launcher/services/Apps.qml":
        text = text.replace("keys.map(k => item[k])", 'keys.map(k => item?.[k] ?? "")')
        text = text.replace("    list: appDb.apps\n", "    listValues: appDb.apps\n")
    elif source == "modules/launcher/services/Actions.qml":
        text = text.replace("a.enabled && (enableDangerous || !a.dangerous)", "(a.enabled ?? true) && (enableDangerous || !(a.dangerous ?? false))")
    elif source == "utils/Searcher.qml":
        text = text.replace(
            "    required property list<QtObject> list\n",
            "    property list<QtObject> list\n"
            "    property var listValues: null\n"
            "    readonly property var sourceList: listValues ?? list\n",
        )
        text = text.replace(
            "    property var extraOpts: ({})\n",
            "    property var extraOpts: ({})\n"
            "    readonly property var validList: sourceList.filter(item => item !== null && item !== undefined)\n",
        )
        text = text.replace("new Fzf.Finder(list,", "new Fzf.Finder(validList,")
        text = text.replace("useFuzzy ? list.map(", "useFuzzy ? validList.map(")
        text = text.replace("return item[key];", 'return item?.[key] ?? "";')
        text = text.replace("return [...list];", "return [...validList];")
    elif source == "utils/SysInfo.qml":
        text = text.replace('Quickshell.env("SHELL").split("/")', '(Quickshell.env("SHELL") || "").split("/")')
    elif source == "services/Wallpapers.qml":
        text = text.replace("    list: wallpapers.entries\n", "    listValues: wallpapers.entries\n")
    elif source == "modules/drawers/ContentWindow.qml":
        text = text.replace("WlrKeyboardFocus.OnDemand", "WlrKeyboardFocus.Exclusive")
    elif source == "modules/launcher/AppList.qml":
        text = text.replace("    required property DrawerVisibilities visibilities\n", "    required property ScreenState screenState\n")
        text = text.replace("            visibilities: root.visibilities", "            screenState: root.screenState")
    elif source == "modules/session/Content.qml":
        text = text.replace(
            '        active: Config.paths.sessionGif.trim() !== ""',
            '        active: root.screenState.session && Config.paths.sessionGif.trim() !== ""',
        )
        text = text.replace("            playing: visible", "            playing: root.screenState.session && visible")
    if source == "modules/dashboard/Content.qml":
        text = re.sub(
            r"\n\s*Component\.onCompleted: active = Qt\.binding\(\(\) => \{.*?\n\s*\}\)\n",
            "\n                        active: index === view.currentIndex\n",
            text,
            flags=re.DOTALL,
        )
        text = text.replace(
            "            RowLayout {\n                id: row\n",
            "            RowLayout {\n                id: row\n\n                width: implicitWidth\n                height: implicitHeight\n",
        )
    if source == "components/ClipRect.qml":
        text = text.replace(
            "    ShaderEffectSource {\n        id: source\n",
            "    ShaderEffectSource {\n        id: source\n\n        anchors.fill: parent\n",
        )
    if source == "modules/drawers/Regions.qml":
        text = text.replace(
            "readonly property real clampedThickness: win.contentItem.Config.border.clampedThickness",
            "readonly property real clampedThickness: Math.max(2, win.Config.border.thickness)",
        )
    text = re.sub(r"^\s*cornerFill\s*:.*\n", "", text, flags=re.MULTILINE)
    return text

def clean_old_tree(output: Path, names: set[str]) -> None:
    for root in ROOTS:
        if root == "config":
            continue
        directory = output / root
        if not directory.exists():
            continue
        for path in directory.rglob("*"):
            if not path.is_file():
                continue
            relative = str(path.relative_to(output))
            if path.name == "qmldir" or (relative not in names and relative not in SEAM_FILES):
                path.unlink()
        for path in sorted(directory.rglob("*"), reverse=True):
            if path.is_dir() and not any(path.iterdir()):
                path.rmdir()


def write_qmldirs(output: Path) -> None:
    for root in ("modules", "services", "components", "utils"):
        directory = output / root
        for path in [directory, *directory.rglob("*")]:
            if not path.is_dir():
                continue
            qml = sorted(path.glob("*.qml"))
            if not qml:
                continue
            lines = []
            for source in qml:
                prefix = "singleton " if "pragma Singleton" in source.read_text(errors="ignore") else ""
                lines.append(f"{prefix}{source.stem} 1.0 {source.name}")
            (path / "qmldir").write_text("\n".join(lines) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Import the pinned Caelestia shell tree")
    parser.add_argument("--upstream", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--revision", default=REVISION)
    args = parser.parse_args()

    names = git(args.upstream, "ls-tree", "-r", "--name-only", args.revision, "--", *ROOTS).splitlines()
    names = [name for name in names if not name.startswith(EXCLUDED)]
    if len(names) != 251:
        raise SystemExit(f"expected 251 pinned files, found {len(names)}")

    clean_old_tree(args.output, set(names))
    for name in names:
        data = git(args.upstream, "show", f"{args.revision}:{name}")
        if name.endswith((".qml", ".js")):
            data = rewrite(name, data)
        destination = args.output / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(data)

    write_qmldirs(args.output)

    print(f"imported {len(names)} files from {args.revision}")


if __name__ == "__main__":
    main()
