pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// DepthEffect is not in this port; members read as empty.
Singleton {
    property var anyInstalled: null
    property string installedModels: ""
    property string qml: ""
    property var wanted: null
    function choiceFor() {
    }
    function setChoice() {
    }
    function stateFor() {
    }
}
