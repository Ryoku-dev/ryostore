/* Yatagarasu Roost — the content.
 * The crow herself on the desktop, standing on her prism
 * wire. Her eye is bound to the service's mood: the colour
 * of the last word the wire carried. She brightens when a
 * fresh scroll lands and settles as it ages.
 */
pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

Item {
    id: root

    property var pluginApi
    property var screen
    property bool active
    property string density: "compact"
    property real s: 1
    property real widthBudget: 0

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property real k: (density === "full" ? 1.35 : 1.0) * s

    implicitWidth: 128 * k + 16 * s
    implicitHeight: 116 * k + 16 * s

    property real _now: Date.now()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root._now = Date.now()
    }
    readonly property bool _awake: service !== null && service !== undefined
        && service.lastArriveAt > 0 && (_now - service.lastArriveAt) < 8000

    Item {
        anchors.centerIn: parent
        width: 128 * root.k
        height: 116 * root.k + 8 * root.s

        KasugaiCrow {
            width: 128
            height: 116
            scale: root.k
            transformOrigin: Item.TopLeft
            mood: root.service ? root.service.mood : ""
            opacity: root._awake ? 1.0 : 0.8
        }

        // Her wire — the prism line she stands on.
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 2
            opacity: root._awake ? 0.95 : 0.55
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#22D3EE" }
                GradientStop { position: 0.38; color: "#818CF8" }
                GradientStop { position: 0.62; color: "#E879F9" }
                GradientStop { position: 0.82; color: "#F5B300" }
                GradientStop { position: 1.0; color: "#F43F5E" }
            }
        }
    }
}
