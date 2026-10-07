pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

// Panel: desktop widgets, pinned apps, and quick commands. EDIT reveals
// unpin / remove marks, the add rows, the widget picker, and each section's HIDE / SHOW.
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 380
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    function setting(key, def) { return root.service ? root.service.get(key, def) : def; }
    readonly property int cols: Math.max(3, Math.min(8, root.setting("columns", 5)))

    // section drag in flight: which section (by order), where it lands, its height
    property int secFrom: -1
    property int secTo: -1
    property real secDragH: 0
    // landing index for the section at `from` dragged by `dy`: the sections whose
    // middles end up above its middle
    function secTarget(from, dy) {
        const it = secRep.itemAt(from);
        const mid = it.y + it.height / 2 + dy;
        let t = 0;
        for (let i = 0; i < secRep.count; i++) {
            const o = secRep.itemAt(i);
            if (i !== from && o.visible && o.y + o.height / 2 < mid) t++;
        }
        return t;
    }
    property bool editing: false
    property bool adding: false

    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight + 32 * root.s

    onActiveChanged: if (!active) { editing = false; adding = false; }

    // a section: hairline, eyebrow, body. In EDIT every section shows its header with
    // a HIDE / SHOW pill (its show* setting); a hidden section keeps only that header.
    component Section: Column {
        id: sec
        property string label
        property string key     // its show* setting
        property string sid     // its id in the section order
        readonly property int pos: root.service ? root.service.sectionOrder.indexOf(sid) : 0
        readonly property bool shown: root.setting(key, true)
        readonly property bool dragging: secDrag.active
        // how far the section's wrapper is moved: with the pointer while dragged, aside
        // while another section passes it
        readonly property real offset: dragging ? secDrag.translation.y
            : root.secFrom < 0 ? 0
            : (pos > root.secFrom && pos <= root.secTo) ? -(root.secDragH + col.spacing)
            : (pos < root.secFrom && pos >= root.secTo) ? (root.secDragH + col.spacing) : 0
        default property alias body: secBody.data
        width: col.width
        spacing: 12 * root.s
        visible: root.editing || shown

        Rectangle { width: sec.width; height: 1; color: Theme.hair }
        Item {
            width: sec.width
            height: Math.max(secLabel.implicitHeight, secPill.height)
            // grip: drag the section
            Item {
                id: secGrip
                visible: root.editing
                width: visible ? 24 * root.s : 0
                height: 20 * root.s
                anchors.verticalCenter: parent.verticalCenter
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2.5 * root.s
                    Repeater {
                        model: 3
                        Rectangle {
                            width: 12 * root.s
                            height: 1.5 * root.s
                            radius: height / 2
                            color: sec.dragging || secGripHover.hovered ? Theme.accent : Theme.iconDim
                        }
                    }
                }
                HoverHandler { id: secGripHover; cursorShape: sec.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
                DragHandler {
                    id: secDrag
                    target: null
                    xAxis.enabled: false
                    onTranslationChanged: if (active) {
                        root.secFrom = sec.pos;
                        root.secDragH = sec.height;
                        root.secTo = root.secTarget(sec.pos, translation.y);
                    }
                    onActiveChanged: if (!active) {
                        const from = root.secFrom, to = root.secTo;
                        root.secFrom = -1;
                        root.secTo = -1;
                        if (from >= 0 && to >= 0 && from !== to) root.service.moveSection(from, to);
                    }
                }
            }
            MicroLabel {
                id: secLabel
                anchors.left: secGrip.right
                anchors.verticalCenter: parent.verticalCenter
                label: sec.label
                s: root.s
                opacity: sec.shown ? 1 : 0.45
            }
            Rectangle {
                id: secPill
                visible: root.editing
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: secPillText.implicitWidth + 14 * root.s
                height: 20 * root.s
                radius: height / 2
                color: secPillArea.containsMouse ? Theme.sheen : "transparent"
                border.width: 1
                border.color: sec.shown ? Theme.hair : Theme.accent
                Text {
                    id: secPillText
                    anchors.centerIn: parent
                    text: sec.shown ? "HIDE" : "SHOW"
                    color: sec.shown ? Theme.faint : Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: 9.5 * root.s
                    font.letterSpacing: 1.2 * root.s
                }
                MouseArea {
                    id: secPillArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.service.save(sec.key, !sec.shown)
                }
            }
        }
        Column {
            id: secBody
            visible: sec.shown
            width: sec.width
            spacing: 12 * root.s
        }
    }

    // a hairline chip: icon + label, accent on hover
    component Chip: Rectangle {
        id: chip
        property string label
        property string glyph: ""
        signal clicked()
        width: chipRow.implicitWidth + 22 * root.s
        height: 30 * root.s
        radius: Motion.rSmall * root.s
        color: chipArea.pressed ? Theme.threadBg : chipArea.containsMouse ? Theme.sheen : "transparent"
        border.width: 1
        border.color: chipArea.containsMouse ? Theme.accent : Theme.hair
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 7 * root.s
            GlyphIcon {
                visible: chip.glyph.length > 0
                anchors.verticalCenter: parent.verticalCenter
                width: 12 * root.s
                height: 12 * root.s
                name: chip.glyph
                color: chipArea.containsMouse ? Theme.accent : Theme.iconDim
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: chipArea.containsMouse ? Theme.bright : Theme.dim
                font.family: Theme.mono
                font.pixelSize: 11.5 * root.s
            }
        }
    }

    // a bordered single-line input
    component Field: Rectangle {
        id: fld
        property alias text: inp.text
        property alias input: inp
        property string placeholder
        signal accepted()
        height: 30 * root.s
        radius: Motion.rSmall * root.s
        color: "transparent"
        border.width: 1
        border.color: inp.activeFocus ? Theme.accent : Theme.border
        TextInput {
            id: inp
            anchors.fill: parent
            anchors.leftMargin: 10 * root.s
            anchors.rightMargin: 10 * root.s
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            color: Theme.bright
            selectionColor: Theme.accent
            selectedTextColor: Theme.cardBot
            font.family: Theme.mono
            font.pixelSize: 11.5 * root.s
            onAccepted: fld.accepted()
            Text {
                visible: !inp.text && !inp.activeFocus
                anchors.verticalCenter: parent.verticalCenter
                text: fld.placeholder
                color: Theme.faint
                font: inp.font
            }
        }
    }

    Column {
        id: col
        x: 16 * root.s
        y: 16 * root.s
        width: root.width - 32 * root.s
        spacing: 14 * root.s

        // header: title, EDIT toggle
        Item {
            width: col.width
            height: Math.max(head.implicitHeight, editPill.height)

            Text {
                id: head
                anchors.verticalCenter: parent.verticalCenter
                text: "Launchpad"
                color: Theme.bright
                font.family: Theme.display
                font.pixelSize: 20 * root.s
            }

            Rectangle {
                id: editPill
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: editText.implicitWidth + 18 * root.s
                height: editText.implicitHeight + 9 * root.s
                radius: height / 2
                color: root.editing ? Theme.threadBg : editArea.containsMouse ? Theme.sheen : "transparent"
                border.width: 1
                border.color: root.editing ? Theme.accent : Theme.border
                Text {
                    id: editText
                    anchors.centerIn: parent
                    text: root.editing ? "DONE" : "EDIT"
                    color: root.editing ? Theme.accent : Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 10.5 * root.s
                    font.letterSpacing: 1.2 * root.s
                }
                MouseArea {
                    id: editArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.editing = !root.editing; root.adding = false; }
                }
            }
        }

        // the sections, in your order (EDIT moves them)
        Repeater {
            id: secRep
            model: root.service ? root.service.sectionOrder : []
            delegate: Item {
                id: secSlot
                required property string modelData
                readonly property var sec: secLoader.item
                width: col.width
                height: secLoader.height
                visible: root.editing || root.setting(({ widgets: "showWidgets", pinned: "showPinned", commands: "showCommands" })[modelData], true)
                z: sec && sec.dragging ? 10 : 0
                transform: Translate {
                    y: secSlot.sec ? secSlot.sec.offset : 0
                    Behavior on y {
                        enabled: !(secSlot.sec && secSlot.sec.dragging)
                        NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
                    }
                }
                // the lifted card under a dragged section
                Rectangle {
                    visible: !!secSlot.sec && secSlot.sec.dragging
                    x: -8 * root.s
                    y: -4 * root.s
                    width: parent.width + 16 * root.s
                    height: parent.height + 12 * root.s
                    radius: Motion.rSmall * root.s
                    color: Theme.cardBot
                    border.width: 1
                    border.color: Theme.accent
                }
                Loader {
                    id: secLoader
                    width: col.width
                    sourceComponent: ({ widgets: widgetsSec, pinned: pinnedSec, commands: commandsSec })[secSlot.modelData]
                }
            }
        }
    }

    // desktop widgets
    Component {
        id: widgetsSec
        Section {
            label: "Widgets"
            key: "showWidgets"
            sid: "widgets"
            DeskWidgets {
                width: col.width
                s: root.s
                active: root.active
                editing: root.editing
                service: root.service
            }
        }
    }

    // pinned apps
    Component {
        id: pinnedSec
        Section {
            label: "Pinned"
            key: "showPinned"
            sid: "pinned"
            Grid {
                id: grid
                visible: !root.editing
                width: col.width
                columns: root.cols
                readonly property real cell: width / root.cols

                Repeater {
                    model: root.service ? root.service.pinned : []
                    delegate: Item {
                        id: tile
                        required property var modelData
                        width: grid.cell
                        height: 66 * root.s

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2 * root.s
                            radius: Motion.rSmall * root.s
                            color: tileArea.containsMouse ? Theme.sheen : "transparent"
                            border.width: 1
                            border.color: tileArea.containsMouse ? Theme.accent : "transparent"
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }
                        Image {
                            id: appIcon
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 9 * root.s
                            width: 30 * root.s
                            height: 30 * root.s
                            sourceSize: Qt.size(width * 2, height * 2)
                            source: root.service ? root.service.icon(tile.modelData) : ""
                            asynchronous: true
                        }
                        // fallback monogram when the theme has no icon
                        Text {
                            visible: appIcon.status !== Image.Ready
                            anchors.centerIn: appIcon
                            text: tile.modelData.name.charAt(0).toUpperCase()
                            color: Theme.accent
                            font.family: Theme.display
                            font.pixelSize: 20 * root.s
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: appIcon.bottom
                            anchors.topMargin: 6 * root.s
                            width: parent.width - 8 * root.s
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.modelData.name
                            color: tileArea.containsMouse ? Theme.bright : Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 10 * root.s
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: tileArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.service.launch(tile.modelData)
                        }
                    }
                }

                // add tile
                Item {
                    visible: root.adding || (root.service && root.service.pinned.length === 0)
                    width: grid.cell
                    height: 66 * root.s
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2 * root.s
                        radius: Motion.rSmall * root.s
                        color: "transparent"
                        border.width: 1
                        border.color: addArea.containsMouse || root.adding ? Theme.accent : Theme.border
                    }
                    Text {
                        anchors.centerIn: parent
                        text: root.adding ? "−" : "+"
                        color: addArea.containsMouse || root.adding ? Theme.accent : Theme.faint
                        font.family: Theme.display
                        font.pixelSize: 22 * root.s
                    }
                    MouseArea {
                        id: addArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.adding = !root.adding;
                            if (root.adding) Qt.callLater(() => search.input.forceActiveFocus());
                        }
                    }
                }
            }

            // EDIT: pinned apps in order, then a button that opens the picker
            Column {
                visible: root.editing
                width: col.width
                spacing: 6 * root.s
                OrderList {
                    width: col.width
                    s: root.s
                    model: root.editing && root.service ? root.service.pinned : []
                    labelOf: (e) => e.name
                    iconOf: (e) => root.service.icon(e)
                    onMoveTo: (from, to) => root.service.moveApp(from, to)
                    onRemove: (i) => root.service.togglePin(root.service.pinned[i])
                }
                Chip {
                    label: root.adding ? "Done adding" : "Pin an app"
                    glyph: root.adding ? "check" : "install"
                    onClicked: {
                        root.adding = !root.adding;
                        if (root.adding) Qt.callLater(() => search.input.forceActiveFocus());
                    }
                }
            }

            // app picker
            Column {
                visible: root.adding
                width: col.width
                spacing: 6 * root.s

                SearchField {
                    id: search
                    width: col.width
                    s: root.s
                    kanji: "探"
                    placeholder: "Find an app to pin"
                    onDismissed: root.adding = false
                }
                Rectangle { width: col.width; height: 1; color: Theme.hair }

                Repeater {
                    model: {
                        if (!root.adding || !root.service) return [];
                        const q = search.text.toLowerCase();
                        return root.service.allApps.filter(e => !q || e.name.toLowerCase().includes(q)
                            || String(e.genericName || "").toLowerCase().includes(q)).slice(0, 6);
                    }
                    delegate: Rectangle {
                        id: pick
                        required property var modelData
                        readonly property bool on: root.service ? root.service.isPinned(modelData) : false
                        width: col.width
                        height: 34 * root.s
                        radius: Motion.rSmall * root.s
                        color: pickArea.containsMouse ? Theme.sheen : "transparent"
                        Image {
                            id: pickIcon
                            x: 8 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20 * root.s
                            height: 20 * root.s
                            sourceSize: Qt.size(width * 2, height * 2)
                            source: root.service ? root.service.icon(pick.modelData) : ""
                            asynchronous: true
                        }
                        Text {
                            anchors.left: pickIcon.right
                            anchors.leftMargin: 10 * root.s
                            anchors.right: pickMark.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: pick.modelData.name
                            color: pick.on ? Theme.bright : Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                            elide: Text.ElideRight
                        }
                        GlyphIcon {
                            id: pickMark
                            anchors.right: parent.right
                            anchors.rightMargin: 10 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            width: 13 * root.s
                            height: 13 * root.s
                            name: pick.on ? "check" : "install"
                            color: pick.on ? Theme.accent : pickArea.containsMouse ? Theme.bright : Theme.iconDim
                        }
                        MouseArea {
                            id: pickArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.service.togglePin(pick.modelData)
                        }
                    }
                }
            }
        }
    }

    // quick commands
    Component {
        id: commandsSec
        Section {
            label: "Commands"
            key: "showCommands"
            sid: "commands"
            Flow {
                visible: !root.editing
                width: col.width
                spacing: 6 * root.s
                Repeater {
                    model: root.service ? root.service.commands : []
                    delegate: Chip {
                        required property var modelData
                        required property int index
                        label: modelData.label
                        glyph: "send"
                        onClicked: root.service.run(modelData)
                    }
                }
                Text {
                    visible: root.service && root.service.commands.length === 0
                    height: 30 * root.s
                    verticalAlignment: Text.AlignVCenter
                    text: "No commands yet. EDIT to add one."
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 11.5 * root.s
                }
            }

            // EDIT: commands in order
            OrderList {
                visible: root.editing
                width: col.width
                s: root.s
                model: root.editing && root.service ? root.service.commands : []
                labelOf: (c) => c.label
                subOf: (c) => c.cmd
                onMoveTo: (from, to) => root.service.moveCommand(from, to)
                onRemove: (i) => root.service.removeCommand(i)
            }

            // add a command
            Row {
                visible: root.editing
                width: col.width
                spacing: 6 * root.s
                Field { id: cmdLabel; width: 92 * root.s; placeholder: "label"; onAccepted: cmdLine.input.forceActiveFocus() }
                Field { id: cmdLine; width: col.width - 92 * root.s - 36 * root.s - 12 * root.s; placeholder: "command"; onAccepted: addCmd.add() }
                Rectangle {
                    id: addCmd
                    function add() {
                        root.service.addCommand(cmdLabel.text, cmdLine.text);
                        cmdLabel.text = "";
                        cmdLine.text = "";
                    }
                    width: 36 * root.s
                    height: 30 * root.s
                    radius: Motion.rSmall * root.s
                    color: addCmdArea.pressed ? Theme.vermDeep : addCmdArea.containsMouse ? Theme.vermLit : Theme.accent
                    Text { anchors.centerIn: parent; text: "+"; color: Theme.cardBot; font.family: Theme.display; font.pixelSize: 18 * root.s }
                    MouseArea { id: addCmdArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: addCmd.add() }
                }
            }
        }
    }
}
