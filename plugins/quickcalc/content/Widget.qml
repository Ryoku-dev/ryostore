pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.PluginKit.Singletons

// content/Widget.qml is the one view every host mounts.
//
// "glyph" density (placed on the bar): a fixed-width Material Symbols mark
// whose click opens content/Panel.qml -- the standard topbarGlyph mechanism,
// pluginApi.togglePanel().
//
// Any other density: mounted by the framePopout host, which this plugin uses
// as its FLOATING WINDOW placement (see service/Main.qml). The calculator
// itself opens in content/FloatingWindow.qml; the shell's frame popout only
// appears when the pointer hovers its edge strip (or on the legacy
// `ryoku-shell plugin` call), and then shows just a small open/close button
// -- never the calculator, which the shell would close 2.5 s after the
// pointer left. This branch also tells the service where the Hub's
// drag-and-drop placer put the popout, so the floating window opens there.
//
// Both branches get `anchors.fill: parent` on their loaded content: the host
// gives THIS item's root a real size, but nothing forwards that size further
// down unless told to -- that was the earlier 0x0 bug.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0

    readonly property bool isGlyph: density === "glyph"
    readonly property bool panelOpen: !!(root.pluginApi && root.pluginApi.panelOpen)
    readonly property var service: root.pluginApi ? root.pluginApi.mainInstance : null

    // --- the popout placement, read from the host that mounted us. The
    // frame-popout host is an ancestor carrying `edge`, `align` and
    // `centered`, bound to the placement the Hub's placer writes. Outside
    // the documented pluginApi contract, so it is looked up defensively: no
    // such ancestor (another host, or a future shell) means "centre".
    property var popoutHost: null
    function findPopoutHost() {
        for (var p = root.parent; p; p = p.parent) {
            if (typeof p.edge === "string" && typeof p.align === "string" && typeof p.centered === "boolean")
                return p;
        }
        return null;
    }
    readonly property string hostEdge: root.popoutHost ? (root.popoutHost.centered ? "center" : root.popoutHost.edge) : "center"
    readonly property string hostAlign: root.popoutHost ? root.popoutHost.align : "center"
    function reportPlacement() {
        if (!root.isGlyph && root.service && typeof root.service.setPlacement === "function")
            root.service.setPlacement(root.hostEdge, root.hostAlign);
    }
    onParentChanged: root.popoutHost = root.findPopoutHost()
    Component.onCompleted: {
        root.popoutHost = root.findPopoutHost();
        root.reportPlacement();
    }
    onHostEdgeChanged: root.reportPlacement()
    onHostAlignChanged: root.reportPlacement()
    onServiceChanged: root.reportPlacement()

    implicitWidth: isGlyph ? (glyphLoader.item ? glyphLoader.item.implicitWidth : 18 * root.s)
                            : (fullLoader.item ? fullLoader.item.implicitWidth : 160)
    implicitHeight: isGlyph ? (18 * root.s)
                             : (fullLoader.item ? fullLoader.item.implicitHeight : 36)

    Loader {
        id: glyphLoader
        anchors.fill: parent
        active: root.isGlyph
        sourceComponent: Item {
            anchors.fill: parent
            implicitWidth: mark.implicitWidth + 4 * root.s
            implicitHeight: 18 * root.s
            Text {
                id: mark
                anchors.centerIn: parent
                text: "calculate"
                font.family: "Material Symbols Rounded"
                renderType: Text.QtRendering
                color: root.panelOpen ? Theme.accent : Theme.dim
                font.pixelSize: 16 * root.s
            }
            MouseArea {
                anchors.fill: parent
                onClicked: if (root.pluginApi && root.pluginApi.togglePanel) root.pluginApi.togglePanel()
            }
        }
    }

    // Frame popout: the small open/close button.
    Loader {
        id: fullLoader
        anchors.fill: parent
        active: !root.isGlyph
        sourceComponent: Item {
            id: opener
            anchors.fill: parent
            implicitWidth: openRow.implicitWidth + 24 * root.s
            implicitHeight: 36 * root.s
            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: openArea.containsMouse ? Theme.tileBg : "transparent"
                border.width: Theme.border2
                border.color: Theme.frameBorder
            }
            Row {
                id: openRow
                anchors.centerIn: parent
                spacing: 8 * root.s
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "calculate"
                    font.family: "Material Symbols Rounded"
                    renderType: Text.QtRendering
                    color: Theme.accent
                    font.pixelSize: 18 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.service && root.service.windowOpen ? "Close calculator" : "Open calculator"
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                }
            }
            MouseArea {
                id: openArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.service) root.service.toggle()
            }
        }
    }
}
