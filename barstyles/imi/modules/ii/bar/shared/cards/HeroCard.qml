import QtQuick
import QtQuick.Layouts

import "../../../../common"
import "../../../../common/widgets"

Rectangle {
    id: heroCardRoot

    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    Layout.preferredWidth: implicitWidth
    implicitWidth: compactMode ? 320 : 380
    implicitHeight: compactMode ? 140 : 180

    property bool adaptiveWidth: false
    property bool compactMode: false
    
    // Internal animation control
    property bool startAnim: false
    
    onStartAnimChanged: {
        if (startAnim) {
            // Reset all internal elements
            shapeItem.scale = 0.8;
            shapeItem.rotation = -15;
            pill.opacity = 0.0;
            pillTranslate.x = 30;
            mainText.opacity = 0.0;
            mainText.scale = 0.9;
            subtitleText.opacity = 0.0;
            
            // Start animations after reset
            Qt.callLater(function() {
                shapeAnim.start();
                pillAnim.start();
                titleAnim.start();
                subtitleAnim.start();
            });
        }
    }

    radius: Appearance.rounding.normal
    color: Appearance.colors.colPrimaryContainer

    property int margins: compactMode ? 16 : 24
    property int iconSize: compactMode ? 64 : 110
    property real iconFontSize: compactMode ? 32 : 48

    property string shapeString: "Cookie9Sided"
    property string icon: ""
    property url iconUrl: ""

    property string title: ""
    property var parsedTitle: {
        var t = title || "";
        var match = t.match(/^(.*?)\s*([ap]m|[AP]M)$/);
        if (match) {
            return { main: match[1], ampm: match[2] };
        }
        return { main: t, ampm: "" };
    }
    property string subtitle: ""
    property int titleSize: compactMode ? Appearance.font.pixelSize.hugeass * 1.5 : Appearance.font.pixelSize.hugeass * 2.5
    property int subtitleSize: compactMode ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.hugeass

    property string pillText: ""
    property string pillIcon: ""

    property color pillColor: Appearance.colors.colOnPrimary
    property color pillTextColor: Appearance.colors.colOnSecondaryContainer
    property color pillIconColor: Appearance.colors.colOnSecondaryContainer

    property color shapeColor: Appearance.colors.colPrimary
    property color symbolColor: Appearance.colors.colOnPrimary
    property color textColor: Appearance.colors.colOnPrimaryContainer

    property alias shapeContent: shapeItem.data
    property alias shapeRotation: shapeItem.rotation
    property int spacing: 16

    Item {
        width: heroCardRoot.iconSize
        height: heroCardRoot.iconSize
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            margins: heroCardRoot.margins
        }

        MaterialShape {
            id: shapeItem
            shapeString: heroCardRoot.shapeString
            implicitSize: heroCardRoot.iconSize
            color: heroCardRoot.shapeColor
            anchors.centerIn: parent
            
            SequentialAnimation {
                id: shapeAnim
                PauseAnimation { duration: 80 }
                ParallelAnimation {
                    NumberAnimation { target: shapeItem; property: "scale"; from: 0.8; to: 1.0; duration: 1120; easing.type: Easing.OutBack }
                    NumberAnimation { target: shapeItem; property: "rotation"; from: -15; to: 0; duration: 1120; easing.type: Easing.OutCubic }
                }
            }
        }

        Image {
            id: iconImage
            visible: heroCardRoot.iconUrl.toString() !== "" && shapeItem.children.length === 0
            anchors.centerIn: parent
            source: heroCardRoot.iconUrl
            sourceSize: Qt.size(heroCardRoot.iconFontSize, heroCardRoot.iconFontSize)
            asynchronous: true
            fillMode: Image.PreserveAspectFit
        }

        MaterialSymbol {
            id: iconSymbol
            visible: heroCardRoot.icon !== "" && heroCardRoot.iconUrl.toString() === "" && shapeItem.children.length === 0
            anchors.centerIn: parent
            text: heroCardRoot.icon
            iconSize: heroCardRoot.iconFontSize
            color: heroCardRoot.symbolColor
            fill: 1
        }
    }

    Rectangle {
        id: pill
        visible: heroCardRoot.pillText !== "" && heroCardRoot.pillIcon !== ""
        implicitHeight: cityRow.implicitHeight + 12
        implicitWidth: cityRow.implicitWidth + 20
        radius: Appearance.rounding.full
        color: heroCardRoot.pillColor
        anchors {
            right: parent.right
            top: parent.top
            margins: heroCardRoot.margins
        }
        
        transform: Translate {
            id: pillTranslate
        }
        
        SequentialAnimation {
            id: pillAnim
            PauseAnimation { duration: 120 }
            ParallelAnimation {
                NumberAnimation { target: pill; property: "opacity"; from: 0.0; to: 1.0; duration: 280 }
                NumberAnimation { target: pillTranslate; property: "x"; from: 30; to: 0; duration: 350; easing.type: Easing.OutCubic }
            }
        }

        RowLayout {
            id: cityRow
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                text: heroCardRoot.pillIcon
                iconSize: Appearance.font.pixelSize.small
                color: heroCardRoot.pillIconColor
            }
            StyledText {
                renderType: Text.QtRendering
                antialiasing: true
                smooth: true
                text: heroCardRoot.pillText
                font {
                    weight: Font.Bold
                    pixelSize: Appearance.font.pixelSize.small
                }
                color: heroCardRoot.pillTextColor
                elide: Text.ElideRight
                Layout.maximumWidth: 120
                Layout.topMargin: 1 // to center the text
            }
        }
    }

    Item {
        id: textContainer
        anchors {
            left: parent.left
            leftMargin: heroCardRoot.iconSize + heroCardRoot.margins * 2 + 16
            right: parent.right
            rightMargin: heroCardRoot.margins
            top: pill.visible ? pill.bottom : parent.top
            topMargin: pill.visible ? heroCardRoot.margins : heroCardRoot.margins
            bottom: parent.bottom
            bottomMargin: heroCardRoot.margins
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                StyledText {
                    id: ampmText
                    text: heroCardRoot.parsedTitle.ampm
                    visible: text !== ""
                    font.pixelSize: heroCardRoot.titleSize * 0.45
                    renderType: Text.QtRendering
                    antialiasing: true
                    smooth: true
                    font.family: Appearance.font.family.title
                    font.weight: Font.Black
                    color: heroCardRoot.textColor
                    anchors {
                        right: parent.right
                        baseline: mainText.baseline
                    }
                }

                StyledText {
                    id: mainText
                    text: heroCardRoot.parsedTitle.main
                    font.pixelSize: heroCardRoot.titleSize
                    font.family: Appearance.font.family.title
                    renderType: Text.QtRendering
                    antialiasing: true
                    smooth: true
                    font.weight: Font.Black
                    color: heroCardRoot.textColor
                    anchors {
                        right: ampmText.visible ? ampmText.left : parent.right
                        rightMargin: ampmText.visible ? 4 : 0
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    
                    SequentialAnimation {
                        id: titleAnim
                        PauseAnimation { duration: 160 }
                        ParallelAnimation {
                            NumberAnimation { target: mainText; property: "opacity"; from: 0.0; to: 1.0; duration: 300 }
                            NumberAnimation { target: mainText; property: "scale"; from: 0.9; to: 1.0; duration: 380; easing.type: Easing.OutBack }
                        }
                    }
                }
            }

            StyledText {
                id: subtitleText
                text: heroCardRoot.subtitle
                renderType: Text.QtRendering
                antialiasing: true
                smooth: true
                Layout.fillWidth: true
                font {
                    pixelSize: heroCardRoot.subtitleSize
                    family: Appearance.font.family.title
                    weight: Font.Black
                }
                color: heroCardRoot.textColor
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                
                SequentialAnimation {
                    id: subtitleAnim
                    PauseAnimation { duration: 200 }
                    NumberAnimation { target: subtitleText; property: "opacity"; from: 0.0; to: 1.0; duration: 320 }
                }
            }
        }
    }
}
