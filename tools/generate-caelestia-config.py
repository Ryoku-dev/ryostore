#!/usr/bin/env python3

import argparse
import ast
import json
import re
import subprocess
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Property:
    kind: str
    type_name: str
    name: str
    default: str = ""


@dataclass
class Node:
    name: str
    properties: list[Property] = field(default_factory=list)


def git_show(repo: Path, revision: str, path: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), "show", f"{revision}:{path}"], text=True
    )


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def balanced(text: str, start: int, opening: str, closing: str) -> tuple[str, int]:
    depth = 0
    quote = ""
    escaped = False
    for index in range(start, len(text)):
        char = text[index]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = ""
            continue
        if char in "\"'":
            quote = char
        elif char == opening:
            depth += 1
        elif char == closing:
            depth -= 1
            if depth == 0:
                return text[start + 1 : index], index + 1
    raise ValueError(f"unterminated {opening}{closing} block")


def split_args(text: str) -> list[str]:
    args = []
    start = 0
    depths = {"(": 0, "{": 0, "[": 0, "<": 0}
    pairs = {")": "(",
        "}": "{",
        "]": "[",
        ">": "<",
    }
    quote = ""
    escaped = False
    for index, char in enumerate(text):
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = ""
            continue
        if char in "\"'":
            quote = char
        elif char in depths:
            depths[char] += 1
        elif char in pairs and depths[pairs[char]]:
            depths[pairs[char]] -= 1
        elif char == "," and not any(depths.values()):
            args.append(text[start:index].strip())
            start = index + 1
    args.append(text[start:].strip())
    return args


def parse_classes(text: str) -> dict[str, Node]:
    text = strip_comments(text)
    nodes = {}
    for match in re.finditer(r"\bclass\s+(\w+)\s*:[^{]+\{", text):
        name = match.group(1)
        body, _ = balanced(text, match.end() - 1, "{", "}")
        node = Node(name)
        pattern = re.compile(
            r"\bCONFIG_(?:GLOBAL_)?(PROPERTY|ENUM_PROPERTY|SUBOBJECT|LIST)\s*\("
        )
        cursor = 0
        while found := pattern.search(body, cursor):
            payload, end = balanced(body, found.end() - 1, "(", ")")
            args = split_args(payload)
            kind = found.group(1)
            if kind in ("PROPERTY", "ENUM_PROPERTY") and len(args) >= 3:
                node.properties.append(Property(kind, args[0], args[1], args[2]))
            elif kind == "SUBOBJECT" and len(args) >= 2:
                node.properties.append(Property(kind, args[0], args[1]))
            elif kind == "LIST" and len(args) >= 3:
                node.properties.append(Property(kind, args[0], args[1], args[2]))
            cursor = end
        nodes[name] = node
    return nodes


def parse_enums(text: str) -> dict[str, list[str]]:
    enums = {}
    for match in re.finditer(r"\bENUM\s*\(", strip_comments(text)):
        payload, _ = balanced(strip_comments(text), match.end() - 1, "(", ")")
        args = split_args(payload)
        enums[args[0]] = [value.strip() for value in args[1:] if value.strip()]
    return enums


def cpp_strings(text: str) -> list[str]:
    return [
        bytes(value, "utf-8").decode("unicode_escape")
        if "\\" in value
        else value
        for value in re.findall(r'(?:u|QStringLiteral\()?"((?:\\.|[^"\\])*)"(?:\)_s|_s)?', text)
    ]


def arithmetic_value(expression: str) -> int | float:
    def visit(node):
        if isinstance(node, ast.Expression):
            return visit(node.body)
        if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
            return node.value
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.UAdd, ast.USub)):
            value = visit(node.operand)
            return value if isinstance(node.op, ast.UAdd) else -value
        if isinstance(node, ast.BinOp) and isinstance(node.op, (ast.Add, ast.Sub, ast.Mult, ast.Div)):
            left = visit(node.left)
            right = visit(node.right)
            if isinstance(node.op, ast.Add):
                return left + right
            if isinstance(node.op, ast.Sub):
                return left - right
            if isinstance(node.op, ast.Mult):
                return left * right
            return left / right
        raise ValueError("unsupported arithmetic default")

    return visit(ast.parse(expression, mode="eval"))

def scalar_default(type_name: str, value: str, enums: dict[str, list[str]]) -> str:
    value = value.strip()
    while value.startswith("DEFAULT_ARG(") and value.endswith(")"):
        value = value[len("DEFAULT_ARG(") : -1].strip()
    for wrapper in ("mark", "markCtx"):
        if value.startswith(wrapper + "("):
            values = cpp_strings(value)
            return json.dumps(values[0] if values else "", ensure_ascii=False)
    if "QStandardPaths::writableLocation" in value:
        match = re.search(r"QStandardPaths::(\w+)Location", value)
        suffix = cpp_strings(value)
        expression = f'root._std(StandardPaths.{match.group(1)}Location)'
        if suffix:
            expression += " + " + json.dumps(suffix[-1], ensure_ascii=False)
        return expression
    if type_name in enums and "::" in value:
        key = value.rsplit("::", 1)[1]
        return str(enums[type_name].index(key))
    if type_name in ("QString", "QByteArray"):
        values = cpp_strings(value)
        return json.dumps(values[0] if values else "", ensure_ascii=False)
    if type_name in ("QStringList", "QList<QString>"):
        return json.dumps(cpp_strings(value), ensure_ascii=False)
    if type_name.startswith("QList<"):
        body = value[1:-1] if value.startswith("{") and value.endswith("}") else value
        values = [
            json.loads(scalar_default("qreal", part, enums))
            for part in split_args(body)
        ]
        return json.dumps(values)
    if type_name == "bool":
        return "true" if value == "true" else "false"
    if value in ("{}", ""):
        if type_name == "QVariant":
            return "null"
        if "List" in type_name or type_name.startswith("QList"):
            return "[]"
        return "{}"
    if value == "std::numeric_limits<int>::max()":
        return "2147483647"
    value = re.sub(r"static_cast<\w+>\((.*)\)", r"\1", value)
    if re.fullmatch(r"[0-9+*/. ()-]+", value):
        return json.dumps(arithmetic_value(value))
    return value


def list_default(value: str, enums: dict[str, list[str]]) -> str:
    value = value.strip()
    while value.startswith("DEFAULT_ARG(") and value.endswith(")"):
        value = value[len("DEFAULT_ARG(") : -1].strip()
    if value == "{}":
        return "[]"
    entries = []
    for match in re.finditer(r"LIST_ENTRY\s*\((\w+)\s*,\s*(true|false)\)", value):
        entries.append({"id": match.group(1), "enabled": match.group(2) == "true"})
    for match in re.finditer(r"ICON_RULE_(EXACT|REGEX)\s*\(\s*u?\"([^\"]*)\"(?:_s)?\s*,\s*u?\"([^\"]*)\"", value):
        kind, pattern, icon = match.groups()
        entries.append({
            "name": pattern if kind == "EXACT" else "",
            "regex": pattern if kind == "REGEX" else "",
            "flags": "",
            "icon": icon,
        })
    for match in re.finditer(r"vmap\s*\(\s*\{", value):
        payload, _ = balanced(value, match.end() - 1, "{", "}")
        record = {}
        cursor = 0
        while cursor < len(payload):
            opening = payload.find("{", cursor)
            if opening < 0:
                break
            pair, cursor = balanced(payload, opening, "{", "}")
            args = split_args(pair)
            if len(args) < 2:
                continue
            keys = cpp_strings(args[0])
            if not keys:
                continue
            raw = ",".join(args[1:]).strip()
            strings = cpp_strings(raw)
            if raw in ("true", "false"):
                parsed = raw == "true"
            elif raw.startswith("mark(") or raw.startswith("markCtx("):
                parsed = strings[0] if strings else ""
            elif re.fullmatch(r"-?\d+(?:\.\d+)?", raw):
                parsed = float(raw) if "." in raw else int(raw)
            elif raw.startswith("QStringList") or raw.startswith("{"):
                parsed = strings
            elif strings:
                parsed = strings[0] if len(strings) == 1 else strings
            else:
                parsed = raw
            record[keys[0]] = parsed
        if record:
            entries.append(record)
    command_rewrites = {
        ("caelestia", "wallpaper", "-r"): ["ryogami", "wallpaper", "random"],
        ("loginctl", "lock-session"): ["ryoku-shell", "lock"],
        ("caelestia", "shell", "nexus", "open"): [
            "qs", "ipc", "call", "shell", "openSurface", "", "settings"
        ],
    }
    for entry in entries:
        command = entry.get("command")
        if isinstance(command, list):
            entry["command"] = command_rewrites.get(tuple(command), command)
    if entries:
        return json.dumps(entries, ensure_ascii=False)
    strings = cpp_strings(value)
    if strings:
        return json.dumps(strings, ensure_ascii=False)
    return "[]"


def add_font_nodes(nodes: dict[str, Node]) -> None:
    styles = {
        "Headline": ("GoogleSansFlex", [(32, 500), (28, 500), (24, 500)]),
        "Title": ("GoogleSansFlex", [(22, 500), (16, 500), (14, 500)]),
        "Body": ("GoogleSansFlex", [(16, 400), (14, 400), (12, 400)]),
        "Label": ("GoogleSansFlex", [(14, 500), (12, 500), (11, 400)]),
        "Mono": ("CaskaydiaCove NF", [(16, 400), (14, 400), (12, 400)]),
    }
    sizes = ("Large", "Medium", "Small")
    for style, (family, values) in styles.items():
        style_node = Node(f"FontStyle{style}", [Property("PROPERTY", "QString", "family", json.dumps(family))])
        for suffix, (size, weight) in zip(sizes, values):
            config_name = f"FontConfig{style}{suffix}"
            vaxes = "{}" if style == "Mono" else '{"ROND": 25}'
            nodes[config_name] = Node(config_name, [
                Property("PROPERTY", "QString", "family", '""'),
                Property("PROPERTY", "int", "size", str(size)),
                Property("PROPERTY", "int", "weight", str(weight)),
                Property("PROPERTY", "bool", "italic", "false"),
                Property("PROPERTY", "QVariantMap", "vaxes", vaxes),
            ])
            style_node.properties.append(Property("SUBOBJECT", config_name, suffix[0].lower() + suffix[1:]))
        nodes[style_node.name] = style_node
    for name, size in (("ExtraLarge", 36), ("Large", 24), ("Medium", 18), ("Small", 15)):
        class_name = f"FontConfigIcon{name}"
        nodes[class_name] = Node(class_name, [
            Property("PROPERTY", "QString", "family", '""'),
            Property("PROPERTY", "int", "size", str(size)),
            Property("PROPERTY", "int", "weight", "400"),
            Property("PROPERTY", "bool", "italic", "false"),
            Property("PROPERTY", "QVariantMap", "vaxes", "{}"),
        ])


def add_computed_nodes(nodes: dict[str, Node]) -> None:
    for class_name, token_name in (
        ("AppearanceRounding", "rounding"),
        ("AppearanceSpacing", "spacing"),
        ("AppearancePadding", "padding"),
    ):
        for name in (
            "extraSmall",
            "small",
            "medium",
            "large",
            "largeIncreased",
            "extraLarge",
            "extraLargeIncreased",
            "extraExtraLarge",
        ):
            nodes[class_name].properties.append(
                Property(
                    "COMPUTED",
                    "int",
                    name,
                    f"Math.trunc(TokenConfig.appearance.{token_name}.{name} * scale)",
                )
            )
    nodes["AppearanceRounding"].properties.append(
        Property("COMPUTED", "int", "full", "TokenConfig.appearance.rounding.full")
    )
    for name in (
        "small",
        "normal",
        "large",
        "extraLarge",
        "expressiveFastSpatial",
        "expressiveDefaultSpatial",
        "expressiveSlowSpatial",
        "expressiveFastEffects",
        "expressiveDefaultEffects",
        "expressiveSlowEffects",
    ):
        nodes["AnimDurations"].properties.append(
            Property(
                "COMPUTED",
                "int",
                name,
                f"Math.trunc(TokenConfig.appearance.animDurations.{name} * scale)",
            )
        )


def qml_type(type_name: str) -> str:
    if type_name == "bool":
        return "bool"
    if type_name in ("int", "quint8", "qint64"):
        return "int"
    if type_name in ("qreal", "double", "float"):
        return "real"
    if type_name in ("QString", "QByteArray"):
        return "string"
    return "var"


def emit_node(
    node_name: str,
    path: list[str],
    nodes: dict[str, Node],
    enums: dict[str, list[str]],
    indent: str,
    seen: set[str],
) -> list[str]:
    if node_name in seen:
        raise ValueError(f"recursive config node {node_name}")
    seen = seen | {node_name}
    lines = []
    node = nodes[node_name]
    for prop in node.properties:
        prop_path = path + [prop.name]
        encoded_path = json.dumps(prop_path, ensure_ascii=False)
        if prop.kind == "SUBOBJECT":
            lines.append(f"{indent}readonly property QtObject {prop.name}: QtObject {{")
            lines.extend(emit_node(prop.type_name, prop_path, nodes, enums, indent + "    ", seen))
            lines.append(f"{indent}}}")
        elif prop.kind == "LIST":
            default = list_default(prop.default, enums)
            lines.append(
                f"{indent}readonly property ConfigList {prop.name}: ConfigList {{ store: root; path: {encoded_path}; defaults: {default} }}"
            )
        elif prop.kind == "ENUM_PROPERTY":
            keys = enums[prop.type_name]
            default_name = prop.default.rsplit("::", 1)[-1]
            default = keys.index(default_name)
            lines.append(
                f"{indent}property int {prop.name}: root._e({encoded_path}, {json.dumps(keys)}, {default})"
            )
            lines.append(
                f"{indent}on{prop.name[0].upper() + prop.name[1:]}Changed: if (root._ready) root.set({encoded_path}, {prop.name})"
            )
        elif prop.kind == "COMPUTED":
            lines.append(
                f"{indent}readonly property {qml_type(prop.type_name)} {prop.name}: {prop.default}"
            )
        else:
            default = scalar_default(prop.type_name, prop.default, enums)
            lines.append(
                f"{indent}property {qml_type(prop.type_name)} {prop.name}: root._v({encoded_path}, {default})"
            )
            lines.append(
                f"{indent}on{prop.name[0].upper() + prop.name[1:]}Changed: if (root._ready) root.set({encoded_path}, {prop.name})"
            )
    return lines


HEADER = '''// Generated from caelestia-dots/shell {revision}. Do not edit.
pragma Singleton

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {{
    id: root

    property var _raw: root._parse(file.text())
    property bool _ready
    Component.onCompleted: _ready = true

    function _parse(text: string): var {{
        try {{
            const parsed = JSON.parse(text || "{{}}");
            if (parsed !== null && typeof parsed === "object" && !Array.isArray(parsed))
                return parsed;
        }} catch (error) {{
            console.warn("caelestia.config: invalid JSON, using defaults", error);
        }}
        return {{}};
    }}

    function _at(path): var {{
        let value = root._raw;
        for (const key of path) {{
            if (value === null || typeof value !== "object" || !(key in value))
                return undefined;
            value = value[key];
        }}
        return value;
    }}

    function _v(path, fallback): var {{
        const value = root._at(path);
        if (value === undefined || value === null)
            return fallback;
        if (Array.isArray(fallback))
            return Array.isArray(value) ? value : fallback;
        if (typeof fallback === "object")
            return typeof value === "object" && !Array.isArray(value) ? value : fallback;
        return typeof value === typeof fallback ? value : fallback;
    }}

    function _e(path, keys, fallback): int {{
        const value = root._at(path);
        if (typeof value === "number")
            return value >= 0 && value < keys.length ? value : fallback;
        if (typeof value !== "string")
            return fallback;
        const index = keys.findIndex(key => key.toLowerCase() === value.toLowerCase());
        return index < 0 ? fallback : index;
    }}

    function _std(location: int): string {{
        return decodeURIComponent(StandardPaths.writableLocation(location).toString().replace(/^file:\\/\\//, ""));
    }}

    function set(path, value): void {{
        if (typeof path === "string")
            path = path.split(".");
        const raw = JSON.parse(JSON.stringify(root._raw));
        let node = raw;
        for (const key of path.slice(0, -1)) {{
            if (node[key] === null || typeof node[key] !== "object" || Array.isArray(node[key]))
                node[key] = {{}};
            node = node[key];
        }}
        node[path[path.length - 1]] = value;
        root._raw = raw;
        file.setText(JSON.stringify(raw, null, 4) + "\\n");
    }}

    function forScreen(screen: string): QtObject {{
        return root;
    }}

    FileView {{
        id: file
        path: `${{Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}}/ryoku/caelestia/{filename}`
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._raw = root._parse(text())
    }}
'''


def write_root(
    output: Path,
    revision: str,
    filename: str,
    root_class: str,
    nodes: dict[str, Node],
    enums: dict[str, list[str]],
) -> None:
    lines = [HEADER.format(revision=revision, filename=filename).rstrip()]
    lines.extend(emit_node(root_class, [], nodes, enums, "    ", set()))
    lines.append("}")
    output.write_text("\n".join(lines) + "\n")


def write_enums(output: Path, revision: str, enums: dict[str, list[str]]) -> None:
    for name, values in enums.items():
        body = ", ".join(values)
        (output / f"{name}.qml").write_text(
            f"// Generated from caelestia-dots/shell {revision}. Do not edit.\n"
            "import QtQml\n\n"
            "QtObject {\n"
            f"    enum Enum {{ {body} }}\n"
            "}\n"
        )


def write_config_facade(output: Path, revision: str, nodes: dict[str, Node]) -> None:
    aliases = [
        prop.name
        for prop in nodes["ConfigRoot"].properties
        if prop.kind == "SUBOBJECT"
    ]
    lines = [
        f"// Generated from caelestia-dots/shell {revision}. Do not edit.",
        "pragma Singleton",
        "",
        "import QtQuick",
        "import Quickshell",
        "",
        "Singleton {",
    ]
    lines.extend(
        f"    readonly property QtObject {name}: GlobalConfig.{name}"
        for name in aliases
    )
    lines.extend(
        [
            "",
            "    function forScreen(screen: string): QtObject {",
            "        return GlobalConfig;",
            "    }",
            "}",
            "",
        ]
    )
    (output / "Config.qml").write_text("\n".join(lines))


def write_qmldir(output: Path, enums: dict[str, list[str]]) -> None:
    entries = [
        *(f"{name} 1.0 {name}.qml" for name in sorted(enums)),
        "singleton Config 1.0 Config.qml",
        "ConfigList 1.0 ConfigList.qml",
        "FontStyle 1.0 FontStyle.qml",
        "singleton GlobalConfig 1.0 GlobalConfig.qml",
        "singleton TokenConfig 1.0 TokenConfig.qml",
        "singleton Tokens 1.0 Tokens.qml",
    ]
    (output / "qmldir").write_text("\n".join(entries) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--upstream", type=Path, required=True)
    parser.add_argument("--revision", default="origin/main")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    config_root = "plugin/src/Caelestia/Config"
    names = subprocess.check_output(
        ["git", "-C", str(args.upstream), "ls-tree", "-r", "--name-only", args.revision, config_root],
        text=True,
    ).splitlines()
    headers = [name for name in names if name.endswith(".hpp")]
    nodes = {}
    for path in headers:
        nodes.update(parse_classes(git_show(args.upstream, args.revision, path)))
    add_font_nodes(nodes)
    add_computed_nodes(nodes)
    enums = parse_enums(git_show(args.upstream, args.revision, f"{config_root}/enums.hpp"))

    args.output.mkdir(parents=True, exist_ok=True)
    expected_qml = {
        *(f"{name}.qml" for name in enums),
        "Config.qml",
        "ConfigList.qml",
        "FontStyle.qml",
        "GlobalConfig.qml",
        "TokenConfig.qml",
        "Tokens.qml",
    }
    for generated in args.output.glob("*.qml"):
        if generated.name not in expected_qml and generated.read_text().startswith("// Generated from caelestia-dots/shell "):
            generated.unlink()
    write_root(args.output / "GlobalConfig.qml", args.revision, "shell.json", "ConfigRoot", nodes, enums)
    write_root(args.output / "TokenConfig.qml", args.revision, "shell-tokens.json", "TokensRoot", nodes, enums)
    write_enums(args.output, args.revision, enums)
    write_config_facade(args.output, args.revision, nodes)
    write_qmldir(args.output, enums)


if __name__ == "__main__":
    main()
