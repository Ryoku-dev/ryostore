import QtQuick
import Quickshell.Widgets
import shell.services
import Ryoku.Ui.Singletons

// One mat on the shelf: the app's icon over its name. The chosen mat carries
// registration marks; the pointer only tints what it is over.
Item {
    id: tile

    required property var item
    required property bool selected
    signal pointed()
    signal activated()

    readonly property string iconSource: Icons.path(tile.item.entry.icon, "application-x-executable")

    Rectangle {
        id: plate
        anchors.fill: parent
        anchors.margins: Tokens.s1
        radius: Tokens.radius
        color: press.pressed ? Tokens.tint16
            : tile.selected ? Tokens.tint10
            : press.containsMouse ? Tokens.tint5 : "transparent"
        Behavior on color { ColorAnimation { duration: Tokens.snap } }
    }

    Text {
        visible: tile.item.pinned === true
        anchors { top: plate.top; right: plate.right; topMargin: Tokens.s1; rightMargin: Tokens.s2 }
        text: "\u2605"
        color: Tokens.inkDim
        font.family: Tokens.ui
        font.pixelSize: Tokens.fSmall
    }

    CornerTicks {
        anchors.fill: plate
        visible: tile.selected
        color: Tokens.ink
    }

    IconImage {
        id: glyph
        visible: tile.iconSource.length > 0
        implicitSize: Tokens.px(44)
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.2)
        source: tile.iconSource
        asynchronous: true
    }

    // An app with no icon in the theme gets its initial set in type instead of
    // an empty square.
    Rectangle {
        visible: !glyph.visible
        width: glyph.implicitSize
        height: glyph.implicitSize
        anchors.horizontalCenter: parent.horizontalCenter
        y: glyph.y
        radius: Tokens.radius
        color: "transparent"
        border.width: Tokens.border
        border.color: Tokens.lineStrong
        Text {
            anchors.centerIn: parent
            text: tile.item.name.charAt(0).toUpperCase()
            color: Tokens.inkDim
            font.family: Tokens.display
            font.pixelSize: Tokens.px(22)
        }
    }

    Text {
        anchors {
            left: parent.left; right: parent.right
            top: glyph.bottom; topMargin: Tokens.s2
            leftMargin: Tokens.s2; rightMargin: Tokens.s2
        }
        text: tile.item.name
        color: tile.selected ? Tokens.ink : Tokens.inkDim
        font.family: Tokens.ui
        font.pixelSize: Tokens.fSmall
        font.weight: tile.selected ? Font.Medium : Font.Normal
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
    }

    // Selection follows the pointer only when it moves, so a grid scrolling
    // under a still pointer never steals the keyboard's choice.
    MouseArea {
        id: press
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPositionChanged: tile.pointed()
        onClicked: tile.activated()
    }
}
