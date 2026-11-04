import QtQuick
import QtQuick.Layouts

import "../../../../common"
import "../../../../common/widgets"

Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: 64
    radius: Appearance.rounding.full

    color: containerColor

    property string shapeString: "Circle"
    property int shapeSize: 40
    property string icon: ""

    property color containerColor: Appearance.colors.colSecondaryContainer
    property color shapeColor: Appearance.colors.colSecondary
    property color symbolColor: Appearance.colors.colOnSecondary
    property color textColor: Appearance.colors.colOnSecondaryContainer
    
    // Left Circle Interaction
    property bool leftInteractive: false
    property bool leftHovered: leftMa.containsMouse
    property real iconFill: 1
    signal leftClicked()

    // Right Circle Action Button
    property bool showRightShape: false
    property string rightShapeString: "Circle"
    property string rightIcon: "stop"
    property real rightIconFill: 1
    property color rightShapeColor: Appearance.colors.colErrorContainer
    property color rightSymbolColor: Appearance.colors.colOnErrorContainer
    property bool rightHovered: rightMa.containsMouse
    signal rightClicked()
    
    // Internal animation control
    property bool startAnim: false
    
    onStartAnimChanged: {
        if (startAnim) {
            // Reset elements
            shapeTranslate.x = -30;
            shapeItem.scale = 0.8;
            shapeItem.rotation = -10;
            if (showRightShape) {
                rightShapeTranslate.x = 30;
                rightShapeItem.scale = 0.8;
            }
            pillText.opacity = 0.0;
            textContainer.opacity = 0.0;
            
            // Start animations
            Qt.callLater(function() {
                shapeAnim.start();
                if (showRightShape && rightShapeContainer.visible) rightShapeAnim.start();
                textAnim.start();
            });
        }
    }

    default property alias shapeContent: shapeItem.children
    property alias text: pillText.text
    property alias textContent: textContainer.children

    Item {
        id: shapeContainer
        width: root.shapeSize
        height: root.shapeSize
        anchors {
            left: parent.left
            leftMargin: 12
            verticalCenter: parent.verticalCenter
        }
        
        transform: Translate {
            id: shapeTranslate
            x: 0
        }
        
        SequentialAnimation {
            id: shapeAnim
            PauseAnimation { duration: 60 }
            ParallelAnimation {
                NumberAnimation { target: shapeTranslate; property: "x"; from: -30; to: 0; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { target: shapeItem; property: "scale"; from: 0.8; to: 1.0; duration: 350; easing.type: Easing.OutBack }
                NumberAnimation { target: shapeItem; property: "rotation"; from: -10; to: 0; duration: 350; easing.type: Easing.OutCubic }
            }
        }

        MaterialShape {
            id: shapeItem
            shapeString: root.shapeString
            implicitSize: root.shapeSize
            color: root.leftInteractive && root.leftHovered ? Qt.lighter(root.shapeColor, 1.15) : root.shapeColor
            anchors.centerIn: parent
            scale: root.leftInteractive && root.leftHovered ? 1.08 : 1.0
            rotation: 0

            Behavior on scale {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            MaterialSymbol {
                id: iconSymbol
                visible: root.icon !== "" && shapeItem.children.length <= 1
                anchors.centerIn: parent
                text: root.icon
                iconSize: Appearance.font.pixelSize.large
                color: root.symbolColor
                fill: root.iconFill
            }
        }

        MouseArea {
            id: leftMa
            anchors.fill: parent
            enabled: root.leftInteractive
            hoverEnabled: root.leftInteractive
            cursorShape: Qt.PointingHandCursor
            onClicked: root.leftClicked()
        }
    }

    Item {
        id: rightShapeContainer
        visible: root.showRightShape
        width: root.shapeSize
        height: root.shapeSize
        anchors {
            right: parent.right
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }

        transform: Translate {
            id: rightShapeTranslate
            x: 0
        }

        SequentialAnimation {
            id: rightShapeAnim
            PauseAnimation { duration: 60 }
            ParallelAnimation {
                NumberAnimation { target: rightShapeTranslate; property: "x"; from: 30; to: 0; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { target: rightShapeItem; property: "scale"; from: 0.8; to: 1.0; duration: 350; easing.type: Easing.OutBack }
            }
        }

        MaterialShape {
            id: rightShapeItem
            shapeString: root.rightShapeString
            implicitSize: root.shapeSize
            color: root.rightHovered ? Qt.lighter(root.rightShapeColor, 1.15) : root.rightShapeColor
            anchors.centerIn: parent
            scale: root.rightHovered ? 1.08 : 1.0

            Behavior on scale {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            MaterialSymbol {
                id: rightIconSymbol
                visible: root.rightIcon !== ""
                anchors.centerIn: parent
                text: root.rightIcon
                iconSize: Appearance.font.pixelSize.large
                color: root.rightSymbolColor
                fill: root.rightIconFill
            }
        }

        MouseArea {
            id: rightMa
            anchors.fill: parent
            enabled: root.showRightShape
            hoverEnabled: root.showRightShape
            cursorShape: Qt.PointingHandCursor
            onClicked: root.rightClicked()
        }
    }

    Item {
        id: textContainer
        anchors {
            verticalCenter: parent.verticalCenter
            horizontalCenter: parent.horizontalCenter
            horizontalCenterOffset: root.showRightShape ? 0 : 9
        }
        opacity: 1.0
        
        Behavior on anchors.horizontalCenterOffset {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        SequentialAnimation {
            id: textAnim
            PauseAnimation { duration: 120 }
            NumberAnimation { target: textContainer; property: "opacity"; from: 0.0; to: 1.0; duration: 250 }
        }

        StyledText {
            id: pillText
            anchors.centerIn: parent
            font.pixelSize: Appearance.font.pixelSize.large
            font.family: Appearance.font.family.title
            font.weight: Font.Bold
            color: root.textColor
            visible: text !== "" && textContainer.children.length <= 1
        }
    }
}

