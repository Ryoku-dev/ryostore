pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

// Bar glyph. A click only opens the ZimaOS card.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0
    property bool open: false
    property real reveal: 0
    property bool tabActive: false
    signal requestClose()

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool panelOpen: pluginApi ? pluginApi.panelOpen : false
    readonly property bool online: service ? service.online : false
    readonly property bool lit: root.panelOpen || hover.hovered

    implicitWidth: 22 * root.s
    implicitHeight: 22 * root.s

    Rectangle {
        anchors.centerIn: parent
        width: 20 * root.s
        height: 20 * root.s
        radius: 0
        color: root.lit ? Theme.sheen : "transparent"
        border.width: root.panelOpen ? 1 : 0
        border.color: Theme.hair
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Item {
        id: markBox
        anchors.centerIn: parent
        width: 16 * root.s
        height: 16 * root.s

        Image {
            id: mark
            anchors.fill: parent
            source: Qt.resolvedUrl("zima-mark.png")
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: mark
            colorization: 1
            colorizationColor: root.panelOpen ? Theme.cream : (hover.hovered ? Theme.cream : Theme.iconDim)
            opacity: root.online || root.panelOpen ? 1 : 0.45
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: {
            if (!root.pluginApi)
                return;
            if (root.open)
                root.requestClose();
            else if (root.pluginApi.togglePanel)
                root.pluginApi.togglePanel();
        }
    }
}
