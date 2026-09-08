import QtQuick
import QtQuick.Layouts
import "."

Item {
    id: root

    property bool toggled: false
    property bool down: false
    property bool hovered: navMouse.containsMouse
    property bool isFirst: false
    property bool isLast: false
    property bool compact: false

    property string iconName: ""
    property string label: ""
    property string badgeText: ""
    property color badgeColor: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimary : "#ff5252"
    property color badgeTextColor: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colOnPrimary : "#ffffff"

    signal clicked()

    Layout.fillWidth: true
    Layout.preferredHeight: 36
    implicitHeight: 36
    height: 36

    Rectangle {
        id: btnBg
        anchors.fill: parent
        radius: (typeof Appearance !== "undefined" && Appearance && Appearance.rounding) ? Appearance.rounding.normal : 6
        color: root.toggled
            ? ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimaryContainer : Qt.rgba(1, 0.3, 0.3, 0.15))
            : (root.hovered
                ? ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colLayer1Hover : Qt.rgba(1, 1, 1, 0.08))
                : "transparent")
        border.width: 1
        border.color: root.toggled
            ? ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimary : "#ff5252")
            : (root.hovered
                ? ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colOutline : Qt.rgba(1, 1, 1, 0.15))
                : "transparent")

        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 100 } }

        // Left accent indicator bar for active item (signature Ryoku style)
        Rectangle {
            visible: root.toggled
            anchors.left: parent.left
            anchors.leftMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 16
            radius: 1.5
            color: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimary : "#ff5252"
        }
    }

    MouseArea {
        id: navMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: root.down = true
        onReleased: root.down = false
        onCanceled: root.down = false
        onClicked: root.clicked()
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: root.compact ? 0 : 14
        anchors.rightMargin: root.compact ? 0 : 12

        RowLayout {
            anchors.fill: parent
            spacing: 10

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: root.iconName
                iconSize: 18
                fill: root.toggled ? 1 : 0
                color: root.toggled
                    ? ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimary : "#ff5252")
                    : (root.hovered
                        ? ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colOnSurface : "#ffffff")
                        : ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colOnSurfaceVariant : "#888888"))
            }

            StyledText {
                visible: !root.compact
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.label
                font.family: (typeof Appearance !== "undefined" && Appearance && Appearance.font) ? Appearance.font.family.main : "Space Grotesk"
                font.pixelSize: 13
                font.weight: root.toggled ? Font.Medium : Font.Normal
                color: root.toggled
                    ? ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colOnSurface : "#ffffff")
                    : (root.hovered
                        ? ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colOnSurface : "#ffffff")
                        : ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colOnSurfaceVariant : "#888888"))
                elide: Text.ElideRight
            }

            Rectangle {
                visible: root.badgeText !== ""
                Layout.alignment: Qt.AlignVCenter
                width: badgeTextItem.implicitWidth + 8
                height: 18
                radius: 4
                color: root.toggled
                    ? ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimary : "#ff5252")
                    : ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colLayer2 : "#222228")
                border.width: 1
                border.color: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colOutline : Qt.rgba(1, 1, 1, 0.1)

                StyledText {
                    id: badgeTextItem
                    anchors.centerIn: parent
                    text: root.badgeText
                    font.family: (typeof Appearance !== "undefined" && Appearance && Appearance.font) ? Appearance.font.family.mono : "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: root.toggled
                        ? ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colOnPrimary : "#ffffff")
                        : ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colOnSurfaceVariant : "#888888")
                }
            }
        }
    }
}
