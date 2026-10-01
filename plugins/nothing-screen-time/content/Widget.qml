import QtQuick

Rectangle {
    id: root
    property var pluginApi
    property var screen
    property bool active: false
    property string density: "compact"
    property real s: 1
    property real widthBudget: 0
    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool available: service && service.data.available === true
    readonly property int seconds: service ? Number(service.data.seconds ?? 0) : 0
    readonly property int hours: Math.floor(seconds / 3600)
    readonly property int minutes: Math.floor(seconds / 60) % 60
    readonly property string readout: !available ? "—" : hours > 0
        ? String(hours) + "h" + String(minutes).padStart(2, "0") + "m"
        : String(minutes).padStart(2, "0") + "m"

    implicitWidth: 256 * s
    implicitHeight: 120 * s
    width: implicitWidth
    height: implicitHeight
    radius: height / 2
    color: "#1C1D21"

    Text {
        anchors.centerIn: parent
        text: root.readout
        color: "#F5F5F5"
        font.family: "Ndot77JPExtended"
        font.pixelSize: 38 * root.s
    }
}
