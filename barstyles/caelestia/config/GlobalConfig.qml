// Generated from caelestia-dots/shell b51fdb35ca7a14ac5a49e0d94fc5de2d79756aed. Do not edit.
pragma Singleton

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var _raw: root._parse(file.text())
    property bool _ready
    Component.onCompleted: _ready = true

    function _parse(text: string): var {
        try {
            const parsed = JSON.parse(text || "{}");
            if (parsed !== null && typeof parsed === "object" && !Array.isArray(parsed))
                return parsed;
        } catch (error) {
            console.warn("caelestia.config: invalid JSON, using defaults", error);
        }
        return {};
    }

    function _at(path): var {
        let value = root._raw;
        for (const key of path) {
            if (value === null || typeof value !== "object" || !(key in value))
                return undefined;
            value = value[key];
        }
        return value;
    }

    function _v(path, fallback): var {
        const value = root._at(path);
        if (value === undefined || value === null)
            return fallback;
        if (Array.isArray(fallback))
            return Array.isArray(value) ? value : fallback;
        if (typeof fallback === "object")
            return typeof value === "object" && !Array.isArray(value) ? value : fallback;
        return typeof value === typeof fallback ? value : fallback;
    }

    function _e(path, keys, fallback): int {
        const value = root._at(path);
        if (typeof value === "number")
            return value >= 0 && value < keys.length ? value : fallback;
        if (typeof value !== "string")
            return fallback;
        const index = keys.findIndex(key => key.toLowerCase() === value.toLowerCase());
        return index < 0 ? fallback : index;
    }

    function _std(location: int): string {
        return decodeURIComponent(StandardPaths.writableLocation(location).toString().replace(/^file:\/\//, ""));
    }

    function set(path, value): void {
        if (typeof path === "string")
            path = path.split(".");
        const raw = JSON.parse(JSON.stringify(root._raw));
        let node = raw;
        for (const key of path.slice(0, -1)) {
            if (node[key] === null || typeof node[key] !== "object" || Array.isArray(node[key]))
                node[key] = {};
            node = node[key];
        }
        node[path[path.length - 1]] = value;
        root._raw = raw;
        file.setText(JSON.stringify(raw, null, 4) + "\n");
    }

    function forScreen(screen: string): QtObject {
        return root;
    }

    FileView {
        id: file
        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/ryoku/caelestia/shell.json`
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._raw = root._parse(text())
    }
    property bool enabled: root._v(["enabled"], true)
    onEnabledChanged: if (root._ready) root.set(["enabled"], enabled)
    readonly property QtObject appearance: QtObject {
        property real deformScale: root._v(["appearance", "deformScale"], 1)
        onDeformScaleChanged: if (root._ready) root.set(["appearance", "deformScale"], deformScale)
        readonly property QtObject rounding: QtObject {
            property real scale: root._v(["appearance", "rounding", "scale"], 1)
            onScaleChanged: if (root._ready) root.set(["appearance", "rounding", "scale"], scale)
            readonly property int extraSmall: Math.trunc(TokenConfig.appearance.rounding.extraSmall * scale)
            readonly property int small: Math.trunc(TokenConfig.appearance.rounding.small * scale)
            readonly property int medium: Math.trunc(TokenConfig.appearance.rounding.medium * scale)
            readonly property int large: Math.trunc(TokenConfig.appearance.rounding.large * scale)
            readonly property int largeIncreased: Math.trunc(TokenConfig.appearance.rounding.largeIncreased * scale)
            readonly property int extraLarge: Math.trunc(TokenConfig.appearance.rounding.extraLarge * scale)
            readonly property int extraLargeIncreased: Math.trunc(TokenConfig.appearance.rounding.extraLargeIncreased * scale)
            readonly property int extraExtraLarge: Math.trunc(TokenConfig.appearance.rounding.extraExtraLarge * scale)
            readonly property int full: TokenConfig.appearance.rounding.full
        }
        readonly property QtObject spacing: QtObject {
            property real scale: root._v(["appearance", "spacing", "scale"], 1)
            onScaleChanged: if (root._ready) root.set(["appearance", "spacing", "scale"], scale)
            readonly property int extraSmall: Math.trunc(TokenConfig.appearance.spacing.extraSmall * scale)
            readonly property int small: Math.trunc(TokenConfig.appearance.spacing.small * scale)
            readonly property int medium: Math.trunc(TokenConfig.appearance.spacing.medium * scale)
            readonly property int large: Math.trunc(TokenConfig.appearance.spacing.large * scale)
            readonly property int largeIncreased: Math.trunc(TokenConfig.appearance.spacing.largeIncreased * scale)
            readonly property int extraLarge: Math.trunc(TokenConfig.appearance.spacing.extraLarge * scale)
            readonly property int extraLargeIncreased: Math.trunc(TokenConfig.appearance.spacing.extraLargeIncreased * scale)
            readonly property int extraExtraLarge: Math.trunc(TokenConfig.appearance.spacing.extraExtraLarge * scale)
        }
        readonly property QtObject padding: QtObject {
            property real scale: root._v(["appearance", "padding", "scale"], 1)
            onScaleChanged: if (root._ready) root.set(["appearance", "padding", "scale"], scale)
            readonly property int extraSmall: Math.trunc(TokenConfig.appearance.padding.extraSmall * scale)
            readonly property int small: Math.trunc(TokenConfig.appearance.padding.small * scale)
            readonly property int medium: Math.trunc(TokenConfig.appearance.padding.medium * scale)
            readonly property int large: Math.trunc(TokenConfig.appearance.padding.large * scale)
            readonly property int largeIncreased: Math.trunc(TokenConfig.appearance.padding.largeIncreased * scale)
            readonly property int extraLarge: Math.trunc(TokenConfig.appearance.padding.extraLarge * scale)
            readonly property int extraLargeIncreased: Math.trunc(TokenConfig.appearance.padding.extraLargeIncreased * scale)
            readonly property int extraExtraLarge: Math.trunc(TokenConfig.appearance.padding.extraExtraLarge * scale)
        }
        readonly property QtObject font: QtObject {
            property real scale: root._v(["appearance", "font", "scale"], 1)
            onScaleChanged: if (root._ready) root.set(["appearance", "font", "scale"], scale)
            readonly property QtObject headline: QtObject {
                property string family: root._v(["appearance", "font", "headline", "family"], "GoogleSansFlex")
                onFamilyChanged: if (root._ready) root.set(["appearance", "font", "headline", "family"], family)
                readonly property QtObject large: QtObject {
                    property string family: root._v(["appearance", "font", "headline", "large", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "headline", "large", "family"], family)
                    property int size: root._v(["appearance", "font", "headline", "large", "size"], 32)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "headline", "large", "size"], size)
                    property int weight: root._v(["appearance", "font", "headline", "large", "weight"], 500)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "headline", "large", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "headline", "large", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "headline", "large", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "headline", "large", "vaxes"], {"ROND": 25})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "headline", "large", "vaxes"], vaxes)
                }
                readonly property QtObject medium: QtObject {
                    property string family: root._v(["appearance", "font", "headline", "medium", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "headline", "medium", "family"], family)
                    property int size: root._v(["appearance", "font", "headline", "medium", "size"], 28)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "headline", "medium", "size"], size)
                    property int weight: root._v(["appearance", "font", "headline", "medium", "weight"], 500)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "headline", "medium", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "headline", "medium", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "headline", "medium", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "headline", "medium", "vaxes"], {"ROND": 25})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "headline", "medium", "vaxes"], vaxes)
                }
                readonly property QtObject small: QtObject {
                    property string family: root._v(["appearance", "font", "headline", "small", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "headline", "small", "family"], family)
                    property int size: root._v(["appearance", "font", "headline", "small", "size"], 24)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "headline", "small", "size"], size)
                    property int weight: root._v(["appearance", "font", "headline", "small", "weight"], 500)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "headline", "small", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "headline", "small", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "headline", "small", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "headline", "small", "vaxes"], {"ROND": 25})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "headline", "small", "vaxes"], vaxes)
                }
            }
            readonly property QtObject title: QtObject {
                property string family: root._v(["appearance", "font", "title", "family"], "GoogleSansFlex")
                onFamilyChanged: if (root._ready) root.set(["appearance", "font", "title", "family"], family)
                readonly property QtObject large: QtObject {
                    property string family: root._v(["appearance", "font", "title", "large", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "title", "large", "family"], family)
                    property int size: root._v(["appearance", "font", "title", "large", "size"], 22)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "title", "large", "size"], size)
                    property int weight: root._v(["appearance", "font", "title", "large", "weight"], 500)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "title", "large", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "title", "large", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "title", "large", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "title", "large", "vaxes"], {"ROND": 25})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "title", "large", "vaxes"], vaxes)
                }
                readonly property QtObject medium: QtObject {
                    property string family: root._v(["appearance", "font", "title", "medium", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "title", "medium", "family"], family)
                    property int size: root._v(["appearance", "font", "title", "medium", "size"], 16)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "title", "medium", "size"], size)
                    property int weight: root._v(["appearance", "font", "title", "medium", "weight"], 500)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "title", "medium", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "title", "medium", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "title", "medium", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "title", "medium", "vaxes"], {"ROND": 25})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "title", "medium", "vaxes"], vaxes)
                }
                readonly property QtObject small: QtObject {
                    property string family: root._v(["appearance", "font", "title", "small", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "title", "small", "family"], family)
                    property int size: root._v(["appearance", "font", "title", "small", "size"], 14)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "title", "small", "size"], size)
                    property int weight: root._v(["appearance", "font", "title", "small", "weight"], 500)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "title", "small", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "title", "small", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "title", "small", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "title", "small", "vaxes"], {"ROND": 25})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "title", "small", "vaxes"], vaxes)
                }
            }
            readonly property QtObject body: QtObject {
                property string family: root._v(["appearance", "font", "body", "family"], "GoogleSansFlex")
                onFamilyChanged: if (root._ready) root.set(["appearance", "font", "body", "family"], family)
                readonly property QtObject large: QtObject {
                    property string family: root._v(["appearance", "font", "body", "large", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "body", "large", "family"], family)
                    property int size: root._v(["appearance", "font", "body", "large", "size"], 16)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "body", "large", "size"], size)
                    property int weight: root._v(["appearance", "font", "body", "large", "weight"], 400)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "body", "large", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "body", "large", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "body", "large", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "body", "large", "vaxes"], {"ROND": 25})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "body", "large", "vaxes"], vaxes)
                }
                readonly property QtObject medium: QtObject {
                    property string family: root._v(["appearance", "font", "body", "medium", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "body", "medium", "family"], family)
                    property int size: root._v(["appearance", "font", "body", "medium", "size"], 14)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "body", "medium", "size"], size)
                    property int weight: root._v(["appearance", "font", "body", "medium", "weight"], 400)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "body", "medium", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "body", "medium", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "body", "medium", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "body", "medium", "vaxes"], {"ROND": 25})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "body", "medium", "vaxes"], vaxes)
                }
                readonly property QtObject small: QtObject {
                    property string family: root._v(["appearance", "font", "body", "small", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "body", "small", "family"], family)
                    property int size: root._v(["appearance", "font", "body", "small", "size"], 12)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "body", "small", "size"], size)
                    property int weight: root._v(["appearance", "font", "body", "small", "weight"], 400)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "body", "small", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "body", "small", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "body", "small", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "body", "small", "vaxes"], {"ROND": 25})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "body", "small", "vaxes"], vaxes)
                }
            }
            readonly property QtObject label: QtObject {
                property string family: root._v(["appearance", "font", "label", "family"], "GoogleSansFlex")
                onFamilyChanged: if (root._ready) root.set(["appearance", "font", "label", "family"], family)
                readonly property QtObject large: QtObject {
                    property string family: root._v(["appearance", "font", "label", "large", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "label", "large", "family"], family)
                    property int size: root._v(["appearance", "font", "label", "large", "size"], 14)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "label", "large", "size"], size)
                    property int weight: root._v(["appearance", "font", "label", "large", "weight"], 500)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "label", "large", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "label", "large", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "label", "large", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "label", "large", "vaxes"], {"ROND": 25})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "label", "large", "vaxes"], vaxes)
                }
                readonly property QtObject medium: QtObject {
                    property string family: root._v(["appearance", "font", "label", "medium", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "label", "medium", "family"], family)
                    property int size: root._v(["appearance", "font", "label", "medium", "size"], 12)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "label", "medium", "size"], size)
                    property int weight: root._v(["appearance", "font", "label", "medium", "weight"], 500)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "label", "medium", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "label", "medium", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "label", "medium", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "label", "medium", "vaxes"], {"ROND": 25})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "label", "medium", "vaxes"], vaxes)
                }
                readonly property QtObject small: QtObject {
                    property string family: root._v(["appearance", "font", "label", "small", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "label", "small", "family"], family)
                    property int size: root._v(["appearance", "font", "label", "small", "size"], 11)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "label", "small", "size"], size)
                    property int weight: root._v(["appearance", "font", "label", "small", "weight"], 400)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "label", "small", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "label", "small", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "label", "small", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "label", "small", "vaxes"], {"ROND": 25})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "label", "small", "vaxes"], vaxes)
                }
            }
            readonly property QtObject mono: QtObject {
                property string family: root._v(["appearance", "font", "mono", "family"], "CaskaydiaCove NF")
                onFamilyChanged: if (root._ready) root.set(["appearance", "font", "mono", "family"], family)
                readonly property QtObject large: QtObject {
                    property string family: root._v(["appearance", "font", "mono", "large", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "mono", "large", "family"], family)
                    property int size: root._v(["appearance", "font", "mono", "large", "size"], 16)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "mono", "large", "size"], size)
                    property int weight: root._v(["appearance", "font", "mono", "large", "weight"], 400)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "mono", "large", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "mono", "large", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "mono", "large", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "mono", "large", "vaxes"], {})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "mono", "large", "vaxes"], vaxes)
                }
                readonly property QtObject medium: QtObject {
                    property string family: root._v(["appearance", "font", "mono", "medium", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "mono", "medium", "family"], family)
                    property int size: root._v(["appearance", "font", "mono", "medium", "size"], 14)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "mono", "medium", "size"], size)
                    property int weight: root._v(["appearance", "font", "mono", "medium", "weight"], 400)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "mono", "medium", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "mono", "medium", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "mono", "medium", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "mono", "medium", "vaxes"], {})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "mono", "medium", "vaxes"], vaxes)
                }
                readonly property QtObject small: QtObject {
                    property string family: root._v(["appearance", "font", "mono", "small", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "mono", "small", "family"], family)
                    property int size: root._v(["appearance", "font", "mono", "small", "size"], 12)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "mono", "small", "size"], size)
                    property int weight: root._v(["appearance", "font", "mono", "small", "weight"], 400)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "mono", "small", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "mono", "small", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "mono", "small", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "mono", "small", "vaxes"], {})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "mono", "small", "vaxes"], vaxes)
                }
            }
            readonly property QtObject icon: QtObject {
                property string family: root._v(["appearance", "font", "icon", "family"], "Material Symbols Rounded")
                onFamilyChanged: if (root._ready) root.set(["appearance", "font", "icon", "family"], family)
                readonly property QtObject extraLarge: QtObject {
                    property string family: root._v(["appearance", "font", "icon", "extraLarge", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "icon", "extraLarge", "family"], family)
                    property int size: root._v(["appearance", "font", "icon", "extraLarge", "size"], 36)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "icon", "extraLarge", "size"], size)
                    property int weight: root._v(["appearance", "font", "icon", "extraLarge", "weight"], 400)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "icon", "extraLarge", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "icon", "extraLarge", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "icon", "extraLarge", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "icon", "extraLarge", "vaxes"], {})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "icon", "extraLarge", "vaxes"], vaxes)
                }
                readonly property QtObject large: QtObject {
                    property string family: root._v(["appearance", "font", "icon", "large", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "icon", "large", "family"], family)
                    property int size: root._v(["appearance", "font", "icon", "large", "size"], 24)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "icon", "large", "size"], size)
                    property int weight: root._v(["appearance", "font", "icon", "large", "weight"], 400)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "icon", "large", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "icon", "large", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "icon", "large", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "icon", "large", "vaxes"], {})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "icon", "large", "vaxes"], vaxes)
                }
                readonly property QtObject medium: QtObject {
                    property string family: root._v(["appearance", "font", "icon", "medium", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "icon", "medium", "family"], family)
                    property int size: root._v(["appearance", "font", "icon", "medium", "size"], 18)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "icon", "medium", "size"], size)
                    property int weight: root._v(["appearance", "font", "icon", "medium", "weight"], 400)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "icon", "medium", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "icon", "medium", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "icon", "medium", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "icon", "medium", "vaxes"], {})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "icon", "medium", "vaxes"], vaxes)
                }
                readonly property QtObject small: QtObject {
                    property string family: root._v(["appearance", "font", "icon", "small", "family"], "")
                    onFamilyChanged: if (root._ready) root.set(["appearance", "font", "icon", "small", "family"], family)
                    property int size: root._v(["appearance", "font", "icon", "small", "size"], 15)
                    onSizeChanged: if (root._ready) root.set(["appearance", "font", "icon", "small", "size"], size)
                    property int weight: root._v(["appearance", "font", "icon", "small", "weight"], 400)
                    onWeightChanged: if (root._ready) root.set(["appearance", "font", "icon", "small", "weight"], weight)
                    property bool italic: root._v(["appearance", "font", "icon", "small", "italic"], false)
                    onItalicChanged: if (root._ready) root.set(["appearance", "font", "icon", "small", "italic"], italic)
                    property var vaxes: root._v(["appearance", "font", "icon", "small", "vaxes"], {})
                    onVaxesChanged: if (root._ready) root.set(["appearance", "font", "icon", "small", "vaxes"], vaxes)
                }
            }
            property string clock: root._v(["appearance", "font", "clock"], "Rubik")
            onClockChanged: if (root._ready) root.set(["appearance", "font", "clock"], clock)
            property string workspaces: root._v(["appearance", "font", "workspaces"], "Rubik")
            onWorkspacesChanged: if (root._ready) root.set(["appearance", "font", "workspaces"], workspaces)
        }
        readonly property QtObject anim: QtObject {
            readonly property QtObject durations: QtObject {
                property real scale: root._v(["appearance", "anim", "durations", "scale"], 1)
                onScaleChanged: if (root._ready) root.set(["appearance", "anim", "durations", "scale"], scale)
                readonly property int small: Math.trunc(TokenConfig.appearance.animDurations.small * scale)
                readonly property int normal: Math.trunc(TokenConfig.appearance.animDurations.normal * scale)
                readonly property int large: Math.trunc(TokenConfig.appearance.animDurations.large * scale)
                readonly property int extraLarge: Math.trunc(TokenConfig.appearance.animDurations.extraLarge * scale)
                readonly property int expressiveFastSpatial: Math.trunc(TokenConfig.appearance.animDurations.expressiveFastSpatial * scale)
                readonly property int expressiveDefaultSpatial: Math.trunc(TokenConfig.appearance.animDurations.expressiveDefaultSpatial * scale)
                readonly property int expressiveSlowSpatial: Math.trunc(TokenConfig.appearance.animDurations.expressiveSlowSpatial * scale)
                readonly property int expressiveFastEffects: Math.trunc(TokenConfig.appearance.animDurations.expressiveFastEffects * scale)
                readonly property int expressiveDefaultEffects: Math.trunc(TokenConfig.appearance.animDurations.expressiveDefaultEffects * scale)
                readonly property int expressiveSlowEffects: Math.trunc(TokenConfig.appearance.animDurations.expressiveSlowEffects * scale)
            }
        }
        readonly property QtObject transparency: QtObject {
            property bool enabled: root._v(["appearance", "transparency", "enabled"], false)
            onEnabledChanged: if (root._ready) root.set(["appearance", "transparency", "enabled"], enabled)
            property real base: root._v(["appearance", "transparency", "base"], 0.85)
            onBaseChanged: if (root._ready) root.set(["appearance", "transparency", "base"], base)
            property real layers: root._v(["appearance", "transparency", "layers"], 0.4)
            onLayersChanged: if (root._ready) root.set(["appearance", "transparency", "layers"], layers)
        }
    }
    readonly property QtObject general: QtObject {
        property string logo: root._v(["general", "logo"], "")
        onLogoChanged: if (root._ready) root.set(["general", "logo"], logo)
        property string language: root._v(["general", "language"], "")
        onLanguageChanged: if (root._ready) root.set(["general", "language"], language)
        property bool showOverFullscreen: root._v(["general", "showOverFullscreen"], false)
        onShowOverFullscreenChanged: if (root._ready) root.set(["general", "showOverFullscreen"], showOverFullscreen)
        property real mediaGifSpeedAdjustment: root._v(["general", "mediaGifSpeedAdjustment"], 300)
        onMediaGifSpeedAdjustmentChanged: if (root._ready) root.set(["general", "mediaGifSpeedAdjustment"], mediaGifSpeedAdjustment)
        property real sessionGifSpeed: root._v(["general", "sessionGifSpeed"], 0.7)
        onSessionGifSpeedChanged: if (root._ready) root.set(["general", "sessionGifSpeed"], sessionGifSpeed)
        readonly property QtObject apps: QtObject {
            property var terminal: root._v(["general", "apps", "terminal"], ["foot"])
            onTerminalChanged: if (root._ready) root.set(["general", "apps", "terminal"], terminal)
            property var audio: root._v(["general", "apps", "audio"], ["pwvucontrol"])
            onAudioChanged: if (root._ready) root.set(["general", "apps", "audio"], audio)
            property var playback: root._v(["general", "apps", "playback"], ["mpv"])
            onPlaybackChanged: if (root._ready) root.set(["general", "apps", "playback"], playback)
            property var explorer: root._v(["general", "apps", "explorer"], ["thunar"])
            onExplorerChanged: if (root._ready) root.set(["general", "apps", "explorer"], explorer)
        }
        readonly property QtObject idle: QtObject {
            property bool lockBeforeSleep: root._v(["general", "idle", "lockBeforeSleep"], true)
            onLockBeforeSleepChanged: if (root._ready) root.set(["general", "idle", "lockBeforeSleep"], lockBeforeSleep)
            property bool inhibitWhenAudio: root._v(["general", "idle", "inhibitWhenAudio"], true)
            onInhibitWhenAudioChanged: if (root._ready) root.set(["general", "idle", "inhibitWhenAudio"], inhibitWhenAudio)
            property bool inhibitWhenCharging: root._v(["general", "idle", "inhibitWhenCharging"], false)
            onInhibitWhenChargingChanged: if (root._ready) root.set(["general", "idle", "inhibitWhenCharging"], inhibitWhenCharging)
            readonly property ConfigList timeouts: ConfigList { store: root; path: ["general", "idle", "timeouts"]; defaults: [{"timeout": 180, "idleAction": "lock"}, {"timeout": 300, "idleAction": "dpms off", "returnAction": "dpms on"}, {"timeout": 600, "idleAction": ["suspendThenHibernate"]}] }
        }
        readonly property QtObject battery: QtObject {
            readonly property ConfigList warnLevels: ConfigList { store: root; path: ["general", "battery", "warnLevels"]; defaults: [{"level": 20, "title": "Low battery", "message": "You might want to plug in a charger", "icon": "battery_android_frame_2"}, {"level": 10, "title": "Did you see the previous message?", "message": "You should probably plug in a charger <b>now</b>", "icon": "battery_android_frame_1"}, {"level": 5, "title": "Critical battery level", "message": "PLUG THE CHARGER RIGHT NOW!!", "icon": "battery_android_alert", "critical": true}] }
            property int criticalLevel: root._v(["general", "battery", "criticalLevel"], 3)
            onCriticalLevelChanged: if (root._ready) root.set(["general", "battery", "criticalLevel"], criticalLevel)
        }
    }
    readonly property QtObject background: QtObject {
        property bool enabled: root._v(["background", "enabled"], true)
        onEnabledChanged: if (root._ready) root.set(["background", "enabled"], enabled)
        property bool wallpaperEnabled: root._v(["background", "wallpaperEnabled"], true)
        onWallpaperEnabledChanged: if (root._ready) root.set(["background", "wallpaperEnabled"], wallpaperEnabled)
        property int wallpaperTransition: root._e(["background", "wallpaperTransition"], ["ChromaticBloom", "ColourDistance", "Crossfade", "Crosshatch", "Crosswarp", "Directional", "DirectionalWipe", "FadeColour", "Glitch", "GlitchDisplace", "HeatMelt", "InkSplash", "InkwellDrop", "Iris", "Morph", "ParametricGlitch", "Perlin", "Pixelate", "PixelfadeWave", "PlasmaFlow", "PolkaDotsCurtain", "PuzzleRight", "RandomSquares", "Smoke", "SoftWarpFade", "VoronoiShatter", "ZoomBlurPull"], 2)
        onWallpaperTransitionChanged: if (root._ready) root.set(["background", "wallpaperTransition"], wallpaperTransition)
        readonly property QtObject desktopClock: QtObject {
            property bool enabled: root._v(["background", "desktopClock", "enabled"], false)
            onEnabledChanged: if (root._ready) root.set(["background", "desktopClock", "enabled"], enabled)
            property real scale: root._v(["background", "desktopClock", "scale"], 1.0)
            onScaleChanged: if (root._ready) root.set(["background", "desktopClock", "scale"], scale)
            property string position: root._v(["background", "desktopClock", "position"], "bottom-right")
            onPositionChanged: if (root._ready) root.set(["background", "desktopClock", "position"], position)
            property bool invertColors: root._v(["background", "desktopClock", "invertColors"], false)
            onInvertColorsChanged: if (root._ready) root.set(["background", "desktopClock", "invertColors"], invertColors)
            readonly property QtObject background: QtObject {
                property bool enabled: root._v(["background", "desktopClock", "background", "enabled"], false)
                onEnabledChanged: if (root._ready) root.set(["background", "desktopClock", "background", "enabled"], enabled)
                property real opacity: root._v(["background", "desktopClock", "background", "opacity"], 0.7)
                onOpacityChanged: if (root._ready) root.set(["background", "desktopClock", "background", "opacity"], opacity)
                property bool blur: root._v(["background", "desktopClock", "background", "blur"], true)
                onBlurChanged: if (root._ready) root.set(["background", "desktopClock", "background", "blur"], blur)
            }
            readonly property QtObject shadow: QtObject {
                property bool enabled: root._v(["background", "desktopClock", "shadow", "enabled"], true)
                onEnabledChanged: if (root._ready) root.set(["background", "desktopClock", "shadow", "enabled"], enabled)
                property real opacity: root._v(["background", "desktopClock", "shadow", "opacity"], 0.7)
                onOpacityChanged: if (root._ready) root.set(["background", "desktopClock", "shadow", "opacity"], opacity)
                property real blur: root._v(["background", "desktopClock", "shadow", "blur"], 0.4)
                onBlurChanged: if (root._ready) root.set(["background", "desktopClock", "shadow", "blur"], blur)
            }
        }
        readonly property QtObject visualiser: QtObject {
            property bool enabled: root._v(["background", "visualiser", "enabled"], false)
            onEnabledChanged: if (root._ready) root.set(["background", "visualiser", "enabled"], enabled)
            property bool autoHide: root._v(["background", "visualiser", "autoHide"], true)
            onAutoHideChanged: if (root._ready) root.set(["background", "visualiser", "autoHide"], autoHide)
            property bool blur: root._v(["background", "visualiser", "blur"], false)
            onBlurChanged: if (root._ready) root.set(["background", "visualiser", "blur"], blur)
            property real rounding: root._v(["background", "visualiser", "rounding"], 1)
            onRoundingChanged: if (root._ready) root.set(["background", "visualiser", "rounding"], rounding)
            property real spacing: root._v(["background", "visualiser", "spacing"], 1)
            onSpacingChanged: if (root._ready) root.set(["background", "visualiser", "spacing"], spacing)
        }
    }
    readonly property QtObject bar: QtObject {
        property bool persistent: root._v(["bar", "persistent"], true)
        onPersistentChanged: if (root._ready) root.set(["bar", "persistent"], persistent)
        property bool showOnHover: root._v(["bar", "showOnHover"], true)
        onShowOnHoverChanged: if (root._ready) root.set(["bar", "showOnHover"], showOnHover)
        property int dragThreshold: root._v(["bar", "dragThreshold"], 20)
        onDragThresholdChanged: if (root._ready) root.set(["bar", "dragThreshold"], dragThreshold)
        readonly property QtObject scrollActions: QtObject {
            property bool workspaces: root._v(["bar", "scrollActions", "workspaces"], true)
            onWorkspacesChanged: if (root._ready) root.set(["bar", "scrollActions", "workspaces"], workspaces)
            property bool volume: root._v(["bar", "scrollActions", "volume"], true)
            onVolumeChanged: if (root._ready) root.set(["bar", "scrollActions", "volume"], volume)
            property bool brightness: root._v(["bar", "scrollActions", "brightness"], true)
            onBrightnessChanged: if (root._ready) root.set(["bar", "scrollActions", "brightness"], brightness)
        }
        readonly property QtObject popouts: QtObject {
            property bool activeWindow: root._v(["bar", "popouts", "activeWindow"], true)
            onActiveWindowChanged: if (root._ready) root.set(["bar", "popouts", "activeWindow"], activeWindow)
            property bool tray: root._v(["bar", "popouts", "tray"], true)
            onTrayChanged: if (root._ready) root.set(["bar", "popouts", "tray"], tray)
            property bool statusIcons: root._v(["bar", "popouts", "statusIcons"], true)
            onStatusIconsChanged: if (root._ready) root.set(["bar", "popouts", "statusIcons"], statusIcons)
        }
        readonly property QtObject workspaces: QtObject {
            property int shown: root._v(["bar", "workspaces", "shown"], 5)
            onShownChanged: if (root._ready) root.set(["bar", "workspaces", "shown"], shown)
            property bool activeIndicator: root._v(["bar", "workspaces", "activeIndicator"], true)
            onActiveIndicatorChanged: if (root._ready) root.set(["bar", "workspaces", "activeIndicator"], activeIndicator)
            property bool occupiedBg: root._v(["bar", "workspaces", "occupiedBg"], false)
            onOccupiedBgChanged: if (root._ready) root.set(["bar", "workspaces", "occupiedBg"], occupiedBg)
            property bool showUnoccupied: root._v(["bar", "workspaces", "showUnoccupied"], true)
            onShowUnoccupiedChanged: if (root._ready) root.set(["bar", "workspaces", "showUnoccupied"], showUnoccupied)
            property bool perMonitor: root._v(["bar", "workspaces", "perMonitor"], true)
            onPerMonitorChanged: if (root._ready) root.set(["bar", "workspaces", "perMonitor"], perMonitor)
            property bool showWindows: root._v(["bar", "workspaces", "showWindows"], true)
            onShowWindowsChanged: if (root._ready) root.set(["bar", "workspaces", "showWindows"], showWindows)
            property bool showWindowsOnSpecialWorkspaces: root._v(["bar", "workspaces", "showWindowsOnSpecialWorkspaces"], true)
            onShowWindowsOnSpecialWorkspacesChanged: if (root._ready) root.set(["bar", "workspaces", "showWindowsOnSpecialWorkspaces"], showWindowsOnSpecialWorkspaces)
            property int maxWindowIcons: root._v(["bar", "workspaces", "maxWindowIcons"], 5)
            onMaxWindowIconsChanged: if (root._ready) root.set(["bar", "workspaces", "maxWindowIcons"], maxWindowIcons)
            property bool activeTrail: root._v(["bar", "workspaces", "activeTrail"], true)
            onActiveTrailChanged: if (root._ready) root.set(["bar", "workspaces", "activeTrail"], activeTrail)
            property int displayType: root._e(["bar", "workspaces", "displayType"], ["Shapes", "Text", "Icons"], 0)
            onDisplayTypeChanged: if (root._ready) root.set(["bar", "workspaces", "displayType"], displayType)
            property int specialDisplayType: root._e(["bar", "workspaces", "specialDisplayType"], ["Shapes", "Text", "Icons"], 2)
            onSpecialDisplayTypeChanged: if (root._ready) root.set(["bar", "workspaces", "specialDisplayType"], specialDisplayType)
            property string label: root._v(["bar", "workspaces", "label"], "  ")
            onLabelChanged: if (root._ready) root.set(["bar", "workspaces", "label"], label)
            property string occupiedLabel: root._v(["bar", "workspaces", "occupiedLabel"], "󰮯")
            onOccupiedLabelChanged: if (root._ready) root.set(["bar", "workspaces", "occupiedLabel"], occupiedLabel)
            property string activeLabel: root._v(["bar", "workspaces", "activeLabel"], "󰮯")
            onActiveLabelChanged: if (root._ready) root.set(["bar", "workspaces", "activeLabel"], activeLabel)
            property int capitalisation: root._e(["bar", "workspaces", "capitalisation"], ["Preserve", "Upper", "Lower"], 0)
            onCapitalisationChanged: if (root._ready) root.set(["bar", "workspaces", "capitalisation"], capitalisation)
            readonly property ConfigList workspaceIcons: ConfigList { store: root; path: ["bar", "workspaces", "workspaceIcons"]; defaults: [] }
            readonly property ConfigList specialWorkspaceIcons: ConfigList { store: root; path: ["bar", "workspaces", "specialWorkspaceIcons"]; defaults: [{"name": "special", "regex": "", "flags": "", "icon": "star"}, {"name": "communication", "regex": "", "flags": "", "icon": "forum"}, {"name": "music", "regex": "", "flags": "", "icon": "music_cast"}, {"name": "todo", "regex": "", "flags": "", "icon": "checklist"}, {"name": "sysmon", "regex": "", "flags": "", "icon": "monitor_heart"}] }
            property var ignoredTags: root._v(["bar", "workspaces", "ignoredTags"], ["hide_in_bar", "xwl_popup"])
            onIgnoredTagsChanged: if (root._ready) root.set(["bar", "workspaces", "ignoredTags"], ignoredTags)
            readonly property ConfigList windowIcons: ConfigList { store: root; path: ["bar", "workspaces", "windowIcons"]; defaults: [{"name": "", "regex": "steam(_app_(default|[0-9]+))?", "flags": "", "icon": "sports_esports"}] }
        }
        readonly property QtObject activeWindow: QtObject {
            property bool compact: root._v(["bar", "activeWindow", "compact"], false)
            onCompactChanged: if (root._ready) root.set(["bar", "activeWindow", "compact"], compact)
            property bool inverted: root._v(["bar", "activeWindow", "inverted"], false)
            onInvertedChanged: if (root._ready) root.set(["bar", "activeWindow", "inverted"], inverted)
            property bool showOnHover: root._v(["bar", "activeWindow", "showOnHover"], true)
            onShowOnHoverChanged: if (root._ready) root.set(["bar", "activeWindow", "showOnHover"], showOnHover)
        }
        readonly property QtObject tray: QtObject {
            property bool background: root._v(["bar", "tray", "background"], false)
            onBackgroundChanged: if (root._ready) root.set(["bar", "tray", "background"], background)
            property bool recolour: root._v(["bar", "tray", "recolour"], false)
            onRecolourChanged: if (root._ready) root.set(["bar", "tray", "recolour"], recolour)
            property bool compact: root._v(["bar", "tray", "compact"], false)
            onCompactChanged: if (root._ready) root.set(["bar", "tray", "compact"], compact)
            readonly property ConfigList iconSubs: ConfigList { store: root; path: ["bar", "tray", "iconSubs"]; defaults: [] }
            property var hiddenIcons: root._v(["bar", "tray", "hiddenIcons"], [])
            onHiddenIconsChanged: if (root._ready) root.set(["bar", "tray", "hiddenIcons"], hiddenIcons)
        }
        readonly property QtObject clock: QtObject {
            property bool background: root._v(["bar", "clock", "background"], false)
            onBackgroundChanged: if (root._ready) root.set(["bar", "clock", "background"], background)
            property bool showDate: root._v(["bar", "clock", "showDate"], false)
            onShowDateChanged: if (root._ready) root.set(["bar", "clock", "showDate"], showDate)
            property bool showIcon: root._v(["bar", "clock", "showIcon"], true)
            onShowIconChanged: if (root._ready) root.set(["bar", "clock", "showIcon"], showIcon)
            property bool showSeconds: root._v(["bar", "clock", "showSeconds"], false)
            onShowSecondsChanged: if (root._ready) root.set(["bar", "clock", "showSeconds"], showSeconds)
        }
        readonly property ConfigList statusIcons: ConfigList { store: root; path: ["bar", "statusIcons"]; defaults: [{"id": "lockStatus", "enabled": true}, {"id": "audio", "enabled": false}, {"id": "microphone", "enabled": false}, {"id": "kbLayout", "enabled": false}, {"id": "network", "enabled": true}, {"id": "bluetooth", "enabled": true}, {"id": "battery", "enabled": true}] }
        readonly property ConfigList entries: ConfigList { store: root; path: ["bar", "entries"]; defaults: [{"id": "logo", "enabled": true}, {"id": "workspaces", "enabled": true}, {"id": "spacer", "enabled": true}, {"id": "activeWindow", "enabled": true}, {"id": "spacer", "enabled": true}, {"id": "tray", "enabled": true}, {"id": "clock", "enabled": true}, {"id": "statusIcons", "enabled": true}, {"id": "power", "enabled": true}] }
        property var excludedScreens: root._v(["bar", "excludedScreens"], [])
        onExcludedScreensChanged: if (root._ready) root.set(["bar", "excludedScreens"], excludedScreens)
    }
    readonly property QtObject border: QtObject {
        property int thickness: root._v(["border", "thickness"], 10)
        onThicknessChanged: if (root._ready) root.set(["border", "thickness"], thickness)
        property int rounding: root._v(["border", "rounding"], 25)
        onRoundingChanged: if (root._ready) root.set(["border", "rounding"], rounding)
        property int smoothing: root._v(["border", "smoothing"], 20)
        onSmoothingChanged: if (root._ready) root.set(["border", "smoothing"], smoothing)
    }
    readonly property QtObject dashboard: QtObject {
        property bool enabled: root._v(["dashboard", "enabled"], true)
        onEnabledChanged: if (root._ready) root.set(["dashboard", "enabled"], enabled)
        property bool showOnHover: root._v(["dashboard", "showOnHover"], true)
        onShowOnHoverChanged: if (root._ready) root.set(["dashboard", "showOnHover"], showOnHover)
        property bool showDashboard: root._v(["dashboard", "showDashboard"], true)
        onShowDashboardChanged: if (root._ready) root.set(["dashboard", "showDashboard"], showDashboard)
        property bool showMedia: root._v(["dashboard", "showMedia"], true)
        onShowMediaChanged: if (root._ready) root.set(["dashboard", "showMedia"], showMedia)
        property bool showPerformance: root._v(["dashboard", "showPerformance"], true)
        onShowPerformanceChanged: if (root._ready) root.set(["dashboard", "showPerformance"], showPerformance)
        property bool showWeather: root._v(["dashboard", "showWeather"], true)
        onShowWeatherChanged: if (root._ready) root.set(["dashboard", "showWeather"], showWeather)
        property bool showClockSeconds: root._v(["dashboard", "showClockSeconds"], false)
        onShowClockSecondsChanged: if (root._ready) root.set(["dashboard", "showClockSeconds"], showClockSeconds)
        property int mediaUpdateInterval: root._v(["dashboard", "mediaUpdateInterval"], 500)
        onMediaUpdateIntervalChanged: if (root._ready) root.set(["dashboard", "mediaUpdateInterval"], mediaUpdateInterval)
        property int resourceUpdateInterval: root._v(["dashboard", "resourceUpdateInterval"], 1000)
        onResourceUpdateIntervalChanged: if (root._ready) root.set(["dashboard", "resourceUpdateInterval"], resourceUpdateInterval)
        property int dragThreshold: root._v(["dashboard", "dragThreshold"], 50)
        onDragThresholdChanged: if (root._ready) root.set(["dashboard", "dragThreshold"], dragThreshold)
        readonly property QtObject performance: QtObject {
            property bool showBattery: root._v(["dashboard", "performance", "showBattery"], true)
            onShowBatteryChanged: if (root._ready) root.set(["dashboard", "performance", "showBattery"], showBattery)
            property bool showGpu: root._v(["dashboard", "performance", "showGpu"], true)
            onShowGpuChanged: if (root._ready) root.set(["dashboard", "performance", "showGpu"], showGpu)
            property bool showCpu: root._v(["dashboard", "performance", "showCpu"], true)
            onShowCpuChanged: if (root._ready) root.set(["dashboard", "performance", "showCpu"], showCpu)
            property bool showMemory: root._v(["dashboard", "performance", "showMemory"], true)
            onShowMemoryChanged: if (root._ready) root.set(["dashboard", "performance", "showMemory"], showMemory)
            property bool showStorage: root._v(["dashboard", "performance", "showStorage"], true)
            onShowStorageChanged: if (root._ready) root.set(["dashboard", "performance", "showStorage"], showStorage)
            property bool showNetwork: root._v(["dashboard", "performance", "showNetwork"], true)
            onShowNetworkChanged: if (root._ready) root.set(["dashboard", "performance", "showNetwork"], showNetwork)
        }
    }
    readonly property QtObject launcher: QtObject {
        property bool enabled: root._v(["launcher", "enabled"], true)
        onEnabledChanged: if (root._ready) root.set(["launcher", "enabled"], enabled)
        property bool showOnHover: root._v(["launcher", "showOnHover"], false)
        onShowOnHoverChanged: if (root._ready) root.set(["launcher", "showOnHover"], showOnHover)
        property int maxShown: root._v(["launcher", "maxShown"], 7)
        onMaxShownChanged: if (root._ready) root.set(["launcher", "maxShown"], maxShown)
        property int maxWallpapers: root._v(["launcher", "maxWallpapers"], 9)
        onMaxWallpapersChanged: if (root._ready) root.set(["launcher", "maxWallpapers"], maxWallpapers)
        property string specialPrefix: root._v(["launcher", "specialPrefix"], "@")
        onSpecialPrefixChanged: if (root._ready) root.set(["launcher", "specialPrefix"], specialPrefix)
        property string actionPrefix: root._v(["launcher", "actionPrefix"], ">")
        onActionPrefixChanged: if (root._ready) root.set(["launcher", "actionPrefix"], actionPrefix)
        property bool enableDangerousActions: root._v(["launcher", "enableDangerousActions"], false)
        onEnableDangerousActionsChanged: if (root._ready) root.set(["launcher", "enableDangerousActions"], enableDangerousActions)
        property int dragThreshold: root._v(["launcher", "dragThreshold"], 50)
        onDragThresholdChanged: if (root._ready) root.set(["launcher", "dragThreshold"], dragThreshold)
        property bool vimKeybinds: root._v(["launcher", "vimKeybinds"], false)
        onVimKeybindsChanged: if (root._ready) root.set(["launcher", "vimKeybinds"], vimKeybinds)
        property var favouriteApps: root._v(["launcher", "favouriteApps"], [])
        onFavouriteAppsChanged: if (root._ready) root.set(["launcher", "favouriteApps"], favouriteApps)
        property var hiddenApps: root._v(["launcher", "hiddenApps"], [])
        onHiddenAppsChanged: if (root._ready) root.set(["launcher", "hiddenApps"], hiddenApps)
        readonly property QtObject useFuzzy: QtObject {
            property bool apps: root._v(["launcher", "useFuzzy", "apps"], false)
            onAppsChanged: if (root._ready) root.set(["launcher", "useFuzzy", "apps"], apps)
            property bool actions: root._v(["launcher", "useFuzzy", "actions"], false)
            onActionsChanged: if (root._ready) root.set(["launcher", "useFuzzy", "actions"], actions)
            property bool schemes: root._v(["launcher", "useFuzzy", "schemes"], false)
            onSchemesChanged: if (root._ready) root.set(["launcher", "useFuzzy", "schemes"], schemes)
            property bool variants: root._v(["launcher", "useFuzzy", "variants"], false)
            onVariantsChanged: if (root._ready) root.set(["launcher", "useFuzzy", "variants"], variants)
            property bool wallpapers: root._v(["launcher", "useFuzzy", "wallpapers"], false)
            onWallpapersChanged: if (root._ready) root.set(["launcher", "useFuzzy", "wallpapers"], wallpapers)
        }
        readonly property ConfigList actions: ConfigList { store: root; path: ["launcher", "actions"]; defaults: [{"name": "Calculator", "icon": "calculate", "description": "Do simple maths equations (powered by Qalc)", "command": ["autocomplete", "calc"]}, {"name": "Scheme", "icon": "palette", "description": "Change the current colour scheme", "command": ["autocomplete", "scheme"]}, {"name": "Wallpaper", "icon": "image", "description": "Change the current wallpaper", "command": ["autocomplete", "wallpaper"]}, {"name": "Variant", "icon": "colors", "description": "Change the current scheme variant", "command": ["autocomplete", "variant"]}, {"name": "Random", "icon": "casino", "description": "Switch to a random wallpaper", "command": ["ryogami", "wallpaper", "random"]}, {"name": "Light", "icon": "light_mode", "description": "Change the scheme to light mode", "command": ["setMode", "light"]}, {"name": "Dark", "icon": "dark_mode", "description": "Change the scheme to dark mode", "command": ["setMode", "dark"]}, {"name": "Shutdown", "icon": "power_settings_new", "description": "Shutdown the system", "command": ["poweroff"], "dangerous": true}, {"name": "Reboot", "icon": "cached", "description": "Reboot the system", "command": ["reboot"], "dangerous": true}, {"name": "Logout", "icon": "exit_to_app", "description": "Log out of the current session", "command": ["logout"], "dangerous": true}, {"name": "Lock", "icon": "lock", "description": "Lock the current session", "command": ["ryoku-shell", "lock"]}, {"name": "Sleep", "icon": "bedtime", "description": "Suspend then hibernate", "command": ["suspendThenHibernate"]}, {"name": "Settings", "icon": "settings", "description": "Configure the shell", "command": ["qs", "ipc", "call", "shell", "openSurface", "", "settings"]}] }
    }
    readonly property QtObject lock: QtObject {
        property bool enabled: root._v(["lock", "enabled"], true)
        onEnabledChanged: if (root._ready) root.set(["lock", "enabled"], enabled)
        property bool useWallpaper: root._v(["lock", "useWallpaper"], false)
        onUseWallpaperChanged: if (root._ready) root.set(["lock", "useWallpaper"], useWallpaper)
        property bool recolourLogo: root._v(["lock", "recolourLogo"], true)
        onRecolourLogoChanged: if (root._ready) root.set(["lock", "recolourLogo"], recolourLogo)
        property bool enableFprint: root._v(["lock", "enableFprint"], true)
        onEnableFprintChanged: if (root._ready) root.set(["lock", "enableFprint"], enableFprint)
        property int maxFprintTries: root._v(["lock", "maxFprintTries"], 3)
        onMaxFprintTriesChanged: if (root._ready) root.set(["lock", "maxFprintTries"], maxFprintTries)
        property bool enableHowdy: root._v(["lock", "enableHowdy"], true)
        onEnableHowdyChanged: if (root._ready) root.set(["lock", "enableHowdy"], enableHowdy)
        property int maxHowdyTries: root._v(["lock", "maxHowdyTries"], 3)
        onMaxHowdyTriesChanged: if (root._ready) root.set(["lock", "maxHowdyTries"], maxHowdyTries)
        property bool triggerHowdyOnWake: root._v(["lock", "triggerHowdyOnWake"], true)
        onTriggerHowdyOnWakeChanged: if (root._ready) root.set(["lock", "triggerHowdyOnWake"], triggerHowdyOnWake)
        property bool hideNotifs: root._v(["lock", "hideNotifs"], false)
        onHideNotifsChanged: if (root._ready) root.set(["lock", "hideNotifs"], hideNotifs)
        property bool enableSessionControls: root._v(["lock", "enableSessionControls"], false)
        onEnableSessionControlsChanged: if (root._ready) root.set(["lock", "enableSessionControls"], enableSessionControls)
    }
    readonly property QtObject nexus: QtObject {
        property int wallpapersPerRow: root._v(["nexus", "wallpapersPerRow"], 4)
        onWallpapersPerRowChanged: if (root._ready) root.set(["nexus", "wallpapersPerRow"], wallpapersPerRow)
        property int maxNetworksShown: root._v(["nexus", "maxNetworksShown"], 5)
        onMaxNetworksShownChanged: if (root._ready) root.set(["nexus", "maxNetworksShown"], maxNetworksShown)
        property int networkRescanInterval: root._v(["nexus", "networkRescanInterval"], 15000)
        onNetworkRescanIntervalChanged: if (root._ready) root.set(["nexus", "networkRescanInterval"], networkRescanInterval)
    }
    readonly property QtObject notifs: QtObject {
        property bool expire: root._v(["notifs", "expire"], true)
        onExpireChanged: if (root._ready) root.set(["notifs", "expire"], expire)
        property int fullscreen: root._e(["notifs", "fullscreen"], ["On", "Off"], 0)
        onFullscreenChanged: if (root._ready) root.set(["notifs", "fullscreen"], fullscreen)
        property int defaultExpireTimeout: root._v(["notifs", "defaultExpireTimeout"], 5000)
        onDefaultExpireTimeoutChanged: if (root._ready) root.set(["notifs", "defaultExpireTimeout"], defaultExpireTimeout)
        property int fullscreenExpireTimeout: root._v(["notifs", "fullscreenExpireTimeout"], 2000)
        onFullscreenExpireTimeoutChanged: if (root._ready) root.set(["notifs", "fullscreenExpireTimeout"], fullscreenExpireTimeout)
        property real clearThreshold: root._v(["notifs", "clearThreshold"], 0.3)
        onClearThresholdChanged: if (root._ready) root.set(["notifs", "clearThreshold"], clearThreshold)
        property int expandThreshold: root._v(["notifs", "expandThreshold"], 20)
        onExpandThresholdChanged: if (root._ready) root.set(["notifs", "expandThreshold"], expandThreshold)
        property bool actionOnClick: root._v(["notifs", "actionOnClick"], false)
        onActionOnClickChanged: if (root._ready) root.set(["notifs", "actionOnClick"], actionOnClick)
        property int groupPreviewNum: root._v(["notifs", "groupPreviewNum"], 3)
        onGroupPreviewNumChanged: if (root._ready) root.set(["notifs", "groupPreviewNum"], groupPreviewNum)
        property bool openExpanded: root._v(["notifs", "openExpanded"], false)
        onOpenExpandedChanged: if (root._ready) root.set(["notifs", "openExpanded"], openExpanded)
    }
    readonly property QtObject osd: QtObject {
        property bool enabled: root._v(["osd", "enabled"], true)
        onEnabledChanged: if (root._ready) root.set(["osd", "enabled"], enabled)
        property int hideDelay: root._v(["osd", "hideDelay"], 2000)
        onHideDelayChanged: if (root._ready) root.set(["osd", "hideDelay"], hideDelay)
        property bool enableBrightness: root._v(["osd", "enableBrightness"], true)
        onEnableBrightnessChanged: if (root._ready) root.set(["osd", "enableBrightness"], enableBrightness)
        property bool enableMicrophone: root._v(["osd", "enableMicrophone"], false)
        onEnableMicrophoneChanged: if (root._ready) root.set(["osd", "enableMicrophone"], enableMicrophone)
    }
    readonly property QtObject services: QtObject {
        property string weatherLocation: root._v(["services", "weatherLocation"], "")
        onWeatherLocationChanged: if (root._ready) root.set(["services", "weatherLocation"], weatherLocation)
        property int weatherUnits: root._e(["services", "weatherUnits"], ["Auto", "Celsius", "Fahrenheit", "Kelvin"], 0)
        onWeatherUnitsChanged: if (root._ready) root.set(["services", "weatherUnits"], weatherUnits)
        property int sensorUnits: root._e(["services", "sensorUnits"], ["Auto", "Celsius", "Fahrenheit", "Kelvin"], 1)
        onSensorUnitsChanged: if (root._ready) root.set(["services", "sensorUnits"], sensorUnits)
        property int dataUnits: root._e(["services", "dataUnits"], ["Binary", "Decimal"], 0)
        onDataUnitsChanged: if (root._ready) root.set(["services", "dataUnits"], dataUnits)
        property int clockFormat: root._e(["services", "clockFormat"], ["Auto", "TwelveHour", "TwentyFourHour"], 0)
        onClockFormatChanged: if (root._ready) root.set(["services", "clockFormat"], clockFormat)
        property int gpuType: root._e(["services", "gpuType"], ["Auto", "Nvidia", "Generic", "None"], 0)
        onGpuTypeChanged: if (root._ready) root.set(["services", "gpuType"], gpuType)
        property int visualiserBars: root._v(["services", "visualiserBars"], 60)
        onVisualiserBarsChanged: if (root._ready) root.set(["services", "visualiserBars"], visualiserBars)
        property real audioIncrement: root._v(["services", "audioIncrement"], 0.1)
        onAudioIncrementChanged: if (root._ready) root.set(["services", "audioIncrement"], audioIncrement)
        property real brightnessIncrement: root._v(["services", "brightnessIncrement"], 0.1)
        onBrightnessIncrementChanged: if (root._ready) root.set(["services", "brightnessIncrement"], brightnessIncrement)
        property real maxVolume: root._v(["services", "maxVolume"], 1.0)
        onMaxVolumeChanged: if (root._ready) root.set(["services", "maxVolume"], maxVolume)
        property bool smartScheme: root._v(["services", "smartScheme"], true)
        onSmartSchemeChanged: if (root._ready) root.set(["services", "smartScheme"], smartScheme)
        property string defaultPlayer: root._v(["services", "defaultPlayer"], "Spotify")
        onDefaultPlayerChanged: if (root._ready) root.set(["services", "defaultPlayer"], defaultPlayer)
        readonly property ConfigList playerAliases: ConfigList { store: root; path: ["services", "playerAliases"]; defaults: [{"from": "com.github.th_ch.youtube_music", "to": "YT Music"}] }
        property int lyricsBackend: root._e(["services", "lyricsBackend"], ["Auto", "Local", "LRCLIB", "NetEase"], 0)
        onLyricsBackendChanged: if (root._ready) root.set(["services", "lyricsBackend"], lyricsBackend)
    }
    readonly property QtObject session: QtObject {
        property bool enabled: root._v(["session", "enabled"], true)
        onEnabledChanged: if (root._ready) root.set(["session", "enabled"], enabled)
        property int dragThreshold: root._v(["session", "dragThreshold"], 30)
        onDragThresholdChanged: if (root._ready) root.set(["session", "dragThreshold"], dragThreshold)
        property bool vimKeybinds: root._v(["session", "vimKeybinds"], false)
        onVimKeybindsChanged: if (root._ready) root.set(["session", "vimKeybinds"], vimKeybinds)
        readonly property QtObject icons: QtObject {
            property string logout: root._v(["session", "icons", "logout"], "logout")
            onLogoutChanged: if (root._ready) root.set(["session", "icons", "logout"], logout)
            property string shutdown: root._v(["session", "icons", "shutdown"], "power_settings_new")
            onShutdownChanged: if (root._ready) root.set(["session", "icons", "shutdown"], shutdown)
            property string hibernate: root._v(["session", "icons", "hibernate"], "downloading")
            onHibernateChanged: if (root._ready) root.set(["session", "icons", "hibernate"], hibernate)
            property string reboot: root._v(["session", "icons", "reboot"], "cached")
            onRebootChanged: if (root._ready) root.set(["session", "icons", "reboot"], reboot)
        }
        readonly property QtObject commands: QtObject {
            property var logout: root._v(["session", "commands", "logout"], ["logout"])
            onLogoutChanged: if (root._ready) root.set(["session", "commands", "logout"], logout)
            property var shutdown: root._v(["session", "commands", "shutdown"], ["poweroff"])
            onShutdownChanged: if (root._ready) root.set(["session", "commands", "shutdown"], shutdown)
            property var hibernate: root._v(["session", "commands", "hibernate"], ["hibernate"])
            onHibernateChanged: if (root._ready) root.set(["session", "commands", "hibernate"], hibernate)
            property var reboot: root._v(["session", "commands", "reboot"], ["reboot"])
            onRebootChanged: if (root._ready) root.set(["session", "commands", "reboot"], reboot)
        }
    }
    readonly property QtObject sidebar: QtObject {
        property bool enabled: root._v(["sidebar", "enabled"], true)
        onEnabledChanged: if (root._ready) root.set(["sidebar", "enabled"], enabled)
        property bool showOnHover: root._v(["sidebar", "showOnHover"], false)
        onShowOnHoverChanged: if (root._ready) root.set(["sidebar", "showOnHover"], showOnHover)
        property int minHoverThreshold: root._v(["sidebar", "minHoverThreshold"], 200)
        onMinHoverThresholdChanged: if (root._ready) root.set(["sidebar", "minHoverThreshold"], minHoverThreshold)
        property int dragThreshold: root._v(["sidebar", "dragThreshold"], 80)
        onDragThresholdChanged: if (root._ready) root.set(["sidebar", "dragThreshold"], dragThreshold)
    }
    readonly property QtObject utilities: QtObject {
        property bool enabled: root._v(["utilities", "enabled"], true)
        onEnabledChanged: if (root._ready) root.set(["utilities", "enabled"], enabled)
        property int maxToasts: root._v(["utilities", "maxToasts"], 4)
        onMaxToastsChanged: if (root._ready) root.set(["utilities", "maxToasts"], maxToasts)
        readonly property QtObject cards: QtObject {
            property bool keepAwake: root._v(["utilities", "cards", "keepAwake"], true)
            onKeepAwakeChanged: if (root._ready) root.set(["utilities", "cards", "keepAwake"], keepAwake)
            property bool recorder: root._v(["utilities", "cards", "recorder"], true)
            onRecorderChanged: if (root._ready) root.set(["utilities", "cards", "recorder"], recorder)
            property bool quickToggles: root._v(["utilities", "cards", "quickToggles"], true)
            onQuickTogglesChanged: if (root._ready) root.set(["utilities", "cards", "quickToggles"], quickToggles)
        }
        readonly property QtObject toasts: QtObject {
            property string fullscreen: root._v(["utilities", "toasts", "fullscreen"], "off")
            onFullscreenChanged: if (root._ready) root.set(["utilities", "toasts", "fullscreen"], fullscreen)
            property bool configLoaded: root._v(["utilities", "toasts", "configLoaded"], true)
            onConfigLoadedChanged: if (root._ready) root.set(["utilities", "toasts", "configLoaded"], configLoaded)
            property bool chargingChanged: root._v(["utilities", "toasts", "chargingChanged"], true)
            onChargingChangedChanged: if (root._ready) root.set(["utilities", "toasts", "chargingChanged"], chargingChanged)
            property bool gameModeChanged: root._v(["utilities", "toasts", "gameModeChanged"], true)
            onGameModeChangedChanged: if (root._ready) root.set(["utilities", "toasts", "gameModeChanged"], gameModeChanged)
            property bool dndChanged: root._v(["utilities", "toasts", "dndChanged"], true)
            onDndChangedChanged: if (root._ready) root.set(["utilities", "toasts", "dndChanged"], dndChanged)
            property bool audioOutputChanged: root._v(["utilities", "toasts", "audioOutputChanged"], true)
            onAudioOutputChangedChanged: if (root._ready) root.set(["utilities", "toasts", "audioOutputChanged"], audioOutputChanged)
            property bool audioInputChanged: root._v(["utilities", "toasts", "audioInputChanged"], true)
            onAudioInputChangedChanged: if (root._ready) root.set(["utilities", "toasts", "audioInputChanged"], audioInputChanged)
            property bool capsLockChanged: root._v(["utilities", "toasts", "capsLockChanged"], true)
            onCapsLockChangedChanged: if (root._ready) root.set(["utilities", "toasts", "capsLockChanged"], capsLockChanged)
            property bool numLockChanged: root._v(["utilities", "toasts", "numLockChanged"], true)
            onNumLockChangedChanged: if (root._ready) root.set(["utilities", "toasts", "numLockChanged"], numLockChanged)
            property bool kbLayoutChanged: root._v(["utilities", "toasts", "kbLayoutChanged"], true)
            onKbLayoutChangedChanged: if (root._ready) root.set(["utilities", "toasts", "kbLayoutChanged"], kbLayoutChanged)
            property bool kbLimit: root._v(["utilities", "toasts", "kbLimit"], true)
            onKbLimitChanged: if (root._ready) root.set(["utilities", "toasts", "kbLimit"], kbLimit)
            property bool vpnChanged: root._v(["utilities", "toasts", "vpnChanged"], true)
            onVpnChangedChanged: if (root._ready) root.set(["utilities", "toasts", "vpnChanged"], vpnChanged)
            property bool nowPlaying: root._v(["utilities", "toasts", "nowPlaying"], false)
            onNowPlayingChanged: if (root._ready) root.set(["utilities", "toasts", "nowPlaying"], nowPlaying)
        }
        readonly property QtObject vpn: QtObject {
            property bool enabled: root._v(["utilities", "vpn", "enabled"], false)
            onEnabledChanged: if (root._ready) root.set(["utilities", "vpn", "enabled"], enabled)
            readonly property ConfigList provider: ConfigList { store: root; path: ["utilities", "vpn", "provider"]; defaults: [] }
            property string selectedProvider: root._v(["utilities", "vpn", "selectedProvider"], "")
            onSelectedProviderChanged: if (root._ready) root.set(["utilities", "vpn", "selectedProvider"], selectedProvider)
        }
        readonly property ConfigList quickToggles: ConfigList { store: root; path: ["utilities", "quickToggles"]; defaults: [{"id": "wifi", "enabled": true}, {"id": "bluetooth", "enabled": true}, {"id": "mic", "enabled": true}, {"id": "settings", "enabled": true}, {"id": "gameMode", "enabled": true}, {"id": "wallpaperPlaying", "enabled": true}, {"id": "dnd", "enabled": true}, {"id": "vpn", "enabled": false}] }
    }
    readonly property QtObject paths: QtObject {
        property string wallpaperDir: root._v(["paths", "wallpaperDir"], root._std(StandardPaths.writableLocation) + "/Wallpapers")
        onWallpaperDirChanged: if (root._ready) root.set(["paths", "wallpaperDir"], wallpaperDir)
        property string lyricsDir: root._v(["paths", "lyricsDir"], root._std(StandardPaths.writableLocation) + "/Lyrics/")
        onLyricsDirChanged: if (root._ready) root.set(["paths", "lyricsDir"], lyricsDir)
        property string sessionGif: root._v(["paths", "sessionGif"], "root:/assets/kurukuru.gif")
        onSessionGifChanged: if (root._ready) root.set(["paths", "sessionGif"], sessionGif)
        property string mediaGif: root._v(["paths", "mediaGif"], "root:/assets/bongocat.gif")
        onMediaGifChanged: if (root._ready) root.set(["paths", "mediaGif"], mediaGif)
        property string noNotifsPic: root._v(["paths", "noNotifsPic"], "root:/assets/dino.png")
        onNoNotifsPicChanged: if (root._ready) root.set(["paths", "noNotifsPic"], noNotifsPic)
        property string lockNoNotifsPic: root._v(["paths", "lockNoNotifsPic"], "root:/assets/dino.png")
        onLockNoNotifsPicChanged: if (root._ready) root.set(["paths", "lockNoNotifsPic"], lockNoNotifsPic)
    }
}
