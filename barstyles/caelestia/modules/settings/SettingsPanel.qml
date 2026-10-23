pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../config"
import "../../components"
import "../../components/containers"
import "../../components/controls"
import "../../services"
import "schema/Bar.js" as BarRows
import "schema/Panels.js" as PanelRows
import "schema/Style.js" as StyleRows

// The style's own settings: the Hub's Caelestia pages, drawn here because a store
// style adds no Hub pages. Every change goes straight to shell.json and applies live.
StyledWindow {
    id: root

    readonly property var pages: [
        { id: "bar", name: qsTr("Bar"), rows: BarRows.rows },
        { id: "panels", name: qsTr("Panels"), rows: PanelRows.rows },
        { id: "style", name: qsTr("Style"), rows: StyleRows.rows }
    ]
    readonly property var page: pages.find(p => p.id === Hub.settingsPage) ?? pages[0]
    readonly property var tabs: [...new Set(page.rows.map(r => r.tab))]
    property string tab: ""
    readonly property string currentTab: tabs.includes(tab) ? tab : tabs[0]
    property string query: ""

    // "caelestia.bar.persistent" -> the raw value in shell.json, or the row's default
    function valueOf(row: var): var {
        const v = GlobalConfig._at(row.key.split(".").slice(1));
        return v === undefined || v === null ? row.def : v;
    }

    function shown(row: var): bool {
        for (const k in row.when ?? {}) {
            const dep = root.allRows.find(r => r.key === k);
            if (!row.when[k].includes(dep ? root.valueOf(dep) : undefined))
                return false;
        }
        return true;
    }

    readonly property var allRows: [].concat(BarRows.rows, PanelRows.rows, StyleRows.rows)
    readonly property var visibleRows: {
        const q = query.trim().toLowerCase();
        const rows = q ? allRows.filter(r => `${r.label} ${r.desc ?? ""}`.toLowerCase().includes(q)) : page.rows.filter(r => r.tab === currentTab);
        return rows.filter(shown);
    }

    name: "caelestia-settings"
    visible: Hub.settingsOpen
    implicitWidth: 820
    implicitHeight: 640
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    IpcHandler {
        target: "caelestiaSettings"

        function toggle(): void {
            Hub.settingsOpen = !Hub.settingsOpen;
        }

        function open(page: string): void {
            Hub.open(page ? `shell${page}` : "shellbar");
        }

        function close(): void {
            Hub.settingsOpen = false;
        }
    }

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.extraLarge
        color: Colours.palette.m3surfaceContainer
        focus: true
        Keys.onEscapePressed: Hub.settingsOpen = false

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.extraLarge
            spacing: Tokens.spacing.large

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "tune"
                    fontStyle: Tokens.font.icon.builders.large.build()
                }

                StyledText {
                    text: qsTr("Caelestia settings")
                    font: Tokens.font.title.medium
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledTextField {
                    Layout.preferredWidth: 240
                    leadingIcon: "search"
                    placeholderText: qsTr("Search settings")
                    onTextChanged: root.query = text
                }

                IconButton {
                    icon: "close"
                    type: IconButton.Text
                    onClicked: Hub.settingsOpen = false
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.query.trim() === ""
                spacing: Tokens.spacing.small

                Repeater {
                    model: root.pages

                    TextButton {
                        required property var modelData

                        text: modelData.name
                        type: root.page.id === modelData.id ? TextButton.Filled : TextButton.Tonal
                        onClicked: Hub.settingsPage = modelData.id
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                visible: root.query.trim() === "" && root.tabs.length > 1
                spacing: Tokens.spacing.small

                Repeater {
                    model: root.tabs

                    TextButton {
                        required property string modelData

                        text: modelData
                        type: root.currentTab === modelData ? TextButton.Tonal : TextButton.Text
                        onClicked: root.tab = modelData
                    }
                }
            }

            StyledFlickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: rows.implicitHeight

                ColumnLayout {
                    id: rows

                    width: parent.width
                    spacing: Tokens.spacing.large

                    Repeater {
                        model: root.visibleRows

                        ColumnLayout {
                            id: entry

                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            StyledText {
                                visible: entry.index === 0 || root.visibleRows[entry.index - 1].group !== entry.modelData.group
                                Layout.topMargin: entry.index === 0 ? 0 : Tokens.spacing.medium
                                text: entry.modelData.group
                                color: Colours.palette.m3primary
                                font: Tokens.font.label.medium
                            }

                            SettingRow {
                                Layout.fillWidth: true
                                row: entry.modelData
                                value: root.valueOf(entry.modelData)
                                onEdited: v => GlobalConfig.set(entry.modelData.key.split(".").slice(1), v)
                            }
                        }
                    }

                    StyledText {
                        visible: root.visibleRows.length === 0
                        text: qsTr("No settings match")
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }
    }
}
