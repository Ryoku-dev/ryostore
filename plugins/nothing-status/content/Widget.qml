import QtQuick

Item {
    id: root
    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0
    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property var state: service ? service.data : ({})
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : ({})
    readonly property bool online: state.network === "full" || state.network === "limited"
    readonly property color ink: "#F5F5F5"
    readonly property color dim: "#B1B3B3"

    implicitWidth: row.implicitWidth
    implicitHeight: 28 * s

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 9 * root.s
        Icon {
            visible: root.settings.showNetwork !== false
            kind: "network"
            width: 17 * root.s; height: 17 * root.s
            ink: root.online ? root.ink : root.dim
        }
        Icon {
            visible: root.settings.showVolume !== false
            kind: "audio"
            width: 17 * root.s; height: 17 * root.s
            ink: root.state.muted ? root.dim : root.ink
        }
        Row {
            visible: root.settings.showBattery !== false && root.state.battery >= 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4 * root.s
            Icon {
                kind: "battery"
                width: 17 * root.s; height: 17 * root.s
                level: root.state.battery ?? 100
                ink: root.state.battery >= 0 && root.state.battery <= 15
                    ? "#C8102E" : root.ink
            }
            Icon {
                visible: root.state.charging === true || root.state.plugged === true
                kind: "charge"
                width: 10 * root.s; height: 17 * root.s
                ink: root.ink
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: String(root.state.battery ?? 0)
                color: root.state.battery >= 0 && root.state.battery <= 15
                    ? "#C8102E" : root.ink
                font.family: "Noto Sans"
                font.pixelSize: 12 * root.s
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.pluginApi) root.pluginApi.togglePanel()
    }
}
