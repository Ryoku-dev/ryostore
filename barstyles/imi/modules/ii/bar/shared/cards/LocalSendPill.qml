import "../../../../common"
import "../../../../common/widgets"
import "../../../../../services"
import QtQuick
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true
    implicitHeight: 64
    radius: Appearance.rounding.full
    color: LocalSend.serverRunning ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHighest

    // Internal animation control
    property bool startAnim: false
    
    onStartAnimChanged: {
        if (startAnim) {
            // Reset elements
            shapeTranslate.x = -30;
            shapeItem.scale = 0.8;
            shapeItem.rotation = -10;
            statusText.opacity = 0.0;
            toggleBtn.scale = 0.8;
            toggleBtn.opacity = 0.0;
            
            // Start animations
            Qt.callLater(function() {
                shapeAnim.start();
                textAnim.start();
                btnAnim.start();
            });
        }
    }

    Item {
        id: shapeContainer
        width: 40
        height: 40
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
            shapeString: "Circle"
            implicitSize: 40
            color: LocalSend.serverRunning ? Appearance.colors.colPrimary : Appearance.colors.colError
            anchors.centerIn: parent
            scale: 1.0
            rotation: 0

            MaterialSymbol {
                anchors.centerIn: parent
                text: "devices"
                iconSize: Appearance.font.pixelSize.huge
                color: LocalSend.serverRunning ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondary
                fill: 1
            }
        }
    }

    RowLayout {
        anchors { left: parent.left; right: toggleBtn.left; verticalCenter: parent.verticalCenter; leftMargin: 64; rightMargin: 12 }

        StyledText {
            id: statusText
            Layout.fillWidth: true
            text: LocalSend.serverRunning ? Translation.tr("LocalSend • Running") : Translation.tr("LocalSend • Stopped")
            font.pixelSize: Appearance.font.pixelSize.large
            font.family: Appearance.font.family.title
            font.weight: Font.Bold
            color: LocalSend.serverRunning ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSecondaryContainer
            horizontalAlignment: Text.AlignHCenter
            opacity: 1.0
            
            SequentialAnimation {
                id: textAnim
                PauseAnimation { duration: 120 }
                NumberAnimation { target: statusText; property: "opacity"; from: 0.0; to: 1.0; duration: 250 }
            }
        }
    }

    RippleButton {
        id: toggleBtn
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        implicitWidth: 40
        implicitHeight: 40
        buttonRadius: Appearance.rounding.full
        colBackground: LocalSend.serverRunning ? Appearance.colors.colPrimary : Appearance.colors.colSecondary
        colBackgroundHover: LocalSend.serverRunning ? Appearance.colors.colPrimaryHover : Appearance.colors.colSecondaryHover
        scale: 1.0
        opacity: 1.0
        
        SequentialAnimation {
            id: btnAnim
            PauseAnimation { duration: 180 }
            ParallelAnimation {
                NumberAnimation { target: toggleBtn; property: "scale"; from: 0.8; to: 1.0; duration: 320; easing.type: Easing.OutBack }
                NumberAnimation { target: toggleBtn; property: "opacity"; from: 0.0; to: 1.0; duration: 280 }
            }
        }
        
        onClicked: {
            if (LocalSend.serverRunning) LocalSend.stopServer()
            else LocalSend.startServer()
        }
        MaterialSymbol {
            anchors {
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: 1 // QML whyyy, why do you need this
                horizontalCenter: parent.horizontalCenter
            }
            text: LocalSend.serverRunning ? "stop_circle" : "play_circle"
            iconSize: Appearance.font.pixelSize.huge
            color: LocalSend.serverRunning ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondary
            fill: 1
        }
    }
}
