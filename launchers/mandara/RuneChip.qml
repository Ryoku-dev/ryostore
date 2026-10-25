import QtQuick

// RuneChip — a locked lane segment, in the shape of the Obelisk's
// crystallized rune tokens from Jurai shell. In Mandara the launcher a
// chip means one thing: this lane is locked. TAB locks the next lane,
// Backspace on an empty field releases the lock.
//
// The shell original wrapped the token in an SDF crystallize shader;
// the launcher keeps the crystal's dress (tinted glass, lane-coloured
// border, the freshest lock glowing) and leaves the shader out — a
// launcher stays light. When the chips learn their deeper work, the
// crystal can come back with them.
Item {
    id: root

    property var laneData: ({ label: "", icon: "◈", color: "#22D3EE" })
    property bool isLast: false

    readonly property color _laneColor: Qt.color(root.laneData.color || "#22D3EE")

    implicitWidth: _chipRow.implicitWidth + 18
    implicitHeight: 24

    // entrance: a small crystallize — scale and fade in, nothing more
    scale: 0.86
    opacity: 0
    Component.onCompleted: {
        scale = 1.0;
        opacity = 1.0;
    }
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 140 } }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: Qt.rgba(root._laneColor.r, root._laneColor.g, root._laneColor.b, 0.13)
        border.width: 1
        border.color: Qt.rgba(root._laneColor.r, root._laneColor.g, root._laneColor.b,
                              root.isLast ? 0.80 : 0.45)
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    Row {
        id: _chipRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: root.laneData.icon || "◈"
            color: root._laneColor
            font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.laneData.label || ""
            color: Qt.rgba(1, 1, 1, 0.90)
            font.family: "monospace"
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
