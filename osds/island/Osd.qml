pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Ryoku.Ui.Singletons

// Island: volume, microphone, brightness and keyboard changes as a black
// pill that springs out from the top edge, the way the Dynamic Island grows.
// The glyph sits in a well of liquid glass; the level is a white bar that
// turns grey when muted.
Item {
    id: root

    required property string kind
    required property var screen
    property real us: 1
    property bool shown: false
    property real value: 0
    property real maxValue: 1
    property bool muted: false
    property string icon: ""
    property url iconSource: ""
    property string label: ""

    property string placement: "top"
    property real reveal: shown ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: Tokens.reduceMotion ? 1 : (root.shown ? 420 : 240)
            easing.type: root.shown ? Easing.OutBack : Easing.InCubic
            easing.overshoot: 1.15
        }
    }

    readonly property bool levels: kind !== "keyboard"
    readonly property real fraction: maxValue > 0 ? Math.max(0, Math.min(1, value / maxValue)) : 0
    readonly property real boosted: maxValue > 1 && value > 1 ? (value - 1) / (maxValue - 1) : 0

    // glass refracts the pill itself
    property var glassSource: null
    property Item glassSpace: null
    property color glassBase: "#000000"

    implicitWidth: 340 * us
    implicitHeight: 54 * us

    // the pill grows from island size to its full width
    Item {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        y: (1 - root.reveal) * -8 * root.us
        width: Math.max(0, root.width * (0.38 + 0.62 * root.reveal))
        height: root.height * (0.7 + 0.3 * Math.min(1, root.reveal))
        opacity: Math.min(1, root.reveal * 1.6)

        RectangularShadow {
            anchors.fill: parent
            radius: height / 2
            blur: 22 * root.us
            spread: -4
            offset.y: 6 * root.us
            color: Qt.rgba(0, 0, 0, 0.5)
        }
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "#000000"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.07)
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 7 * root.us
            anchors.rightMargin: 18 * root.us
            opacity: Math.max(0, (root.reveal - 0.45) / 0.55)

            GlassControl {
                id: well
                anchors.verticalCenter: parent.verticalCenter
                width: pill.height - 14 * root.us
                height: width
                tint: root.muted ? "#ffffff" : Tokens.sun
                tintAmount: root.muted ? 0 : 0.22
                shadow: 0.3
                Image {
                    id: glyph
                    anchors.centerIn: parent
                    width: 20 * root.us
                    height: width
                    source: root.iconSource
                    sourceSize.width: 64
                    sourceSize.height: 64
                    fillMode: Image.PreserveAspectFit
                    visible: false
                }
                MultiEffect {
                    anchors.fill: glyph
                    source: glyph
                    brightness: 1
                    colorization: 1
                    colorizationColor: root.muted ? Qt.rgba(1, 1, 1, 0.5) : "#ffffff"
                }
            }

            Text {
                id: name
                visible: !root.levels
                anchors.left: well.right
                anchors.leftMargin: 12 * root.us
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: "#ffffff"
                font.family: Tokens.ui
                font.pixelSize: 15 * root.us
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            // level
            Item {
                visible: root.levels
                anchors.left: well.right
                anchors.leftMargin: 14 * root.us
                anchors.right: pct.left
                anchors.rightMargin: 12 * root.us
                anchors.verticalCenter: parent.verticalCenter
                height: 7 * root.us
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.16)
                }
                Rectangle {
                    height: parent.height
                    radius: height / 2
                    width: Math.max(height, parent.width * Math.min(1, root.fraction * root.maxValue))
                    color: root.muted ? Qt.rgba(1, 1, 1, 0.4) : "#ffffff"
                    Behavior on width { NumberAnimation { duration: Tokens.dur(120); easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Tokens.dur(160) } }
                }
                // past 100 % with volume boost, the overflow glows in the accent
                Rectangle {
                    visible: root.boosted > 0
                    anchors.right: parent.right
                    height: parent.height
                    radius: height / 2
                    width: parent.width * 0.18 * root.boosted
                    color: Tokens.sun
                }
            }
            Text {
                id: pct
                visible: root.levels
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 34 * root.us
                horizontalAlignment: Text.AlignRight
                text: root.muted ? "Off" : Math.round(root.value * 100)
                color: Qt.rgba(235 / 255, 235 / 255, 245 / 255, 0.7)
                font.family: Tokens.ui
                font.pixelSize: 13 * root.us
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
    }
}
