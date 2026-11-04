pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Ryoku.Ui.Singletons
import shell.services as HostServices

// Screen filters for the quick toggle and its dialog, over the host's screen
// shader switch: Ryoku's compositor provider resolves a shader by name, the
// choice is persisted in the host config, and Wm applies it live. There are no
// shader files to scan and no hyprshade; the name list is the host's.
Singleton {
    id: root

    // Every consumer of the old API can ask this instead of probing for a daemon.
    readonly property bool hyprshadeAvailable: Wm.caps.screenShader === true

    readonly property var shaders: root.hyprshadeAvailable
        ? Array.from(HostServices.Config.screenShaders)
            .filter(name => name.length > 0)
            .map(name => ({ name: name, path: "", dir: "Ryoku", source: "ryoku" }))
        : []

    readonly property string activeName: root.hyprshadeAvailable ? String(HostServices.Config.screenShader ?? "") : ""
    readonly property bool active: root.activeName.length > 0
    // The old dialog printed the applied file path; the name is what identifies
    // a Ryoku shader.
    readonly property string activePath: root.activeName

    readonly property string statusText: root.active ? root.displayName(root.activeName) : Translation.tr("Off")
    readonly property bool loading: false
    property string errorMessage: ""

    // Left click turns on the first shader the host ships; there is no history to replay.
    readonly property string defaultShaderName: root.shaders.length > 0 ? root.shaders[0].name : ""

    function displayName(name: string): string {
        if (name.length === 0)
            return Translation.tr("Off");
        const spaced = name.replace(/[-_]+/g, " ").trim();
        return spaced.charAt(0).toUpperCase() + spaced.slice(1);
    }

    function iconFor(name: string): string {
        switch (name) {
        case "halftone":
            return "blur_on";
        case "bone":
            return "texture";
        case "onebit":
            return "contrast";
        case "vignette":
            return "gradient";
        case "grain":
            return "grain";
        case "grayscale":
            return "filter_b_and_w";
        case "invert-colors":
            return "invert_colors";
        case "sepia":
            return "filter_vintage";
        case "anti-flashbang":
            return "flash_off";
        case "blue-light-filter":
            return "bedtime";
        default:
            return "tonality";
        }
    }

    function findShader(name: string): var {
        return Array.from(root.shaders).find(shader => shader.name === name) ?? null;
    }

    function apply(name: string) {
        if (!root.hyprshadeAvailable)
            return;
        root.errorMessage = "";
        HostServices.Config.setScreenShader(String(name ?? ""));
    }

    function clear() {
        root.apply("");
    }

    function toggle() {
        if (root.active) {
            root.clear();
            return;
        }
        if (root.defaultShaderName.length > 0)
            root.apply(root.defaultShaderName);
    }

    // The host config pushes state on its own; nothing to rescan.
    function refresh() {}
}
