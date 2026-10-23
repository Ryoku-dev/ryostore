import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"
import "../../../modules/tansu/phone"

// One notification card of the Quick Panel's list. The same card is used
// three ways (QuickPanelFace.qml decides which):
//
//   - a lone notification:       tap it for the app's own action (activated(); the
//                                panel dismisses it when the app has none), swipe
//                                or middle / right click it away (dismissed())
//   - the header of a group:     several notifications from one source
//                                collapse into this single card with a
//                                count pill and a chevron. Tap it to open
//                                or close the dropdown (toggled()); swipe
//                                or middle / right click it to clear the
//                                whole group (dismissed())
//   - a row inside the dropdown: a lone card again, a little narrower
//
// Pure UI (no Quickshell imports), like QuickPanelFace itself.
Item {
    id: card

    property var key
    property string app: ""
    property string title: ""
    property string body: ""
    property double time: 0
    property int urgency: 1
    property string icon: ""
    readonly property bool materialIcon: icon.startsWith("material:")
    property string agoText: ""

    property int groupCount: 1
    property bool expanded: false
    readonly property bool group: groupCount > 1

    readonly property real slideX: slide.x
    readonly property real slideOpacity: slide.opacity

    property bool blocked: false
    property int clearIndex: 0
    property real cardWidth: 526

    signal dismissed()
    signal toggled()
    signal activated()

    function clearOut() {
        clearOutAnim.restart()
    }

    width: cardWidth
    height: 95.06

    readonly property bool pressed: cardArea.pressed && !cardArea.drag.active

    readonly property real swipeDistance: 130
    property bool leaving: false
    property bool swiped: false

    NumberAnimation {
        id: settle
        target: slide
        property: "x"
        duration: 160
        easing.type: Easing.OutCubic
        onFinished: {
            if (card.leaving) {
                restore.start()
                card.dismissed()
            }
        }
    }

    Timer {
        id: restore
        interval: 400
        onTriggered: {
            card.leaving = false
            slide.x = 0
        }
    }

    SequentialAnimation {
        id: clearOutAnim
        PauseAnimation { duration: Math.min(card.clearIndex, 5) * 35 }
        NumberAnimation {
            target: slide
            property: "x"
            to: -card.width
            duration: 140
            easing.type: Easing.InCubic
        }
    }

    Item {
        id: slide
        width: card.width
        height: card.height
        opacity: 1 - Math.min(1, Math.abs(x) / (card.width * 0.75))

        readonly property color edgeTone: Theme.classic ? Qt.color("#e9e9e9") : Qt.darker(Theme.pSurfaceHover, 1.12)

        Rectangle {
            anchors.fill: parent
            radius: 16.5
            color: Theme.pSurfaceHover
            opacity: card.pressed ? 0.7 : 1
            border.width: card.urgency === 2 ? 3 : 0
            border.color: Theme.pLine
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.pSurfaceHover }
                GradientStop { position: 0.72; color: Theme.pSurfaceHover }
                GradientStop { position: 1.0; color: slide.edgeTone }
            }
            antialiasing: true
        }

        Rectangle {
            anchors.fill: parent
            radius: 16.5
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(slide.edgeTone.r, slide.edgeTone.g, slide.edgeTone.b, 0) }
                GradientStop { position: 0.62; color: Qt.rgba(slide.edgeTone.r, slide.edgeTone.g, slide.edgeTone.b, 0) }
                GradientStop { position: 1.0; color: Qt.rgba(slide.edgeTone.r, slide.edgeTone.g, slide.edgeTone.b, 0.6) }
            }
            antialiasing: true
        }

        Item {
            x: 20
            width: 44
            height: 44
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                visible: !card.materialIcon
                anchors.fill: parent
                radius: width / 2
                color: Theme.pSurface
                antialiasing: true
            }

            ShellBadge {
                anchors.centerIn: parent
                size: 42
                visible: card.materialIcon
                glyph: card.materialIcon ? card.icon.substring(9) : ""
            }

            Image {
                anchors.centerIn: parent
                width: parent.width
                height: width
                visible: card.icon !== "" && !card.materialIcon
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(Math.ceil(width * 3), Math.ceil(width * 3))
                source: card.materialIcon ? "" : card.icon
            }

            MaterialIcon {
                anchors.centerIn: parent
                size: parent.width - 6
                visible: card.icon === ""
                name: "apps"
            }
        }

        Row {
            x: 76
            y: 8
            spacing: 8

            Text {
                id: appText
                width: Math.min(implicitWidth, card.cardWidth - 198 - (card.group ? 34 : 0))
                elide: Text.ElideRight
                text: card.app
                color: Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            Rectangle {
                visible: card.group
                height: 18
                width: Math.max(18, countText.implicitWidth + 12)
                radius: 9
                color: Theme.pLine
                antialiasing: true
                anchors.verticalCenter: appText.verticalCenter

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: card.groupCount > 9 ? "9+" : card.groupCount
                    color: "white"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.ExtraBold
                }
            }
        }

        Text {
            x: parent.width - 24 - width
            y: 9
            width: 70
            horizontalAlignment: Text.AlignRight
            text: card.agoText
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.Medium
        }

        Text {
            x: 76
            y: 26
            width: card.cardWidth - 100 - (card.group ? 36 : 0)
            elide: Text.ElideRight
            text: card.title
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        Text {
            x: 76
            y: 51
            width: card.cardWidth - 100 - (card.group ? 36 : 0)
            visible: card.body !== ""
            text: card.body
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeight: 0.92
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 15
        }

        MaterialIcon {
            visible: card.group
            x: parent.width - 24 - width
            y: 46
            size: 28
            name: "expand_more"
            rotation: card.expanded ? 180 : 0
            Behavior on rotation {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    MouseArea {
        id: cardArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        enabled: !card.leaving && !card.blocked
        // Keep the dismiss pull: the phone's page flick would otherwise take it.
        preventStealing: true
        drag.target: slide
        drag.axis: Drag.XAxis
        drag.minimumX: -card.width
        drag.maximumX: card.width

        onPressed: {
            settle.stop()
            card.swiped = false
        }

        onPositionChanged: if (drag.active) PanelActivity.touch()

        onReleased: {
            const dx = slide.x
            card.swiped = Math.abs(dx) > 4
            if (Math.abs(dx) >= card.swipeDistance) {
                card.leaving = true
                settle.duration = 140
                settle.to = dx > 0 ? card.width : -card.width
                settle.restart()
            } else if (dx !== 0) {
                settle.duration = 160
                settle.to = 0
                settle.restart()
            }
        }

        onClicked: mouse => {
            if (card.swiped)
                return
            if (mouse.button !== Qt.LeftButton)
                card.dismissed()
            else if (card.group)
                card.toggled()
            else
                card.activated()
        }
    }
}
