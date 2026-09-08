pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "lib/binds.js" as Binds
import "Singletons"

/**
 * 鍵 KEYBINDS surface: a read-only, searchable reference of the keyboard
 * shortcuts parsed from ~/.config/hypr/modules/binds.lua -- each row a combo chip
 * on the left and its name or derived action on the right; hovering a row reveals
 * the underlying command. This surface never writes the file: binds.lua is owned
 * by Ryoku, so editing a shortcut hands off to Ryoku Settings > Keybinds
 * (`ryoku-shell hub open keybinds`) rather than rewriting the compositor's config
 * behind its back. Tapping a row, pressing Return, or the bottom bar opens that
 * page. Reached from its IPC route; morphs back on the back chevron.
 */
PillSurface {
    id: root

    mTop: 15
    mLeft: 19
    mRight: 19
    mBottom: 14

    implicitHeight: content.implicitHeight

    signal requestSurface(string name)

    readonly property string bindsPath: Quickshell.env("HOME") + "/.config/hypr/modules/binds.lua"

    property var binds: []
    property int focusIndex: 0
    property string query: ""

    /**
     * Binds whose combo, label, name or inner command contains the current query
     * as a case-insensitive substring. An empty query passes every bind through.
     */
    readonly property var filtered: {
        if (root.query.length === 0)
            return root.binds;
        var q = root.query.toLowerCase();
        return root.binds.filter(function (b) {
            return (b.combo + " " + b.label + " " + b.name + " " + b.cmd).toLowerCase().indexOf(q) !== -1;
        });
    }

    /**
     * Display form of a combo: mouse tokens are spelled out so a scroll or button
     * gesture reads clearly.
     */
    function comboPretty(c) {
        return c.replace("mouse_up", "Scroll ↑")
                .replace("mouse_down", "Scroll ↓")
                .replace("mouse:272", "LMB")
                .replace("mouse:273", "RMB");
    }

    function refresh() {
        root.binds = Binds.parse(bindsFile.text());
        if (root.focusIndex >= root.filtered.length)
            root.focusIndex = Math.max(0, root.filtered.length - 1);
    }

    /**
     * Slide the focused row by `dir` (+1 down, -1 up), clamped over the filtered
     * list, and keep it in view.
     */
    function move(dir) {
        if (root.filtered.length === 0)
            return;
        root.focusIndex = Math.max(0, Math.min(root.filtered.length - 1, root.focusIndex + dir));
        list.positionViewAtIndex(root.focusIndex, ListView.Contain);
    }

    /** Enter / row-tap: hand editing to Ryoku Settings, which owns binds.lua. */
    function activate() {
        openKeybindSettings();
    }

    function openKeybindSettings() {
        Quickshell.execDetached(["ryoku-shell", "hub", "open", "keybinds"]);
    }

    onActiveChanged: {
        if (active) {
            bindsFile.reload();
            refresh();
            focusIndex = 0;
            query = "";
        }
    }

    readonly property Item focusRowItem: list.focusRowItem

    readonly property bool rowFocused: focusRowItem !== null && active

    readonly property point rowPoint: {
        void root.width;
        void root.height;
        void root.focusIndex;
        void list.contentY;
        if (!focusRowItem)
            return Qt.point(4 * root.s, root.height / 2);
        return focusRowItem.mapToItem(root, 4 * root.s, focusRowItem.height / 2);
    }

    ameForm: rowFocused ? "rowseam" : "off"
    amePoint: rowPoint

    FileView {
        id: bindsFile
        path: root.bindsPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.refresh()
        onFileChanged: reload()
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Item {
            width: parent.width
            height: 22 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.showGlyphs
                    text: "鍵"
                    color: Theme.cream
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 16 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "KEYBINDS"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.6 * root.s
                }
            }

            GlyphIcon {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-left"
                color: Theme.iconDim
                stroke: 2.2
            }
        }

        Item { width: 1; height: 8 * root.s }

        Item {
            width: parent.width
            height: 28 * root.s

            Text {
                id: searchGlyph
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: Flags.showGlyphs
                width: Flags.showGlyphs ? implicitWidth : 0
                text: "探"
                color: Theme.dim
                font.family: Theme.fontJp
                font.weight: Font.Medium
                font.pixelSize: 15 * root.s
            }

            TextField {
                id: searchField
                anchors.left: searchGlyph.right
                anchors.leftMargin: Flags.showGlyphs ? 9 * root.s : 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                background: null
                padding: 0
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 13 * root.s
                placeholderText: "search binds"
                placeholderTextColor: Theme.faint
                selectByMouse: true
                selectionColor: Theme.verm
                onTextChanged: {
                    root.query = text;
                    root.focusIndex = 0;
                }
                Keys.onPressed: (e) => {
                    if (e.key === Qt.Key_Down) {
                        root.move(1);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Up) {
                        root.move(-1);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                        root.activate();
                        e.accepted = true;
                    }
                }
            }

            Rectangle {
                anchors.left: searchField.left
                anchors.right: searchField.right
                anchors.top: searchField.bottom
                anchors.topMargin: 3 * root.s
                height: 1
                color: Theme.faint
                opacity: searchField.activeFocus ? 0.7 : 0.18
                Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }
        }

        Item { width: 1; height: 8 * root.s }

        ListView {
            id: list
            width: parent.width
            height: Math.min(contentHeight, 250 * root.s)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.filtered

            property Item focusRowItem: null

            delegate: Item {
                id: brow
                required property int index
                required property var modelData

                readonly property bool focused: root.focusIndex === brow.index

                width: ListView.view.width
                height: 38 * root.s

                onFocusedChanged: if (focused) list.focusRowItem = brow

                HoverHandler {
                    id: rowHover
                    onHoveredChanged: if (hovered) root.focusIndex = brow.index
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 3 * root.s
                    anchors.bottomMargin: 3 * root.s
                    radius: 9 * root.s
                    color: (rowHover.hovered || brow.focused) ? Theme.frameBg : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                Rectangle {
                    id: comboChip
                    anchors.left: parent.left
                    anchors.leftMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: comboText.implicitWidth + 16 * root.s
                    height: comboText.implicitHeight + 8 * root.s
                    radius: 7 * root.s
                    color: brow.focused ? Qt.alpha(Theme.vermLit, 0.16) : Theme.frameBg
                    border.width: 1
                    border.color: brow.focused ? Qt.alpha(Theme.vermLit, 0.45) : Theme.hairSoft
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    Text {
                        id: comboText
                        anchors.centerIn: parent
                        text: root.comboPretty(brow.modelData.combo)
                        color: brow.focused ? Theme.cream : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 0.3 * root.s
                    }
                }

                Column {
                    anchors.left: comboChip.right
                    anchors.leftMargin: 12 * root.s
                    anchors.right: parent.right
                    anchors.rightMargin: 14 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1 * root.s

                    Text {
                        anchors.right: parent.right
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        text: brow.modelData.label
                        color: brow.focused ? Theme.subtle : Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.right: parent.right
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        visible: rowHover.hovered && brow.modelData.cmd.length > 0
                        text: brow.modelData.cmd
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        font.weight: Font.Normal
                        elide: Text.ElideLeft
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.focusIndex = brow.index;
                        root.openKeybindSettings();
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 38 * root.s

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 5 * root.s
                anchors.bottomMargin: 5 * root.s
                radius: 9 * root.s
                color: editArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.1) : "transparent"
                border.width: 1
                border.color: Qt.alpha(Theme.vermLit, editArea.containsMouse ? 0.6 : 0.32)

                Text {
                    anchors.centerIn: parent
                    text: "Edit in Ryoku Settings"
                    color: Theme.vermLit
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.5 * root.s
                }

                MouseArea {
                    id: editArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openKeybindSettings()
                }
            }
        }

        Item { width: 1; height: 9 * root.s }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hairSoft
        }

        Item {
            width: parent.width
            height: 20 * root.s

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 4 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: "read-only · edit in ryoku settings · esc close"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1 * root.s
            }
        }
    }
}
