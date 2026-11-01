import QtQuick
import Ryoku.PluginKit.Singletons

// content/Panel.qml is the bar panel: when this plugin is on the bar and the
// manifest declares entryPoints.panel, the host renders this file under the
// plugin's glyph in the shared panel surface (Escape or an outside click closes
// it, one panel open at a time). The host sets pluginApi, density ("full"), s,
// widthBudget (from manifest panel.width) and active; report implicitHeight and
// the host sizes the card to it.
//
// Lists every removable disk currently attached, grouped with its mounted
// partitions, each with its own Unmount button, plus a per-disk Eject button
// that unmounts everything on the disk and powers it off. No action here ever
// runs from the bar glyph itself (R: no click on the bar mutates state) --
// every button lives in this panel, reached only by an explicit open.
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 360
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property var drives: service ? service.drives : []
    readonly property string lastError: service ? service.lastError : ""
    readonly property string lastAction: service ? service.lastAction : ""

    // Group the flat drive list into removable disks + their mounted
    // partitions (or the disk itself, if it has no partition table).
    readonly property var groups: {
        var byPath = {};
        var order = [];
        for (var i = 0; i < root.drives.length; i++) {
            var d = root.drives[i];
            if (!d.removable)
                continue;
            if (d.type === "disk") {
                if (!byPath[d.path]) {
                    byPath[d.path] = {
                        diskPath: d.path,
                        model: d.model || d.name,
                        sizeLabel: d.sizeLabel,
                        rows: []
                    };
                    order.push(d.path);
                }
                if (d.mountpoint !== "")
                    byPath[d.path].rows.push(d);
            } else if (d.mountpoint !== "") {
                var parent = d.parentPath;
                if (!byPath[parent]) {
                    byPath[parent] = {
                        diskPath: parent,
                        model: parent,
                        sizeLabel: "",
                        rows: []
                    };
                    order.push(parent);
                }
                byPath[parent].rows.push(d);
            }
        }
        var out = [];
        for (var j = 0; j < order.length; j++)
            out.push(byPath[order[j]]);
        return out;
    }

    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight + 24 * root.s

    Column {
        id: col
        x: 12 * root.s
        y: 12 * root.s
        width: root.width - 24 * root.s
        spacing: 10 * root.s

        Row {
            width: parent.width
            Text {
                text: "Removable Drives"
                color: Theme.bright
                font.family: Theme.display
                font.pixelSize: 16 * root.s
            }
        }

        Text {
            visible: root.lastAction !== ""
            text: root.lastAction + "…"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }

        Text {
            visible: root.lastError !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.lastError
            color: Theme.vermDeep
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }

        Text {
            visible: root.groups.length === 0
            text: "No removable drives connected."
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 13 * root.s
        }

        Repeater {
            model: root.groups
            delegate: Column {
                required property var modelData
                width: col.width
                spacing: 6 * root.s

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.dim
                    opacity: 0.25
                }

                Row {
                    width: parent.width
                    spacing: 8 * root.s

                    Text {
                        text: "usb"
                        font.family: "Material Symbols Rounded"
                        renderType: Text.QtRendering
                        font.pixelSize: 14 * root.s
                        color: Theme.dim
                    }

                    Column {
                        width: parent.width - 100 * root.s
                        Text {
                            text: modelData.model + (modelData.sizeLabel ? " · " + modelData.sizeLabel : "")
                            color: Theme.bright
                            font.family: Theme.font
                            font.pixelSize: 13 * root.s
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: modelData.diskPath
                            color: Theme.dim
                            font.family: Theme.mono
                            font.pixelSize: 10 * root.s
                        }
                    }

                    Rectangle {
                        width: ejectLabel.implicitWidth + 16 * root.s
                        height: ejectLabel.implicitHeight + 8 * root.s
                        radius: Theme.radius
                        // Always enabled: eject/power-off is valid even when the
                        // disk already has nothing mounted (the normal state
                        // right after Unmount), so it must not grey out there.
                        color: ejectArea.pressed ? Theme.vermDeep : Theme.accent

                        Text {
                            id: ejectLabel
                            anchors.centerIn: parent
                            text: "Eject"
                            color: Theme.cardBot
                            font.family: Theme.font
                            font.pixelSize: 11 * root.s
                        }

                        MouseArea {
                            id: ejectArea
                            anchors.fill: parent
                            onClicked: if (root.service)
                                root.service.ejectDisk(modelData.diskPath)
                        }
                    }
                }

                Repeater {
                    model: modelData.rows
                    delegate: Row {
                        required property var modelData
                        width: parent.width
                        spacing: 8 * root.s
                        leftPadding: 22 * root.s

                        Column {
                            width: parent.width - 170 * root.s
                            Text {
                                text: (modelData.label || modelData.fstype || modelData.name) + (modelData.sizeLabel ? " · " + modelData.sizeLabel : "")
                                color: Theme.bright
                                font.family: Theme.font
                                font.pixelSize: 12 * root.s
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: modelData.mountpoint
                                color: Theme.dim
                                font.family: Theme.mono
                                font.pixelSize: 10 * root.s
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        Rectangle {
                            width: unmountLabel.implicitWidth + 16 * root.s
                            height: unmountLabel.implicitHeight + 8 * root.s
                            radius: Theme.radius
                            color: unmountArea.pressed ? Theme.vermDeep : Theme.tileBg

                            Text {
                                id: unmountLabel
                                anchors.centerIn: parent
                                text: "Unmount"
                                color: Theme.bright
                                font.family: Theme.font
                                font.pixelSize: 11 * root.s
                            }

                            MouseArea {
                                id: unmountArea
                                anchors.fill: parent
                                onClicked: if (root.service)
                                    root.service.unmountOne(modelData.path)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: refreshLabel.implicitWidth + 24 * root.s
            height: refreshLabel.implicitHeight + 12 * root.s
            radius: Theme.radius
            color: refreshArea.pressed ? Theme.vermDeep : Theme.tileBg

            Text {
                id: refreshLabel
                anchors.centerIn: parent
                text: "Refresh"
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 12 * root.s
            }

            MouseArea {
                id: refreshArea
                anchors.fill: parent
                onClicked: if (root.service)
                    root.service.refresh()
            }
        }
    }
}
