pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../services"
import "."

// The nine search panels this launcher ports from the barstyle's overview.
// Everything else the upstream registry listed (AI, bluetooth, translator,
// file browser, speed test, settings toggles, ...) is cut, and its prefix
// routes with it.
Singleton {
    id: root

    // The AI chat is not part of this port. Keeping the flag keeps the gated
    // AI branches in the ported surfaces on their off path without edits.
    readonly property bool aiPolicyEnabled: false

    readonly property var panels: [
        { id: "clipboard", source: "ClipboardPanel.qml", prefixKey: "clipboard", keywords: ["clipboard", "clip", "paste"], label: qsTr("Clipboard"), icon: "content_paste", searchIcon: "content_paste_search", searchShape: "Gem", searchRotationStep: 90, width: () => Config.options.search.clipboard.panelWidth ?? 860, enabled: () => Config.options.search.modules.clipboard, accent: false, focusMode: "list", queryProperty: "searchQuery", hosted: true },
        { id: "emojis", source: "EmojiPanel.qml", prefixKey: "emojis", keywords: ["emoji", "emojis", "emoticon", "smiley"], label: qsTr("Emojis"), icon: "mood", searchIcon: "add_reaction", searchShape: "Sunny", searchRotationStep: 45, width: () => Config.options.search.appearance.panelWidth, enabled: () => Config.options.search.modules.emojis.enable, accent: true, focusMode: "grid", queryProperty: "searchQuery", hosted: true },
        { id: "commands", source: "CommandsPanel.qml", prefixKey: "", keywords: ["command", "commands", "cmd", "terminal"], label: qsTr("Commands"), icon: "terminal", searchIcon: "terminal", searchShape: "Ghostish", searchRotationStep: 360, width: () => Config.options.search.appearance.panelWidth, enabled: () => true, accent: true, focusMode: "list", queryProperty: "searchQuery", hosted: true }
    ]

    readonly property var enabledPanels: root.panels.filter(panel => panel.enabled())
    readonly property var activePrefixes: root.enabledPanels.map(panel => root.prefixOf(panel)).filter(prefix => prefix.length > 0)
    // Alias configuration is a catalogue, not a snapshot of the currently
    // enabled Loaders. Keeping every public panel here lets users prepare an
    // alias before enabling its module, while LauncherSearch still suppresses
    // execution until the target itself is enabled.
    readonly property var aliasTargets: root.panels.filter(panel => panel.aliasable !== false).map(panel => ({
        id: panel.id,
        name: panel.label,
        icon: panel.icon,
        enabled: panel.enabled()
    }))

    function byId(panelId) {
        return root.panels.find(panel => panel.id === panelId) ?? null;
    }

    function prefixOf(panel) {
        if (!panel?.prefixKey)
            return "";
        return String(Config.options.search.prefix[panel.prefixKey] ?? "");
    }

    function resolve(query) {
        const text = String(query ?? "");
        for (const panel of root.enabledPanels) {
            const prefix = root.prefixOf(panel);
            if (prefix.length > 0 && text.startsWith(prefix))
                return panel;
        }
        return null;
    }
}
