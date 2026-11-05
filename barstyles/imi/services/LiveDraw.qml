pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// LiveDraw is not in this port; members read as empty.
Singleton {
    property string board: ""
    property var boardColor: null
    property string boardOn: ""
    property string boardPattern: ""
    property var color: null
    property string drawing: ""
    property string enabled: ""
    property var eraser: null
    property var lastShape: null
    property var mouseSmoothing: null
    property var nativeCursor: null
    property var palette: null
    property var revision: null
    property var sheetCount: null
    property string sheetMode: ""
    property var smoothing: null
    property real spotlight: 0
    property var tool: null
    property var trayCollapsed: null
    property string trayDock: ""
    property var trayHidden: null
    property real trayOffsetX: 0
    property real trayOffsetY: 0
    property real trayOpen: 0
    property var usePressure: null
    property var width: null
    property string workspaceSlideAxis: ""
    property var workspaceSlideCurve: null
    property var workspaceSlideDistance: null
    property var workspaceSlideEnabled: null
    property real workspaceSlideFade: 0
    property var workspaceSlideMs: null
    property var zoom: null
    function addStroke() {
    }
    function canRedo() {
    }
    function canUndo() {
    }
    function clear() {
    }
    function close() {
    }
    function ensureTools() {
    }
    function eraseAt() {
    }
    function keyFor() {
    }
    function redo() {
    }
    function setBoard() {
    }
    function setSpotlight() {
    }
    function setTool() {
    }
    function setZoom() {
    }
    function specialFor() {
    }
    function strokesFor() {
    }
    function toggle() {
    }
    function undo() {
    }
}
