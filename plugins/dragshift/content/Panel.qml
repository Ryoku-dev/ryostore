pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.PluginKit.Singletons
import "urls.js" as Urls

// The bar panel: the dropped files, then a row of buttons per kind of action.
// Convert and Tools run in the background and report here; an editor opens in
// its own window and reports with a notification. Dropping files onto the panel
// itself works too.
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 360
    property bool active: false

    readonly property var svc: pluginApi ? pluginApi.mainInstance : null
    readonly property bool busy: svc ? svc.busy : false
    readonly property var files: svc ? svc.files : []
    readonly property var result: svc ? svc.result : null

    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight + 24 * root.s

    // ---- small building blocks ---------------------------------------------
    component Label: Text {
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: 11 * root.s
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.2
    }

    component Body: Text {
        color: Theme.bright
        font.family: Theme.font
        font.pixelSize: 13 * root.s
        wrapMode: Text.Wrap
        width: col.width
    }

    component Chip: Rectangle {
        id: chip
        property string label: ""
        property string hint: ""
        property bool primary: false
        property bool enabledChip: true
        signal clicked()

        width: chipText.implicitWidth + 20 * root.s
        height: chipText.implicitHeight + 12 * root.s
        radius: Theme.radius
        opacity: chip.enabledChip ? 1 : 0.4
        color: chipArea.pressed ? Theme.vermDeep
             : chip.primary ? Theme.accent
             : chipArea.containsMouse ? Theme.threadBg : Theme.tileBg
        border.width: 1
        border.color: chipArea.containsMouse ? Theme.accent : Theme.hair

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.primary ? Theme.cardBot : Theme.bright
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: chip.enabledChip
            onClicked: chip.clicked()
        }
    }

    // ---- drop onto the panel too -------------------------------------------
    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onEntered: (drag) => { if (drag.hasUrls) drag.accept(Qt.CopyAction); }
        onDropped: (ev) => {
            const paths = Urls.toPaths(ev.urls);
            if (paths.length > 0 && root.svc) {
                ev.accept(Qt.CopyAction);
                root.svc.setFiles(paths);
            }
        }
    }

    Column {
        id: col
        x: 12 * root.s
        y: 12 * root.s
        width: root.width - 24 * root.s
        spacing: 10 * root.s

        // header
        Item {
            width: col.width
            height: title.implicitHeight
            Text {
                id: title
                text: "DragShift"
                color: Theme.bright
                font.family: Theme.display
                font.pixelSize: 16 * root.s
            }
            Chip {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.files.length > 0 && !root.busy
                label: "Clear"
                onClicked: root.svc.clear()
            }
        }

        // engine problem: the one line that says how to fix it
        Rectangle {
            visible: !!root.svc && root.svc.doctorState === "error"
            width: col.width
            height: visible ? doctorCol.implicitHeight + 16 * root.s : 0
            radius: Theme.radius
            color: Theme.frameBg
            border.width: 1
            border.color: Theme.sun
            Column {
                id: doctorCol
                x: 8 * root.s
                y: 8 * root.s
                width: parent.width - 16 * root.s
                spacing: 4 * root.s
                Body { width: parent.width; text: root.svc ? root.svc.doctorError : "" }
                TextEdit {
                    width: parent.width
                    visible: text.length > 0
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    text: root.svc ? root.svc.doctorFix : ""
                    color: Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 11 * root.s
                }
                Chip { label: "Check again"; onClicked: root.svc.checkEngine() }
            }
        }

        // the Shift+drag trigger hasn't fired yet: say how to set it up
        Rectangle {
            visible: !!root.svc && !root.svc.triggerSeen
            width: col.width
            height: visible ? trigCol.implicitHeight + 16 * root.s : 0
            radius: Theme.radius
            color: Theme.frameBg
            border.width: 1
            border.color: Theme.accent
            Column {
                id: trigCol
                x: 8 * root.s
                y: 8 * root.s
                width: parent.width - 16 * root.s
                spacing: 4 * root.s
                Body {
                    width: parent.width
                    text: root.svc && root.svc.hyprland
                        ? "Turn on Shift+drag: add DragShift's trigger to your Hyprland config, then start a drag and tap Shift. This icon hides itself after the first menu."
                        : "Shift+drag needs Hyprland. Drop files on ⇄ instead."
                }
                TextEdit {
                    width: parent.width
                    visible: !!root.svc && root.svc.hyprland && root.svc.triggerSnippet !== ""
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    text: root.svc ? "sed -i '/^-- DRAGSHIFT-TRIGGER-BEGIN$/,/^-- DRAGSHIFT-TRIGGER-END$/d' ~/.config/hypr/user.lua; { echo; cat '" + root.svc.triggerSnippet + "'; } >> ~/.config/hypr/user.lua; ryoku wm act config.reload" : ""
                    color: Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 11 * root.s
                }
            }
        }

        // nothing dropped yet
        Body {
            visible: root.files.length === 0 && !(root.svc && root.svc.filesError)
            color: Theme.dim
            text: "Drag files onto ⇄ in the bar (or here): images, PDFs, Word or text files. Results are saved next to the originals; the originals are never changed."
        }

        Body {
            visible: !!root.svc && root.svc.filesError.length > 0
            color: Theme.sun
            text: root.svc ? root.svc.filesError : ""
        }

        // the files
        Body {
            visible: root.files.length > 0
            text: root.files.length === 1 ? Urls.baseName(root.files[0])
                : root.files.length + " files: " + root.files.slice(0, 3).map(Urls.baseName).join(", ")
                  + (root.files.length > 3 ? ", …" : "")
            elide: Text.ElideMiddle
            maximumLineCount: 2
        }
        Body {
            visible: !!root.svc && root.svc.loadingActions
            color: Theme.dim
            text: "Reading files…"
        }
        Body {
            visible: !!root.svc && root.svc.skipped.length > 0
            color: Theme.dim
            font.pixelSize: 11 * root.s
            text: root.svc ? "Skipped " + root.svc.skipped.length + " (another kind, or not a file)" : ""
        }

        // actions
        Repeater {
            model: [
                { key: "convert", title: "Convert to" },
                { key: "tools", title: "Tools" },
                { key: "editors", title: "Open in editor" }
            ]
            delegate: Column {
                id: section
                required property var modelData
                readonly property var items: !root.svc ? []
                    : section.modelData.key === "convert" ? root.svc.convertActions
                    : section.modelData.key === "tools" ? root.svc.toolActions
                    : root.svc.editorActions
                visible: items.length > 0
                width: col.width
                spacing: 6 * root.s
                Label { text: section.modelData.title }
                Flow {
                    width: col.width
                    spacing: 6 * root.s
                    Repeater {
                        model: section.items
                        delegate: Chip {
                            required property var modelData
                            label: modelData.label
                            enabledChip: !root.busy && (!root.svc || root.svc.doctorState !== "error")
                            onClicked: {
                                if (section.modelData.key === "convert")
                                    root.svc.convertTo(modelData.id, modelData.label);
                                else if (section.modelData.key === "tools")
                                    root.svc.runTool(modelData.id, modelData.label, modelData.all === true);
                                else
                                    root.svc.openEditor(modelData.id, modelData.label);
                            }
                        }
                    }
                }
            }
        }

        // working
        Row {
            visible: root.busy
            spacing: 8 * root.s
            Body {
                width: implicitWidth
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.accent
                text: root.svc ? root.svc.busyLabel : ""
            }
            Chip { label: "Cancel"; onClicked: root.svc.cancel() }
        }

        // result
        Rectangle {
            visible: !!root.result && !root.busy
            width: col.width
            height: visible ? resultCol.implicitHeight + 16 * root.s : 0
            radius: Theme.radius
            color: Theme.tileBg
            border.width: 1
            border.color: (root.result && root.result.ok) ? Theme.accent : Theme.sun
            Column {
                id: resultCol
                x: 8 * root.s
                y: 8 * root.s
                width: parent.width - 16 * root.s
                spacing: 4 * root.s
                Body {
                    width: parent.width
                    font.pixelSize: 14 * root.s
                    text: !root.result ? "" : root.result.ok ? (root.result.title || "Done") : "Couldn't finish"
                }
                Body {
                    width: parent.width
                    color: Theme.dim
                    text: !root.result ? "" : root.result.ok
                        ? [root.result.detail, root.result.good].filter(x => !!x).join(" · ")
                        : (root.result.error || "")
                }
                Flow {
                    visible: !!root.result && root.result.ok && !!root.result.outs && root.result.outs.length > 0
                    width: parent.width
                    spacing: 6 * root.s
                    Chip { label: "Open"; primary: true; onClicked: root.svc.openResult() }
                    Chip { label: "Show in folder"; onClicked: root.svc.revealResult() }
                    Chip { label: "Undo"; onClicked: root.svc.undo() }
                }
            }
        }

        Body {
            visible: !!root.svc && root.svc.notice.length > 0
            color: Theme.dim
            font.pixelSize: 12 * root.s
            text: root.svc ? root.svc.notice : ""
        }
    }
}
