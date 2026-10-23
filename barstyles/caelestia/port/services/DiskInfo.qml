import QtQml

QtObject {
    property string mount: "/"
    property real used: 0
    property real total: 0
    readonly property real free: Math.max(0, total - used)
    readonly property real perc: total > 0 ? used / total : 0
    property bool hasRoot: true
}
